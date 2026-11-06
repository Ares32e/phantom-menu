// zm_zspawn - spawn any zombie / boss type that the current map has loaded
// (Kronos). Driven by the Kronos Map Builder Enemies panel.
//
// Settings: kronos\spawnmenu\settings.json, read every 0.5 s.
//   run   "spawn <ai type> [count] [distance]"
//         e.g. "spawn sat_spawner_zombie_abom_zm 1 300"
//         "spawn <ai type> [count] [distance] [scale] [statue]"
//           scale  size factor (1 = normal, e.g. 8 = giant; 0.1..40)
//           statue 1 = pinned in place (linked to an invisible anchor)
//         "scale <factor>" resizes everything this mod spawned (live)
//         "clear" removes everything this mod spawned.
//         Runs once, then the mod empties it.
// Debug: kronos\spawnmenu_dbg\state.json
//
// Uses the game's own spawn-by-name helper in script_4db5d44a376c1c35
// (namespace_85d424ad210ad4c9::function_35dc52fde01c4d08(type, origin,
// angles, team)). It adds the "actor_" prefix and quietly does nothing if
// the type isn't loaded on this map, so other maps' bosses can't break it.
// Named zm_zspawn so it links last: a failure here can't stop other mods.

#using script_1eaed13c599e2b34;
#using script_2301d27669c5a079;
#using script_25a8fa2ac8997425;
#using script_315d0ecfeb067b1c;
#using script_3a9d7a7cfee99885;
#using script_3b64eb40368c1450;
#using script_3f8889c16399185c;
#using script_427ce33ec0c820cf;
#using script_4c770a9a4ad7659c;
#using script_4e3b2b1d9542e66b;
#using script_4f24ca7a470a5fa8;
#using script_4fca32f463c5e4fa;
#using script_554830d27078277d;
#using script_692b19b8e5f8f9e8;
#using script_724b8f06df0c96b1;
#using script_734dce84c468439b;
#using script_74f99c09414692fa;
#using script_aa3bac81ad4fc8e;
#using script_4db5d44a376c1c35;

autoexec zm_zs_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_zs_init_is_zombies())
    {
        return;
    }
    level.zm_zs_ticks = 0;
    level.zm_zs_spawned = [];
    level.zm_zs_total = 0;
    level namespace_42ffbe510c7bd5b1::function_3e93ae4f7823fe81(#"player_spawned", &zm_zs_spawned_cb);
    nengine_store_clear("spawnmenu_dbg");
    nengine_store_load("spawnmenu", "settings");
    nengine_store_set("spawnmenu", "run", "");
    nengine_store_set("spawnmenu", "version", 1);
    nengine_store_save("spawnmenu", "settings");
    zm_zs_dbg("init", 1);
}

zm_zs_dbg(key, value)
{
    if (!isdefined(value))
    {
        value = "undefined";
    }
    nengine_store_set("spawnmenu_dbg", key, value);
    nengine_store_save("spawnmenu_dbg", "state");
}

zm_zs_spawned_cb(params)
{
    if (isdefined(self.zm_zs) || !self function_b36623eefe0028c8())
    {
        return;
    }
    self.zm_zs = 1;
    if (!isdefined(level.zm_zs_running))
    {
        level.zm_zs_running = 1;
        level.zm_zs_player = self;
        zm_zs_dbg("spawned", 1);
        level thread zm_zs_loop();
    }
}

zm_zs_loop()
{
    while (1)
    {
        level zm_zs_tick();
        wait 0.5;
    }
}

zm_zs_tick()
{
    level.zm_zs_ticks++;
    nengine_store_load("spawnmenu", "settings");
    cmd = nengine_store_get("spawnmenu", "run");
    if (!isdefined(cmd) || !isstring(cmd) || cmd == "")
    {
        return;
    }
    nengine_store_set("spawnmenu", "run", "");
    nengine_store_save("spawnmenu", "settings");
    level.zm_zs_out = "?";
    zm_zs_command(cmd);
    zm_zs_dbg("last_run", cmd + " -> " + level.zm_zs_out);
    if (isdefined(level.zm_zs_player))
    {
        level.zm_zs_player iprintln("^5Spawn^7 " + level.zm_zs_out);
    }
}

