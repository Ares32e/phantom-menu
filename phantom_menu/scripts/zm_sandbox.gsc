// zm_sandbox - place props in a Zombies match from a settings file (Kronos, BO7).
// Driven by the Kronos Map Builder. REWRITTEN 2026-11-04 (the 2026-11-03 file was lost;
// rebuilt from the recovered pieces of it plus the builder's file format).
//
// Settings: kronos\sandbox\settings.json, read every second (live, no restart):
//   enabled       1 = props on, 0 = all removed
//   p1..pN        one prop each: "model x y z yaw pitch roll" (pitch/roll optional)
//   slots         N, how many p keys are read (default 50, max 1000, live)
//   spawn_rate    new props spawned per second at most (default 50)
//   max_entities  stop spawning when the map's entity count reaches this (default 900)
//   collide       0 off, 1 zombies avoid only (solid), 2 copy brush onto the prop,
//                 3 invisible block (copy of brush clip_brush on a helper entity)
//   clip_brush    which of the map's brushes to copy (see "brushes" / "brush_near")
//   any_model     1 = try any model name (other maps' models spawn invisible)
//   run           one-off command, emptied after it runs:
//                   pos | tp x y z | scan | map_props | brushes | brush_near |
//                   load <zone> <model> | loaded <zone> | unload <zone> | del <slot>
// Debug: kronos\sandbox_dbg\state.json (map, reloads, models "a|b|c", pos, brush_near,
//        map_props, last_run, slots, entities, waiting, slotN, collideN).
// Map props list: kronos\sandbox_map\<map>.json  e1..eN = "model x y z yaw pitch roll".
//
// Kronos loses locals across a wait: each tick is its own call and all state
// lives on level.zm_sb_* / player fields.

#using script_3f8889c16399185c;
#using script_4c770a9a4ad7659c;

autoexec zm_sb_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_sb_init_is_zombies())
    {
        return;
    }
    level.zm_sb_slots = 50;     // live: setting "slots" (1..1000)
    level.zm_sb_slot_max = 1000;
    level.zm_sb_quiet = 0;      // 1 = debug writes wait for one save at the end of a reload
    level.zm_sb_budget = 0;     // new props still allowed this reload ("spawn_rate")
    level.zm_sb_ents = 0;       // entity count estimate during a reload
    level.zm_sb_ent_limit = 900; // live: setting "max_entities"
    level.zm_sb_waiting = 0;    // slots held back by spawn_rate / max_entities
    level.zm_sb_tick = 1;
    level.zm_sb_reloads = 0;
    level.zm_sb_props = [];
    level.zm_sb_spec = [];
    level.zm_sb_known = [];
    level.zm_sb_model_list = [];
    level.zm_sb_brushes = [];
    level.zm_sb_collide_now = -1;
    level.zm_sb_clip_now = -1;
    level namespace_42ffbe510c7bd5b1::function_3e93ae4f7823fe81(#"player_spawned", &zm_sb_spawned);
    nengine_store_clear("sandbox_dbg");
    zm_sb_defaults();
    zm_sb_dbg("init", 1);
}

zm_sb_dbg(key, value)
{
    if (!isdefined(value))
    {
        value = "undefined";
    }
    nengine_store_set("sandbox_dbg", key, value);
    if (level.zm_sb_quiet != 1)
    {
        nengine_store_save("sandbox_dbg", "state");
    }
}

// ---------------------------------------------------------------- settings

zm_sb_defaults()
{
    nengine_store_load("sandbox", "settings");
    if (zm_sb_int("version", 0) < 1)
    {
        nengine_store_set("sandbox", "version", 1);
        nengine_store_set("sandbox", "enabled", 1);
        nengine_store_set("sandbox", "collide", 3);
        nengine_store_set("sandbox", "clip_brush", 0);
        nengine_store_set("sandbox", "any_model", 0);
        nengine_store_set("sandbox", "slots", 50);
        nengine_store_set("sandbox", "spawn_rate", 50);
        nengine_store_set("sandbox", "max_entities", 900);
        nengine_store_set("sandbox", "run", "");
        nengine_store_save("sandbox", "settings");
    }
}

