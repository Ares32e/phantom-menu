// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_fun - Phantom menu "Chaos" + secret options (own code, game built-ins only).
// Reached from the main menu with action "zz <action> [value]" (level.zm_dmz_run).
// State on level / player / AI fields (Kronos GSC loses locals after calls and waits).

#using scripts\common\utility;
// game outline system (rainbow zombies)
#using script_7af4b8f37e520205;

autoexec zm_dmz_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmz_init_is_zombies())
    {
        return;
    }
    level.zm_dmz_run = &zm_dmz_run;
    level.zm_dmz_drop = &zm_dmz_drop;
    level.zm_dmz_fxnames_fn = &zm_dmz_fx_names;
    level.zm_dmz_fxat = &zm_dmz_fx_at;
    nengine_store_set("devmenu_dbg", "fun", "linked");
}

zm_dmz_run(a, v)
{
    self.zm_dmz_a = a;
    self.zm_dmz_v = v;
    zm_dmz_input_start();
    if (a == "slowmo")
    {
        level.zm_dmz_slow = 1 - zm_dmz_flag(level.zm_dmz_slow);
        if (level.zm_dmz_slow)
        {
            setslowmotion(1, zm_dmz_num("slowmo_scale", 0.35), 0.5);
            return "bullet time ON";
        }
        setslowmotion(zm_dmz_num("slowmo_scale", 0.35), 1, 0.5);
        return "bullet time OFF";
    }
    if (a == "pound")
    {
        return "ground pound: " + self zm_dmz_pound(self.origin, zm_dmz_num("pound_r", 350), 1) + " zombies";
    }
    if (a == "punch")
    {
        self.zm_dmz_punch = 1 - zm_dmz_flag(self.zm_dmz_punch);
        return "explosive punch " + zm_dmz_onoff(self.zm_dmz_punch) + " (knife with the menu closed)";
    }
    if (a == "tpgun")
    {
        self.zm_dmz_tpgun = 1 - zm_dmz_flag(self.zm_dmz_tpgun);
        return "teleport gun " + zm_dmz_onoff(self.zm_dmz_tpgun) + " (shoot with the menu closed)";
    }
    if (a == "yeet")
    {
        level.zm_dmz_yl = zm_dmz_list();
        level.zm_dmz_yn = 0;
        for (level.zm_dmz_yi = 0; level.zm_dmz_yi < level.zm_dmz_yl.size; level.zm_dmz_yi++)
        {
            level.zm_dmz_ya = level.zm_dmz_yl[level.zm_dmz_yi];
            if (zm_dmz_ok(level.zm_dmz_ya) && distance(level.zm_dmz_ya.origin, self.origin) < zm_dmz_num("yeet_r", 700))
            {
                level.zm_dmz_ya thread zm_dmz_launch(randomfloatrange(500, 900), 1);
                level.zm_dmz_yn++;
            }
        }
        earthquake(0.3, 0.8, self.origin, 800);
        return "launched " + level.zm_dmz_yn + " zombies";
    }
    if (a == "zgrab")
    {
        return self zm_dmz_grab();
    }
    if (a == "zthrow")
    {
        return self zm_dmz_throw();
    }
    if (a == "orbit")
    {
        level.zm_dmz_orbit = 1 - zm_dmz_flag(level.zm_dmz_orbit);
        if (level.zm_dmz_orbit)
        {
            self thread zm_dmz_orbit_loop();
            return "zombie orbit ON";
        }
        return "zombie orbit OFF";
    }
    if (a == "rapture")
    {
        level.zm_dmz_rap = 1 - zm_dmz_flag(level.zm_dmz_rap);
        if (level.zm_dmz_rap)
        {
            return "zombies float: " + self zm_dmz_rapture_on() + " lifted";
        }
        zm_dmz_rapture_off();
        return "zombies come down";
    }
    if (a == "quake")
    {
        earthquake(0.6, 3, self.origin, 3000);
        return "earthquake!";
    }
    if (a == "fxgun")
    {
        self.zm_dmz_fxgun = 1 - zm_dmz_flag(self.zm_dmz_fxgun);
        zm_dmz_fx_names();
        return "effect gun " + zm_dmz_onoff(self.zm_dmz_fxgun) + " (a random effect where you shoot)";
    }
    if (a == "zeus")
    {
        self.zm_dmz_zeus = 1 - zm_dmz_flag(self.zm_dmz_zeus);
        return "Zeus shots " + zm_dmz_onoff(self.zm_dmz_zeus) + " (lightning where you shoot)";
    }
    if (a == "freezeray")
    {
        self.zm_dmz_fray = 1 - zm_dmz_flag(self.zm_dmz_fray);
        return "freeze-ray shots " + zm_dmz_onoff(self.zm_dmz_fray) + " (zombies freeze, then shatter)";
    }
    if (a == "meteor")
    {
        level.zm_dmz_meteor = 1 - zm_dmz_flag(level.zm_dmz_meteor);
        if (level.zm_dmz_meteor)
        {
            self thread zm_dmz_meteor_loop();
        }
        return "meteor shower " + zm_dmz_onoff(level.zm_dmz_meteor);
    }
    if (a == "snap")
    {
        return "snap: " + self zm_dmz_snap() + " zombies turn to dust";
    }
    if (a == "burn")
    {
        level.zm_dmz_burn = 1 - zm_dmz_flag(level.zm_dmz_burn);
        if (level.zm_dmz_burn)
        {
            level thread zm_dmz_burn_loop();
        }
        return "burning zombies " + zm_dmz_onoff(level.zm_dmz_burn);
    }
    if (a == "invis")
    {
        level.zm_dmz_invis = 1 - zm_dmz_flag(level.zm_dmz_invis);
        if (level.zm_dmz_invis)
        {
            level thread zm_dmz_invis_loop();
        }
        return "invisible zombies " + zm_dmz_onoff(level.zm_dmz_invis);
    }
    if (a == "spin")
    {
        if (isdefined(level.zm_dmz_twmode) && level.zm_dmz_twmode == "spin")
        {
            zm_dmz_twist_off();
            return "beyblade zombies OFF";
        }
        return "beyblade zombies: " + self zm_dmz_twist_on("spin") + " spinning";
    }
    if (a == "flip")
    {
        if (isdefined(level.zm_dmz_twmode) && level.zm_dmz_twmode == "flip")
        {
            zm_dmz_twist_off();
            return "upside-down zombies OFF";
        }
        return "upside-down zombies: " + self zm_dmz_twist_on("flip") + " flipped";
    }
    if (a == "tornado")
    {
        return "zombie tornado: " + self zm_dmz_tornado() + " caught";
    }
    if (a == "conga")
    {
        if (zm_dmz_flag(level.zm_dmz_conga))
        {
            zm_dmz_conga_off();
            return "conga line OFF";
        }
        return "conga line: " + self zm_dmz_conga_on() + " zombies follow you";
    }
    if (a == "boom")
    {
        self.zm_dmz_boom = 1 - zm_dmz_flag(self.zm_dmz_boom);
        return "explosive bullets " + zm_dmz_onoff(self.zm_dmz_boom) + " (every shot blows up where it hits)";
    }
    if (a == "fireworks")
    {
        return "fireworks: " + self zm_dmz_fireworks() + " zombies";
    }
    if (a == "magnet")
    {
        return "zombie magnet: " + self zm_dmz_magnet() + " pulled in";
    }
    if (a == "powerparty")
    {
        return "power-up party: " + self zm_dmz_powerup_party() + " power-ups";
    }
    if (a == "step")
    {
        self.zm_dmz_step = 1 - zm_dmz_flag(self.zm_dmz_step);
        return "shadow step " + zm_dmz_onoff(self.zm_dmz_step) + " (knife with the menu closed)";
    }
    if (a == "storm")
    {
        level.zm_dmz_storm = 1 - zm_dmz_flag(level.zm_dmz_storm);
        if (level.zm_dmz_storm)
        {
            self thread zm_dmz_storm_loop();
        }
        return "lightning storm " + zm_dmz_onoff(level.zm_dmz_storm);
    }
    if (a == "aura")
    {
        self.zm_dmz_aura = 1 - zm_dmz_flag(self.zm_dmz_aura);
        if (self.zm_dmz_aura)
        {
            self thread zm_dmz_aura_loop();
        }
        return "death aura " + zm_dmz_onoff(self.zm_dmz_aura);
    }
    if (a == "nova")
    {
        return "frost nova: " + self zm_dmz_frost_nova() + " frozen";
    }
    if (a == "rainbow")
    {
        level.zm_dmz_rb = 1 - zm_dmz_flag(level.zm_dmz_rb);
        if (level.zm_dmz_rb)
        {
            self thread zm_dmz_rainbow_loop();
            return "rainbow zombies ON";
        }
        return "rainbow zombies OFF";
    }
    if (a == "blackhole")
    {
        self thread zm_dmz_blackhole();
        return "black hole!";
    }
    if (a == "rocket")
    {
        self.zm_dmz_rk = self zm_dmz_look();
        if (!isdefined(self.zm_dmz_rk))
        {
            return "^1look at a zombie first";
        }
        self.zm_dmz_rk thread zm_dmz_rocket(self);
        return "zombie rocket!";
    }
    if (a == "bounce")
    {
        level.zm_dmz_bn = 1 - zm_dmz_flag(level.zm_dmz_bn);
        if (level.zm_dmz_bn)
        {
            self thread zm_dmz_bounce_loop();
            return "zombie trampoline ON";
        }
        return "zombie trampoline OFF";
    }
    if (a == "fxlist")
    {
        return "effects: " + zm_dmz_fx_dump();
    }
    if (a == "fxplay")
    {
        self.zm_dmz_fxpa = self getplayerangles();
        self.zm_dmz_fxp = self.origin + anglestoforward((0, self.zm_dmz_fxpa[1], 0)) * 250 + (0, 0, 60);
        level.zm_dmz_fxk = self.zm_dmz_v;
        self thread zm_dmz_fx_try(level.zm_dmz_fxk, self.zm_dmz_fxp);
        return "playing effect " + level.zm_dmz_fxk;
    }
    if (a == "sndplay")
    {
        self playsound(self.zm_dmz_v);
        nengine_store_set("devmenu_dbg", "snd_last", self.zm_dmz_v);
        return "sound " + self.zm_dmz_v;
    }
    if (a == "hell")
    {
        earthquake(0.5, 4, self.origin, 4000);
        setslowmotion(1, 0.5, 0.3);
        level.zm_dmz_slow = 1;
        self thread zm_dmz_hell_end();
        return "^1HELL MODE^7 - welcome";
    }
    return "unknown fun action " + a;
}

// ---------------------------------------------------------------- helpers

zm_dmz_list()
{
    // the game's zombies, plus AI the menu spawned (those are on team "axis")
    if (isdefined(level.zombie_team))
    {
        level.zm_dmz_list_a = getaiarray(level.zombie_team);
    }
    else
    {
        level.zm_dmz_list_a = getaiarray("team_two_hundred");
    }
    if (!isdefined(level.zombie_team) || level.zombie_team != "axis")
    {
        level.zm_dmz_list_b = getaiarray("axis");
        for (level.zm_dmz_list_i = 0; level.zm_dmz_list_i < level.zm_dmz_list_b.size; level.zm_dmz_list_i++)
        {
            level.zm_dmz_list_a[level.zm_dmz_list_a.size] = level.zm_dmz_list_b[level.zm_dmz_list_i];
        }
    }
    return level.zm_dmz_list_a;
}

zm_dmz_ok(ai)
{
    if (!isdefined(ai) || !isalive(ai))
    {
        return 0;
    }
    // b_ignore_cleanup is set on specials (Abominations, HVTs ...) too, so it is not a reason to skip here
    if (zm_dmz_flag(ai.magic_bullet_shield) || zm_dmz_flag(ai.damageshield) || zm_dmz_flag(ai.zm_dmz_busy))
    {
        return 0;
    }
    return 1;
}

zm_dmz_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

zm_dmz_onoff(v)
{
    if (v)
    {
        return "ON";
    }
    return "OFF";
}

zm_dmz_num(key, def)
{
    level.zm_dmz_nv = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dmz_nv) || (isstring(level.zm_dmz_nv) && level.zm_dmz_nv == "") || (!isstring(level.zm_dmz_nv) && level.zm_dmz_nv == 0))
    {
        return def;
    }
    if (isstring(level.zm_dmz_nv))
    {
        return float(level.zm_dmz_nv);
    }
    return level.zm_dmz_nv;
}

