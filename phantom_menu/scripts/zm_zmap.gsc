// zm_zmap - "Zombies map" mode for the Kronos Map Builder (Kronos, BO7 Zombies).
// Turns an area you built with the sandbox into its own little map:
//   - Play: you are moved to your player start,
//   - every zombie the game spawns is moved to one of your zombie spawners,
//   - leave the play area and you are put back at the start.
//
// Settings: kronos\zmap\settings.json, read every 0.5 s (live, no restart):
//   active    1 = map running, 0 = off (normal game)
//   start     "x y z" player start
//   spawners  "x y z;x y z;..." zombie spawn points (max 64)
//   area      "x0 y0 z0 x1 y1 z1" play area box ("" = no box)
//   keep_in   1 = pull players / zombies back into the area
// Debug: kronos\zmap_dbg\state.json
//
// Kronos loses locals across a wait: every tick is its own call and all state
// lives on level.zm_zm_*.

#using script_3f8889c16399185c;
#using script_4c770a9a4ad7659c;

autoexec zm_zm_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_zm_init_is_zombies())
    {
        return;
    }
    level.zm_zm_on = 0;
    level.zm_zm_moved = 0;
    level.zm_zm_pulled = 0;
    level.zm_zm_ticks = 0;
    level.zm_zm_spawners = [];
    level.zm_zm_has_area = 0;
    level namespace_42ffbe510c7bd5b1::function_3e93ae4f7823fe81(#"player_spawned", &zm_zm_spawned);
    nengine_store_clear("zmap_dbg");
    nengine_store_load("zmap", "settings");
    v = nengine_store_get("zmap", "active");
    if (!isdefined(v))
    {
        nengine_store_set("zmap", "active", 0);
        nengine_store_set("zmap", "start", "");
        nengine_store_set("zmap", "spawners", "");
        nengine_store_set("zmap", "area", "");
        nengine_store_set("zmap", "keep_in", 1);
        nengine_store_save("zmap", "settings");
    }
    zm_zm_dbg("init", 1);
}

zm_zm_dbg(key, value)
{
    if (!isdefined(value))
    {
        value = "undefined";
    }
    nengine_store_set("zmap_dbg", key, value);
    nengine_store_save("zmap_dbg", "state");
}

zm_zm_str(key)
{
    v = nengine_store_get("zmap", key);
    if (!isdefined(v) || !isstring(v))
    {
        return "";
    }
    return v;
}

zm_zm_int(key, fallback)
{
    v = nengine_store_get("zmap", key);
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
    if (isstring(v) && v != "")
    {
        return int(v);
    }
    return fallback;
}

zm_zm_vec(s)
{
    w = strtok(s, " ");
    if (w.size < 3)
    {
        return undefined;
    }
    return (float(w[0]), float(w[1]), float(w[2]));
}

zm_zm_spawned(params)
{
    if (isdefined(self.zm_zm) || !self function_b36623eefe0028c8())
    {
        return;
    }
    self.zm_zm = 1;
    if (!isdefined(level.zm_zm_running))
    {
        level.zm_zm_running = 1;
        level.zm_zm_player = self;
        zm_zm_dbg("spawned", 1);
        level thread zm_zm_loop();
    }
}

zm_zm_loop()
{
    while (1)
    {
        level zm_zm_tick();
        wait 0.5;
    }
}

