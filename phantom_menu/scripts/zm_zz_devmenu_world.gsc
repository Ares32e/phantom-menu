// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_world - Phantom menu: Zombies + World options (game calls as FuzMenu uses them,
// Phantom's own code around them). Own script with FuzMenu's include list, reached through
// level.zm_dmw_run (one entry point, action name + value), so a missing game script only
// breaks these options. State lives on level / player fields (Kronos loses locals).

#using scripts\common\utility;
#using scripts\common\weapon;
#using scripts\common\callbacks;
#using scripts\common\status_effects\effect_charm;
#using scripts\mp\zm\systems\zm_armor;
#using scripts\mp\zm\systems\agent_manager;
#using script_3b64eb40368c1450;
#using script_4e3b2b1d9542e66b;
#using script_4fca32f463c5e4fa;
#using script_25a8fa2ac8997425;
#using script_3a9d7a7cfee99885;
#using script_2301d27669c5a079;
#using script_aa3bac81ad4fc8e;
#using script_427ce33ec0c820cf;
#using script_4f24ca7a470a5fa8;
#using script_724b8f06df0c96b1;
#using script_734dce84c468439b;
#using script_1f6b7243f8d72fef;
#using script_53d9b43dfecd95ed;
#using script_681a06cc8e9fcb34;
#using script_7b92812967b04687;
#using script_6c2f6a14fa53759e;
#using script_6b0663a111030b30;
#using script_c1369b1abe9a0d1;
#using script_8c8e132af264960;
#using script_1ade2fa7cae9593d;

autoexec zm_dmw_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmw_init_is_zombies())
    {
        return;
    }
    level.zm_dmw_run = &zm_dmw_run;
    level.zm_dmw_flags = [];
    level.zm_dmw_zones_fn = &zm_dmw_zones;
    level thread zm_dmw_rot_start();
    level callback::add(#"hash_652eb614ba902b3d", &zm_dmw_on_damaged);
    nengine_store_set("devmenu_dbg", "world", "linked");
}

// self = player. a = action, v = value (string). Returns a message for the menu.
zm_dmw_run(a, v)
{
    self.zm_dmw_a = a;
    self.zm_dmw_v = v;
    if (a == "leaveone")
    {
        level.zm_dmw_keep = 1;
        level thread zm_dmw_clear_ai();
        return "killing all zombies but one";
    }
    if (a == "despawn")
    {
        return self zm_dmw_toggle_despawn();
    }
    if (a == "stopspawns")
    {
        return zm_dmw_toggle_stop_spawns();
    }
    if (a == "cap")
    {
        level.zm_dmw_cap = int(self.zm_dmw_v);
        if (!isdefined(level.zm_dmw_cap_on))
        {
            level.zm_dmw_cap_on = 1;
            level thread zm_dmw_cap_loop();
        }
        if (level.zm_dmw_cap <= 0)
        {
            return "zombies per round: normal";
        }
        return "zombies per round: " + level.zm_dmw_cap;
    }
    if (a == "spawnrate")
    {
        return zm_dmw_spawn_rate(float(self.zm_dmw_v));
    }
    if (a == "friendly")
    {
        self thread zm_dmw_summon_allies();
        return "summoning friendly zombies...";
    }
    if (a == "tessie")
    {
        self thread zm_dmw_tessie();
        return "spawning Tessie...";
    }
    if (a == "counter")
    {
        level.zm_dmw_counter = 1 - zm_dmw_flag(level.zm_dmw_counter);
        if (level.zm_dmw_counter)
        {
            level thread zm_dmw_counter_loop();
            return "zombie counter on";
        }
        setdvar(@"phantom_hud", "");
        return "zombie counter off";
    }
    if (a == "train")
    {
        return self zm_dmw_toggle_train();
    }
    if (a == "forcespawn")
    {
        return self zm_dmw_force_spawn();
    }
    if (a == "power")
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f("power_on");
        return "power turned on";
    }
    if (a == "doors")
    {
        level.zm_dmw_doors = getentarray("zombie_door", "targetname");
        for (level.zm_dmw_di = 0; level.zm_dmw_di < level.zm_dmw_doors.size; level.zm_dmw_di++)
        {
            level.zm_dmw_doors[level.zm_dmw_di] thread doorbuy::function_ff4e31657c10cfde(undefined, undefined, 0);
        }
        return "opening " + level.zm_dmw_doors.size + " doors";
    }
    if (a == "boss")
    {
        return self zm_dmw_boss();
    }
    if (a == "restart")
    {
        // the phantom_bg add-on runs this on the console (map_restart)
        setdvar(@"phantom_exec", "map_restart " + gettime());
        return "restarting the map...";
    }
    if (a == "freebox" || a == "fastbox")
    {
        return zm_dmw_box(a);
    }
    // ---- Player
    if (a == "noclip")
    {
        // the phantom_bg add-on runs the Kronos "noclip" console command (same as the N key)
        setdvar(@"phantom_exec", "noclip " + gettime());
        return "noclip toggled";
    }
    if (a == "cinema")
    {
        self.zm_dmw_cinema = 1 - zm_dmw_flag(self.zm_dmw_cinema);
        setdvar(@"phantom_exec", "noclip " + gettime());
        self setclientomnvar("ui_hide_hud", self.zm_dmw_cinema);
        if (self.zm_dmw_cinema)
        {
            self disableweapons();
            return "cinematic mode ON (noclip, no HUD, no gun)";
        }
        self enableweapons();
        return "cinematic mode OFF";
    }
    if (a == "infpoints")
    {
        self.zm_dmw_infpts = 1 - zm_dmw_flag(self.zm_dmw_infpts);
        if (self.zm_dmw_infpts)
        {
            self thread zm_dmw_points_loop();
            return "infinite points ON";
        }
        return "infinite points OFF";
    }
    if (a == "freebuy")
    {
        self.zm_dmw_freebuy = 1 - zm_dmw_flag(self.zm_dmw_freebuy);
        if (self.zm_dmw_freebuy)
        {
            self thread zm_dmw_free_buy_loop();
            return "free purchases ON";
        }
        return "free purchases OFF";
    }
    if (a == "nofall")
    {
        self.zm_dmw_nofall = 1 - zm_dmw_flag(self.zm_dmw_nofall);
        return "no fall damage " + zm_dmw_onoff(self.zm_dmw_nofall);
    }
    if (a == "noexplo")
    {
        self.zm_dmw_noexplo = 1 - zm_dmw_flag(self.zm_dmw_noexplo);
        return "no explosive self-damage " + zm_dmw_onoff(self.zm_dmw_noexplo);
    }
    if (a == "shield")
    {
        self.zm_dmw_shield = 1 - zm_dmw_flag(self.zm_dmw_shield);
        self.zm_dmw_shield_hits = 15;
        return "back shield " + zm_dmw_onoff(self.zm_dmw_shield) + " (15 hits from behind)";
    }
    if (a == "health")
    {
        if (isdefined(self.maxhealth) && self.maxhealth > 0)
        {
            self.health = self.maxhealth;
            return "health restored";
        }
        return "^1can't restore health";
    }
    if (a == "revives")
    {
        if (isdefined(level.var_d387a7914df3c24a) && zm_dmw_flag(level.var_d387a7914df3c24a.var_75911fb102b4859d))
        {
            return "^1self revives are blocked in this mode";
        }
        self namespace_b80f99000c537b86::function_a2e03a85015b1897(10, 1);
        if (!isdefined(self.game_extrainfo))
        {
            self.game_extrainfo = 0;
        }
        self.game_extrainfo = self.game_extrainfo | 2048;
        return "10 self revives";
    }
    if (a == "tacsprint")
    {
        self.zm_dmw_tac = 1 - zm_dmw_flag(self.zm_dmw_tac);
        if (self.zm_dmw_tac)
        {
            self setperk("specialty_infinite_tacsprint", 1);
        }
        else
        {
            self unsetperk("specialty_infinite_tacsprint", 1);
        }
        return "infinite tactical sprint " + zm_dmw_onoff(self.zm_dmw_tac);
    }
    // ---- Teleports
    if (a == "tpzone")
    {
        zm_dmw_zones();
        self.zm_dmw_zi = int(self.zm_dmw_v);
        if (self.zm_dmw_zi < 0 || self.zm_dmw_zi >= level.zm_dmw_zone_pos.size)
        {
            return "^1no such location";
        }
        return self zm_dmw_teleport(level.zm_dmw_zone_pos[self.zm_dmw_zi], "teleported to " + level.zm_dmw_zone_names[self.zm_dmw_zi]);
    }
    if (a == "tpspawn")
    {
        if (!isdefined(self.zm_dm_spawn_origin))
        {
            return "^1spawn point not known";
        }
        return self zm_dmw_teleport(self.zm_dm_spawn_origin, "back at the spawn point");
    }
    if (a == "unstuck")
    {
        self.zm_dmw_nav = getclosestpointonnavmesh(self.origin);
        if (!isdefined(self.zm_dmw_nav))
        {
            return "^1no walkable ground nearby";
        }
        return self zm_dmw_teleport(self.zm_dmw_nav + (0, 0, 8), "unstuck");
    }
    // ---- Fun
    if (a == "size")
    {
        self.zm_dmw_sz = float(self.zm_dmw_v);
        self.zm_dmw_lt = self zm_dmw_look();
        if (!isdefined(self.zm_dmw_lt))
        {
            return "^1look at a zombie first";
        }
        self.zm_dmw_lt setscale(self.zm_dmw_sz);
        return "zombie size x" + self.zm_dmw_v;
    }
    if (a == "sizeall")
    {
        self.zm_dmw_sz = float(self.zm_dmw_v);
        level.zm_dmw_sl = zm_dmw_list();
        for (level.zm_dmw_si = 0; level.zm_dmw_si < level.zm_dmw_sl.size; level.zm_dmw_si++)
        {
            if (isdefined(level.zm_dmw_sl[level.zm_dmw_si]) && isalive(level.zm_dmw_sl[level.zm_dmw_si]))
            {
                level.zm_dmw_sl[level.zm_dmw_si] setscale(self.zm_dmw_sz);
            }
        }
        return "all zombies size x" + self.zm_dmw_v;
    }
    if (a == "pet")
    {
        self.zm_dmw_lt = self zm_dmw_look();
        if (!isdefined(self.zm_dmw_lt))
        {
            return "^1look at a zombie first";
        }
        self.zm_dmw_team = "allies";
        if (isdefined(self.team))
        {
            self.zm_dmw_team = self.team;
        }
        self thread zm_dmw_turncoat(self.zm_dmw_lt);
        return "this zombie is your pet now";
    }
    if (a == "speed")
    {
        level.zm_dmw_speed = self.zm_dmw_v;
        if (!isdefined(level.zm_dmw_speed_on))
        {
            level.zm_dmw_speed_on = 1;
            level thread zm_dmw_speed_loop();
        }
        if (level.zm_dmw_speed == "off")
        {
            return "zombie speed: normal";
        }
        return "zombie speed: " + level.zm_dmw_speed;
    }
    if (a == "rain")
    {
        level.zm_dmw_rain = 1 - zm_dmw_flag(level.zm_dmw_rain);
        if (level.zm_dmw_rain)
        {
            self thread zm_dmw_rain_loop();
        }
        return "power-up rain " + zm_dmw_onoff(level.zm_dmw_rain);
    }
    if (a == "ragdoll")
    {
        self.zm_dmw_lt = self zm_dmw_look();
        if (!isdefined(self.zm_dmw_lt))
        {
            return "^1look at a zombie first";
        }
        self.zm_dmw_lt thread zm_dmw_ragdoll_one();
        return "ragdoll!";
    }
    if (a == "ragdollall")
    {
        level.zm_dmw_rgl = zm_dmw_list();
        level.zm_dmw_rgn = 0;
        for (level.zm_dmw_rgi = 0; level.zm_dmw_rgi < level.zm_dmw_rgl.size; level.zm_dmw_rgi++)
        {
            if (isdefined(level.zm_dmw_rgl[level.zm_dmw_rgi]) && isalive(level.zm_dmw_rgl[level.zm_dmw_rgi]) && !zm_dmw_protected(level.zm_dmw_rgl[level.zm_dmw_rgi]))
            {
                level.zm_dmw_rgl[level.zm_dmw_rgi] thread zm_dmw_ragdoll_one();
                level.zm_dmw_rgn++;
            }
        }
        return "ragdolled " + level.zm_dmw_rgn + " zombies";
    }
    if (a == "forceblock" || a == "forceflank")
    {
        self.zm_dmw_lt = self zm_dmw_look();
        if (!isdefined(self.zm_dmw_lt))
        {
            return "^1look at a zombie first";
        }
        self.zm_dmw_dg_f = anglestoforward(self getplayerangles());
        self.zm_dmw_dgfl = vectornormalize((self.zm_dmw_dg_f[0], self.zm_dmw_dg_f[1], 0));
        if (a == "forceflank")
        {
            self.zm_dmw_lt.zm_dmw_dg_to = (self.origin[0], self.origin[1], self.zm_dmw_lt.origin[2]) - self.zm_dmw_dgfl * 120;
            self.zm_dmw_lt.zm_dmw_dg_flank = 1;
        }
        else
        {
            self.zm_dmw_side = vectornormalize((0 - self.zm_dmw_dgfl[1], self.zm_dmw_dgfl[0], 0));
            self.zm_dmw_lt.zm_dmw_dg_to = self.zm_dmw_lt.origin + self.zm_dmw_side * 150;
            self.zm_dmw_lt.zm_dmw_dg_block = 1;
        }
        self.zm_dmw_lt.zm_dmw_dashing = 0;
        self.zm_dmw_lt thread zm_dmw_dash();
        return a + " sent";
    }
    if (a == "dodge")
    {
        level.zm_dmw_dodge = 1 - zm_dmw_flag(level.zm_dmw_dodge);
        if (level.zm_dmw_dodge)
        {
            self thread zm_dmw_dodge_loop();
        }
        return "dodging zombies " + zm_dmw_onoff(level.zm_dmw_dodge);
    }
    // ---- Map rotation (same switch as Debug Options > Phantom Options)
    if (a == "rotation")
    {
        if (getdvar("phantom_o_rot") == "1")
        {
            setdvar("phantom_o_rot", "0");
            return "map rotation OFF";
        }
        setdvar("phantom_o_rot", "1");
        return "MAP ROTATION ON: a new part of the map every few rounds";
    }
    if (a == "rotnow")
    {
        if (getdvar("phantom_o_rot") != "1")
        {
            return "^1turn map rotation on first";
        }
        level thread zm_dmw_rot_move();
        return "rotating now";
    }
    // ---- Saved spots (per map, kept in kronos\devmenu\settings.json)
    if (a == "spotsave")
    {
        self.zm_dmw_key = "spot_" + level.script + "_" + self.zm_dmw_v;
        self.zm_dmw_ang = self getplayerangles();
        nengine_store_set("devmenu", self.zm_dmw_key, int(self.origin[0]) + " " + int(self.origin[1]) + " " + int(self.origin[2]) + " " + int(self.zm_dmw_ang[1]));
        nengine_store_save("devmenu", "settings");
        return "saved spot " + self.zm_dmw_v + " on this map";
    }
    if (a == "spotgo")
    {
        self.zm_dmw_key = "spot_" + level.script + "_" + self.zm_dmw_v;
        self.zm_dmw_sv = nengine_store_get("devmenu", self.zm_dmw_key);
        if (!isdefined(self.zm_dmw_sv) || !isstring(self.zm_dmw_sv) || self.zm_dmw_sv == "")
        {
            return "^1spot " + self.zm_dmw_v + " is empty on this map";
        }
        self.zm_dmw_sp = strtok(self.zm_dmw_sv, " ");
        if (self.zm_dmw_sp.size < 3)
        {
            return "^1spot " + self.zm_dmw_v + " is broken";
        }
        return self zm_dmw_teleport((float(self.zm_dmw_sp[0]), float(self.zm_dmw_sp[1]), float(self.zm_dmw_sp[2])), "at spot " + self.zm_dmw_v);
    }
    return "unknown world action " + a;
}