zm_dmz_count(key)
{
    level.zm_dmz_cv = nengine_store_get("devmenu_dbg", key);
    if (!isdefined(level.zm_dmz_cv) || isstring(level.zm_dmz_cv))
    {
        level.zm_dmz_cv = 0;
    }
    nengine_store_set("devmenu_dbg", key, level.zm_dmz_cv + 1);
}

// self = AI: die as a rag doll.
zm_dmz_ragdoll_kill()
{
    self.no_powerups = 1;
    self kill();
    if (isdefined(self))
    {
        self startragdoll();
    }
}

// Kill zombies within r of pos (all around, or in front of self when front = 0 uses aim).
zm_dmz_pound(pos, r, all)
{
    self.zm_dmz_pp = pos;
    self.zm_dmz_pr = r;
    self.zm_dmz_pf = anglestoforward(self getplayerangles());
    level.zm_dmz_pl = zm_dmz_list();
    level.zm_dmz_pn = 0;
    for (level.zm_dmz_pi = 0; level.zm_dmz_pi < level.zm_dmz_pl.size; level.zm_dmz_pi++)
    {
        level.zm_dmz_pa = level.zm_dmz_pl[level.zm_dmz_pi];
        if (!zm_dmz_ok(level.zm_dmz_pa))
        {
            continue;
        }
        if (distance(level.zm_dmz_pa.origin, self.zm_dmz_pp) > self.zm_dmz_pr)
        {
            continue;
        }
        level.zm_dmz_pa thread zm_dmz_launch(randomfloatrange(150, 350), 1);
        level.zm_dmz_pn++;
    }
    earthquake(0.45, 1, self.zm_dmz_pp, 900);
    zm_dmz_fx_at(zm_dmz_str("pound_fx", "shatterblast_explosion_effect"), self.zm_dmz_pp, 3);
    zm_dmz_snd_at(zm_dmz_str("pound_snd", "prj_ammomod_shatterblast_proc_explode"), self.zm_dmz_pp);
    zm_dmz_count("fun_pound");
    return level.zm_dmz_pn;
}

// self = AI: fly up h units (mover), then die as a rag doll when kill = 1.
zm_dmz_launch(h, killit)
{
    self.zm_dmz_busy = 1;
    self.zm_dmz_lh = h;
    self.zm_dmz_lk = killit;
    self.zm_dmz_mv = spawn("script_origin", self.origin);
    self linkto(self.zm_dmz_mv);
    self.zm_dmz_mv moveto(self.origin + (randomfloatrange(-80, 80), randomfloatrange(-80, 80), self.zm_dmz_lh), 0.45, 0, 0.3);
    wait 0.45;
    if (!isdefined(self))
    {
        return;
    }
    self unlink();
    if (isdefined(self.zm_dmz_mv))
    {
        self.zm_dmz_mv delete();
    }
    zm_dmz_count("fun_launched");
    if (self.zm_dmz_lk)
    {
        self zm_dmz_ragdoll_kill();
    }
    else
    {
        self.zm_dmz_busy = 0;
    }
}

// ---------------------------------------------------------------- input (knife / shoot events)

zm_dmz_input_start()
{
    if (isdefined(self.zm_dmz_in))
    {
        return;
    }
    self.zm_dmz_in = 1;
    self notifyonplayercommand("zm_dmz_melee", "+melee");
    self notifyonplayercommand("zm_dmz_melee", "+melee_zoom");
    self notifyonplayercommand("zm_dmz_fire", "+attack");
    self thread zm_dmz_melee_loop();
    self thread zm_dmz_fire_loop();
}

zm_dmz_menu_open()
{
    if (isdefined(level.zm_dm_open) && level.zm_dm_open)
    {
        return 1;
    }
    return 0;
}

zm_dmz_melee_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmz_melee");
        if (zm_dmz_flag(self.zm_dmz_step) && !zm_dmz_menu_open())
        {
            self zm_dmz_shadow_step();
        }
        else if (zm_dmz_flag(self.zm_dmz_punch) && !zm_dmz_menu_open())
        {
            self zm_dmz_punch_hit();
        }
    }
}

zm_dmz_punch_hit()
{
    self.zm_dmz_hf = anglestoforward(self getplayerangles());
    self zm_dmz_pound(self.origin + self.zm_dmz_hf * 90, zm_dmz_num("punch_r", 170), 0);
    zm_dmz_count("fun_punch");
}

zm_dmz_fire_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmz_fire");
        if (zm_dmz_flag(self.zm_dmz_tpgun) && !zm_dmz_menu_open())
        {
            self zm_dmz_teleport_aim();
        }
        else if (zm_dmz_flag(self.zm_dmz_boom) && !zm_dmz_menu_open())
        {
            self zm_dmz_boom_shot();
        }
        if (zm_dmz_flag(self.zm_dmz_fxgun) && !zm_dmz_menu_open())
        {
            self zm_dmz_fxgun_shot();
        }
        if (zm_dmz_flag(self.zm_dmz_zeus) && !zm_dmz_menu_open())
        {
            self zm_dmz_zeus_shot();
        }
        if (zm_dmz_flag(self.zm_dmz_fray) && !zm_dmz_menu_open())
        {
            self zm_dmz_freeze_shot();
        }
    }
}

// Teleport gun: to where the aim line hits the world (game physics trace), on walkable ground.
zm_dmz_teleport_aim()
{
    self.zm_dmz_eye = self geteye();
    self.zm_dmz_af = anglestoforward(self getplayerangles());
    self.zm_dmz_hit = physicstrace(self.zm_dmz_eye, self.zm_dmz_eye + self.zm_dmz_af * zm_dmz_num("tpgun_range", 4000));
    if (!isdefined(self.zm_dmz_hit))
    {
        return;
    }
    self.zm_dmz_to = self.zm_dmz_hit - self.zm_dmz_af * 40;
    self.zm_dmz_nav = getclosestpointonnavmesh(self.zm_dmz_to);
    if (isdefined(self.zm_dmz_nav) && distance(self.zm_dmz_nav, self.zm_dmz_to) < 300)
    {
        self.zm_dmz_to = self.zm_dmz_nav;
    }
    zm_dmz_fx_at(zm_dmz_str("tpgun_fx_out", "aether_shroud_teleport"), self.origin, 2);
    self setorigin(self.zm_dmz_to);
    zm_dmz_fx_at(zm_dmz_str("tpgun_fx_in", "teleport_splash"), self.zm_dmz_to, 2);
    zm_dmz_snd_at(zm_dmz_str("tpgun_snd", "evt_zm_sat_pap_teleport_in"), self.zm_dmz_to);
    zm_dmz_count("fun_tpgun");
    nengine_store_set("devmenu_dbg", "fun_tp_last", int(self.zm_dmz_to[0]) + " " + int(self.zm_dmz_to[1]) + " " + int(self.zm_dmz_to[2]));
}

// ---------------------------------------------------------------- gravity gun (zombies)

zm_dmz_look()
{
    self.zm_dmz_lb = undefined;
    self.zm_dmz_lbs = 0.97;
    self.zm_dmz_leye = self geteye();
    self.zm_dmz_lf = anglestoforward(self getplayerangles());
    level.zm_dmz_ll = zm_dmz_list();
    for (level.zm_dmz_li = 0; level.zm_dmz_li < level.zm_dmz_ll.size; level.zm_dmz_li++)
    {
        level.zm_dmz_la = level.zm_dmz_ll[level.zm_dmz_li];
        if (!zm_dmz_ok(level.zm_dmz_la))
        {
            continue;
        }
        level.zm_dmz_ld = (level.zm_dmz_la.origin + (0, 0, 40)) - self.zm_dmz_leye;
        level.zm_dmz_llen = length(level.zm_dmz_ld);
        if (level.zm_dmz_llen < 1 || level.zm_dmz_llen > 2500)
        {
            continue;
        }
        level.zm_dmz_lc = vectordot(level.zm_dmz_ld, self.zm_dmz_lf) / level.zm_dmz_llen;
        if (level.zm_dmz_lc > self.zm_dmz_lbs)
        {
            self.zm_dmz_lbs = level.zm_dmz_lc;
            self.zm_dmz_lb = level.zm_dmz_la;
        }
    }
    if (!isdefined(self.zm_dmz_lb))
    {
        // nothing in the aim cone: the nearest zombie within 400 units
        self.zm_dmz_lbd = 400;
        for (level.zm_dmz_li = 0; level.zm_dmz_li < level.zm_dmz_ll.size; level.zm_dmz_li++)
        {
            level.zm_dmz_la = level.zm_dmz_ll[level.zm_dmz_li];
            if (zm_dmz_ok(level.zm_dmz_la) && distance(level.zm_dmz_la.origin, self.origin) < self.zm_dmz_lbd)
            {
                self.zm_dmz_lbd = distance(level.zm_dmz_la.origin, self.origin);
                self.zm_dmz_lb = level.zm_dmz_la;
            }
        }
    }
    return self.zm_dmz_lb;
}

zm_dmz_grab()
{
    if (isdefined(self.zm_dmz_g))
    {
        return "^1you're already holding a zombie - throw it";
    }
    self.zm_dmz_gt = self zm_dmz_look();
    if (!isdefined(self.zm_dmz_gt))
    {
        return "^1look at a zombie first";
    }
    self.zm_dmz_gt.zm_dmz_busy = 1;
    self.zm_dmz_gm = spawn("script_origin", self.zm_dmz_gt.origin);
    self.zm_dmz_gt linkto(self.zm_dmz_gm);
    self.zm_dmz_g = self.zm_dmz_gt;
    self thread zm_dmz_grab_loop();
    zm_dmz_count("fun_grab");
    return "zombie grabbed - look around, then Throw";
}

zm_dmz_grab_loop()
{
    self endon("disconnect");
    while (isdefined(self.zm_dmz_g) && isalive(self.zm_dmz_g) && isdefined(self.zm_dmz_gm))
    {
        self zm_dmz_grab_step();
        waitframe();
    }
    if (isdefined(self.zm_dmz_gm) && !zm_dmz_flag(self.zm_dmz_throwing))
    {
        self.zm_dmz_gm delete();
    }
    self.zm_dmz_g = undefined;
}

zm_dmz_grab_step()
{
    self.zm_dmz_gp = self geteye() + anglestoforward(self getplayerangles()) * 160 - (0, 0, 60);
    self.zm_dmz_gm.origin = self.zm_dmz_gp;
}

zm_dmz_throw()
{
    if (!isdefined(self.zm_dmz_g) || !isdefined(self.zm_dmz_gm))
    {
        return "^1grab a zombie first";
    }
    self.zm_dmz_tz = self.zm_dmz_g;
    self.zm_dmz_tm = self.zm_dmz_gm;
    self.zm_dmz_throwing = 1;
    self.zm_dmz_g = undefined;
    self.zm_dmz_eye2 = self geteye();
    self.zm_dmz_tf = anglestoforward(self getplayerangles());
    self.zm_dmz_tend = physicstrace(self.zm_dmz_eye2, self.zm_dmz_eye2 + self.zm_dmz_tf * 1500);
    if (!isdefined(self.zm_dmz_tend))
    {
        self.zm_dmz_tend = self.zm_dmz_eye2 + self.zm_dmz_tf * 1500;
    }
    self.zm_dmz_tm moveto(self.zm_dmz_tend - self.zm_dmz_tf * 40, 0.35);
    self.zm_dmz_tz thread zm_dmz_throw_end(self.zm_dmz_tm);
    self.zm_dmz_throwing = 0;
    zm_dmz_count("fun_throw");
    return "YEET";
}

// self = thrown AI
zm_dmz_throw_end(mover)
{
    self.zm_dmz_tmv = mover;
    wait 0.35;
    if (isdefined(self))
    {
        self unlink();
        self zm_dmz_ragdoll_kill();
    }
    if (isdefined(self.zm_dmz_tmv))
    {
        self.zm_dmz_tmv delete();
    }
}

// ---------------------------------------------------------------- orbit