zm_sb_str(key)
{
    v = nengine_store_get("sandbox", key);
    if (!isdefined(v) || !isstring(v))
    {
        return "";
    }
    return v;
}

// Numbers typed into the file can come back as int, float or text.
zm_sb_int(key, fallback)
{
    v = nengine_store_get("sandbox", key);
    if (!isdefined(v))
    {
        return fallback;
    }
    if (isint(v))
    {
        return v;
    }
    if (isfloat(v))
    {
        return int(v);
    }
    if (isstring(v))
    {
        if (v == "")
        {
            return fallback;
        }
        return int(v);
    }
    return fallback;
}

zm_sb_num(w, i)
{
    if (w.size > i)
    {
        return float(w[i]);
    }
    return 0;
}

zm_sb_vec(v)
{
    return int(v[0]) + " " + int(v[1]) + " " + int(v[2]);
}

// ---------------------------------------------------------------- player

zm_sb_spawned(params)
{
    if (isdefined(self.zm_sb) || !self function_b36623eefe0028c8())
    {
        return;
    }
    self.zm_sb = 1;
    zm_sb_dbg("spawned", 1);
    self iprintln("^5Sandbox^7 loaded - build with the Kronos Map Builder");
    if (!isdefined(level.zm_sb_running))
    {
        level.zm_sb_running = 1;
        level.zm_sb_player = self;
        level.zm_sb_map = zm_sb_mapname();
        zm_sb_dbg("map", level.zm_sb_map);
        zm_sb_scan();
        zm_sb_scan_brushes();
        zm_sb_reload();
        level thread zm_sb_loop();
    }
}

zm_sb_mapname()
{
    m = level.script;
    if (!isdefined(m) || !isstring(m) || m == "")
    {
        m = getdvar(@"mapname");
    }
    if (!isdefined(m) || !isstring(m))
    {
        return "unknown";
    }
    return m;
}

zm_sb_loop()
{
    while (1)
    {
        level zm_sb_reload();
        wait level.zm_sb_tick;
    }
}

zm_sb_reload()
{
    level.zm_sb_reloads++;
    nengine_store_load("sandbox", "settings");
    enabled = zm_sb_int("enabled", 1);
    // Run a one-off command, then clear it so the same one can be sent again.
    cmd = zm_sb_str("run");
    if (cmd != "")
    {
        nengine_store_set("sandbox", "run", "");
        nengine_store_save("sandbox", "settings");
        out = zm_sb_command(cmd);
        zm_sb_dbg("last_run", cmd + " -> " + out);
        if (isdefined(level.zm_sb_player))
        {
            level.zm_sb_player iprintln("^5Sandbox^7 " + cmd + " ^3" + out);
        }
    }
    // Collision mode or source brush changed: rebuild every prop with it.
    collide = zm_sb_int("collide", 3);
    clip = zm_sb_int("clip_brush", 0);
    if (collide != level.zm_sb_collide_now || clip != level.zm_sb_clip_now)
    {
        level.zm_sb_collide_now = collide;
        level.zm_sb_clip_now = clip;
        zm_sb_respawn_all();
        zm_sb_dbg("collide_now", "mode " + collide + " brush " + clip);
    }
    // Slot count (live). Shrinking removes the props above the new count.
    n = zm_sb_int("slots", 50);
    if (n < 1)
    {
        n = 1;
    }
    if (n > level.zm_sb_slot_max)
    {
        n = level.zm_sb_slot_max;
    }
    for (i = n + 1; i <= level.zm_sb_slots; i++)
    {
        zm_sb_clear_slot(i);
    }
    level.zm_sb_slots = n;
    // Spawn at most spawn_rate new props per second, and never let the map's
    // total entity count pass max_entities (running out of entities can end the match).
    level.zm_sb_budget = zm_sb_int("spawn_rate", 50);
    level.zm_sb_ent_limit = zm_sb_int("max_entities", 900);
    level.zm_sb_ents = getentarray().size;
    level.zm_sb_waiting = 0;
    level.zm_sb_quiet = 1;
    count = 0;
    for (i = 1; i <= level.zm_sb_slots; i++)
    {
        spec = "";
        if (enabled == 1)
        {
            spec = zm_sb_str("p" + i);
        }
        zm_sb_apply(i, spec);
        if (isdefined(level.zm_sb_props[i]))
        {
            count++;
        }
    }
    level.zm_sb_quiet = 0;
    zm_sb_dbg("slots", level.zm_sb_slots);
    zm_sb_dbg("entities", level.zm_sb_ents + " of max " + level.zm_sb_ent_limit);
    zm_sb_dbg("waiting", level.zm_sb_waiting);
    zm_sb_dbg("props", count);
    zm_sb_dbg("reloads", level.zm_sb_reloads);
}