zm_zm_tick()
{
    level.zm_zm_ticks++;
    nengine_store_load("zmap", "settings");
    on = zm_zm_int("active", 0);
    if (on != 1)
    {
        if (level.zm_zm_on == 1)
        {
            level.zm_zm_on = 0;
            zm_zm_dbg("active", 0);
            if (isdefined(level.zm_zm_player))
            {
                level.zm_zm_player iprintln("^5Zombies map^7 stopped");
            }
        }
        return;
    }
    zm_zm_read();
    p = level.zm_zm_player;
    if (level.zm_zm_on != 1)
    {
        // just started: put the player at the start
        level.zm_zm_on = 1;
        level.zm_zm_moved = 0;
        level.zm_zm_pulled = 0;
        if (isdefined(p) && isdefined(level.zm_zm_start))
        {
            p setorigin(level.zm_zm_start + (0, 0, 8));
            p iprintln("^5Zombies map^7 started - " + level.zm_zm_spawners.size + " zombie spawners");
        }
        zm_zm_dbg("active", 1);
    }
    keep = zm_zm_int("keep_in", 1);
    if (isdefined(p) && isalive(p) && keep == 1 && level.zm_zm_has_area == 1 && isdefined(level.zm_zm_start) && !zm_zm_inside(p.origin, 64))
    {
        p setorigin(level.zm_zm_start + (0, 0, 8));
        level.zm_zm_pulled++;
        zm_zm_dbg("player_pulled_back", level.zm_zm_pulled);
    }
    if (level.zm_zm_spawners.size == 0)
    {
        return;
    }
    ais = getaiarray();
    level.zm_zm_alive = ais.size;
    for (i = 0; i < ais.size; i++)
    {
        zm_zm_ai(ais[i], keep);
    }
    if (level.zm_zm_ticks % 4 == 0)
    {
        zm_zm_dbg("zombies", "moved to spawners so far " + level.zm_zm_moved + ", alive now " + level.zm_zm_alive);
    }
}

// Read start / spawners / area from the settings (they can change while playing).
zm_zm_read()
{
    level.zm_zm_start = zm_zm_vec(zm_zm_str("start"));
    sp = zm_zm_str("spawners");
    if (!isdefined(level.zm_zm_sp_text) || level.zm_zm_sp_text != sp)
    {
        level.zm_zm_sp_text = sp;
        level.zm_zm_spawners = [];
        parts = strtok(sp, ";");
        for (i = 0; i < parts.size && i < 64; i++)
        {
            v = zm_zm_vec(parts[i]);
            if (isdefined(v))
            {
                level.zm_zm_spawners[level.zm_zm_spawners.size] = v;
            }
        }
        zm_zm_dbg("spawners", level.zm_zm_spawners.size);
    }
    a = strtok(zm_zm_str("area"), " ");
    level.zm_zm_has_area = 0;
    if (a.size >= 6)
    {
        level.zm_zm_has_area = 1;
        level.zm_zm_lo = (float(a[0]), float(a[1]), float(a[2]));
        level.zm_zm_hi = (float(a[3]), float(a[4]), float(a[5]));
    }
}

zm_zm_inside(pos, extra)
{
    if (level.zm_zm_has_area != 1)
    {
        return 1;
    }
    lo = level.zm_zm_lo;
    hi = level.zm_zm_hi;
    if (pos[0] < lo[0] - extra || pos[0] > hi[0] + extra || pos[1] < lo[1] - extra || pos[1] > hi[1] + extra)
    {
        return 0;
    }
    if (pos[2] < lo[2] - extra - 200 || pos[2] > hi[2] + extra + 200)
    {
        return 0;
    }
    return 1;
}

// One call per zombie so one odd AI can't stop the rest.
zm_zm_ai(ai, keep)
{
    if (!isdefined(ai) || !isalive(ai))
    {
        return;
    }
    if (isdefined(ai.zm_zm_done) && (keep != 1 || zm_zm_inside(ai.origin, 256)))
    {
        return;
    }
    ai.zm_zm_done = 1;
    s = level.zm_zm_spawners[randomint(level.zm_zm_spawners.size)];
    ai forceteleport(s + (randomfloatrange(-24, 24), randomfloatrange(-24, 24), 8), (0, randomint(360), 0));
    level.zm_zm_moved++;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_zm_init_is_zombies()
{
    level.zm_zm_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_zm_init_gt) || level.zm_zm_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_zm_init_gt, 0, 2) == "zm";
}