zm_dmz_orbit_loop()
{
    self endon("disconnect");
    level.zm_dmz_ob = [];
    level.zm_dmz_obm = [];
    level.zm_dmz_ol = zm_dmz_list();
    // the round's zombies (HVTs / specials / bosses included when they are hunting); orbit_n / orbit_range limit it
    level.zm_dmz_omax = zm_dmz_num("orbit_n", 999);
    level.zm_dmz_orng = zm_dmz_num("orbit_range", 999999);
    for (level.zm_dmz_oi = 0; level.zm_dmz_oi < level.zm_dmz_ol.size && level.zm_dmz_ob.size < level.zm_dmz_omax; level.zm_dmz_oi++)
    {
        level.zm_dmz_oa = level.zm_dmz_ol[level.zm_dmz_oi];
        // only the round's zombies: ones that are hunting a player (sleeping / placed map zombies have no enemy)
        if (isdefined(level.zm_dmz_oa) && isalive(level.zm_dmz_oa) && isdefined(level.zm_dmz_oa.enemy) && !zm_dmz_flag(level.zm_dmz_oa.zm_dmz_busy) && distance(level.zm_dmz_oa.origin, self.origin) < level.zm_dmz_orng)
        {
            level.zm_dmz_oa.zm_dmz_busy = 1;
            level.zm_dmz_obm[level.zm_dmz_ob.size] = spawn("script_origin", level.zm_dmz_oa.origin);
            level.zm_dmz_oa linkto(level.zm_dmz_obm[level.zm_dmz_ob.size]);
            level.zm_dmz_ob[level.zm_dmz_ob.size] = level.zm_dmz_oa;
        }
    }
    nengine_store_set("devmenu_dbg", "fun_orbit", level.zm_dmz_ob.size);
    level.zm_dmz_ot = 0;
    while (zm_dmz_flag(level.zm_dmz_orbit))
    {
        self zm_dmz_orbit_step();
        waitframe();
    }
    for (level.zm_dmz_oi = 0; level.zm_dmz_oi < level.zm_dmz_ob.size; level.zm_dmz_oi++)
    {
        if (isdefined(level.zm_dmz_ob[level.zm_dmz_oi]))
        {
            level.zm_dmz_ob[level.zm_dmz_oi] unlink();
            level.zm_dmz_ob[level.zm_dmz_oi].zm_dmz_busy = 0;
        }
        if (isdefined(level.zm_dmz_obm[level.zm_dmz_oi]))
        {
            level.zm_dmz_obm[level.zm_dmz_oi] delete();
        }
    }
}

zm_dmz_orbit_step()
{
    level.zm_dmz_ot = level.zm_dmz_ot + zm_dmz_num("orbit_speed", 4);
    for (level.zm_dmz_oj = 0; level.zm_dmz_oj < level.zm_dmz_ob.size; level.zm_dmz_oj++)
    {
        if (!isdefined(level.zm_dmz_obm[level.zm_dmz_oj]))
        {
            continue;
        }
        // rings of 8: each further ring is wider, a bit higher and turns the other way
        level.zm_dmz_oring = int(level.zm_dmz_oj / 8);
        level.zm_dmz_oinr = level.zm_dmz_ob.size - level.zm_dmz_oring * 8;
        if (level.zm_dmz_oinr > 8)
        {
            level.zm_dmz_oinr = 8;
        }
        level.zm_dmz_odir = 1;
        if (level.zm_dmz_oring % 2 == 1)
        {
            level.zm_dmz_odir = -1;
        }
        level.zm_dmz_oyaw = level.zm_dmz_ot * level.zm_dmz_odir + (level.zm_dmz_oj % 8) * 360 / level.zm_dmz_oinr;
        level.zm_dmz_obm[level.zm_dmz_oj].origin = self.origin + anglestoforward((0, level.zm_dmz_oyaw, 0)) * (zm_dmz_num("orbit_r", 170) + level.zm_dmz_oring * 120) + (0, 0, 40 + level.zm_dmz_oring * 60);
    }
}

// ---------------------------------------------------------------- rapture (zombies float)

zm_dmz_rapture_on()
{
    level.zm_dmz_rp = [];
    level.zm_dmz_rpm = [];
    level.zm_dmz_rl = zm_dmz_list();
    for (level.zm_dmz_ri = 0; level.zm_dmz_ri < level.zm_dmz_rl.size; level.zm_dmz_ri++)
    {
        level.zm_dmz_ra = level.zm_dmz_rl[level.zm_dmz_ri];
        if (zm_dmz_ok(level.zm_dmz_ra) && distance(level.zm_dmz_ra.origin, self.origin) < 2000)
        {
            level.zm_dmz_ra.zm_dmz_busy = 1;
            level.zm_dmz_rpm[level.zm_dmz_rp.size] = spawn("script_origin", level.zm_dmz_ra.origin);
            level.zm_dmz_ra linkto(level.zm_dmz_rpm[level.zm_dmz_rp.size]);
            level.zm_dmz_rpm[level.zm_dmz_rp.size] moveto(level.zm_dmz_ra.origin + (0, 0, randomfloatrange(150, 300)), 3, 0.5, 1);
            level.zm_dmz_rp[level.zm_dmz_rp.size] = level.zm_dmz_ra;
        }
    }
    zm_dmz_count("fun_rapture");
    return level.zm_dmz_rp.size;
}

zm_dmz_rapture_off()
{
    if (!isdefined(level.zm_dmz_rp))
    {
        return;
    }
    for (level.zm_dmz_ri = 0; level.zm_dmz_ri < level.zm_dmz_rp.size; level.zm_dmz_ri++)
    {
        if (isdefined(level.zm_dmz_rp[level.zm_dmz_ri]) && isdefined(level.zm_dmz_rpm[level.zm_dmz_ri]))
        {
            level.zm_dmz_rp[level.zm_dmz_ri] thread zm_dmz_rapture_down(level.zm_dmz_rpm[level.zm_dmz_ri]);
        }
    }
    level.zm_dmz_rp = [];
}

// self = floating AI: drop back down, free it.
zm_dmz_rapture_down(mover)
{
    self.zm_dmz_rdm = mover;
    self.zm_dmz_rdn = getclosestpointonnavmesh(self.origin);
    if (isdefined(self.zm_dmz_rdn))
    {
        self.zm_dmz_rdm moveto(self.zm_dmz_rdn, 0.6, 0.4, 0);
        wait 0.6;
    }
    if (isdefined(self))
    {
        self unlink();
        self.zm_dmz_busy = 0;
    }
    if (isdefined(self.zm_dmz_rdm))
    {
        self.zm_dmz_rdm delete();
    }
}

// ---------------------------------------------------------------- zombie rain (called by main on each spawned AI)

// self = freshly spawned AI: start high above and drop down to where it spawned.
zm_dmz_drop()
{
    self.zm_dmz_busy = 1;
    self.zm_dmz_dp = self.origin;
    self.zm_dmz_dm = spawn("script_origin", self.origin + (0, 0, randomfloatrange(500, 900)));
    self linkto(self.zm_dmz_dm);
    self.zm_dmz_dm moveto(self.zm_dmz_dp, randomfloatrange(0.8, 1.4), 0.6, 0);
    wait 1.4;
    if (isdefined(self))
    {
        self unlink();
        self.zm_dmz_busy = 0;
        earthquake(0.15, 0.3, self.origin, 400);
    }
    if (isdefined(self.zm_dmz_dm))
    {
        self.zm_dmz_dm delete();
    }
}

// ---------------------------------------------------------------- secret: hell mode

zm_dmz_hell_end()
{
    self endon("disconnect");
    wait 6;
    setslowmotion(0.5, 1, 0.5);
    level.zm_dmz_slow = 0;
}

// ---------------------------------------------------------------- secret: rainbow zombies
// Every hunting zombie gets an outline whose colour cycles (game outline system).
zm_dmz_rainbow_loop()
{
    self endon("disconnect");
    level.zm_dmz_rbi = 0;
    while (zm_dmz_flag(level.zm_dmz_rb))
    {
        self zm_dmz_rainbow_step();
        wait 0.2;
    }
    self zm_dmz_rainbow_clear();
}

zm_dmz_rainbow_step()
{
    self zm_dmz_rainbow_clear();
    level.zm_dmz_rbc = strtok("outline_nodepth_red|outline_nodepth_orange|outline_nodepth_yellow|outline_nodepth_green|outline_nodepth_cyan|outline_nodepth_blue|outline_nodepth_purple", "|");
    level.zm_dmz_rbi++;
    level.zm_dmz_rbl = zm_dmz_list();
    level.zm_dmz_rbe = [];
    level.zm_dmz_rbid = [];
    for (level.zm_dmz_rj = 0; level.zm_dmz_rj < level.zm_dmz_rbl.size && level.zm_dmz_rbe.size < 40; level.zm_dmz_rj++)
    {
        level.zm_dmz_rba = level.zm_dmz_rbl[level.zm_dmz_rj];
        if (isdefined(level.zm_dmz_rba) && isalive(level.zm_dmz_rba) && isdefined(level.zm_dmz_rba.enemy))
        {
            level.zm_dmz_rbid[level.zm_dmz_rbe.size] = namespace_ba924364166f1600::function_a274c8bc03853643(level.zm_dmz_rba, self, level.zm_dmz_rbc[(level.zm_dmz_rbi + level.zm_dmz_rj) % level.zm_dmz_rbc.size], "level_script");
            level.zm_dmz_rbe[level.zm_dmz_rbe.size] = level.zm_dmz_rba;
        }
    }
    zm_dmz_count("fun_rainbow");
}

zm_dmz_rainbow_clear()
{
    if (!isdefined(level.zm_dmz_rbe))
    {
        return;
    }
    for (level.zm_dmz_rj = 0; level.zm_dmz_rj < level.zm_dmz_rbe.size; level.zm_dmz_rj++)
    {
        if (isdefined(level.zm_dmz_rbe[level.zm_dmz_rj]) && isdefined(level.zm_dmz_rbid[level.zm_dmz_rj]))
        {
            namespace_ba924364166f1600::function_a41e6d627e1bfc9c(level.zm_dmz_rbid[level.zm_dmz_rj], level.zm_dmz_rbe[level.zm_dmz_rj]);
        }
    }
    level.zm_dmz_rbe = [];
    level.zm_dmz_rbid = [];
}