// The zombie the player is looking at (within ~8 degrees, 4000 units), or undefined.
zm_dmw_look()
{
    self.zm_dmw_lk_best = undefined;
    self.zm_dmw_lk_bs = 0.98;
    self.zm_dmw_lk_eye = self geteye();
    self.zm_dmw_lk_f = anglestoforward(self getplayerangles());
    level.zm_dmw_lk_l = zm_dmw_list();
    for (level.zm_dmw_lk_i = 0; level.zm_dmw_lk_i < level.zm_dmw_lk_l.size; level.zm_dmw_lk_i++)
    {
        level.zm_dmw_lk_ai = level.zm_dmw_lk_l[level.zm_dmw_lk_i];
        if (!isdefined(level.zm_dmw_lk_ai) || !isalive(level.zm_dmw_lk_ai))
        {
            continue;
        }
        level.zm_dmw_lk_d = (level.zm_dmw_lk_ai.origin + (0, 0, 40)) - self.zm_dmw_lk_eye;
        level.zm_dmw_lk_len = length(level.zm_dmw_lk_d);
        if (level.zm_dmw_lk_len < 1 || level.zm_dmw_lk_len > 4000)
        {
            continue;
        }
        level.zm_dmw_lk_c = vectordot(level.zm_dmw_lk_d, self.zm_dmw_lk_f) / level.zm_dmw_lk_len;
        if (level.zm_dmw_lk_c > self.zm_dmw_lk_bs)
        {
            self.zm_dmw_lk_bs = level.zm_dmw_lk_c;
            self.zm_dmw_lk_best = level.zm_dmw_lk_ai;
        }
    }
    if (!isdefined(self.zm_dmw_lk_best))
    {
        // not aiming at one: the nearest zombie within 400 units
        self.zm_dmw_lk_bd = 400;
        for (level.zm_dmw_lk_i = 0; level.zm_dmw_lk_i < level.zm_dmw_lk_l.size; level.zm_dmw_lk_i++)
        {
            level.zm_dmw_lk_ai = level.zm_dmw_lk_l[level.zm_dmw_lk_i];
            if (isdefined(level.zm_dmw_lk_ai) && isalive(level.zm_dmw_lk_ai) && distance(level.zm_dmw_lk_ai.origin, self.origin) < self.zm_dmw_lk_bd)
            {
                self.zm_dmw_lk_bd = distance(level.zm_dmw_lk_ai.origin, self.origin);
                self.zm_dmw_lk_best = level.zm_dmw_lk_ai;
            }
        }
    }
    return self.zm_dmw_lk_best;
}