zm_zs_command(cmd)
{
    w = strtok(cmd, " ");
    if (w.size == 0)
    {
        return;
    }
    if (w[0] == "clear")
    {
        zm_zs_clear();
        return;
    }
    if (w[0] == "scale" && w.size > 1)
    {
        level.zm_zs_scale = zm_zs_clamp_scale(float(w[1]));
        n = 0;
        for (i = 0; i < level.zm_zs_spawned.size; i++)
        {
            ai = level.zm_zs_spawned[i];
            if (isdefined(ai))
            {
                ai setscale(level.zm_zs_scale);
                n++;
            }
        }
        level.zm_zs_out = "scaled " + n + " to " + level.zm_zs_scale;
        return;
    }
    if (w[0] != "spawn" || w.size < 2)
    {
        level.zm_zs_out = "unknown command";
        return;
    }
    count = 1;
    dist = 300;
    if (w.size > 2)
    {
        count = int(w[2]);
    }
    if (w.size > 3)
    {
        dist = int(w[3]);
    }
    if (count < 1)
    {
        count = 1;
    }
    if (count > 24)
    {
        count = 24;
    }
    level.zm_zs_scale = 1;
    level.zm_zs_statue = 0;
    if (w.size > 4)
    {
        level.zm_zs_scale = zm_zs_clamp_scale(float(w[4]));
    }
    if (w.size > 5)
    {
        level.zm_zs_statue = int(w[5]);
    }
    level.zm_zs_type = w[1];
    level.zm_zs_ok = 0;
    for (i = 0; i < count; i++)
    {
        zm_zs_spawn_one(i, count, dist);
    }
    if (level.zm_zs_ok == 0)
    {
        level.zm_zs_out = "nothing spawned: " + level.zm_zs_type + " is not loaded on this map";
    }
    else
    {
        level.zm_zs_out = "spawned " + level.zm_zs_ok + " x " + level.zm_zs_type + " scale " + level.zm_zs_scale + (level.zm_zs_statue == 1 ? " statue" : "");
    }
}

zm_zs_clamp_scale(s)
{
    if (s < 0.1)
    {
        return 0.1;
    }
    if (s > 40)
    {
        return 40;
    }
    return s;
}

// One AI, spread in an arc in front of the player.
zm_zs_spawn_one(i, count, dist)
{
    p = level.zm_zs_player;
    if (!isdefined(p))
    {
        return;
    }
    yaw = 0;
    a = p.angles;
    if (isdefined(a))
    {
        yaw = a[1];
    }
    off = 0;
    if (count > 1)
    {
        off = (i - (count - 1) / 2) * 12;
    }
    dir = anglestoforward((0, yaw + off, 0));
    pos = p.origin + dir * dist;
    ai = namespace_85d424ad210ad4c9::function_35dc52fde01c4d08(level.zm_zs_type, pos, (0, yaw + 180, 0), "axis");
    if (isdefined(ai))
    {
        level.zm_zs_ok++;
        level.zm_zs_total++;
        level.zm_zs_spawned[level.zm_zs_spawned.size] = ai;
        if (level.zm_zs_scale != 1)
        {
            ai setscale(level.zm_zs_scale);
        }
        if (level.zm_zs_statue == 1)
        {
            // Pin it: link to an invisible anchor so it can't walk away.
            anchor = spawn("script_model", pos);
            anchor setmodel("tag_origin");
            anchor.angles = (0, yaw + 180, 0);
            ai linkto(anchor);
            ai.zm_zs_anchor = anchor;
        }
        zm_zs_dbg("total", level.zm_zs_total);
    }
}

zm_zs_clear()
{
    n = 0;
    for (i = 0; i < level.zm_zs_spawned.size; i++)
    {
        ai = level.zm_zs_spawned[i];
        if (isdefined(ai))
        {
            if (isdefined(ai.zm_zs_anchor))
            {
                ai.zm_zs_anchor delete();
            }
            ai delete();
            n++;
        }
    }
    level.zm_zs_spawned = [];
    level.zm_zs_out = "removed " + n;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_zs_init_is_zombies()
{
    level.zm_zs_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_zs_init_gt) || level.zm_zs_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_zs_init_gt, 0, 2) == "zm";
}