// ---------------------------------------------------------------- secret: black hole
// A point 450 units in front of you pulls every hunting zombie within 1500 units into a spinning
// ball for 3 s, then blows them all away.
zm_dmz_blackhole()
{
    self endon("disconnect");
    self.zm_dmz_bpa = self getplayerangles();
    self.zm_dmz_bhf = anglestoforward((0, self.zm_dmz_bpa[1], 0));
    level.zm_dmz_bhp = self.origin + self.zm_dmz_bhf * 450 + (0, 0, 120);
    level.zm_dmz_bh = [];
    level.zm_dmz_bhm = [];
    level.zm_dmz_bl = zm_dmz_list();
    for (level.zm_dmz_bi = 0; level.zm_dmz_bi < level.zm_dmz_bl.size; level.zm_dmz_bi++)
    {
        level.zm_dmz_ba = level.zm_dmz_bl[level.zm_dmz_bi];
        if (zm_dmz_ok(level.zm_dmz_ba) && distance(level.zm_dmz_ba.origin, level.zm_dmz_bhp) < 1500)
        {
            level.zm_dmz_ba.zm_dmz_busy = 1;
            level.zm_dmz_bhm[level.zm_dmz_bh.size] = spawn("script_origin", level.zm_dmz_ba.origin);
            level.zm_dmz_ba linkto(level.zm_dmz_bhm[level.zm_dmz_bh.size]);
            level.zm_dmz_bh[level.zm_dmz_bh.size] = level.zm_dmz_ba;
        }
    }
    // dark trails on every pulled zombie (setting bh_fx_trail, "|" list), removed when it ends
    level.zm_dmz_bht_names = strtok(zm_dmz_str("bh_fx_trail", "shadow_vortex_teleport_trail|aether_energy_trail"), "|");
    for (level.zm_dmz_bi = 0; level.zm_dmz_bi < level.zm_dmz_bh.size; level.zm_dmz_bi++)
    {
        for (level.zm_dmz_btn = 0; level.zm_dmz_btn < level.zm_dmz_bht_names.size; level.zm_dmz_btn++)
        {
            level.zm_dmz_bh[level.zm_dmz_bi] thread zm_dmz_fx_on(level.zm_dmz_bht_names[level.zm_dmz_btn]);
        }
    }
    zm_dmz_count("fun_blackhole");
    nengine_store_set("devmenu_dbg", "fun_blackhole_n", level.zm_dmz_bh.size);
    // effects + sounds: the game's own (settings bh_fx_start / bh_fx_loop / bh_fx_end and
    // bh_snd_start / bh_snd_loop / bh_snd_end, "|"-separated names)
    // The hole itself is one effect entity (spawnfx, re-triggered while it lives) and one sound
    // entity with a looping sound; both are deleted when it ends, so nothing is left behind.
    // No screen shake and no screen-wide effects.
    level.zm_dmz_bhs = spawn("script_origin", level.zm_dmz_bhp);
    level.zm_dmz_bhs zm_dmz_snd_list(zm_dmz_str("bh_snd_start", "prj_ammomod_shadowvortex_proc_oneshot|wpn_dark_flare_fire_plr_start"));
    level.zm_dmz_bhs playloopsound(zm_dmz_str("bh_snd_loop", "wpn_dark_flare_spin_plr_loop"));
    level.zm_dmz_bhfx = [];
    zm_dmz_bh_core(30);
    level.zm_dmz_bht = 0;
    level.zm_dmz_bhf = 0;
    while (level.zm_dmz_bht < 3)
    {
        zm_dmz_blackhole_step();
        if (level.zm_dmz_bhf % 10 == 0)
        {
            // the core grows while it eats: a cluster of dark balls whose spread widens
            zm_dmz_bh_core(30 + level.zm_dmz_bht * 30);
        }
        if (level.zm_dmz_bhf % 6 == 3)
        {
            zm_dmz_bh_embers();
        }
        level.zm_dmz_bhf++;
        waitframe();
        level.zm_dmz_bht = level.zm_dmz_bht + 0.05;
    }
    // collapse: the hole goes, one burst where it was, then everything is removed
    zm_dmz_bh_core_clear();
    level.zm_dmz_bhs stoploopsound();
    level.zm_dmz_bhs zm_dmz_snd_list(zm_dmz_str("bh_snd_end", "evt_zm_core_powerup_nuke_explode|evt_zm_core_powerup_nuke_lfe|prj_ammomod_shatterblast_proc_explode|prj_ammomod_shadowvortex_disappear"));
    level.zm_dmz_bhe = strtok(zm_dmz_str("bh_fx_end", "shatterblast_explosion_effect_100|perk_phd_explode_lg|shadow_vortex_explosive"), "|");
    for (level.zm_dmz_bei = 0; level.zm_dmz_bei < level.zm_dmz_bhe.size; level.zm_dmz_bei++)
    {
        level.zm_dmz_bhend = zm_dmz_fx_spawn(level.zm_dmz_bhe[level.zm_dmz_bei], level.zm_dmz_bhp);
        if (isdefined(level.zm_dmz_bhend))
        {
            level.zm_dmz_bhend thread zm_dmz_delete_later(3);
        }
    }
    level.zm_dmz_bhs thread zm_dmz_delete_later(3);
    for (level.zm_dmz_bi = 0; level.zm_dmz_bi < level.zm_dmz_bh.size; level.zm_dmz_bi++)
    {
        if (isdefined(level.zm_dmz_bhm[level.zm_dmz_bi]))
        {
            level.zm_dmz_bhm[level.zm_dmz_bi] moveto(level.zm_dmz_bhp + anglestoforward((randomfloatrange(-40, 10), randomfloatrange(0, 360), 0)) * 700, 0.4);
        }
    }
    wait 0.4;
    for (level.zm_dmz_bi = 0; level.zm_dmz_bi < level.zm_dmz_bh.size; level.zm_dmz_bi++)
    {
        if (isdefined(level.zm_dmz_bh[level.zm_dmz_bi]))
        {
            level.zm_dmz_bh[level.zm_dmz_bi] zm_dmz_fx_off_all();
            level.zm_dmz_bh[level.zm_dmz_bi] unlink();
            level.zm_dmz_bh[level.zm_dmz_bi] zm_dmz_ragdoll_kill();
        }
        if (isdefined(level.zm_dmz_bhm[level.zm_dmz_bi]))
        {
            level.zm_dmz_bhm[level.zm_dmz_bi] delete();
        }
    }
}

zm_dmz_blackhole_step()
{
    // spiral in: radius shrinks from 400 to 40 while spinning
    level.zm_dmz_bhr = 400 - level.zm_dmz_bht * 144;
    if (level.zm_dmz_bhr < 40)
    {
        level.zm_dmz_bhr = 40;
    }
    for (level.zm_dmz_bj = 0; level.zm_dmz_bj < level.zm_dmz_bh.size; level.zm_dmz_bj++)
    {
        if (!isdefined(level.zm_dmz_bhm[level.zm_dmz_bj]))
        {
            continue;
        }
        level.zm_dmz_bya = level.zm_dmz_bht * 360 + level.zm_dmz_bj * 360 / level.zm_dmz_bh.size;
        level.zm_dmz_bpi = ((level.zm_dmz_bj * 37) % 60) - 30;
        level.zm_dmz_bhm[level.zm_dmz_bj].origin = level.zm_dmz_bhp + anglestoforward((level.zm_dmz_bpi, level.zm_dmz_bya, 0)) * level.zm_dmz_bhr;
    }
}

// ---------------------------------------------------------------- secret: zombie rocket
// self = AI: rises, then flies along the player's aim and blows up the zombies where it lands.
zm_dmz_rocket(p)
{
    self.zm_dmz_busy = 1;
    self.zm_dmz_rp = p;
    self.zm_dmz_reye = p geteye();
    self.zm_dmz_rf = anglestoforward(p getplayerangles());
    self.zm_dmz_rend = physicstrace(self.zm_dmz_reye, self.zm_dmz_reye + self.zm_dmz_rf * 3000);
    if (!isdefined(self.zm_dmz_rend))
    {
        self.zm_dmz_rend = self.zm_dmz_reye + self.zm_dmz_rf * 3000;
    }
    self.zm_dmz_rm = spawn("script_origin", self.origin);
    self linkto(self.zm_dmz_rm);
    self.zm_dmz_rm moveto(self.origin + (0, 0, 150), 0.3, 0.2, 0);
    wait 0.3;
    if (!isdefined(self))
    {
        return;
    }
    self.zm_dmz_rm moveto(self.zm_dmz_rend, 0.5, 0.4, 0);
    wait 0.5;
    if (isdefined(self.zm_dmz_rp))
    {
        self.zm_dmz_rp zm_dmz_pound(self.zm_dmz_rend, 300, 1);
    }
    if (isdefined(self))
    {
        self unlink();
        self zm_dmz_ragdoll_kill();
    }
    if (isdefined(self.zm_dmz_rm))
    {
        self.zm_dmz_rm delete();
    }
    zm_dmz_count("fun_rocket");
}

// ---------------------------------------------------------------- secret: zombie trampoline
// Hunting zombies near you hop high into the air now and then.
zm_dmz_bounce_loop()
{
    self endon("disconnect");
    while (zm_dmz_flag(level.zm_dmz_bn))
    {
        self zm_dmz_bounce_step();
        wait 0.5;
    }
}

zm_dmz_bounce_step()
{
    level.zm_dmz_bol = zm_dmz_list();
    for (level.zm_dmz_boi = 0; level.zm_dmz_boi < level.zm_dmz_bol.size; level.zm_dmz_boi++)
    {
        level.zm_dmz_boa = level.zm_dmz_bol[level.zm_dmz_boi];
        if (zm_dmz_ok(level.zm_dmz_boa) && isdefined(level.zm_dmz_boa.enemy) && distance(level.zm_dmz_boa.origin, self.origin) < 1500 && randomint(100) < 20)
        {
            level.zm_dmz_boa thread zm_dmz_hop();
        }
    }
}

// self = AI: one hop up and back down on the same spot.
zm_dmz_hop()
{
    self.zm_dmz_busy = 1;
    self.zm_dmz_hp0 = self.origin;
    self.zm_dmz_hm = spawn("script_origin", self.origin);
    self linkto(self.zm_dmz_hm);
    self.zm_dmz_hm moveto(self.origin + (0, 0, randomfloatrange(150, 300)), 0.4, 0, 0.35);
    wait 0.4;
    if (isdefined(self.zm_dmz_hm))
    {
        self.zm_dmz_hm moveto(self.zm_dmz_hp0, 0.4, 0.35, 0);
    }
    wait 0.4;
    if (isdefined(self))
    {
        self unlink();
        self.zm_dmz_busy = 0;
    }
    if (isdefined(self.zm_dmz_hm))
    {
        self.zm_dmz_hm delete();
    }
    zm_dmz_count("fun_hops");
}

// ---------------------------------------------------------------- effects (the game's own loaded effect tables)
// level.var_d1e5f36ab9f106 = the main effect table (filled by the game with loadfx), plus the
// other script tables. Keys are readable names at run time: written to dbg fx_<table>_<n> chunks.
zm_dmz_fx_dump()
{
    level.zm_dmz_fxtabs = [];
    level.zm_dmz_fxtabs["main"] = level.var_d1e5f36ab9f106;
    level.zm_dmz_fxtabs["t2"] = level.var_3acf9fbc9cf0f7b5;
    level.zm_dmz_fxtabs["t3"] = level.var_7e2f6e5a16d8b454;
    level.zm_dmz_fxtabs["t4"] = level.var_a8b7f48696aacf;
    level.zm_dmz_fxtabs["t5"] = level.var_788f1aed54176507;
    level.zm_dmz_fxtabs["t6"] = level.var_86a604cd1383c9e8;
    level.zm_dmz_fxtabs["t7"] = level.var_3e9f8ee09befcb87;
    level.zm_dmz_fxtn = getarraykeys(level.zm_dmz_fxtabs);
    level.zm_dmz_fxtotal = 0;
    for (level.zm_dmz_fti = 0; level.zm_dmz_fti < level.zm_dmz_fxtn.size; level.zm_dmz_fti++)
    {
        level.zm_dmz_fxt = level.zm_dmz_fxtabs[level.zm_dmz_fxtn[level.zm_dmz_fti]];
        if (!isdefined(level.zm_dmz_fxt))
        {
            continue;
        }
        level.zm_dmz_fxks = getarraykeys(level.zm_dmz_fxt);
        level.zm_dmz_fxs = "";
        level.zm_dmz_fxc = 0;
        for (level.zm_dmz_fki = 0; level.zm_dmz_fki < level.zm_dmz_fxks.size; level.zm_dmz_fki++)
        {
            level.zm_dmz_fxs = level.zm_dmz_fxs + level.zm_dmz_fxks[level.zm_dmz_fki] + "|";
            if (level.zm_dmz_fxs.size > 800)
            {
                nengine_store_set("devmenu_dbg", "fx_" + level.zm_dmz_fxtn[level.zm_dmz_fti] + "_" + level.zm_dmz_fxc, level.zm_dmz_fxs);
                level.zm_dmz_fxc++;
                level.zm_dmz_fxs = "";
            }
        }
        if (level.zm_dmz_fxs != "")
        {
            nengine_store_set("devmenu_dbg", "fx_" + level.zm_dmz_fxtn[level.zm_dmz_fti] + "_" + level.zm_dmz_fxc, level.zm_dmz_fxs);
        }
        level.zm_dmz_fxtotal = level.zm_dmz_fxtotal + level.zm_dmz_fxks.size;
    }
    return level.zm_dmz_fxtotal;
}

// The effect for a key: "table:key" or just key (main table first, then the others).
zm_dmz_fx_get(k)
{
    level.zm_dmz_fg_k = k;
    if (isdefined(level.var_d1e5f36ab9f106) && isdefined(level.var_d1e5f36ab9f106[level.zm_dmz_fg_k]))
    {
        return level.var_d1e5f36ab9f106[level.zm_dmz_fg_k];
    }
    if (isdefined(level.var_3acf9fbc9cf0f7b5) && isdefined(level.var_3acf9fbc9cf0f7b5[level.zm_dmz_fg_k]))
    {
        return level.var_3acf9fbc9cf0f7b5[level.zm_dmz_fg_k];
    }
    if (isdefined(level.var_7e2f6e5a16d8b454) && isdefined(level.var_7e2f6e5a16d8b454[level.zm_dmz_fg_k]))
    {
        return level.var_7e2f6e5a16d8b454[level.zm_dmz_fg_k];
    }
    if (isdefined(level.var_788f1aed54176507) && isdefined(level.var_788f1aed54176507[level.zm_dmz_fg_k]))
    {
        return level.var_788f1aed54176507[level.zm_dmz_fg_k];
    }
    if (isdefined(level.var_86a604cd1383c9e8) && isdefined(level.var_86a604cd1383c9e8[level.zm_dmz_fg_k]))
    {
        return level.var_86a604cd1383c9e8[level.zm_dmz_fg_k];
    }
    return undefined;
}