// Zombie speed for everyone (game AI speed stack, like the no-spread option): walk / run /
// sprint / off. New zombies get it too.
zm_dmw_speed_loop()
{
    while (1)
    {
        zm_dmw_speed_step();
        wait 0.5;
    }
}

zm_dmw_speed_step()
{
    level.zm_dmw_spl = zm_dmw_list();
    for (level.zm_dmw_spi = 0; level.zm_dmw_spi < level.zm_dmw_spl.size; level.zm_dmw_spi++)
    {
        level.zm_dmw_spa = level.zm_dmw_spl[level.zm_dmw_spi];
        if (!isdefined(level.zm_dmw_spa) || !isalive(level.zm_dmw_spa) || zm_dmw_protected(level.zm_dmw_spa))
        {
            continue;
        }
        if (isdefined(level.zm_dmw_spa.zm_dmw_spd) && level.zm_dmw_spa.zm_dmw_spd == level.zm_dmw_speed)
        {
            continue;
        }
        level.zm_dmw_spa.zm_dmw_spd = level.zm_dmw_speed;
        level.zm_dmw_spd_n = zm_dmw_count(level.zm_dmw_spd_n);
        nengine_store_set("devmenu_dbg", "speed_set", level.zm_dmw_spd_n + " " + level.zm_dmw_speed);
        if (level.zm_dmw_speed == "off")
        {
            level.zm_dmw_spa namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0(undefined, "phantom_speed");
        }
        else
        {
            level.zm_dmw_spa namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0(level.zm_dmw_speed, "phantom_speed", 100);
        }
    }
}