// ---------------------------------------------------------------- props

zm_sb_clear_slot(i)
{
    if (isdefined(level.zm_sb_props[i]))
    {
        level.zm_sb_props[i] zm_sb_kill();
    }
    level.zm_sb_props[i] = undefined;
    level.zm_sb_spec[i] = "";
}

zm_sb_apply(i, spec)
{
    old = level.zm_sb_spec[i];
    if (!isdefined(old))
    {
        old = "";
    }
    if (!isdefined(spec))
    {
        spec = "";
    }
    if (spec == old)
    {
        return;
    }
    level.zm_sb_spec[i] = spec;
    ent = level.zm_sb_props[i];
    if (spec == "")
    {
        if (isdefined(ent))
        {
            ent zm_sb_kill();
        }
        level.zm_sb_props[i] = undefined;
        zm_sb_dbg("slot" + i, "");
        return;
    }
    w = strtok(spec, " ");
    if (w.size < 4)
    {
        zm_sb_dbg("slot" + i, "need: model x y z [yaw pitch roll]");
        return;
    }
    model = w[0];
    if (!zm_sb_model_ok(model))
    {
        zm_sb_dbg("slot" + i, "model not used on this map: " + model + " (run scan, or set any_model 1)");
        if (isdefined(ent))
        {
            ent zm_sb_kill();
        }
        level.zm_sb_props[i] = undefined;
        return;
    }
    pos = (float(w[1]), float(w[2]), float(w[3]));
    ang = (zm_sb_num(w, 5), zm_sb_num(w, 4), zm_sb_num(w, 6));
    if (isdefined(ent) && isdefined(ent.zm_sb_model) && ent.zm_sb_model == model)
    {
        ent.origin = pos;
        ent.angles = ang;
        if (isdefined(ent.zm_sb_helper))
        {
            ent.zm_sb_helper.origin = pos;
            ent.zm_sb_helper.angles = ang;
        }
    }
    else
    {
        // Out of this second's spawn budget, or at the entity cap: try again next reload.
        if (level.zm_sb_budget <= 0 || level.zm_sb_ents + 2 > level.zm_sb_ent_limit)
        {
            level.zm_sb_spec[i] = old;
            level.zm_sb_waiting++;
            zm_sb_dbg("slot" + i, "waiting (spawn_rate / max_entities) " + spec);
            return;
        }
        level.zm_sb_budget--;
        if (isdefined(ent))
        {
            ent zm_sb_kill();
            level.zm_sb_ents--;
        }
        ent = spawn("script_model", pos);
        level.zm_sb_ents++;
        ent setmodel(model);
        ent.zm_sb_model = model;
        ent.angles = ang;
        level.zm_sb_props[i] = ent;
        level.zm_sb_col_msg = "none";
        ent zm_sb_collide();
        if (isdefined(ent.zm_sb_helper))
        {
            level.zm_sb_ents++;
        }
        zm_sb_dbg("collide" + i, level.zm_sb_col_msg);
    }
    zm_sb_dbg("slot" + i, "ok " + spec);
}

zm_sb_kill()
{
    if (isdefined(self.zm_sb_helper))
    {
        self.zm_sb_helper delete();
    }
    self delete();
}

zm_sb_respawn_all()
{
    for (i = 1; i <= level.zm_sb_slots; i++)
    {
        zm_sb_clear_slot(i);
    }
}