// Own thread so a bad effect only ends this call (dbg fx_ok / fx_missing).
zm_dmz_fx_try(k, pos)
{
    level.zm_dmz_ft_fx = zm_dmz_fx_get(k);
    if (!isdefined(level.zm_dmz_ft_fx))
    {
        nengine_store_set("devmenu_dbg", "fx_missing", k);
        return;
    }
    playfx(level.zm_dmz_ft_fx, pos);
    zm_dmz_count("fx_ok");
}

// Play every effect in a "|" list at pos (each in its own thread: an unknown name only ends that one).
zm_dmz_fx_list(names, pos)
{
    level.zm_dmz_fl = strtok(names, "|");
    for (level.zm_dmz_fli = 0; level.zm_dmz_fli < level.zm_dmz_fl.size; level.zm_dmz_fli++)
    {
        level thread zm_dmz_fx_try(level.zm_dmz_fl[level.zm_dmz_fli], pos);
    }
}

// self = entity: play every sound alias in a "|" list from it.
zm_dmz_snd_list(names)
{
    self.zm_dmz_sl = strtok(names, "|");
    for (self.zm_dmz_sli = 0; self.zm_dmz_sli < self.zm_dmz_sl.size; self.zm_dmz_sli++)
    {
        self playsound(self.zm_dmz_sl[self.zm_dmz_sli]);
    }
    zm_dmz_count("snd_played");
}

zm_dmz_delete_later(t)
{
    wait t;
    if (isdefined(self))
    {
        self delete();
    }
}

zm_dmz_str(key, def)
{
    level.zm_dmz_ss = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dmz_ss) || !isstring(level.zm_dmz_ss) || level.zm_dmz_ss == "")
    {
        return def;
    }
    return level.zm_dmz_ss;
}

// A deletable effect: spawnfx + triggerfx (undefined when the name is not loaded on this map).
zm_dmz_fx_spawn(name, pos)
{
    level.zm_dmz_fs_fx = zm_dmz_fx_get(name);
    if (!isdefined(level.zm_dmz_fs_fx))
    {
        nengine_store_set("devmenu_dbg", "fx_missing", name);
        return undefined;
    }
    level.zm_dmz_fs_e = spawnfx(level.zm_dmz_fs_fx, pos);
    triggerfx(level.zm_dmz_fs_e);
    zm_dmz_count("fx_ok");
    return level.zm_dmz_fs_e;
}

// Black hole core: bh_core_n (5) dark balls around the centre, spread r; rebuilt as it grows.
zm_dmz_bh_core(r)
{
    zm_dmz_bh_core_clear();
    level.zm_dmz_bcn = int(zm_dmz_num("bh_core_n", 5));
    level.zm_dmz_bcfx = zm_dmz_str("bh_fx_hole", "dark_flare_ball_effect");
    level.zm_dmz_bhfx[0] = zm_dmz_fx_spawn(level.zm_dmz_bcfx, level.zm_dmz_bhp);
    for (level.zm_dmz_bci = 1; level.zm_dmz_bci < level.zm_dmz_bcn; level.zm_dmz_bci++)
    {
        level.zm_dmz_bcp = level.zm_dmz_bhp + anglestoforward(((level.zm_dmz_bci % 2) * 50 - 25, level.zm_dmz_bci * 360 / (level.zm_dmz_bcn - 1) + level.zm_dmz_bht * 90, 0)) * r;
        level.zm_dmz_bhfx[level.zm_dmz_bhfx.size] = zm_dmz_fx_spawn(level.zm_dmz_bcfx, level.zm_dmz_bcp);
    }
    level.zm_dmz_bhfx[level.zm_dmz_bhfx.size] = zm_dmz_fx_spawn(zm_dmz_str("bh_fx_swirl", "shadow_vortex_warp_air_fx"), level.zm_dmz_bhp);
}

zm_dmz_bh_core_clear()
{
    if (!isdefined(level.zm_dmz_bhfx))
    {
        level.zm_dmz_bhfx = [];
        return;
    }
    for (level.zm_dmz_bcj = 0; level.zm_dmz_bcj < level.zm_dmz_bhfx.size; level.zm_dmz_bcj++)
    {
        if (isdefined(level.zm_dmz_bhfx[level.zm_dmz_bcj]))
        {
            level.zm_dmz_bhfx[level.zm_dmz_bcj] delete();
        }
    }
    level.zm_dmz_bhfx = [];
}

// self = entity: effect on its tag_origin (remembered, so zm_dmz_fx_off_all can remove it).
zm_dmz_fx_on(name)
{
    self.zm_dmz_fo_fx = zm_dmz_fx_get(name);
    if (!isdefined(self.zm_dmz_fo_fx))
    {
        return;
    }
    playfxontag(self.zm_dmz_fo_fx, self, "tag_origin");
    if (!isdefined(self.zm_dmz_fxon))
    {
        self.zm_dmz_fxon = [];
    }
    self.zm_dmz_fxon[self.zm_dmz_fxon.size] = self.zm_dmz_fo_fx;
    zm_dmz_count("fx_ok");
}

zm_dmz_fx_off_all()
{
    if (!isdefined(self.zm_dmz_fxon))
    {
        return;
    }
    for (self.zm_dmz_foi = 0; self.zm_dmz_foi < self.zm_dmz_fxon.size; self.zm_dmz_foi++)
    {
        killfxontag(self.zm_dmz_fxon[self.zm_dmz_foi], self, "tag_origin");
    }
    self.zm_dmz_fxon = [];
}

// Dark embers: a short burst (setting bh_fx_ember) at a few of the spinning bodies, removed after 1.5 s.
zm_dmz_bh_embers()
{
    level.zm_dmz_ben = zm_dmz_str("bh_fx_ember", "dark_flare_impact_effect");
    for (level.zm_dmz_bej = 0; level.zm_dmz_bej < level.zm_dmz_bh.size; level.zm_dmz_bej++)
    {
        if (isdefined(level.zm_dmz_bh[level.zm_dmz_bej]) && randomint(100) < 40)
        {
            level.zm_dmz_bee = zm_dmz_fx_spawn(level.zm_dmz_ben, level.zm_dmz_bh[level.zm_dmz_bej].origin + (0, 0, 40));
            if (isdefined(level.zm_dmz_bee))
            {
                level.zm_dmz_bee thread zm_dmz_delete_later(1.5);
            }
        }
    }
}

// Every effect name loaded on this map (the game's effect tables), sorted, no duplicates.
// Fills level.zm_dmz_fx_names; returns the count.
zm_dmz_fx_names()
{
    if (isdefined(level.zm_dmz_fx_names) && level.zm_dmz_fx_names.size > 0)
    {
        return level.zm_dmz_fx_names.size;
    }
    level.zm_dmz_fxn_seen = [];
    level.zm_dmz_fx_names = [];
    level.zm_dmz_fxn_tabs = [];
    level.zm_dmz_fxn_tabs[0] = level.var_d1e5f36ab9f106;
    level.zm_dmz_fxn_tabs[1] = level.var_3acf9fbc9cf0f7b5;
    level.zm_dmz_fxn_tabs[2] = level.var_7e2f6e5a16d8b454;
    level.zm_dmz_fxn_tabs[3] = level.var_788f1aed54176507;
    level.zm_dmz_fxn_tabs[4] = level.var_86a604cd1383c9e8;
    for (level.zm_dmz_fxn_t = 0; level.zm_dmz_fxn_t < 5; level.zm_dmz_fxn_t++)
    {
        if (!isdefined(level.zm_dmz_fxn_tabs[level.zm_dmz_fxn_t]))
        {
            continue;
        }
        level.zm_dmz_fxn_k = getarraykeys(level.zm_dmz_fxn_tabs[level.zm_dmz_fxn_t]);
        for (level.zm_dmz_fxn_i = 0; level.zm_dmz_fxn_i < level.zm_dmz_fxn_k.size; level.zm_dmz_fxn_i++)
        {
            level.zm_dmz_fxn_n = level.zm_dmz_fxn_k[level.zm_dmz_fxn_i];
            if (isstring(level.zm_dmz_fxn_n) && !isdefined(level.zm_dmz_fxn_seen[level.zm_dmz_fxn_n]))
            {
                level.zm_dmz_fxn_seen[level.zm_dmz_fxn_n] = 1;
                level.zm_dmz_fx_names[level.zm_dmz_fx_names.size] = level.zm_dmz_fxn_n;
            }
        }
    }
    return level.zm_dmz_fx_names.size;
}

// ================================================================ batch 2 (effects + sounds are the game's own;
// every effect name / sound alias can be changed live with the settings named next to them)

// One-shot effect at pos that removes itself after t seconds.
zm_dmz_fx_at(name, pos, t)
{
    level.zm_dmz_fa_e = zm_dmz_fx_spawn(name, pos);
    if (isdefined(level.zm_dmz_fa_e))
    {
        level.zm_dmz_fa_e thread zm_dmz_delete_later(t);
    }
}

// One-shot sound at pos from a temporary entity.
zm_dmz_snd_at(names, pos)
{
    level.zm_dmz_sa_e = spawn("script_origin", pos);
    level.zm_dmz_sa_e zm_dmz_snd_list(names);
    level.zm_dmz_sa_e thread zm_dmz_delete_later(4);
}

// ---------------------------------------------------------------- chaos: zombie fireworks
// Hunting zombies near you shoot up into the sky and burst like fireworks.
zm_dmz_fireworks()
{
    level.zm_dmz_fwl = zm_dmz_list();
    level.zm_dmz_fwn = 0;
    for (level.zm_dmz_fwi = 0; level.zm_dmz_fwi < level.zm_dmz_fwl.size && level.zm_dmz_fwn < 12; level.zm_dmz_fwi++)
    {
        level.zm_dmz_fwa = level.zm_dmz_fwl[level.zm_dmz_fwi];
        if (zm_dmz_ok(level.zm_dmz_fwa) && distance(level.zm_dmz_fwa.origin, self.origin) < 1200)
        {
            level.zm_dmz_fwa thread zm_dmz_firework_one(level.zm_dmz_fwn * 0.25);
            level.zm_dmz_fwn++;
        }
    }
    return level.zm_dmz_fwn;
}

// self = AI: wait, rocket up with a sparkle trail, burst.
zm_dmz_firework_one(delay)
{
    self.zm_dmz_busy = 1;
    wait delay;
    if (!isdefined(self) || !isalive(self))
    {
        return;
    }
    self.zm_dmz_fwm = spawn("script_origin", self.origin);
    self linkto(self.zm_dmz_fwm);
    self zm_dmz_fx_on(zm_dmz_str("fw_fx_trail", "fx_trail"));
    zm_dmz_snd_at(zm_dmz_str("fw_snd_launch", "prj_ammomod_fireworks_fire_large|amb_vfx_fireworks_launch"), self.origin);
    self.zm_dmz_fwtop = self.origin + (randomfloatrange(-150, 150), randomfloatrange(-150, 150), randomfloatrange(700, 1000));
    self.zm_dmz_fwm moveto(self.zm_dmz_fwtop, 0.9, 0.2, 0.3);
    wait 0.9;
    zm_dmz_fx_at(zm_dmz_str("fw_fx_burst", "firework_vfx"), self.zm_dmz_fwtop, 4);
    zm_dmz_fx_at(zm_dmz_str("fw_fx_burst2", "energy_mine_explosion3"), self.zm_dmz_fwtop, 3);
    zm_dmz_snd_at(zm_dmz_str("fw_snd_burst", "prj_ammomod_fireworks_explo|amb_vfx_fireworks_explo"), self.zm_dmz_fwtop);
    if (isdefined(self))
    {
        self zm_dmz_fx_off_all();
        self unlink();
        self zm_dmz_ragdoll_kill();
    }
    if (isdefined(self.zm_dmz_fwm))
    {
        self.zm_dmz_fwm delete();
    }
    zm_dmz_count("fun_fireworks");
}