// Power-up rain: a random power-up from this map's table near the player every rain_gap s.
zm_dmw_rain_loop()
{
    self endon("disconnect");
    if (!utility::issharedfuncdefined(#"powerups", #"dropPowerup") || !utility::issharedfuncdefined(#"powerups", #"hash_a25fdc7ee24539fb"))
    {
        level.zm_dmw_rain = 0;
        return;
    }
    while (zm_dmw_flag(level.zm_dmw_rain))
    {
        self zm_dmw_rain_drop();
        wait zm_dmw_num("rain_gap", 4);
    }
}

zm_dmw_rain_drop()
{
    level.zm_dmw_pr = utility::callsharedfunc(#"powerups", #"hash_a25fdc7ee24539fb");
    if (!isdefined(level.zm_dmw_pr) || !isdefined(level.zm_dmw_pr.powerups))
    {
        return;
    }
    level.zm_dmw_prk = getarraykeys(level.zm_dmw_pr.powerups);
    if (!isdefined(level.zm_dmw_prk) || level.zm_dmw_prk.size == 0)
    {
        return;
    }
    level.zm_dmw_prn = level.zm_dmw_prk[randomint(level.zm_dmw_prk.size)];
    if (level.zm_dmw_prn == "nuke" && zm_dmw_num("rain_nukes", 0) != 1)
    {
        return;
    }
    level.zm_dmw_prp = self.origin + anglestoforward((0, randomfloatrange(0, 360), 0)) * randomfloatrange(80, 350);
    level.zm_dmw_prnav = getclosestpointonnavmesh(level.zm_dmw_prp);
    if (isdefined(level.zm_dmw_prnav))
    {
        level.zm_dmw_prp = level.zm_dmw_prnav;
    }
    level thread zm_dmw_drop_now();
}

zm_dmw_drop_now()
{
    utility::callsharedfunc(#"powerups", #"dropPowerup", level.zm_dmw_prn, level.zm_dmw_prp + (0, 0, 40), undefined, undefined, undefined, 0);
}

// self = AI: die and fall over as a rag doll.
zm_dmw_ragdoll_one()
{
    self.no_powerups = 1;
    self kill();
    if (isdefined(self))
    {
        self startragdoll();
    }
}

// Dodging zombies: a zombie you aim at dashes to the side (a quick sideways slide), and a
// zombie closing in sometimes lunges at you. Fake "omni movement": AI can't use the player's
// movement system, so the dash moves them along the ground with a mover.
zm_dmw_dodge_loop()
{
    self endon("disconnect");
    while (zm_dmw_flag(level.zm_dmw_dodge))
    {
        self zm_dmw_dodge_step();
        wait 0.1;
    }
}

zm_dmw_dodge_step()
{
    self.zm_dmw_dg_eye = self geteye();
    self.zm_dmw_dg_f = anglestoforward(self getplayerangles());
    level.zm_dmw_dgl = zm_dmw_list();
    for (level.zm_dmw_dgi = 0; level.zm_dmw_dgi < level.zm_dmw_dgl.size; level.zm_dmw_dgi++)
    {
        level.zm_dmw_dga = level.zm_dmw_dgl[level.zm_dmw_dgi];
        if (!isdefined(level.zm_dmw_dga) || !isalive(level.zm_dmw_dga) || zm_dmw_protected(level.zm_dmw_dga) || zm_dmw_flag(level.zm_dmw_dga.zm_dmw_dashing))
        {
            continue;
        }
        if (isdefined(level.zm_dmw_dga.zm_dmw_dg_next) && gettime() < level.zm_dmw_dga.zm_dmw_dg_next)
        {
            continue;
        }
        level.zm_dmw_dgd = (level.zm_dmw_dga.origin + (0, 0, 40)) - self.zm_dmw_dg_eye;
        level.zm_dmw_dglen = length(level.zm_dmw_dgd);
        if (level.zm_dmw_dglen < 120 || level.zm_dmw_dglen > 1500)
        {
            continue;
        }
        level.zm_dmw_dgc = vectordot(level.zm_dmw_dgd, self.zm_dmw_dg_f) / level.zm_dmw_dglen;
        if (level.zm_dmw_dgc > 0.985 && randomint(100) < zm_dmw_num("dodge_chance", 60))
        {
            // sideways, left or right of the line of fire
            level.zm_dmw_dgs = vectornormalize((0 - self.zm_dmw_dg_f[1], self.zm_dmw_dg_f[0], 0));
            if (randomint(2) == 0)
            {
                level.zm_dmw_dgs = level.zm_dmw_dgs * -1;
            }
            level.zm_dmw_dga.zm_dmw_dg_to = level.zm_dmw_dga.origin + level.zm_dmw_dgs * randomfloatrange(110, 190);
            level.zm_dmw_dga thread zm_dmw_dash();
        }
        else if (level.zm_dmw_dgc > 0.8 && level.zm_dmw_dglen > 150 && level.zm_dmw_dglen < 500 && zm_dmw_flank_ready())
        {
            // flank: now and then a close zombie in front of you dashes around behind you
            level.zm_dmw_flank_next = gettime() + int(zm_dmw_num("flank_gap", 12) * 1000);
            level.zm_dmw_dgfl = vectornormalize((self.zm_dmw_dg_f[0], self.zm_dmw_dg_f[1], 0));
            level.zm_dmw_dga.zm_dmw_dg_to = (self.origin[0], self.origin[1], level.zm_dmw_dga.origin[2]) - level.zm_dmw_dgfl * randomfloatrange(90, 150);
            level.zm_dmw_dga.zm_dmw_dg_flank = 1;
            level.zm_dmw_dga thread zm_dmw_dash();
        }
        else if (level.zm_dmw_dgc > 0.6 && level.zm_dmw_dgc < 0.97 && level.zm_dmw_dglen > 250 && level.zm_dmw_dglen < 900 && zm_dmw_block_ready())
        {
            // block: now and then a zombie off to the side slides into your line of fire
            level.zm_dmw_block_next = gettime() + int(zm_dmw_num("block_gap", 8) * 1000);
            level.zm_dmw_dgfl = vectornormalize((self.zm_dmw_dg_f[0], self.zm_dmw_dg_f[1], 0));
            level.zm_dmw_dga.zm_dmw_dg_to = (self.origin[0], self.origin[1], level.zm_dmw_dga.origin[2]) + level.zm_dmw_dgfl * distance2d(self.origin, level.zm_dmw_dga.origin);
            if (distance(level.zm_dmw_dga.zm_dmw_dg_to, level.zm_dmw_dga.origin) < 280)
            {
                level.zm_dmw_dga.zm_dmw_dg_block = 1;
                level.zm_dmw_dga thread zm_dmw_dash();
            }
        }
        else if (level.zm_dmw_dglen > 200 && level.zm_dmw_dglen < 500 && randomint(1000) < zm_dmw_num("lunge_chance", 15))
        {
            // lunge toward the player
            level.zm_dmw_dgt = vectornormalize((self.origin - level.zm_dmw_dga.origin) * (1, 1, 0));
            level.zm_dmw_dga.zm_dmw_dg_to = level.zm_dmw_dga.origin + level.zm_dmw_dgt * 170;
            level.zm_dmw_dga thread zm_dmw_dash();
        }
    }
}

// self = AI: slide to self.zm_dmw_dg_to (snapped to walkable ground) over dodge_time s.
zm_dmw_dash()
{
    self.zm_dmw_dashing = 1;
    level.zm_dmw_dash_n = zm_dmw_count(level.zm_dmw_dash_n);
    nengine_store_set("devmenu_dbg", "dodges", level.zm_dmw_dash_n);
    self.zm_dmw_dg_next = gettime() + int(zm_dmw_num("dodge_cooldown", 1.5) * 1000);
    self.zm_dmw_dg_nav = getclosestpointonnavmesh(self.zm_dmw_dg_to);
    if (!isdefined(self.zm_dmw_dg_nav) || distance2d(self.zm_dmw_dg_nav, self.zm_dmw_dg_to) > 60 || abs(self.zm_dmw_dg_nav[2] - self.zm_dmw_dg_to[2]) > 120)
    {
        level.zm_dmw_dg_fail = zm_dmw_count(level.zm_dmw_dg_fail);
        nengine_store_set("devmenu_dbg", "dodge_nofloor", level.zm_dmw_dg_fail);
        self.zm_dmw_dg_block = 0;
        self.zm_dmw_dg_flank = 0;
        self.zm_dmw_dashing = 0;
        return;
    }
    self.zm_dmw_dg_mover = spawn("script_origin", self.origin);
    self linkto(self.zm_dmw_dg_mover);
    self.zm_dmw_dg_t = zm_dmw_num("dodge_time", 0.22);
    if (zm_dmw_flag(self.zm_dmw_dg_block))
    {
        self.zm_dmw_dg_block = 0;
        self.zm_dmw_dg_t = zm_dmw_num("block_time", 0.3);
        level.zm_dmw_block_n = zm_dmw_count(level.zm_dmw_block_n);
        nengine_store_set("devmenu_dbg", "blocks", level.zm_dmw_block_n);
    }
    if (zm_dmw_flag(self.zm_dmw_dg_flank))
    {
        self.zm_dmw_dg_flank = 0;
        self.zm_dmw_dg_t = zm_dmw_num("flank_time", 0.4);
        level.zm_dmw_flank_n = zm_dmw_count(level.zm_dmw_flank_n);
        nengine_store_set("devmenu_dbg", "flanks", level.zm_dmw_flank_n);
    }
    self.zm_dmw_dg_mover moveto(self.zm_dmw_dg_nav, self.zm_dmw_dg_t);
    wait self.zm_dmw_dg_t;
    if (!isdefined(self))
    {
        return;
    }
    self unlink();
    self.zm_dmw_dashing = 0;
    if (isdefined(self.zm_dmw_dg_mover))
    {
        self.zm_dmw_dg_mover delete();
    }
}

zm_dmw_onoff(v)
{
    if (v)
    {
        return "ON";
    }
    return "OFF";
}

// Game teleport (shared fn zm_utility / teleport_player), angles kept.
zm_dmw_teleport(pos, msg)
{
    self.zm_dmw_tpos = pos;
    self.zm_dmw_tmsg = msg;
    if (!utility::issharedfuncdefined(#"zm_utility", #"teleport_player"))
    {
        self setorigin(self.zm_dmw_tpos);
        return self.zm_dmw_tmsg;
    }
    self thread zm_dmw_do_teleport();
    return self.zm_dmw_tmsg;
}

zm_dmw_do_teleport()
{
    self utility::callsharedfunc(#"zm_utility", #"teleport_player", self.zm_dmw_tpos, self getplayerangles(), "pc_menu");
}

// Map locations: the game's zone list (level.var_63a203e154ffeca0.var_7a113819421452c2), each
// zone's spot moved onto the walkable mesh. Fills level.zm_dmw_zone_names / _pos; returns count.
zm_dmw_zones()
{
    if (isdefined(level.zm_dmw_zone_names))
    {
        return level.zm_dmw_zone_names.size;
    }
    level.zm_dmw_zone_names = [];
    level.zm_dmw_zone_pos = [];
    level.zm_dmw_zroot = level.var_63a203e154ffeca0;
    if (!isdefined(level.zm_dmw_zroot) || !isdefined(level.zm_dmw_zroot.var_7a113819421452c2))
    {
        return 0;
    }
    level.zm_dmw_zkeys = getarraykeys(level.zm_dmw_zroot.var_7a113819421452c2);
    for (level.zm_dmw_zk = 0; level.zm_dmw_zk < level.zm_dmw_zkeys.size; level.zm_dmw_zk++)
    {
        level.zm_dmw_zkey = level.zm_dmw_zkeys[level.zm_dmw_zk];
        if (!isstring(level.zm_dmw_zkey))
        {
            continue;
        }
        level.zm_dmw_zp = zm_dmw_zone_point(level.zm_dmw_zroot.var_7a113819421452c2[level.zm_dmw_zkey]);
        if (!isdefined(level.zm_dmw_zp))
        {
            continue;
        }
        level.zm_dmw_zname = level.zm_dmw_zkey;
        if (issubstr(level.zm_dmw_zname, "zone_"))
        {
            level.zm_dmw_zname = removesubstr(level.zm_dmw_zname, "zone_");
        }
        level.zm_dmw_zone_names[level.zm_dmw_zone_names.size] = level.zm_dmw_zname;
        level.zm_dmw_zone_pos[level.zm_dmw_zone_pos.size] = level.zm_dmw_zp;
    }
    return level.zm_dmw_zone_names.size;
}

zm_dmw_zone_point(zone)
{
    if (!isdefined(zone))
    {
        return undefined;
    }
    level.zm_dmw_spots = [zone];
    if (isdefined(zone.var_2e0e0e223186f0d7))
    {
        level.zm_dmw_vols = zone.var_2e0e0e223186f0d7;
        level.zm_dmw_vk = getarraykeys(level.zm_dmw_vols);
        for (level.zm_dmw_vi = 0; level.zm_dmw_vi < level.zm_dmw_vk.size; level.zm_dmw_vi++)
        {
            level.zm_dmw_spots[level.zm_dmw_spots.size] = level.zm_dmw_vols[level.zm_dmw_vk[level.zm_dmw_vi]];
        }
    }
    for (level.zm_dmw_si2 = 0; level.zm_dmw_si2 < level.zm_dmw_spots.size; level.zm_dmw_si2++)
    {
        level.zm_dmw_sp = level.zm_dmw_spots[level.zm_dmw_si2];
        if (isdefined(level.zm_dmw_sp) && isdefined(level.zm_dmw_sp.var_78ed774afe1cc998))
        {
            level.zm_dmw_nav2 = getclosestpointonnavmesh(level.zm_dmw_sp.var_78ed774afe1cc998);
            if (isdefined(level.zm_dmw_nav2) && distance(level.zm_dmw_nav2, level.zm_dmw_sp.var_78ed774afe1cc998) <= 192)
            {
                return level.zm_dmw_nav2 + (0, 0, 8);
            }
        }
    }
    return undefined;
}

// Infinite points: keep points topped up (game set_points), once a second.
zm_dmw_points_loop()
{
    self endon("disconnect");
    while (zm_dmw_flag(self.zm_dmw_infpts))
    {
        self namespace_c40c7bec6c50de09::function_40dc4b206b63ac2e(999999);
        wait 1;
    }
}

// Free purchases: any points spent are given straight back (FuzMenu's shortcut).
zm_dmw_free_buy_loop()
{
    self endon("disconnect");
    self.zm_dmw_last_pts = self namespace_c40c7bec6c50de09::function_8f0a9502ff7321a();
    while (zm_dmw_flag(self.zm_dmw_freebuy))
    {
        self.zm_dmw_cur_pts = self namespace_c40c7bec6c50de09::function_8f0a9502ff7321a();
        if (isdefined(self.zm_dmw_last_pts) && isdefined(self.zm_dmw_cur_pts) && self.zm_dmw_cur_pts < self.zm_dmw_last_pts)
        {
            self namespace_c40c7bec6c50de09::function_40dc4b206b63ac2e(self.zm_dmw_last_pts);
        }
        else
        {
            self.zm_dmw_last_pts = self.zm_dmw_cur_pts;
        }
        waitframe();
    }
}

// Damage hook (game callback): no fall damage, no explosive damage, back shield.
zm_dmw_on_damaged(params)
{
    if (!isdefined(self) || !isdefined(params) || !isdefined(params.var_f5a880abf0b199dc))
    {
        return;
    }
    if (params.var_f5a880abf0b199dc == "MOD_FALLING" && zm_dmw_flag(self.zm_dmw_nofall))
    {
        params.var_a87b62c261a8d114 = 0;
    }
    if (zm_dmw_flag(self.zm_dmw_noexplo) && (params.var_f5a880abf0b199dc == "MOD_GRENADE_SPLASH" || params.var_f5a880abf0b199dc == "MOD_PROJECTILE_SPLASH" || params.var_f5a880abf0b199dc == "MOD_EXPLOSIVE"))
    {
        params.var_a87b62c261a8d114 = 0;
    }
    if (zm_dmw_flag(self.zm_dmw_shield) && isdefined(self.zm_dmw_shield_hits) && self.zm_dmw_shield_hits > 0 && params.var_f5a880abf0b199dc == "MOD_MELEE" && isdefined(params.var_917e21c98d80255e) && !isplayer(params.var_917e21c98d80255e) && params.var_a87b62c261a8d114 > 0)
    {
        self.zm_dmw_fwd = anglestoforward((0, self getplayerangles()[1], 0));
        self.zm_dmw_dir = vectornormalize((params.var_917e21c98d80255e.origin[0] - self.origin[0], params.var_917e21c98d80255e.origin[1] - self.origin[1], 0));
        if (vectordot(self.zm_dmw_fwd, self.zm_dmw_dir) < -0.2)
        {
            params.var_a87b62c261a8d114 = 0;
            self.zm_dmw_shield_hits--;
            if (self.zm_dmw_shield_hits <= 0)
            {
                self iprintlnbold("^1back shield broken");
            }
        }
    }
}

zm_dmw_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

// The zombie team's AI that can be killed (not protected / sleeping).
zm_dmw_list()
{
    // the game's zombies, plus AI the menu spawned (those are on team "axis")
    if (isdefined(level.zombie_team))
    {
        level.zm_dmw_list_a = getaiarray(level.zombie_team);
    }
    else
    {
        level.zm_dmw_list_a = getaiarray("team_two_hundred");
    }
    if (!isdefined(level.zombie_team) || level.zombie_team != "axis")
    {
        level.zm_dmw_list_b = getaiarray("axis");
        for (level.zm_dmw_list_i = 0; level.zm_dmw_list_i < level.zm_dmw_list_b.size; level.zm_dmw_list_i++)
        {
            level.zm_dmw_list_a[level.zm_dmw_list_a.size] = level.zm_dmw_list_b[level.zm_dmw_list_i];
        }
    }
    return level.zm_dmw_list_a;
}

zm_dmw_protected(ai)
{
    if (zm_dmw_flag(ai.b_ignore_cleanup) || zm_dmw_flag(ai.magic_bullet_shield) || zm_dmw_flag(ai.damageshield))
    {
        return 1;
    }
    return 0;
}

// Kill all zombies (keeps one when level.zm_dmw_keep is 1), one per frame.
zm_dmw_clear_ai()
{
    level.zm_dmw_cl = zm_dmw_list();
    level.zm_dmw_kept = 0;
    for (level.zm_dmw_ci = 0; level.zm_dmw_ci < level.zm_dmw_cl.size; level.zm_dmw_ci++)
    {
        level.zm_dmw_ai = level.zm_dmw_cl[level.zm_dmw_ci];
        if (!isdefined(level.zm_dmw_ai) || !isalive(level.zm_dmw_ai) || zm_dmw_protected(level.zm_dmw_ai))
        {
            continue;
        }
        if (zm_dmw_flag(level.zm_dmw_keep) && !level.zm_dmw_kept)
        {
            level.zm_dmw_kept = 1;
            continue;
        }
        level.zm_dmw_ai.no_powerups = 1;
        level.zm_dmw_ai.b_cleaned_up = 1;
        level.zm_dmw_ai kill();
        waitframe();
    }
    level.zm_dmw_keep = 0;
}

// Despawn zombies: the game's own despawn switch + clear the ones alive.
zm_dmw_toggle_despawn()
{
    if (!isdefined(level.var_a009ab14ee0d3223))
    {
        return "^1round spawner not found";
    }
    level.zm_dmw_flags["despawn"] = 1 - zm_dmw_flag(level.zm_dmw_flags["despawn"]);
    namespace_ea0d69869863f098::function_b1aacaee86092345(level.zm_dmw_flags["despawn"], "phantom_despawn");
    if (level.zm_dmw_flags["despawn"])
    {
        level.zm_dmw_keep = 0;
        level thread zm_dmw_clear_ai();
        return "despawn zombies ON";
    }
    if (level.var_a009ab14ee0d3223 namespace_214d79f87f4bf971::function_e5c588558239ba2a("pause_zombie_spawning"))
    {
        level namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f("pause_round_timeout");
    }
    return "despawn zombies OFF";
}

// Stop spawns: the round spawner's own pause switches + the round timeout flag.
zm_dmw_toggle_stop_spawns()
{
    if (!isdefined(level.var_a009ab14ee0d3223))
    {
        return "^1round spawner not found";
    }
    level.zm_dmw_flags["stop"] = 1 - zm_dmw_flag(level.zm_dmw_flags["stop"]);
    level.var_a009ab14ee0d3223.b_value_pause_zombie_spawning = level.zm_dmw_flags["stop"];
    level.var_a009ab14ee0d3223.var_3d4f61bfa1003fcd = level.zm_dmw_flags["stop"];
    if (isdefined(level.flag))
    {
        if (level.zm_dmw_flags["stop"])
        {
            utility::flag_set("pause_round_timeout");
        }
        else
        {
            utility::flag_clear("pause_round_timeout");
        }
    }
    if (level.zm_dmw_flags["stop"])
    {
        return "zombie spawns stopped";
    }
    return "zombie spawns back on";
}

// Zombies per round: every new zombie past the cap in this round is killed as it spawns.
zm_dmw_cap_loop()
{
    level.zm_dmw_cap_round = -1;
    level.zm_dmw_cap_count = 0;
    while (1)
    {
        if (isdefined(level.zm_dmw_cap) && level.zm_dmw_cap > 0)
        {
            zm_dmw_cap_step();
        }
        wait 0.25;
    }
}

zm_dmw_cap_step()
{
    level.zm_dmw_rn = 0;
    if (isdefined(level.round_number))
    {
        level.zm_dmw_rn = level.round_number;
    }
    if (level.zm_dmw_rn != level.zm_dmw_cap_round)
    {
        level.zm_dmw_cap_round = level.zm_dmw_rn;
        level.zm_dmw_cap_count = 0;
    }
    level.zm_dmw_cpl = zm_dmw_list();
    for (level.zm_dmw_cpi = 0; level.zm_dmw_cpi < level.zm_dmw_cpl.size; level.zm_dmw_cpi++)
    {
        level.zm_dmw_cpa = level.zm_dmw_cpl[level.zm_dmw_cpi];
        if (!isdefined(level.zm_dmw_cpa) || !isalive(level.zm_dmw_cpa) || zm_dmw_protected(level.zm_dmw_cpa))
        {
            continue;
        }
        if (!zm_dmw_flag(level.zm_dmw_cpa.zm_dmw_seen))
        {
            level.zm_dmw_cpa.zm_dmw_seen = 1;
            level.zm_dmw_cap_count++;
            if (level.zm_dmw_cap_count > level.zm_dmw_cap)
            {
                level.zm_dmw_cpa.no_powerups = 1;
                level.zm_dmw_cpa kill();
            }
        }
    }
}

// Spawn rate: the round spawner asks level.var_7f3b57eeced54ded for the delay between spawns;
// our hook divides the normal delay by the rate (1 = put the old hook back).
zm_dmw_spawn_rate(r)
{
    level.zm_dmw_rate = r;
    if (r != 1 && !zm_dmw_flag(level.zm_dmw_rate_hooked))
    {
        level.zm_dmw_rate_hooked = 1;
        level.zm_dmw_rate_prev = level.var_7f3b57eeced54ded;
        level.var_7f3b57eeced54ded = &zm_dmw_spawn_delay;
    }
    else if (r == 1 && zm_dmw_flag(level.zm_dmw_rate_hooked))
    {
        level.zm_dmw_rate_hooked = 0;
        level.var_7f3b57eeced54ded = level.zm_dmw_rate_prev;
    }
    return "spawn rate x" + r;
}

zm_dmw_spawn_delay(round, info)
{
    level.zm_dmw_delay = undefined;
    if (isdefined(level.zm_dmw_rate_prev))
    {
        level.zm_dmw_delay = [[ level.zm_dmw_rate_prev ]](round, info);
    }
    if (!isdefined(level.zm_dmw_delay))
    {
        level.zm_dmw_delay = zm_round_spawning::function_5f35aa2e209190da(round, info);
    }
    return max(0.025, level.zm_dmw_delay / level.zm_dmw_rate);
}

// Friendly zombies: a few of this map's special enemies spawned on your team (game agent
// manager + charm / guard, like FuzMenu).
zm_dmw_summon_allies()
{
    self endon("disconnect");
    self.zm_dmw_map = "";
    if (isdefined(level.mapname))
    {
        self.zm_dmw_map = level.mapname;
    }
    if (self.zm_dmw_map == "zm_sat_scarab")
    {
        self.zm_dmw_types = ["sat_spawner_zombie_phobos_zm", "t10_spawner_zombie_triton", "sat_spawner_zombie_neptune_zm"];
    }
    else if (self.zm_dmw_map == "zm_sat_firefly")
    {
        self.zm_dmw_types = ["zombie_shade", "zombie_base_armored_light", "zombie_base_armored_heavy"];
    }
    else if (self.zm_dmw_map == "zm_sat_hornet")
    {
        self.zm_dmw_types = ["zombie_orion", "zombie_abom", "zombie_hellhound"];
    }
    else if (self.zm_dmw_map == "zm_sat_locust")
    {
        self.zm_dmw_types = ["zombie_boss_virgil", "zombie_karkinos", "zombie_base_armored_heavy"];
    }
    else if (self.zm_dmw_map == "zm_sat_mantis")
    {
        self.zm_dmw_types = ["zombie_aeon", "zombie_base_armored_heavy", "zombie_mimic_emp"];
    }
    else if (self.zm_dmw_map == "zm_sat_ruby")
    {
        self.zm_dmw_types = ["zombie_galileo", "zombie_shade", "zombie_galileo_drone"];
    }
    else
    {
        self.zm_dmw_types = ["zombie_base_armored_heavy", "zombie_base_armored_light"];
    }
    self.zm_dmw_offs = [(150, 0, 0), (-150, 0, 0), (0, 150, 0), (0, -150, 0)];
    self.zm_dmw_made = 0;
    self.zm_dmw_team = "allies";
    if (isdefined(self.team))
    {
        self.zm_dmw_team = self.team;
    }
    for (self.zm_dmw_si = 0; self.zm_dmw_si < self.zm_dmw_types.size; self.zm_dmw_si++)
    {
        self.zm_dmw_agent = agent_manager::spawn_agent(self.zm_dmw_types[self.zm_dmw_si], self.origin + self.zm_dmw_offs[self.zm_dmw_si % 4], self getplayerangles(), self.zm_dmw_team);
        if (isdefined(self.zm_dmw_agent) && isalive(self.zm_dmw_agent))
        {
            self.zm_dmw_made++;
            self thread zm_dmw_turncoat(self.zm_dmw_agent);
        }
        waitframe();
    }
    self iprintlnbold("^5PHANTOM^7  friendly zombies: " + self.zm_dmw_made);
}

zm_dmw_turncoat(ai)
{
    self endon("disconnect");
    self.zm_dmw_tc = ai;
    self.zm_dmw_tc_used = 0;
    if (isdefined(self.team) && isdefined(self.zm_dmw_tc.aisettings) && zm_dmw_flag(self.zm_dmw_tc.aisettings.var_abb7ad1e6db7fa37))
    {
        if (zm_dmw_flag(self.zm_dmw_tc effect_charm::charm(-2, self, undefined, "toxic", 1)))
        {
            self.zm_dmw_tc_used = 1;
            self.zm_dmw_tc.agentteam = self.team;
            self zm_dmw_guard(self.zm_dmw_tc, self.team);
        }
    }
    if (self.zm_dmw_tc_used)
    {
        return;
    }
    self.zm_dmw_tcm = self.zm_dmw_tc;
    for (self.zm_dmw_tci = 0; self.zm_dmw_tci < 15; self.zm_dmw_tci++)
    {
        if (!isdefined(self.zm_dmw_tcm) || !isalive(self.zm_dmw_tcm))
        {
            return;
        }
        self.zm_dmw_tcm.team = self.zm_dmw_team;
        self.zm_dmw_tcm.agentteam = self.zm_dmw_team;
        waitframe();
    }
    if (!isdefined(self.zm_dmw_tcm) || !isalive(self.zm_dmw_tcm))
    {
        return;
    }
    self.zm_dmw_tcm clearpath();
    self.zm_dmw_tcm.allowpain = 0;
    if (isdefined(self.zm_dmw_tcm.maxhealth))
    {
        self.zm_dmw_tcm.health = self.zm_dmw_tcm.maxhealth;
    }
    self zm_dmw_guard(self.zm_dmw_tcm, self.zm_dmw_team);
}

zm_dmw_guard(ai, team)
{
    if (isdefined(ai._blackboard))
    {
        ai._blackboard.var_ea5eb773cb969ee1 = 1;
        ai._blackboard.var_1b77d9c7d397d112 = self;
        ai._blackboard.var_3144a4e051a50472 = 500;
    }
    ai.ignore_enemy_count = 1;
    ai setsafeguardent(self);
    ai setsafeguardrange(400);
    ai disableaimassist();
    level notify(#"hash_323ddea58a826636", team, [ai], 1);
}

// Tessie (the game's drivable truck), spawned above you, unbreakable.
zm_dmw_tessie()
{
    self endon("disconnect");
    if (!utility::issharedfuncdefined(%"hash_62a07b56f29782f5", #"spawn"))
    {
        self iprintlnbold("^1Tessie isn't on this map");
        return;
    }
    self.zm_dmw_td = spawnstruct();
    self.zm_dmw_td.origin = self.origin + (0, 0, 100);
    self.zm_dmw_td.angles = self getplayerangles();
    self.zm_dmw_td.script_vehiclebundle = %"hash_62a07b56f29782f5";
    self.zm_dmw_td.script_godmode = 1;
    self.zm_dmw_veh = utility::callsharedfunc(%"hash_62a07b56f29782f5", #"spawn", self.zm_dmw_td, undefined);
    if (!isdefined(self.zm_dmw_veh))
    {
        self iprintlnbold("^1Tessie could not spawn here");
        return;
    }
    waitframe();
    if (!isdefined(self.zm_dmw_veh))
    {
        return;
    }
    self.zm_dmw_veh.var_e1230b4b12571ca0 = 5;
    if (isdefined(self.zm_dmw_veh.var_b59ff7c648465b45))
    {
        [[ self.zm_dmw_veh.var_b59ff7c648465b45 ]](self.zm_dmw_veh, 1, 1);
    }
    self.zm_dmw_veh utility::function_7c10ea82c1e305b8("single", "vehicle_use");
    self.zm_dmw_veh.godmode = 1;
    self.zm_dmw_veh thread zm_dmw_keep_health();
    self iprintlnbold("^5PHANTOM^7  Tessie spawned");
}

zm_dmw_keep_health()
{
    while (isdefined(self) && isdefined(self.health))
    {
        if (isdefined(self.maxhealth) && self.health < self.maxhealth)
        {
            self.health = self.maxhealth;
        }
        waitframe();
    }
}

// Zombie counter: active zombies, written to dvar phantom_hud once a second; the phantom_bg
// add-on draws it at the top of the screen (no GSC text slots used).
zm_dmw_counter_loop()
{
    while (zm_dmw_flag(level.zm_dmw_counter))
    {
        zm_dmw_counter_step();
        wait 1;
    }
    setdvar(@"phantom_hud", "");
}

zm_dmw_counter_step()
{
    level.zm_dmw_cnl = zm_dmw_list();
    level.zm_dmw_cnt = 0;
    for (level.zm_dmw_cni = 0; level.zm_dmw_cni < level.zm_dmw_cnl.size; level.zm_dmw_cni++)
    {
        level.zm_dmw_cna = level.zm_dmw_cnl[level.zm_dmw_cni];
        if (isdefined(level.zm_dmw_cna) && isalive(level.zm_dmw_cna) && isdefined(level.zm_dmw_cna.var_e4312c2c1a4a2190) && !zm_dmw_flag(level.zm_dmw_cna.var_79d93e09fbd8c147))
        {
            level.zm_dmw_cnt++;
        }
    }
    setdvar(@"phantom_hud", "Zombies: " + level.zm_dmw_cnt);
}

// Zombies in a line: the game's "no spreader" switch + one speed for every zombie.
zm_dmw_toggle_train()
{
    level.zm_dmw_flags["train"] = 1 - zm_dmw_flag(level.zm_dmw_flags["train"]);
    if (level.zm_dmw_flags["train"])
    {
        namespace_60b3bdcc70f79fc6::function_9771699e420ec0fd("disallow_zombie_spreader");
        level thread zm_dmw_train_loop();
        return "zombies in a line ON";
    }
    return "zombies in a line OFF";
}

zm_dmw_train_loop()
{
    while (zm_dmw_flag(level.zm_dmw_flags["train"]))
    {
        zm_dmw_train_step(1);
        wait 0.25;
    }
    zm_dmw_train_step(0);
}

zm_dmw_train_step(on)
{
    level.zm_dmw_trl = zm_dmw_list();
    for (level.zm_dmw_tri = 0; level.zm_dmw_tri < level.zm_dmw_trl.size; level.zm_dmw_tri++)
    {
        level.zm_dmw_tra = level.zm_dmw_trl[level.zm_dmw_tri];
        if (!isdefined(level.zm_dmw_tra) || !isalive(level.zm_dmw_tra) || zm_dmw_protected(level.zm_dmw_tra))
        {
            continue;
        }
        if (on && !zm_dmw_flag(level.zm_dmw_tra.zm_dmw_train))
        {
            level.zm_dmw_tra.zm_dmw_train = 1;
            level.zm_dmw_tra namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0("sprint", "phantom_train", 100);
        }
        else if (!on && zm_dmw_flag(level.zm_dmw_tra.zm_dmw_train))
        {
            level.zm_dmw_tra.zm_dmw_train = 0;
            level.zm_dmw_tra namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0(undefined, "phantom_train");
        }
    }
}

// Force spawn here: switch on the spawn zone you stand in (and its linked zones).
zm_dmw_force_spawn()
{
    self.zm_dmw_zone = namespace_63a203e154ffeca0::function_90e5c3e2272b0130(self.origin);
    if (!isdefined(self.zm_dmw_zone))
    {
        return "^1no spawn zone here";
    }
    namespace_63a203e154ffeca0::function_b59ce32b3b1a7b17(self.zm_dmw_zone.var_8a1bbd1390cd5db6, 1);
    return "zombies now spawn in this area";
}

// Start the boss fight: the game's own quest skip for this map (FuzMenu's per-map steps).
zm_dmw_boss()
{
    self.zm_dmw_map = "";
    if (isdefined(level.mapname))
    {
        self.zm_dmw_map = level.mapname;
    }
    if (self.zm_dmw_map == "zm_sat_firefly")
    {
        level thread zm_quest::function_80abdea0cd4c89a7(#"hash_3f649ec0d0d43e11", #"hash_58856a1155dbeffd");
    }
    else if (self.zm_dmw_map == "zm_sat_hornet")
    {
        level thread zm_quest::function_80abdea0cd4c89a7(#"hash_bdb609e170f7f8b1", #"release_pearl");
    }
    else if (self.zm_dmw_map == "zm_sat_locust")
    {
        level thread zm_quest::function_80abdea0cd4c89a7(#"hash_4ea0f6575cbebdf2", #"hash_506974861a05f68d");
    }
    else if (self.zm_dmw_map == "zm_sat_mantis")
    {
        level thread zm_quest::function_11b75e2232ce3d4(["prepare_final_fight", 1]);
    }
    else if (self.zm_dmw_map == "zm_sat_ruby")
    {
        level thread zm_quest::function_80abdea0cd4c89a7(#"ruby_mq", #"boss_fight");
    }
    else
    {
        return "^1boss fight start isn't known for this map";
    }
    self thread zm_dmw_boss_followup();
    return "starting the boss fight...";
}

zm_dmw_boss_followup()
{
    self endon("disconnect");
    wait 3;
    if (self.zm_dmw_map == "zm_sat_mantis")
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f("twins_warning_vo_done");
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f("start_boss_fight");
    }
    else if (self.zm_dmw_map == "zm_sat_locust")
    {
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f("mq_encounter_starting");
        namespace_60b3bdcc70f79fc6::function_36488e0e5a90d20f("boss_vote_passed");
    }
}

// Mystery box: free (cost hook returns false) / faster (spin time hook 0.65), by replacing the
// game's shared function and putting the old one back when switched off.
zm_dmw_box(k)
{
    level.zm_dmw_bg = #"hash_ce6dbbcbb4e41fbf";
    level.zm_dmw_bid = #"hash_f24224b472aa905";
    level.zm_dmw_bf = &zm_dmw_box_free;
    if (k == "fastbox")
    {
        level.zm_dmw_bid = #"hash_fc6574ba8b7263fc";
        level.zm_dmw_bf = &zm_dmw_box_fast;
    }
    if (!isdefined(level.zm_dmw_box_on))
    {
        level.zm_dmw_box_on = [];
        level.zm_dmw_box_prev = [];
    }
    if (!zm_dmw_flag(level.zm_dmw_box_on[k]))
    {
        level.zm_dmw_box_prev[k] = level.var_9e5c1a9e0a29d3ce[level.zm_dmw_bg][level.zm_dmw_bid];
        level.var_9e5c1a9e0a29d3ce[level.zm_dmw_bg][level.zm_dmw_bid] = level.zm_dmw_bf;
        level.zm_dmw_box_on[k] = 1;
        return k + " ON";
    }
    level.var_9e5c1a9e0a29d3ce[level.zm_dmw_bg][level.zm_dmw_bid] = level.zm_dmw_box_prev[k];
    level.zm_dmw_box_on[k] = 0;
    return k + " OFF";
}

zm_dmw_box_free(box)
{
    return 0;
}

zm_dmw_box_fast()
{
    return 0.65;
}

zm_dmw_num(key, def)
{
    level.zm_dmw_nv = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dmw_nv) || (isstring(level.zm_dmw_nv) && level.zm_dmw_nv == "") || (!isstring(level.zm_dmw_nv) && level.zm_dmw_nv == 0))
    {
        return def;
    }
    if (isstring(level.zm_dmw_nv))
    {
        return float(level.zm_dmw_nv);
    }
    return level.zm_dmw_nv;
}

zm_dmw_count(n)
{
    if (!isdefined(n))
    {
        return 1;
    }
    return n + 1;
}

// Blocks happen now and then: at most one every block_gap s (8), and only block_chance % (35)
// of the times a zombie is in place for one.
zm_dmw_block_ready()
{
    if (isdefined(level.zm_dmw_block_next) && gettime() < level.zm_dmw_block_next)
    {
        return 0;
    }
    if (randomint(100) >= zm_dmw_num("block_chance", 35))
    {
        level.zm_dmw_block_next = gettime() + 1000;
        return 0;
    }
    return 1;
}

// Flanks: at most one every flank_gap s (12), only flank_chance % (30) of the chances.
zm_dmw_flank_ready()
{
    if (isdefined(level.zm_dmw_flank_next) && gettime() < level.zm_dmw_flank_next)
    {
        return 0;
    }
    if (randomint(100) >= zm_dmw_num("flank_chance", 30))
    {
        level.zm_dmw_flank_next = gettime() + 1000;
        return 0;
    }
    return 1;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmw_init_is_zombies()
{
    level.zm_dmw_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmw_init_gt) || level.zm_dmw_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmw_init_gt, 0, 2) == "zm";
}

// ---------------------------------------------------------------- MAP ROTATION
// Every N rounds everyone is teleported to another part of the map (game zones, boss areas, and
// hidden spots: walkable ground next to the map's own objects far from every zone, often outside
// the normal play area, plus the player's saved spots). Until the next rotation nobody can leave
// that area: players who walk out of the circle are put back, far zombies are brought in so a
// round can always be finished.
// Switches (dvars; Debug Options > Phantom Options or the menu): phantom_o_rot 1 on,
// phantom_o_rotn rounds between moves, phantom_o_rotspots 0 all / 1 zones / 2 hidden,
// phantom_o_rotr circle size, phantom_o_rotstay 1 = zombies are not brought in.
zm_dmw_rot_start()
{
    if (isdefined(level.zm_dmw_rot_running))
    {
        return;
    }
    level.zm_dmw_rot_running = 1;
    level thread zm_dmw_rot_loop();
}

zm_dmw_rot_dv(name, def)
{
    level.zm_dmw_rdv = getdvar(name);
    if (!isdefined(level.zm_dmw_rdv) || level.zm_dmw_rdv == "" || level.zm_dmw_rdv == "0" && def != "0")
    {
        return def;
    }
    return level.zm_dmw_rdv;
}

zm_dmw_rot_loop()
{
    while (!isdefined(level.players) || level.players.size < 1)
    {
        wait 1;
    }
    wait 5;
    while (1)
    {
        zm_dmw_rot_tick();
        wait 0.25;
    }
}

zm_dmw_rot_tick()
{
    level.zm_dmw_rot_on = zm_dmw_rot_dv("phantom_o_rot", "0") == "1";
    if (!level.zm_dmw_rot_on)
    {
        level.zm_dmw_rot_center = undefined;
        level.zm_dmw_rot_last_round = undefined;
        return;
    }
    level.zm_dmw_rot_round = 0;
    if (isdefined(level.zm_dm_round_now_fn))
    {
        level.zm_dmw_rot_round = [[ level.zm_dm_round_now_fn ]]();
    }
    // first time on: move right away; then every N rounds
    if (!isdefined(level.zm_dmw_rot_last_round))
    {
        level.zm_dmw_rot_last_round = level.zm_dmw_rot_round;
        level thread zm_dmw_rot_move();
    }
    else
    {
        level.zm_dmw_rot_every = int(zm_dmw_rot_dv("phantom_o_rotn", "1"));
        if (level.zm_dmw_rot_every < 1)
        {
            level.zm_dmw_rot_every = 1;
        }
        if (level.zm_dmw_rot_round >= level.zm_dmw_rot_last_round + level.zm_dmw_rot_every)
        {
            level.zm_dmw_rot_last_round = level.zm_dmw_rot_round;
            level thread zm_dmw_rot_move();
        }
    }
    zm_dmw_rot_keep();
}

// all places to rotate between (built once per match)
zm_dmw_rot_build()
{
    if (isdefined(level.zm_dmw_rot_spots))
    {
        return;
    }
    level.zm_dmw_rot_spots = [];
    level.zm_dmw_rot_names = [];
    level.zm_dmw_rot_kind = [];
    zm_dmw_zones();
    for (level.zm_dmw_rb = 0; level.zm_dmw_rb < level.zm_dmw_zone_pos.size; level.zm_dmw_rb++)
    {
        level.zm_dmw_rot_spots[level.zm_dmw_rot_spots.size] = level.zm_dmw_zone_pos[level.zm_dmw_rb];
        level.zm_dmw_rot_names[level.zm_dmw_rot_names.size] = level.zm_dmw_zone_names[level.zm_dmw_rb];
        level.zm_dmw_rot_kind[level.zm_dmw_rot_kind.size] = "zone";
    }
    level.zm_dmw_rot_zone_n = level.zm_dmw_rot_spots.size;
    // hidden spots: walkable ground next to map objects that are far from every zone and each other
    level.zm_dmw_rents = getentarray();
    level.zm_dmw_rot_wild_n = 0;
    for (level.zm_dmw_rb = 0; level.zm_dmw_rb < level.zm_dmw_rents.size && level.zm_dmw_rot_wild_n < 40; level.zm_dmw_rb++)
    {
        level.zm_dmw_re = level.zm_dmw_rents[level.zm_dmw_rb];
        if (!isdefined(level.zm_dmw_re) || !isdefined(level.zm_dmw_re.origin) || isplayer(level.zm_dmw_re) || isai(level.zm_dmw_re))
        {
            continue;
        }
        level.zm_dmw_rn = getclosestpointonnavmesh(level.zm_dmw_re.origin);
        if (!isdefined(level.zm_dmw_rn) || distance(level.zm_dmw_rn, level.zm_dmw_re.origin) > 300)
        {
            continue;
        }
        level.zm_dmw_rfar = 1;
        for (level.zm_dmw_rc = 0; level.zm_dmw_rc < level.zm_dmw_rot_spots.size; level.zm_dmw_rc++)
        {
            level.zm_dmw_rlim = 800;
            if (level.zm_dmw_rot_kind[level.zm_dmw_rc] == "zone")
            {
                level.zm_dmw_rlim = 1200;
            }
            if (distance(level.zm_dmw_rn, level.zm_dmw_rot_spots[level.zm_dmw_rc]) < level.zm_dmw_rlim)
            {
                level.zm_dmw_rfar = 0;
                break;
            }
        }
        if (!level.zm_dmw_rfar)
        {
            continue;
        }
        level.zm_dmw_rot_wild_n++;
        level.zm_dmw_rot_spots[level.zm_dmw_rot_spots.size] = level.zm_dmw_rn + (0, 0, 8);
        level.zm_dmw_rot_names[level.zm_dmw_rot_names.size] = "hidden spot " + level.zm_dmw_rot_wild_n;
        level.zm_dmw_rot_kind[level.zm_dmw_rot_kind.size] = "wild";
    }
    // the player's saved spots on this map count as hidden spots too
    for (level.zm_dmw_rb = 1; level.zm_dmw_rb <= 5; level.zm_dmw_rb++)
    {
        level.zm_dmw_rsv = nengine_store_get("devmenu", "spot_" + level.script + "_" + level.zm_dmw_rb);
        if (!isdefined(level.zm_dmw_rsv) || !isstring(level.zm_dmw_rsv) || level.zm_dmw_rsv == "")
        {
            continue;
        }
        level.zm_dmw_rsp = strtok(level.zm_dmw_rsv, " ");
        if (level.zm_dmw_rsp.size < 3)
        {
            continue;
        }
        level.zm_dmw_rot_spots[level.zm_dmw_rot_spots.size] = (float(level.zm_dmw_rsp[0]), float(level.zm_dmw_rsp[1]), float(level.zm_dmw_rsp[2]));
        level.zm_dmw_rot_names[level.zm_dmw_rot_names.size] = "saved spot " + level.zm_dmw_rb;
        level.zm_dmw_rot_kind[level.zm_dmw_rot_kind.size] = "wild";
    }
    nengine_store_set("devmenu_dbg", "rot_spots", level.zm_dmw_rot_zone_n + " zones, " + (level.zm_dmw_rot_spots.size - level.zm_dmw_rot_zone_n) + " hidden/saved");
}

zm_dmw_rot_move()
{
    zm_dmw_rot_build();
    if (level.zm_dmw_rot_spots.size < 1)
    {
        nengine_store_set("devmenu_dbg", "rot_fail", "no spots");
        return;
    }
    level.zm_dmw_rmode = zm_dmw_rot_dv("phantom_o_rotspots", "0");
    // pick a place of the wanted kind, not the current one, preferring places far from here
    level.zm_dmw_rpick = undefined;
    for (level.zm_dmw_rtry = 0; level.zm_dmw_rtry < 40; level.zm_dmw_rtry++)
    {
        level.zm_dmw_ri = randomint(level.zm_dmw_rot_spots.size);
        level.zm_dmw_rk = level.zm_dmw_rot_kind[level.zm_dmw_ri];
        if (level.zm_dmw_rmode == "1" && level.zm_dmw_rk != "zone")
        {
            continue;
        }
        if (level.zm_dmw_rmode == "2" && level.zm_dmw_rk != "wild")
        {
            continue;
        }
        if (isdefined(level.zm_dmw_rot_center) && distance(level.zm_dmw_rot_spots[level.zm_dmw_ri], level.zm_dmw_rot_center) < 1000 && level.zm_dmw_rtry < 30)
        {
            continue;
        }
        level.zm_dmw_rpick = level.zm_dmw_ri;
        break;
    }
    if (!isdefined(level.zm_dmw_rpick))
    {
        level.zm_dmw_rpick = randomint(level.zm_dmw_rot_spots.size);
    }
    level.zm_dmw_rot_target = level.zm_dmw_rot_spots[level.zm_dmw_rpick];
    level.zm_dmw_rot_tname = level.zm_dmw_rot_names[level.zm_dmw_rpick];
    if (isdefined(level.zm_dm_tell_fn))
    {
        [[ level.zm_dm_tell_fn ]]("^5MAP ROTATION^7 - moving to " + level.zm_dmw_rot_tname + " in 3 seconds");
    }
    wait 3;
    zm_dmw_rot_arrive();
}

zm_dmw_rot_arrive()
{
    level.zm_dmw_rot_center = level.zm_dmw_rot_target;
    for (level.zm_dmw_rp = 0; level.zm_dmw_rp < level.players.size; level.zm_dmw_rp++)
    {
        level.zm_dmw_rpl = level.players[level.zm_dmw_rp];
        if (isdefined(level.zm_dmw_rpl) && isalive(level.zm_dmw_rpl))
        {
            level.zm_dmw_rpl zm_dmw_teleport(level.zm_dmw_rot_center + (level.zm_dmw_rp * 40, 0, 0), "");
        }
    }
    level.zm_dmw_rot_moves = zm_dmw_count(level.zm_dmw_rot_moves);
    nengine_store_set("devmenu_dbg", "rot_last", level.zm_dmw_rot_tname + " (" + int(level.zm_dmw_rot_center[0]) + " " + int(level.zm_dmw_rot_center[1]) + " " + int(level.zm_dmw_rot_center[2]) + ") round " + level.zm_dmw_rot_round);
    nengine_store_set("devmenu_dbg", "rot_moves", level.zm_dmw_rot_moves);
    if (isdefined(level.zm_dm_tell_fn))
    {
        [[ level.zm_dm_tell_fn ]]("^5MAP ROTATION^7 - " + level.zm_dmw_rot_tname + ": you can't leave this area until the next rotation");
    }
}

// keeps players inside the circle and brings far zombies in
zm_dmw_rot_keep()
{
    if (!isdefined(level.zm_dmw_rot_center))
    {
        return;
    }
    level.zm_dmw_rr = int(zm_dmw_rot_dv("phantom_o_rotr", "900"));
    if (level.zm_dmw_rr < 300)
    {
        level.zm_dmw_rr = 900;
    }
    for (level.zm_dmw_rp = 0; level.zm_dmw_rp < level.players.size; level.zm_dmw_rp++)
    {
        level.zm_dmw_rpl = level.players[level.zm_dmw_rp];
        if (!isdefined(level.zm_dmw_rpl) || !isalive(level.zm_dmw_rpl))
        {
            continue;
        }
        level.zm_dmw_rd = distance2d(level.zm_dmw_rpl.origin, level.zm_dmw_rot_center);
        if (level.zm_dmw_rd <= level.zm_dmw_rr && abs(level.zm_dmw_rpl.origin[2] - level.zm_dmw_rot_center[2]) < 600)
        {
            continue;
        }
        // back inside: a walkable point a little inside the edge, else the centre
        level.zm_dmw_rdir = vectornormalize((level.zm_dmw_rpl.origin[0] - level.zm_dmw_rot_center[0], level.zm_dmw_rpl.origin[1] - level.zm_dmw_rot_center[1], 0));
        level.zm_dmw_rback = getclosestpointonnavmesh(level.zm_dmw_rot_center + level.zm_dmw_rdir * (level.zm_dmw_rr - 120));
        if (!isdefined(level.zm_dmw_rback) || distance2d(level.zm_dmw_rback, level.zm_dmw_rot_center) > level.zm_dmw_rr)
        {
            level.zm_dmw_rback = level.zm_dmw_rot_center;
        }
        level.zm_dmw_rpl setorigin(level.zm_dmw_rback + (0, 0, 8));
        level.zm_dmw_rot_backs = zm_dmw_count(level.zm_dmw_rot_backs);
        nengine_store_set("devmenu_dbg", "rot_backs", level.zm_dmw_rot_backs);
        if (!isdefined(level.zm_dmw_rpl.zm_dmw_rot_told) || gettime() - level.zm_dmw_rpl.zm_dmw_rot_told > 4000)
        {
            level.zm_dmw_rpl.zm_dmw_rot_told = gettime();
            if (isdefined(level.zm_dm_tell_fn))
            {
                [[ level.zm_dm_tell_fn ]]("^1you can't leave this area^7 until the next map rotation");
            }
        }
    }
    // far zombies are brought in every 2 seconds (so a round can always be finished)
    level.zm_dmw_rot_zt = zm_dmw_count(level.zm_dmw_rot_zt);
    if (level.zm_dmw_rot_zt % 8 != 0 || zm_dmw_rot_dv("phantom_o_rotstay", "0") == "1")
    {
        return;
    }
    level.zm_dmw_rz = zm_dmw_list();
    for (level.zm_dmw_rzi = 0; level.zm_dmw_rzi < level.zm_dmw_rz.size; level.zm_dmw_rzi++)
    {
        level.zm_dmw_rza = level.zm_dmw_rz[level.zm_dmw_rzi];
        if (!isdefined(level.zm_dmw_rza) || !isalive(level.zm_dmw_rza) || zm_dmw_protected(level.zm_dmw_rza))
        {
            continue;
        }
        if (distance(level.zm_dmw_rza.origin, level.zm_dmw_rot_center) < level.zm_dmw_rr + 600)
        {
            continue;
        }
        level.zm_dmw_rang = randomint(360);
        level.zm_dmw_rzp = getclosestpointonnavmesh(level.zm_dmw_rot_center + (cos(level.zm_dmw_rang) * level.zm_dmw_rr * 0.8, sin(level.zm_dmw_rang) * level.zm_dmw_rr * 0.8, 0));
        if (!isdefined(level.zm_dmw_rzp) || distance2d(level.zm_dmw_rzp, level.zm_dmw_rot_center) > level.zm_dmw_rr)
        {
            level.zm_dmw_rzp = level.zm_dmw_rot_center;
        }
        level.zm_dmw_rza forceteleport(level.zm_dmw_rzp + (0, 0, 8), (0, randomint(360), 0));
        level.zm_dmw_rot_zin = zm_dmw_count(level.zm_dmw_rot_zin);
    }
    nengine_store_set("devmenu_dbg", "rot_zombies_in", level.zm_dmw_rot_zin);
}