zm_sb_model_ok(model)
{
    if (zm_sb_int("any_model", 0) == 1)
    {
        return 1;
    }
    if (isdefined(level.zm_sb_known["" + model]))
    {
        return 1;
    }
    // Models from transient files this mod loaded ("load" command), once loaded.
    if (isdefined(level.zm_sb_tr_zone) && isdefined(level.zm_sb_tr_zone["" + model]))
    {
        return isinfiltransientloaded(level.zm_sb_tr_zone["" + model]);
    }
    return 0;
}

// ---------------------------------------------------------------- collision
// BO7 props have no collision of their own (solid() only makes zombies walk
// around them). The game gives props collision by copying a brush's shape:
//   collide 2 = copy brush clip_brush onto the prop itself
//   collide 3 = copy it onto an invisible helper at the prop

zm_sb_collide()
{
    mode = level.zm_sb_collide_now;
    if (mode <= 0)
    {
        self notsolid();
        level.zm_sb_col_msg = "off";
        return;
    }
    self solid();
    if (mode == 1)
    {
        level.zm_sb_col_msg = "solid (zombies avoid)";
        return;
    }
    b = level.zm_sb_clip_now;
    if (b < 0 || b >= level.zm_sb_brushes.size || !isdefined(level.zm_sb_brushes[b]))
    {
        level.zm_sb_col_msg = "solid only: no brush " + b + " (map has " + level.zm_sb_brushes.size + ")";
        return;
    }
    brush = level.zm_sb_brushes[b];
    if (mode == 2)
    {
        self clonebrushmodeltoscriptmodel(brush);
        level.zm_sb_col_msg = "brush " + b + " on prop";
        return;
    }
    h = spawn("script_model", self.origin);
    h.angles = self.angles;
    h clonebrushmodeltoscriptmodel(brush);
    h solid();
    self.zm_sb_helper = h;
    level.zm_sb_col_msg = "block from brush " + b;
}

// ---------------------------------------------------------------- scans

// Every model the map is using right now: these are the ones that can be placed.
zm_sb_scan()
{
    ents = getentarray();
    for (i = 0; i < ents.size; i++)
    {
        zm_sb_scan_one(ents[i]);
    }
    s = "";
    for (i = 0; i < level.zm_sb_model_list.size; i++)
    {
        if (i > 0)
        {
            s = s + "|";
        }
        s = s + level.zm_sb_model_list[i];
    }
    zm_sb_dbg("models", s);
    return level.zm_sb_model_list.size + " models on this map";
}

zm_sb_scan_one(e)
{
    if (!isdefined(e) || !isdefined(e.model))
    {
        return;
    }
    m = "" + e.model;
    if (m == "" || issubstr(m, "*") || isdefined(level.zm_sb_known[m]))
    {
        return;
    }
    level.zm_sb_known[m] = 1;
    level.zm_sb_model_list[level.zm_sb_model_list.size] = m;
}

// Brush models ("*N") the collision modes can copy.
zm_sb_scan_brushes()
{
    level.zm_sb_brushes = [];
    ents = getentarray();
    for (i = 0; i < ents.size; i++)
    {
        e = ents[i];
        if (zm_sb_is_brush(e))
        {
            level.zm_sb_brushes[level.zm_sb_brushes.size] = e;
        }
    }
    zm_sb_dbg("brushes", level.zm_sb_brushes.size);
    return level.zm_sb_brushes.size + " brushes";
}

// A brush entity: classname script_brushmodel (the map's "*N" models). The model name
// isn't always readable as "*N" in BO7, so check the classname first.
zm_sb_is_brush(e)
{
    if (!isdefined(e))
    {
        return 0;
    }
    if (isdefined(e.zm_sb_model))
    {
        return 0;
    }
    if (isdefined(e.classname) && e.classname == "script_brushmodel")
    {
        return 1;
    }
    if (isdefined(e.model) && issubstr("" + e.model, "*"))
    {
        return 1;
    }
    return 0;
}

zm_sb_brush_near(p)
{
    best = -1;
    bd = 0;
    for (i = 0; i < level.zm_sb_brushes.size; i++)
    {
        b = level.zm_sb_brushes[i];
        if (!isdefined(b))
        {
            continue;
        }
        dx = b.origin[0] - p.origin[0];
        dy = b.origin[1] - p.origin[1];
        dz = b.origin[2] - p.origin[2];
        d = dx * dx + dy * dy + dz * dz;
        if (best < 0 || d < bd)
        {
            best = i;
            bd = d;
        }
    }
    if (best < 0)
    {
        s = "-1 no brushes on this map";
    }
    else
    {
        b = level.zm_sb_brushes[best];
        s = best + " " + b.model + " at " + zm_sb_vec(b.origin);
    }
    zm_sb_dbg("brush_near", s);
    return s;
}