// ---------------------------------------------------------------- chaos: zombie magnet
// Every hunting zombie within 2500 units is yanked to a ring around you (lightning on arrival).
zm_dmz_magnet()
{
    level.zm_dmz_mgl = zm_dmz_list();
    level.zm_dmz_mgn = 0;
    for (level.zm_dmz_mgi = 0; level.zm_dmz_mgi < level.zm_dmz_mgl.size; level.zm_dmz_mgi++)
    {
        level.zm_dmz_mga = level.zm_dmz_mgl[level.zm_dmz_mgi];
        if (zm_dmz_ok(level.zm_dmz_mga) && isdefined(level.zm_dmz_mga.enemy) && distance(level.zm_dmz_mga.origin, self.origin) < 2500)
        {
            level.zm_dmz_mgto = self.origin + anglestoforward((0, level.zm_dmz_mgn * 37, 0)) * (220 + (level.zm_dmz_mgn % 3) * 60);
            level.zm_dmz_mgnav = getclosestpointonnavmesh(level.zm_dmz_mgto);
            if (isdefined(level.zm_dmz_mgnav))
            {
                level.zm_dmz_mgto = level.zm_dmz_mgnav;
            }
            level.zm_dmz_mga thread zm_dmz_yank(level.zm_dmz_mgto);
            level.zm_dmz_mgn++;
        }
    }
    if (level.zm_dmz_mgn > 0)
    {
        zm_dmz_snd_at(zm_dmz_str("mg_snd", "evt_ai_orion_charge_lightning_shoot"), self.origin);
    }
    return level.zm_dmz_mgn;
}

// self = AI: slide to pos over 0.5 s, then a lightning zap where it lands.
zm_dmz_yank(pos)
{
    self.zm_dmz_busy = 1;
    self.zm_dmz_yk = pos;
    self.zm_dmz_ykm = spawn("script_origin", self.origin);
    self linkto(self.zm_dmz_ykm);
    self.zm_dmz_ykm moveto(self.zm_dmz_yk, 0.5, 0.1, 0.2);
    wait 0.5;
    zm_dmz_fx_at(zm_dmz_str("mg_fx", "vfx_lightning_zaps_impact"), self.zm_dmz_yk + (0, 0, 20), 2);
    if (isdefined(self))
    {
        self unlink();
        self.zm_dmz_busy = 0;
    }
    if (isdefined(self.zm_dmz_ykm))
    {
        self.zm_dmz_ykm delete();
    }
    zm_dmz_count("fun_magnet");
}

// ---------------------------------------------------------------- chaos: power-up party
// One of every power-up this map has (no nuke unless rain_nukes 1), in a circle around you.
zm_dmz_powerup_party()
{
    if (!utility::issharedfuncdefined(#"powerups", #"dropPowerup") || !utility::issharedfuncdefined(#"powerups", #"hash_a25fdc7ee24539fb"))
    {
        return 0;
    }
    level.zm_dmz_pp_root = utility::callsharedfunc(#"powerups", #"hash_a25fdc7ee24539fb");
    if (!isdefined(level.zm_dmz_pp_root) || !isdefined(level.zm_dmz_pp_root.powerups))
    {
        return 0;
    }
    level.zm_dmz_pp_k = getarraykeys(level.zm_dmz_pp_root.powerups);
    level.zm_dmz_pp_n = 0;
    for (level.zm_dmz_pp_i = 0; level.zm_dmz_pp_i < level.zm_dmz_pp_k.size; level.zm_dmz_pp_i++)
    {
        level.zm_dmz_pp_name = level.zm_dmz_pp_k[level.zm_dmz_pp_i];
        if (level.zm_dmz_pp_name == "nuke" && zm_dmz_num("rain_nukes", 0) != 1)
        {
            continue;
        }
        level.zm_dmz_pp_pos = self.origin + anglestoforward((0, level.zm_dmz_pp_n * 45, 0)) * 160;
        level.zm_dmz_pp_nav = getclosestpointonnavmesh(level.zm_dmz_pp_pos);
        if (isdefined(level.zm_dmz_pp_nav))
        {
            level.zm_dmz_pp_pos = level.zm_dmz_pp_nav;
        }
        level.zm_dmz_pp_drop_name = level.zm_dmz_pp_name;
        level.zm_dmz_pp_drop_pos = level.zm_dmz_pp_pos + (0, 0, 40);
        zm_dmz_pp_drop();
        level.zm_dmz_pp_n++;
    }
    zm_dmz_count("fun_powerparty");
    return level.zm_dmz_pp_n;
}

zm_dmz_pp_drop()
{
    utility::callsharedfunc(#"powerups", #"dropPowerup", level.zm_dmz_pp_drop_name, level.zm_dmz_pp_drop_pos, undefined, undefined, undefined, 0);
}

// ---------------------------------------------------------------- secret: shadow step
// Knife with the menu closed: you blink up to 450 units where you look, a shadow burst where you
// leave and where you arrive.
zm_dmz_shadow_step()
{
    self.zm_dmz_ss_eye = self geteye();
    self.zm_dmz_ss_pa = self getplayerangles();
    self.zm_dmz_ss_f = anglestoforward((0, self.zm_dmz_ss_pa[1], 0));
    self.zm_dmz_ss_hit = physicstrace(self.zm_dmz_ss_eye, self.zm_dmz_ss_eye + self.zm_dmz_ss_f * zm_dmz_num("step_range", 450));
    if (!isdefined(self.zm_dmz_ss_hit))
    {
        self.zm_dmz_ss_hit = self.zm_dmz_ss_eye + self.zm_dmz_ss_f * zm_dmz_num("step_range", 450);
    }
    self.zm_dmz_ss_to = getclosestpointonnavmesh(self.zm_dmz_ss_hit - self.zm_dmz_ss_f * 40);
    if (!isdefined(self.zm_dmz_ss_to) || distance(self.zm_dmz_ss_to, self.origin) < 60)
    {
        return;
    }
    zm_dmz_fx_at(zm_dmz_str("step_fx_out", "shadow_vortex_warp_ground_fx"), self.origin, 2);
    zm_dmz_snd_at(zm_dmz_str("step_snd_out", "evt_zm_sat_pap_teleport_out"), self.origin);
    self setorigin(self.zm_dmz_ss_to);
    zm_dmz_fx_at(zm_dmz_str("step_fx_in", "shadow_vortex_special_impact_fx"), self.zm_dmz_ss_to, 2);
    zm_dmz_snd_at(zm_dmz_str("step_snd_in", "evt_zm_sat_pap_teleport_in"), self.zm_dmz_ss_to);
    zm_dmz_count("fun_shadowstep");
}

// ---------------------------------------------------------------- secret: lightning storm
// While on: every storm_gap (0.8) s lightning hits a hunting zombie near you, then jumps to up to
// 3 more close by. Each hit is a kill.
zm_dmz_storm_loop()
{
    self endon("disconnect");
    while (zm_dmz_flag(level.zm_dmz_storm))
    {
        self zm_dmz_storm_strike();
        wait zm_dmz_num("storm_gap", 0.8);
    }
}

zm_dmz_storm_strike()
{
    level.zm_dmz_stl = zm_dmz_list();
    level.zm_dmz_st_t = undefined;
    level.zm_dmz_st_tries = 0;
    while (level.zm_dmz_st_tries < 12 && level.zm_dmz_stl.size > 0)
    {
        level.zm_dmz_st_c = level.zm_dmz_stl[randomint(level.zm_dmz_stl.size)];
        if (zm_dmz_ok(level.zm_dmz_st_c) && distance(level.zm_dmz_st_c.origin, self.origin) < 1300)
        {
            level.zm_dmz_st_t = level.zm_dmz_st_c;
            break;
        }
        level.zm_dmz_st_tries++;
    }
    if (!isdefined(level.zm_dmz_st_t))
    {
        return;
    }
    level.zm_dmz_st_p = level.zm_dmz_st_t.origin;
    zm_dmz_fx_at(zm_dmz_str("storm_fx", "lightning_strike"), level.zm_dmz_st_p, 3);
    zm_dmz_fx_at(zm_dmz_str("storm_fx_hit", "vfx_lightning_zaps_impact"), level.zm_dmz_st_p + (0, 0, 30), 2);
    zm_dmz_snd_at(zm_dmz_str("storm_snd", "evt_lightning_strike|evt_lightning_strike_impact"), level.zm_dmz_st_p);
    level.zm_dmz_st_t zm_dmz_ragdoll_kill();
    // chain to up to 3 more close by
    level.zm_dmz_st_chain = 0;
    for (level.zm_dmz_st_i = 0; level.zm_dmz_st_i < level.zm_dmz_stl.size && level.zm_dmz_st_chain < 3; level.zm_dmz_st_i++)
    {
        level.zm_dmz_st_o = level.zm_dmz_stl[level.zm_dmz_st_i];
        if (zm_dmz_ok(level.zm_dmz_st_o) && distance(level.zm_dmz_st_o.origin, level.zm_dmz_st_p) < 300)
        {
            zm_dmz_fx_at(zm_dmz_str("storm_fx_chain", "chain_lightning_bolt"), level.zm_dmz_st_o.origin + (0, 0, 40), 2);
            level.zm_dmz_st_o zm_dmz_ragdoll_kill();
            level.zm_dmz_st_chain++;
        }
    }
    zm_dmz_count("fun_storm");
}

// ---------------------------------------------------------------- secret: death aura
// While on: zombies that get within aura_r (110) of you burst apart.
zm_dmz_aura_loop()
{
    self endon("disconnect");
    while (zm_dmz_flag(self.zm_dmz_aura))
    {
        self zm_dmz_aura_step();
        wait 0.15;
    }
}

zm_dmz_aura_step()
{
    level.zm_dmz_aul = zm_dmz_list();
    for (level.zm_dmz_aui = 0; level.zm_dmz_aui < level.zm_dmz_aul.size; level.zm_dmz_aui++)
    {
        level.zm_dmz_aua = level.zm_dmz_aul[level.zm_dmz_aui];
        if (zm_dmz_ok(level.zm_dmz_aua) && distance(level.zm_dmz_aua.origin, self.origin) < zm_dmz_num("aura_r", 110))
        {
            zm_dmz_fx_at(zm_dmz_str("aura_fx", "brainrot_elite_explosion"), level.zm_dmz_aua.origin + (0, 0, 30), 2);
            zm_dmz_snd_at(zm_dmz_str("aura_snd", "exp_ai_orion_lightning_strike_impact"), level.zm_dmz_aua.origin);
            level.zm_dmz_aua thread zm_dmz_launch(randomfloatrange(150, 300), 1);
            zm_dmz_count("fun_aura");
        }
    }
}

// ---------------------------------------------------------------- secret: frost nova
// Every zombie within 700 units freezes solid for 3 s, then shatters.
zm_dmz_frost_nova()
{
    level.zm_dmz_fnl = zm_dmz_list();
    level.zm_dmz_fn = [];
    level.zm_dmz_fnm = [];
    for (level.zm_dmz_fni = 0; level.zm_dmz_fni < level.zm_dmz_fnl.size; level.zm_dmz_fni++)
    {
        level.zm_dmz_fna = level.zm_dmz_fnl[level.zm_dmz_fni];
        if (zm_dmz_ok(level.zm_dmz_fna) && distance(level.zm_dmz_fna.origin, self.origin) < zm_dmz_num("nova_r", 700))
        {
            level.zm_dmz_fna.zm_dmz_busy = 1;
            level.zm_dmz_fnm[level.zm_dmz_fn.size] = spawn("script_origin", level.zm_dmz_fna.origin);
            level.zm_dmz_fna linkto(level.zm_dmz_fnm[level.zm_dmz_fn.size]);
            level.zm_dmz_fna zm_dmz_fx_on(zm_dmz_str("nova_fx_ice", "flash_freeze_shatter_fx"));
            level.zm_dmz_fn[level.zm_dmz_fn.size] = level.zm_dmz_fna;
        }
    }
    zm_dmz_snd_at(zm_dmz_str("nova_snd", "prj_ammomod_cryofreeze_proc|evt_ee_viking_helmet_frost_blast"), self.origin);
    level.zm_dmz_fn_n = level.zm_dmz_fn.size;
    self thread zm_dmz_frost_shatter();
    zm_dmz_count("fun_nova");
    return level.zm_dmz_fn_n;
}

zm_dmz_frost_shatter()
{
    self endon("disconnect");
    wait zm_dmz_num("nova_time", 3);
    for (level.zm_dmz_fsi = 0; level.zm_dmz_fsi < level.zm_dmz_fn.size; level.zm_dmz_fsi++)
    {
        level.zm_dmz_fsa = level.zm_dmz_fn[level.zm_dmz_fsi];
        if (isdefined(level.zm_dmz_fsa))
        {
            zm_dmz_fx_at(zm_dmz_str("nova_fx_shatter", "flash_freeze_shatter_fx"), level.zm_dmz_fsa.origin + (0, 0, 40), 2);
            zm_dmz_snd_at(zm_dmz_str("nova_snd_shatter", "evt_ammomod_cryofreeze_ai_shatter|exp_ai_zombie_frost_death"), level.zm_dmz_fsa.origin);
            level.zm_dmz_fsa zm_dmz_fx_off_all();
            level.zm_dmz_fsa unlink();
            level.zm_dmz_fsa zm_dmz_ragdoll_kill();
        }
        if (isdefined(level.zm_dmz_fnm[level.zm_dmz_fsi]))
        {
            level.zm_dmz_fnm[level.zm_dmz_fsi] delete();
        }
    }
    level.zm_dmz_fn = [];
    level.zm_dmz_fnm = [];
}

// Explosive bullets: where the shot hits (game physics trace along the aim), zombies within
// boom_r (150) are blown up (ground pound blast: launch + rag doll, effect + sound).
zm_dmz_boom_shot()
{
    self.zm_dmz_be = self geteye();
    self.zm_dmz_bf = anglestoforward(self getplayerangles());
    self.zm_dmz_bhit = physicstrace(self.zm_dmz_be, self.zm_dmz_be + self.zm_dmz_bf * 6000);
    if (!isdefined(self.zm_dmz_bhit))
    {
        return;
    }
    self zm_dmz_pound(self.zm_dmz_bhit, zm_dmz_num("boom_r", 150), 1);
    zm_dmz_count("fun_boom");
}

// ================================================================ batch 3: shots, storms, model-breakers

// ---------------------------------------------------------------- shots (self = player, from the fire loop)
// Zeus shots: lightning hits where the shot lands, killing zombies within zeus_r (180).
zm_dmz_zeus_shot()
{
    self.zm_dmz_ze = self geteye();
    self.zm_dmz_zf = anglestoforward(self getplayerangles());
    self.zm_dmz_zh = physicstrace(self.zm_dmz_ze, self.zm_dmz_ze + self.zm_dmz_zf * 6000);
    if (!isdefined(self.zm_dmz_zh))
    {
        return;
    }
    zm_dmz_fx_at(zm_dmz_str("zeus_fx", "lightning_strike"), self.zm_dmz_zh, 3);
    zm_dmz_fx_at(zm_dmz_str("zeus_fx_hit", "vfx_lightning_zaps_impact"), self.zm_dmz_zh + (0, 0, 20), 2);
    zm_dmz_snd_at(zm_dmz_str("zeus_snd", "evt_lightning_strike|evt_lightning_strike_impact"), self.zm_dmz_zh);
    level.zm_dmz_zl = zm_dmz_list();
    for (level.zm_dmz_zi = 0; level.zm_dmz_zi < level.zm_dmz_zl.size; level.zm_dmz_zi++)
    {
        level.zm_dmz_za = level.zm_dmz_zl[level.zm_dmz_zi];
        if (zm_dmz_ok(level.zm_dmz_za) && distance(level.zm_dmz_za.origin, self.zm_dmz_zh) < zm_dmz_num("zeus_r", 180))
        {
            zm_dmz_fx_at(zm_dmz_str("zeus_fx_chain", "chain_lightning_bolt"), level.zm_dmz_za.origin + (0, 0, 40), 2);
            level.zm_dmz_za zm_dmz_ragdoll_kill();
        }
    }
    zm_dmz_count("fun_zeus");
}

// Freeze-ray shots: zombies within freeze_r (160) of the hit freeze for 2.5 s, then shatter.
zm_dmz_freeze_shot()
{
    self.zm_dmz_fe = self geteye();
    self.zm_dmz_ff = anglestoforward(self getplayerangles());
    self.zm_dmz_fh = physicstrace(self.zm_dmz_fe, self.zm_dmz_fe + self.zm_dmz_ff * 6000);
    if (!isdefined(self.zm_dmz_fh))
    {
        return;
    }
    zm_dmz_snd_at(zm_dmz_str("nova_snd", "prj_ammomod_cryofreeze_proc|evt_ee_viking_helmet_frost_blast"), self.zm_dmz_fh);
    level.zm_dmz_rl2 = zm_dmz_list();
    for (level.zm_dmz_ri2 = 0; level.zm_dmz_ri2 < level.zm_dmz_rl2.size; level.zm_dmz_ri2++)
    {
        level.zm_dmz_ra2 = level.zm_dmz_rl2[level.zm_dmz_ri2];
        if (zm_dmz_ok(level.zm_dmz_ra2) && distance(level.zm_dmz_ra2.origin, self.zm_dmz_fh) < zm_dmz_num("freeze_r", 160))
        {
            level.zm_dmz_ra2 thread zm_dmz_freeze_one();
        }
    }
    zm_dmz_count("fun_freezeray");
}

// self = AI: frozen in place (ice effect), then shatters
zm_dmz_freeze_one()
{
    self.zm_dmz_busy = 1;
    self.zm_dmz_fm = spawn("script_origin", self.origin);
    self linkto(self.zm_dmz_fm);
    self zm_dmz_fx_on(zm_dmz_str("nova_fx_ice", "flash_freeze_shatter_fx"));
    wait 2.5;
    if (isdefined(self))
    {
        zm_dmz_fx_at(zm_dmz_str("nova_fx_shatter", "flash_freeze_shatter_fx"), self.origin + (0, 0, 40), 2);
        zm_dmz_snd_at(zm_dmz_str("nova_snd_shatter", "evt_ammomod_cryofreeze_ai_shatter|exp_ai_zombie_frost_death"), self.origin);
        self zm_dmz_fx_off_all();
        self unlink();
        self zm_dmz_ragdoll_kill();
    }
    if (isdefined(self.zm_dmz_fm))
    {
        self.zm_dmz_fm delete();
    }
}

// ---------------------------------------------------------------- meteor shower
// Fireballs crash down around you every meteor_gap (0.6) s; each kills zombies within 160.
zm_dmz_meteor_loop()
{
    self endon("disconnect");
    while (zm_dmz_flag(level.zm_dmz_meteor))
    {
        self zm_dmz_meteor_one();
        wait zm_dmz_num("meteor_gap", 0.6);
    }
}

zm_dmz_meteor_one()
{
    level.zm_dmz_mp = self.origin + anglestoforward((0, randomfloatrange(0, 360), 0)) * randomfloatrange(200, 900);
    level.zm_dmz_mnav = getclosestpointonnavmesh(level.zm_dmz_mp);
    if (isdefined(level.zm_dmz_mnav))
    {
        level.zm_dmz_mp = level.zm_dmz_mnav;
    }
    level thread zm_dmz_meteor_fall(level.zm_dmz_mp);
}

zm_dmz_meteor_fall(pos)
{
    level.zm_dmz_mf_p = pos;
    level.zm_dmz_mf_e = spawn("script_model", level.zm_dmz_mf_p + (randomfloatrange(-300, 300), randomfloatrange(-300, 300), 1500));
    level.zm_dmz_mf_e setmodel("tag_origin");
    level.zm_dmz_mf_e zm_dmz_fx_on(zm_dmz_str("meteor_fx_trail", "vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_trail"));
    level.zm_dmz_mf_e moveto(level.zm_dmz_mf_p, 0.7, 0.5, 0);
    level.zm_dmz_mf_e thread zm_dmz_meteor_hit(level.zm_dmz_mf_p);
}

// self = the falling fireball
zm_dmz_meteor_hit(pos)
{
    self.zm_dmz_mh = pos;
    wait 0.7;
    zm_dmz_fx_at(zm_dmz_str("meteor_fx_hit", "vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_explo"), self.zm_dmz_mh, 3);
    zm_dmz_snd_at(zm_dmz_str("meteor_snd", "prj_ammomod_shatterblast_proc_explode"), self.zm_dmz_mh);
    earthquake(0.2, 0.4, self.zm_dmz_mh, 700);
    level.zm_dmz_mhl = zm_dmz_list();
    for (level.zm_dmz_mhi = 0; level.zm_dmz_mhi < level.zm_dmz_mhl.size; level.zm_dmz_mhi++)
    {
        if (zm_dmz_ok(level.zm_dmz_mhl[level.zm_dmz_mhi]) && distance(level.zm_dmz_mhl[level.zm_dmz_mhi].origin, self.zm_dmz_mh) < 160)
        {
            level.zm_dmz_mhl[level.zm_dmz_mhi] thread zm_dmz_launch(randomfloatrange(200, 400), 1);
        }
    }
    self zm_dmz_fx_off_all();
    self delete();
    zm_dmz_count("fun_meteor");
}

// ---------------------------------------------------------------- Thanos snap: half of the hunting zombies turn to dust
zm_dmz_snap()
{
    level.zm_dmz_sl2 = zm_dmz_list();
    level.zm_dmz_sn = 0;
    level.zm_dmz_sflip = 0;
    for (level.zm_dmz_si2 = 0; level.zm_dmz_si2 < level.zm_dmz_sl2.size; level.zm_dmz_si2++)
    {
        level.zm_dmz_sa = level.zm_dmz_sl2[level.zm_dmz_si2];
        if (zm_dmz_ok(level.zm_dmz_sa) && isdefined(level.zm_dmz_sa.enemy))
        {
            level.zm_dmz_sflip = 1 - level.zm_dmz_sflip;
            if (level.zm_dmz_sflip)
            {
                level.zm_dmz_sa thread zm_dmz_dust(randomfloatrange(0, 2));
                level.zm_dmz_sn++;
            }
        }
    }
    zm_dmz_count("fun_snap");
    return level.zm_dmz_sn;
}

// self = AI: after a moment, aether dust + gone
zm_dmz_dust(delay)
{
    self.zm_dmz_busy = 1;
    wait delay;
    if (!isdefined(self) || !isalive(self))
    {
        return;
    }
    zm_dmz_fx_at(zm_dmz_str("snap_fx", "aether_shroud_teleport"), self.origin + (0, 0, 30), 2);
    zm_dmz_snd_at(zm_dmz_str("snap_snd", "evt_zm_sat_pap_teleport_out"), self.origin);
    self.no_powerups = 1;
    self hide();
    self kill();
}

// ---------------------------------------------------------------- burning zombies (fire on every hunting zombie)
zm_dmz_burn_loop()
{
    while (zm_dmz_flag(level.zm_dmz_burn))
    {
        zm_dmz_burn_step();
        wait 0.5;
    }
    level.zm_dmz_bnl = zm_dmz_list();
    for (level.zm_dmz_bni = 0; level.zm_dmz_bni < level.zm_dmz_bnl.size; level.zm_dmz_bni++)
    {
        if (isdefined(level.zm_dmz_bnl[level.zm_dmz_bni]) && zm_dmz_flag(level.zm_dmz_bnl[level.zm_dmz_bni].zm_dmz_burning))
        {
            level.zm_dmz_bnl[level.zm_dmz_bni].zm_dmz_burning = 0;
            level.zm_dmz_bnl[level.zm_dmz_bni] zm_dmz_fx_off_all();
        }
    }
}

zm_dmz_burn_step()
{
    level.zm_dmz_bnl = zm_dmz_list();
    for (level.zm_dmz_bni = 0; level.zm_dmz_bni < level.zm_dmz_bnl.size; level.zm_dmz_bni++)
    {
        level.zm_dmz_bna = level.zm_dmz_bnl[level.zm_dmz_bni];
        if (isdefined(level.zm_dmz_bna) && isalive(level.zm_dmz_bna) && isdefined(level.zm_dmz_bna.enemy) && !zm_dmz_flag(level.zm_dmz_bna.zm_dmz_burning))
        {
            level.zm_dmz_bna.zm_dmz_burning = 1;
            level.zm_dmz_bna zm_dmz_fx_on(zm_dmz_str("burn_fx", "vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_trail"));
        }
    }
}

// ---------------------------------------------------------------- invisible zombies
zm_dmz_invis_loop()
{
    while (zm_dmz_flag(level.zm_dmz_invis))
    {
        zm_dmz_invis_step(1);
        wait 0.5;
    }
    zm_dmz_invis_step(0);
}

zm_dmz_invis_step(on)
{
    level.zm_dmz_ivl = zm_dmz_list();
    for (level.zm_dmz_ivi = 0; level.zm_dmz_ivi < level.zm_dmz_ivl.size; level.zm_dmz_ivi++)
    {
        level.zm_dmz_iva = level.zm_dmz_ivl[level.zm_dmz_ivi];
        if (!isdefined(level.zm_dmz_iva))
        {
            continue;
        }
        if (on && !zm_dmz_flag(level.zm_dmz_iva.zm_dmz_hidden))
        {
            level.zm_dmz_iva.zm_dmz_hidden = 1;
            level.zm_dmz_iva hide();
        }
        else if (!on && zm_dmz_flag(level.zm_dmz_iva.zm_dmz_hidden))
        {
            level.zm_dmz_iva.zm_dmz_hidden = 0;
            level.zm_dmz_iva show();
        }
    }
}

// ---------------------------------------------------------------- model-breakers: spin / flip (movers)
// mode "spin": hunting zombies near you spin like tops; "flip": turned upside down, floating
zm_dmz_twist_on(mode)
{
    zm_dmz_twist_off();
    level.zm_dmz_tw = [];
    level.zm_dmz_twm = [];
    level.zm_dmz_twmode = mode;
    level.zm_dmz_twl = zm_dmz_list();
    for (level.zm_dmz_twi = 0; level.zm_dmz_twi < level.zm_dmz_twl.size && level.zm_dmz_tw.size < 24; level.zm_dmz_twi++)
    {
        level.zm_dmz_twa = level.zm_dmz_twl[level.zm_dmz_twi];
        if (zm_dmz_ok(level.zm_dmz_twa) && isdefined(level.zm_dmz_twa.enemy) && distance(level.zm_dmz_twa.origin, self.origin) < 2000)
        {
            level.zm_dmz_twa.zm_dmz_busy = 1;
            level.zm_dmz_twm[level.zm_dmz_tw.size] = spawn("script_model", level.zm_dmz_twa.origin);
            level.zm_dmz_twm[level.zm_dmz_tw.size] setmodel("tag_origin");
            level.zm_dmz_twa linkto(level.zm_dmz_twm[level.zm_dmz_tw.size]);
            if (mode == "flip")
            {
                level.zm_dmz_twm[level.zm_dmz_tw.size] moveto(level.zm_dmz_twa.origin + (0, 0, 90), 0.6);
                level.zm_dmz_twm[level.zm_dmz_tw.size] rotateto((0, randomfloatrange(0, 360), 180), 0.6);
            }
            level.zm_dmz_tw[level.zm_dmz_tw.size] = level.zm_dmz_twa;
        }
    }
    if (mode == "spin")
    {
        level thread zm_dmz_spin_loop();
    }
    return level.zm_dmz_tw.size;
}

zm_dmz_spin_loop()
{
    while (isdefined(level.zm_dmz_twmode) && level.zm_dmz_twmode == "spin")
    {
        for (level.zm_dmz_spj = 0; level.zm_dmz_spj < level.zm_dmz_twm.size; level.zm_dmz_spj++)
        {
            if (isdefined(level.zm_dmz_twm[level.zm_dmz_spj]))
            {
                level.zm_dmz_twm[level.zm_dmz_spj] rotateyaw(720, 1);
            }
        }
        wait 1;
    }
}

zm_dmz_twist_off()
{
    level.zm_dmz_twmode = undefined;
    if (!isdefined(level.zm_dmz_tw))
    {
        return;
    }
    for (level.zm_dmz_twi = 0; level.zm_dmz_twi < level.zm_dmz_tw.size; level.zm_dmz_twi++)
    {
        if (isdefined(level.zm_dmz_tw[level.zm_dmz_twi]))
        {
            level.zm_dmz_tw[level.zm_dmz_twi] unlink();
            level.zm_dmz_tw[level.zm_dmz_twi].zm_dmz_busy = 0;
        }
        if (isdefined(level.zm_dmz_twm[level.zm_dmz_twi]))
        {
            level.zm_dmz_twm[level.zm_dmz_twi] delete();
        }
    }
    level.zm_dmz_tw = [];
    level.zm_dmz_twm = [];
}

// ---------------------------------------------------------------- zombie tornado
// Hunting zombies within 1500 get sucked into a rising, spinning column 400 units in front of you
// for tornado_time (6) s, then thrown out.
zm_dmz_tornado()
{
    self.zm_dmz_tpa = self getplayerangles();
    level.zm_dmz_tc = self.origin + anglestoforward((0, self.zm_dmz_tpa[1], 0)) * 400;
    level.zm_dmz_to = [];
    level.zm_dmz_tom = [];
    level.zm_dmz_tl = zm_dmz_list();
    for (level.zm_dmz_ti = 0; level.zm_dmz_ti < level.zm_dmz_tl.size && level.zm_dmz_to.size < 30; level.zm_dmz_ti++)
    {
        level.zm_dmz_ta = level.zm_dmz_tl[level.zm_dmz_ti];
        if (zm_dmz_ok(level.zm_dmz_ta) && distance(level.zm_dmz_ta.origin, level.zm_dmz_tc) < 1500)
        {
            level.zm_dmz_ta.zm_dmz_busy = 1;
            level.zm_dmz_tom[level.zm_dmz_to.size] = spawn("script_origin", level.zm_dmz_ta.origin);
            level.zm_dmz_ta linkto(level.zm_dmz_tom[level.zm_dmz_to.size]);
            level.zm_dmz_to[level.zm_dmz_to.size] = level.zm_dmz_ta;
        }
    }
    zm_dmz_snd_at(zm_dmz_str("tornado_snd", "prj_ammomod_shadowvortex_proc_oneshot"), level.zm_dmz_tc);
    level thread zm_dmz_tornado_run();
    zm_dmz_count("fun_tornado");
    return level.zm_dmz_to.size;
}

zm_dmz_tornado_run()
{
    level.zm_dmz_tt = 0;
    level.zm_dmz_tdur = zm_dmz_num("tornado_time", 6);
    while (level.zm_dmz_tt < level.zm_dmz_tdur)
    {
        for (level.zm_dmz_tj = 0; level.zm_dmz_tj < level.zm_dmz_to.size; level.zm_dmz_tj++)
        {
            if (!isdefined(level.zm_dmz_tom[level.zm_dmz_tj]))
            {
                continue;
            }
            level.zm_dmz_th = 40 + ((level.zm_dmz_tj * 53) % 500) + level.zm_dmz_tt * 20;
            level.zm_dmz_tr = 80 + level.zm_dmz_th * 0.35;
            level.zm_dmz_tya = level.zm_dmz_tt * 300 + level.zm_dmz_tj * 47;
            level.zm_dmz_tom[level.zm_dmz_tj].origin = level.zm_dmz_tc + anglestoforward((0, level.zm_dmz_tya, 0)) * level.zm_dmz_tr + (0, 0, level.zm_dmz_th);
        }
        waitframe();
        level.zm_dmz_tt = level.zm_dmz_tt + 0.05;
    }
    for (level.zm_dmz_tj = 0; level.zm_dmz_tj < level.zm_dmz_to.size; level.zm_dmz_tj++)
    {
        if (isdefined(level.zm_dmz_to[level.zm_dmz_tj]))
        {
            level.zm_dmz_to[level.zm_dmz_tj] unlink();
            level.zm_dmz_to[level.zm_dmz_tj] zm_dmz_ragdoll_kill();
        }
        if (isdefined(level.zm_dmz_tom[level.zm_dmz_tj]))
        {
            level.zm_dmz_tom[level.zm_dmz_tj] delete();
        }
    }
}

// ---------------------------------------------------------------- conga line: up to 10 zombies follow your path
zm_dmz_conga_on()
{
    zm_dmz_conga_off();
    level.zm_dmz_cg = [];
    level.zm_dmz_cgm = [];
    level.zm_dmz_cgh = [];
    level.zm_dmz_cgl = zm_dmz_list();
    for (level.zm_dmz_cgi = 0; level.zm_dmz_cgi < level.zm_dmz_cgl.size && level.zm_dmz_cg.size < 10; level.zm_dmz_cgi++)
    {
        level.zm_dmz_cga = level.zm_dmz_cgl[level.zm_dmz_cgi];
        if (zm_dmz_ok(level.zm_dmz_cga) && isdefined(level.zm_dmz_cga.enemy) && distance(level.zm_dmz_cga.origin, self.origin) < 2500)
        {
            level.zm_dmz_cga.zm_dmz_busy = 1;
            level.zm_dmz_cgm[level.zm_dmz_cg.size] = spawn("script_origin", level.zm_dmz_cga.origin);
            level.zm_dmz_cga linkto(level.zm_dmz_cgm[level.zm_dmz_cg.size]);
            level.zm_dmz_cg[level.zm_dmz_cg.size] = level.zm_dmz_cga;
        }
    }
    level.zm_dmz_conga = 1;
    self thread zm_dmz_conga_loop();
    return level.zm_dmz_cg.size;
}

zm_dmz_conga_loop()
{
    self endon("disconnect");
    while (zm_dmz_flag(level.zm_dmz_conga))
    {
        self zm_dmz_conga_step();
        wait 0.1;
    }
}

zm_dmz_conga_step()
{
    // trail of your last positions (newest first), one zombie every 6 steps behind you
    level.zm_dmz_cgh2 = [];
    level.zm_dmz_cgh2[0] = self.origin;
    for (level.zm_dmz_cgk = 0; level.zm_dmz_cgk < level.zm_dmz_cgh.size && level.zm_dmz_cgk < 80; level.zm_dmz_cgk++)
    {
        level.zm_dmz_cgh2[level.zm_dmz_cgh2.size] = level.zm_dmz_cgh[level.zm_dmz_cgk];
    }
    level.zm_dmz_cgh = level.zm_dmz_cgh2;
    for (level.zm_dmz_cgk = 0; level.zm_dmz_cgk < level.zm_dmz_cgm.size; level.zm_dmz_cgk++)
    {
        level.zm_dmz_cgx = (level.zm_dmz_cgk + 1) * 6;
        if (level.zm_dmz_cgx >= level.zm_dmz_cgh.size)
        {
            level.zm_dmz_cgx = level.zm_dmz_cgh.size - 1;
        }
        if (isdefined(level.zm_dmz_cgm[level.zm_dmz_cgk]))
        {
            level.zm_dmz_cgm[level.zm_dmz_cgk] moveto(level.zm_dmz_cgh[level.zm_dmz_cgx], 0.1);
        }
    }
}

zm_dmz_conga_off()
{
    level.zm_dmz_conga = 0;
    if (!isdefined(level.zm_dmz_cg))
    {
        return;
    }
    for (level.zm_dmz_cgi = 0; level.zm_dmz_cgi < level.zm_dmz_cg.size; level.zm_dmz_cgi++)
    {
        if (isdefined(level.zm_dmz_cg[level.zm_dmz_cgi]))
        {
            level.zm_dmz_cg[level.zm_dmz_cgi] unlink();
            level.zm_dmz_cg[level.zm_dmz_cgi].zm_dmz_busy = 0;
        }
        if (isdefined(level.zm_dmz_cgm[level.zm_dmz_cgi]))
        {
            level.zm_dmz_cgm[level.zm_dmz_cgi] delete();
        }
    }
    level.zm_dmz_cg = [];
    level.zm_dmz_cgm = [];
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmz_init_is_zombies()
{
    level.zm_dmz_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmz_init_gt) || level.zm_dmz_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmz_init_gt, 0, 2) == "zm";
}

// Effect gun: every shot plays a random loaded effect where it lands
zm_dmz_fxgun_shot()
{
    self.zm_dmz_ge = self geteye();
    self.zm_dmz_gh = physicstrace(self.zm_dmz_ge, self.zm_dmz_ge + anglestoforward(self getplayerangles()) * 6000);
    if (!isdefined(self.zm_dmz_gh) || !isdefined(level.zm_dmz_fx_names) || level.zm_dmz_fx_names.size == 0)
    {
        return;
    }
    self.zm_dmz_gk = level.zm_dmz_fx_names[randomint(level.zm_dmz_fx_names.size)];
    self thread zm_dmz_fx_try(self.zm_dmz_gk, self.zm_dmz_gh + (0, 0, 10));
    zm_dmz_count("fun_fxgun");
    nengine_store_set("devmenu_dbg", "fun_fxgun_last", self.zm_dmz_gk);
}