// Every placed model entity of the map -> kronos\sandbox_map\<map>.json (e1..eN).
zm_sb_map_props()
{
    nengine_store_clear("sandbox_map");
    ents = getentarray();
    level.zm_sb_mp_n = 0;
    for (i = 0; i < ents.size; i++)
    {
        zm_sb_map_prop(ents[i]);
    }
    nengine_store_set("sandbox_map", "count", level.zm_sb_mp_n);
    nengine_store_save("sandbox_map", level.zm_sb_map);
    s = level.zm_sb_mp_n + " map props (" + zm_sb_time() + ")";
    zm_sb_dbg("map_props", s);
    return s;
}

zm_sb_map_prop(e)
{
    if (!isdefined(e) || !isdefined(e.model) || isdefined(e.zm_sb_model))
    {
        return;
    }
    m = "" + e.model;
    if (m == "" || issubstr(m, "*"))
    {
        return;
    }
    a = e.angles;
    if (!isdefined(a))
    {
        a = (0, 0, 0);
    }
    level.zm_sb_mp_n++;
    nengine_store_set("sandbox_map", "e" + level.zm_sb_mp_n, m + " " + zm_sb_vec(e.origin) + " " + int(a[1]) + " " + int(a[0]) + " " + int(a[2]));
}

// Changes every call so the builder sees a new message.
zm_sb_time()
{
    return "reload " + level.zm_sb_reloads;
}

// ---------------------------------------------------------------- commands

zm_sb_command(cmd)
{
    p = level.zm_sb_player;
    if (!isdefined(p))
    {
        return "no player yet";
    }
    w = strtok(cmd, " ");
    if (w.size == 0)
    {
        return "empty";
    }
    c = w[0];
    // "load <transient zone> <model>": load a model's own _tr file into this
    // match (game function loadinfiltransient), then allow <model> in slots.
    // Zone = the .ff file name without .ff, e.g.
    //   load mp_ww_prop_sat_3_pumpkins_execution_tr prop_sat_3_pumpkins_execution
    if (c == "load" && w.size > 2)
    {
        if (!isdefined(level.zm_sb_tr_zone))
        {
            level.zm_sb_tr_zone = [];
        }
        loadinfiltransient(w[1]);
        level.zm_sb_tr_zone[w[2]] = w[1];
        return "loading " + w[1] + " for " + w[2] + " (check with: loaded " + w[1] + ")";
    }
    if (c == "loaded" && w.size > 1)
    {
        return "loaded " + isinfiltransientloaded(w[1]);
    }
    if (c == "unload" && w.size > 1)
    {
        unloadinfiltransient(w[1]);
        return "unloading " + w[1];
    }
    if (c == "pos")
    {
        a = p getplayerangles();
        s = zm_sb_vec(p.origin) + " " + int(a[1]);
        zm_sb_dbg("pos", s);
        return s;
    }
    if (c == "tp" && w.size > 3)
    {
        p setorigin((float(w[1]), float(w[2]), float(w[3])));
        return "moved";
    }
    if (c == "scan")
    {
        return zm_sb_scan();
    }
    if (c == "brushes")
    {
        return zm_sb_scan_brushes();
    }
    if (c == "brush_near")
    {
        return zm_sb_brush_near(p);
    }
    if (c == "map_props")
    {
        return zm_sb_map_props();
    }
    if (c == "del" && w.size > 1)
    {
        i = int(w[1]);
        zm_sb_clear_slot(i);
        nengine_store_set("sandbox", "p" + i, "");
        nengine_store_save("sandbox", "settings");
        return "slot " + i + " emptied";
    }
    return "unknown command";
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_sb_init_is_zombies()
{
    level.zm_sb_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_sb_init_gt) || level.zm_sb_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_sb_init_gt, 0, 2) == "zm";
}
