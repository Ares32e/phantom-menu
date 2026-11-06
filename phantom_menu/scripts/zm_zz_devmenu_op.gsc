// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_op - Phantom menu "Overpowered" options (own code; game calls as FuzMenu uses them):
// damage multipliers / one-shot kills / headshot crits (zombie damage callback), aimbot while
// aiming, zombie ESP through walls, infinite field upgrade, kill pinata (power-ups from kills),
// chain-reaction kills (killed zombies blow up the ones around them), auto nuke.
// Reached from the main menu with action "op <action> [value]" (level.zm_dmo_run).
// State on level / player / AI fields (Kronos GSC loses locals after calls and waits).

#using scripts\common\utility;
#using scripts\common\callbacks;
#using scripts\common\weapon;
#using script_25a8fa2ac8997425;
#using script_2301d27669c5a079;
#using script_6c2f6a14fa53759e;

autoexec zm_dmo_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmo_init_is_zombies())
    {
        return;
    }
    level.zm_dmo_run = &zm_dmo_run;
    level thread zm_dmo_round_watch();
    level thread zm_dmo_opts_loop();
    level.zm_dmo_dmg = 1;
    level.zm_dmo_crit = 1;
    level callback::add("on_zombie_ai_damaged", &zm_dmo_on_damaged);
    level callback::add("on_zombie_ai_killed", &zm_dmo_on_killed);
    nengine_store_set("devmenu_dbg", "op", "linked");
}

zm_dmo_run(a, v)
{
    self.zm_dmo_a = a;
    self.zm_dmo_v = v;
    if (a == "dmg")
    {
        level.zm_dmo_dmg = float(self.zm_dmo_v);
        if (level.zm_dmo_dmg <= 1)
        {
            level.zm_dmo_dmg = 1;
            return "damage: normal";
        }
        if (level.zm_dmo_dmg >= 100000)
        {
            return "one-shot kills ON";
        }
        return "damage x" + self.zm_dmo_v;
    }
    if (a == "crit")
    {
        level.zm_dmo_crit = float(self.zm_dmo_v);
        if (level.zm_dmo_crit <= 1)
        {
            level.zm_dmo_crit = 1;
            return "headshots: normal";
        }
        return "headshot damage x" + self.zm_dmo_v;
    }
    if (a == "aimbot")
    {
        self.zm_dmo_aim = 1 - zm_dmo_flag(self.zm_dmo_aim);
        if (self.zm_dmo_aim)
        {
            self zm_dmo_ads_start();
            self thread zm_dmo_aimbot_loop();
        }
        return "aimbot " + zm_dmo_onoff(self.zm_dmo_aim) + " (locks onto heads while you aim)";
    }
    if (a == "esp")
    {
        level.zm_dmo_esp = 1 - zm_dmo_flag(level.zm_dmo_esp);
        if (level.zm_dmo_esp)
        {
            level thread zm_dmo_esp_loop();
        }
        return "zombie ESP " + zm_dmo_onoff(level.zm_dmo_esp) + " (red outline through walls)";
    }
    if (a == "fieldup")
    {
        self.zm_dmo_fu = 1 - zm_dmo_flag(self.zm_dmo_fu);
        if (self.zm_dmo_fu)
        {
            self thread zm_dmo_fieldup_loop();
        }
        return "infinite field upgrade " + zm_dmo_onoff(self.zm_dmo_fu);
    }
    if (a == "pinata")
    {
        level.zm_dmo_pinata = 1 - zm_dmo_flag(level.zm_dmo_pinata);
        return "kill pinata " + zm_dmo_onoff(level.zm_dmo_pinata) + " (kills can drop power-ups)";
    }
    if (a == "chain")
    {
        level.zm_dmo_chain = 1 - zm_dmo_flag(level.zm_dmo_chain);
        return "chain reaction " + zm_dmo_onoff(level.zm_dmo_chain) + " (killed zombies blow up the ones near them)";
    }
    if (a == "autonuke")
    {
        level.zm_dmo_nuke = 1 - zm_dmo_flag(level.zm_dmo_nuke);
        if (level.zm_dmo_nuke)
        {
            level thread zm_dmo_nuke_loop();
        }
        return "auto nuke " + zm_dmo_onoff(level.zm_dmo_nuke) + " (every " + zm_dmo_num("autonuke_gap", 15) + " s)";
    }
    if (a == "mode_gungame")
    {
        level.zm_dmo_gg = 1 - zm_dmo_flag(level.zm_dmo_gg);
        if (level.zm_dmo_gg)
        {
            level.zm_dmo_mode_p = self;
            level.zm_dmo_gg_list = [[ level.zm_dm_all_guns_fn ]]();
            level.zm_dmo_gg_i = 0;
            level.zm_dmo_gg_k = 0;
            self zm_dmo_gg_give();
            return "GUN GAME: every " + zm_dmo_num("gg_kills", 3) + " kills a new gun (" + level.zm_dmo_gg_list.size + " guns)";
        }
        return "gun game OFF";
    }
    if (a == "mode_oitc")
    {
        level.zm_dmo_oitc = 1 - zm_dmo_flag(level.zm_dmo_oitc);
        if (level.zm_dmo_oitc)
        {
            level.zm_dmo_mode_p = self;
            [[ level.zm_dm_give_named_fn ]]("sat_pi_alcor");
            self thread zm_dmo_oitc_loop();
            return "ONE IN THE CHAMBER: 1 bullet, every kill gives one back";
        }
        return "one in the chamber OFF";
    }
    if (a == "mode_sharp")
    {
        level.zm_dmo_sharp = 1 - zm_dmo_flag(level.zm_dmo_sharp);
        if (level.zm_dmo_sharp)
        {
            level.zm_dmo_mode_p = self;
            level.zm_dmo_gg_list = [[ level.zm_dm_all_guns_fn ]]();
            self thread zm_dmo_sharp_loop();
            return "SHARPSHOOTER: a random gun every " + zm_dmo_num("sharp_gap", 30) + " s";
        }
        return "sharpshooter OFF";
    }
    if (a == "rule_hs")
    {
        level.zm_dmo_r_hs = 1 - zm_dmo_flag(level.zm_dmo_r_hs);
        return "headshots only " + zm_dmo_onoff(level.zm_dmo_r_hs);
    }
    if (a == "rule_melee")
    {
        level.zm_dmo_r_melee = 1 - zm_dmo_flag(level.zm_dmo_r_melee);
        return "melee only " + zm_dmo_onoff(level.zm_dmo_r_melee);
    }
    if (a == "rule_tough")
    {
        level.zm_dmo_r_tough = int(v);
        if (level.zm_dmo_r_tough <= 1)
        {
            level.zm_dmo_r_tough = 1;
            return "zombies normal toughness";
        }
        return "zombies " + level.zm_dmo_r_tough + "x tougher";
    }
    if (a == "rule_roulette")
    {
        level.zm_dmo_roul = 1 - zm_dmo_flag(level.zm_dmo_roul);
        level.zm_dmo_mode_p = self;
        level.zm_dmo_gg_list = [[ level.zm_dm_all_guns_fn ]]();
        return "weapon roulette " + zm_dmo_onoff(level.zm_dmo_roul) + " (a random gun every round)";
    }
    if (a == "rule_heal")
    {
        level.zm_dmo_rheal = 1 - zm_dmo_flag(level.zm_dmo_rheal);
        return "round-end full heal + revive " + zm_dmo_onoff(level.zm_dmo_rheal);
    }
    if (a == "rule_rest")
    {
        level.zm_dmo_rest = int(v);
        if (level.zm_dmo_rest <= 0)
        {
            level.zm_dmo_rest = 0;
            return "no rest between rounds";
        }
        return "rest break " + level.zm_dmo_rest + " s at the start of every round";
    }
    if (a == "rule_sprint")
    {
        level.zm_dmo_ssr = int(v);
        if (level.zm_dmo_ssr <= 0)
        {
            level.zm_dmo_ssr = 0;
            return "super sprinters OFF";
        }
        level thread zm_dmo_sprint_loop();
        return "super sprinters from round " + level.zm_dmo_ssr;
    }
    if (a == "rule_timer")
    {
        level.zm_dmo_timer = 1 - zm_dmo_flag(level.zm_dmo_timer);
        if (level.zm_dmo_timer)
        {
            level.zm_dmo_timer_t0 = gettime();
            level thread zm_dmo_timer_loop();
        }
        else
        {
            setdvar(@"phantom_hud", "");
        }
        return "match timer " + zm_dmo_onoff(level.zm_dmo_timer);
    }
    if (a == "gamble" || a == "rule_gamble")
    {
        return self zm_dmo_gamble();
    }
    if (a == "perksoff" || a == "rule_perksoff")
    {
        return "removed " + self zm_dmo_take_perks() + " perks";
    }
    if (a == "rule_onegun")
    {
        if (zm_dmo_flag(level.zm_dmo_og_on))
        {
            zm_dmo_onegun_stop();
            return "one gun roulette OFF";
        }
        self zm_dmo_onegun_start();
        return "ONE GUN ROULETTE: press Use at the crate behind you";
    }
    if (a == "rule_off")
    {
        level.zm_dmo_r_hs = 0;
        level.zm_dmo_r_melee = 0;
        level.zm_dmo_r_tough = 1;
        level.zm_dmo_roul = 0;
        level.zm_dmo_rheal = 0;
        level.zm_dmo_rest = 0;
        level.zm_dmo_ssr = 0;
        if (zm_dmo_flag(level.zm_dmo_timer))
        {
            level.zm_dmo_timer = 0;
            setdvar(@"phantom_hud", "");
        }
        return "all match rules OFF";
    }
    if (a == "mode_off")
    {
        level.zm_dmo_gg = 0;
        level.zm_dmo_oitc = 0;
        level.zm_dmo_sharp = 0;
        return "all game modes OFF";
    }
    return "unknown overpowered action " + a;
}

// ---------------------------------------------------------------- helpers

zm_dmo_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

zm_dmo_onoff(v)
{
    if (v)
    {
        return "ON";
    }
    return "OFF";
}

zm_dmo_num(key, def)
{
    level.zm_dmo_nv = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dmo_nv) || (isstring(level.zm_dmo_nv) && level.zm_dmo_nv == "") || (!isstring(level.zm_dmo_nv) && level.zm_dmo_nv == 0))
    {
        return def;
    }
    if (isstring(level.zm_dmo_nv))
    {
        return float(level.zm_dmo_nv);
    }
    return level.zm_dmo_nv;
}

zm_dmo_list()
{
    if (isdefined(level.zombie_team))
    {
        level.zm_dmo_la = getaiarray(level.zombie_team);
    }
    else
    {
        level.zm_dmo_la = getaiarray("team_two_hundred");
    }
    if (!isdefined(level.zombie_team) || level.zombie_team != "axis")
    {
        level.zm_dmo_lb = getaiarray("axis");
        for (level.zm_dmo_li = 0; level.zm_dmo_li < level.zm_dmo_lb.size; level.zm_dmo_li++)
        {
            level.zm_dmo_la[level.zm_dmo_la.size] = level.zm_dmo_lb[level.zm_dmo_li];
        }
    }
    return level.zm_dmo_la;
}

zm_dmo_killable(ai)
{
    if (!isdefined(ai) || !isalive(ai))
    {
        return 0;
    }
    if (zm_dmo_flag(ai.magic_bullet_shield) || zm_dmo_flag(ai.damageshield))
    {
        return 0;
    }
    return 1;
}

// ---------------------------------------------------------------- damage (self = zombie)
zm_dmo_on_damaged(params)
{
    if (!isdefined(params) || !isdefined(params.var_a87b62c261a8d114) || params.var_a87b62c261a8d114 <= 0 || !isplayer(params.var_917e21c98d80255e))
    {
        return;
    }
    level.zm_dmo_hit = level.zm_dmo_dmg;
    // match rules: headshots only / melee only / tougher zombies
    level.zm_dmo_ishead = zm_dmo_flag(params.var_4f9d5587bf9a2b1e) || params.var_181dac8470cfcf7e == "head" || params.var_f5a880abf0b199dc == "MOD_HEAD_SHOT";
    if (zm_dmo_flag(level.zm_dmo_r_hs) && !level.zm_dmo_ishead)
    {
        zm_dmo_count("rule_blocked_body");
        params.var_a87b62c261a8d114 = 0;
        return;
    }
    if (zm_dmo_flag(level.zm_dmo_r_melee) && params.var_f5a880abf0b199dc != "MOD_MELEE")
    {
        zm_dmo_count("rule_blocked_nonmelee");
        params.var_a87b62c261a8d114 = 0;
        return;
    }
    if (isdefined(level.zm_dmo_r_tough) && level.zm_dmo_r_tough > 1)
    {
        level.zm_dmo_hit = level.zm_dmo_hit / level.zm_dmo_r_tough;
        zm_dmo_count("rule_tough_hits");
    }
    if (level.zm_dmo_crit != 1 && (zm_dmo_flag(params.var_4f9d5587bf9a2b1e) || params.var_181dac8470cfcf7e == "head" || params.var_f5a880abf0b199dc == "MOD_HEAD_SHOT"))
    {
        level.zm_dmo_hit = level.zm_dmo_hit * level.zm_dmo_crit;
    }
    if (level.zm_dmo_hit != 1)
    {
        params.var_a87b62c261a8d114 = int(max(1, min(params.var_a87b62c261a8d114 * level.zm_dmo_hit, 2000000000)));
    }
}

// ---------------------------------------------------------------- kills (self = the zombie)
zm_dmo_on_killed(params)
{
    if (!isdefined(self))
    {
        return;
    }
    level.zm_dmo_kpos = self.origin;
    if (isdefined(level.zm_dmo_kpts) && level.zm_dmo_kpts > 0 && isdefined(level.players) && level.players.size > 0)
    {
        level.players[0] namespace_c40c7bec6c50de09::function_95df551cd7179ba3(level.zm_dmo_kpts);
        zm_dmo_count("bonus_kill_points");
    }
    if (zm_dmo_flag(level.zm_dmo_gg) && isdefined(level.zm_dmo_mode_p))
    {
        level.zm_dmo_gg_k++;
        zm_dmo_count("mode_gg_kills");
        if (level.zm_dmo_gg_k >= zm_dmo_num("gg_kills", 3))
        {
            level.zm_dmo_gg_k = 0;
            level.zm_dmo_gg_i++;
            level.zm_dmo_mode_p thread zm_dmo_gg_give();
        }
    }
    if (zm_dmo_flag(level.zm_dmo_oitc) && isdefined(level.zm_dmo_mode_p))
    {
        level.zm_dmo_mode_p thread zm_dmo_oitc_reward();
    }
    if (zm_dmo_flag(level.zm_dmo_pinata) && randomint(100) < zm_dmo_num("pinata_chance", 12))
    {
        level thread zm_dmo_pinata_drop();
    }
    if (zm_dmo_flag(level.zm_dmo_chain) && !zm_dmo_flag(self.zm_dmo_chained))
    {
        level.zm_dmo_cpos = self.origin;
        level thread zm_dmo_chain_blast();
    }
}

zm_dmo_pinata_drop()
{
    if (!utility::issharedfuncdefined(#"powerups", #"dropPowerup") || !utility::issharedfuncdefined(#"powerups", #"hash_a25fdc7ee24539fb"))
    {
        return;
    }
    level.zm_dmo_pp = level.zm_dmo_kpos;
    level.zm_dmo_root = utility::callsharedfunc(#"powerups", #"hash_a25fdc7ee24539fb");
    if (!isdefined(level.zm_dmo_root) || !isdefined(level.zm_dmo_root.powerups))
    {
        return;
    }
    level.zm_dmo_pk = getarraykeys(level.zm_dmo_root.powerups);
    if (level.zm_dmo_pk.size == 0)
    {
        return;
    }
    level.zm_dmo_pn = level.zm_dmo_pk[randomint(level.zm_dmo_pk.size)];
    if (level.zm_dmo_pn == "nuke" && zm_dmo_num("rain_nukes", 0) != 1)
    {
        return;
    }
    utility::callsharedfunc(#"powerups", #"dropPowerup", level.zm_dmo_pn, level.zm_dmo_pp + (0, 0, 40), undefined, undefined, undefined, 0);
}

// killed zombie blows up: the zombies within chain_r (160) die too (and blow up in turn)
zm_dmo_chain_blast()
{
    waitframe();
    level.zm_dmo_bp = level.zm_dmo_cpos;
    if (isdefined(level.zm_dmz_fxat))
    {
        level [[ level.zm_dmz_fxat ]]("brainrot_elite_explosion", level.zm_dmo_bp + (0, 0, 30), 2);
    }
    earthquake(0.2, 0.4, level.zm_dmo_bp, 500);
    level.zm_dmo_cl = zm_dmo_list();
    level.zm_dmo_cn = 0;
    for (level.zm_dmo_ci = 0; level.zm_dmo_ci < level.zm_dmo_cl.size && level.zm_dmo_cn < 6; level.zm_dmo_ci++)
    {
        level.zm_dmo_ca = level.zm_dmo_cl[level.zm_dmo_ci];
        if (zm_dmo_killable(level.zm_dmo_ca) && distance(level.zm_dmo_ca.origin, level.zm_dmo_bp) < zm_dmo_num("chain_r", 160))
        {
            level.zm_dmo_ca.no_powerups = 1;
            level.zm_dmo_ca kill();
            level.zm_dmo_cn++;
        }
    }
}

// ---------------------------------------------------------------- auto nuke
zm_dmo_nuke_loop()
{
    while (zm_dmo_flag(level.zm_dmo_nuke))
    {
        wait zm_dmo_num("autonuke_gap", 15);
        if (zm_dmo_flag(level.zm_dmo_nuke))
        {
            zm_dmo_nuke_now();
        }
    }
}

zm_dmo_nuke_now()
{
    level.zm_dmo_nl = zm_dmo_list();
    for (level.zm_dmo_ni = 0; level.zm_dmo_ni < level.zm_dmo_nl.size; level.zm_dmo_ni++)
    {
        if (zm_dmo_killable(level.zm_dmo_nl[level.zm_dmo_ni]) && isdefined(level.zm_dmo_nl[level.zm_dmo_ni].enemy))
        {
            level.zm_dmo_nl[level.zm_dmo_ni].no_powerups = 1;
            level.zm_dmo_nl[level.zm_dmo_ni] kill();
        }
    }
    nengine_store_set("devmenu_dbg", "op_nuke", gettime());
}

// ---------------------------------------------------------------- field upgrade (self = player)
zm_dmo_fieldup_loop()
{
    self endon("disconnect");
    while (zm_dmo_flag(self.zm_dmo_fu))
    {
        if (isalive(self) && utility::issharedfuncdefined(#"full_power", #"give_power"))
        {
            self utility::callsharedfunc(#"full_power", #"give_power");
        }
        wait 1;
    }
}

// ---------------------------------------------------------------- ESP: red outline through walls
zm_dmo_esp_loop()
{
    while (zm_dmo_flag(level.zm_dmo_esp))
    {
        zm_dmo_esp_step(1);
        wait 0.1;
    }
    zm_dmo_esp_step(0);
}

zm_dmo_esp_step(on)
{
    level.zm_dmo_el = zm_dmo_list();
    for (level.zm_dmo_ei = 0; level.zm_dmo_ei < level.zm_dmo_el.size; level.zm_dmo_ei++)
    {
        level.zm_dmo_ea = level.zm_dmo_el[level.zm_dmo_ei];
        if (!isdefined(level.zm_dmo_ea))
        {
            continue;
        }
        if (on && isalive(level.zm_dmo_ea))
        {
            level.zm_dmo_ea hudoutlineenable("outline_nodepth_red");
            level.zm_dmo_ea.zm_dmo_wh = 1;
        }
        else if (zm_dmo_flag(level.zm_dmo_ea.zm_dmo_wh))
        {
            level.zm_dmo_ea.zm_dmo_wh = 0;
            level.zm_dmo_ea hudoutlinedisable();
        }
    }
}

// ---------------------------------------------------------------- aimbot (self = player)
// aim (ADS) events, because adsbuttonpressed() is always 0 here
zm_dmo_ads_start()
{
    if (isdefined(self.zm_dmo_ads_on))
    {
        return;
    }
    self.zm_dmo_ads_on = 1;
    self.zm_dmo_ads = 0;
    self notifyonplayercommand("zm_dmo_ads_dn", "+speed_throw");
    self notifyonplayercommand("zm_dmo_ads_dn", "+toggleads_throw");
    self notifyonplayercommand("zm_dmo_ads_up", "-speed_throw");
    self notifyonplayercommand("zm_dmo_ads_up", "-toggleads_throw");
    self thread zm_dmo_ads_dn_loop();
    self thread zm_dmo_ads_up_loop();
}

zm_dmo_ads_dn_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmo_ads_dn");
        self.zm_dmo_ads = 1;
    }
}

zm_dmo_ads_up_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmo_ads_up");
        self.zm_dmo_ads = 0;
    }
}

zm_dmo_aimbot_loop()
{
    self endon("disconnect");
    while (zm_dmo_flag(self.zm_dmo_aim))
    {
        if (self.zm_dmo_ads && !(isdefined(level.zm_dm_open) && level.zm_dm_open))
        {
            self zm_dmo_aim_step();
        }
        wait 0.05;
    }
}

zm_dmo_aim_step()
{
    self.zm_dmo_eye = self geteye();
    self.zm_dmo_f = anglestoforward(self getplayerangles());
    self.zm_dmo_best = undefined;
    // only heads within about 25 degrees of the crosshair, and in sight
    self.zm_dmo_bs = 0.9;
    level.zm_dmo_al = zm_dmo_list();
    for (level.zm_dmo_ai_i = 0; level.zm_dmo_ai_i < level.zm_dmo_al.size; level.zm_dmo_ai_i++)
    {
        level.zm_dmo_aa = level.zm_dmo_al[level.zm_dmo_ai_i];
        if (!isdefined(level.zm_dmo_aa) || !isalive(level.zm_dmo_aa))
        {
            continue;
        }
        level.zm_dmo_head = level.zm_dmo_aa gettagorigin("j_head");
        if (!isdefined(level.zm_dmo_head))
        {
            continue;
        }
        level.zm_dmo_dot = vectordot(self.zm_dmo_f, vectornormalize(level.zm_dmo_head - self.zm_dmo_eye));
        if (level.zm_dmo_dot > self.zm_dmo_bs && sighttracepassed(self.zm_dmo_eye, level.zm_dmo_head, 0, self))
        {
            self.zm_dmo_bs = level.zm_dmo_dot;
            self.zm_dmo_best = level.zm_dmo_head;
        }
    }
    if (isdefined(self.zm_dmo_best))
    {
        self setplayerangles(vectortoangles(self.zm_dmo_best - self.zm_dmo_eye));
    }
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmo_init_is_zombies()
{
    level.zm_dmo_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmo_init_gt) || level.zm_dmo_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmo_init_gt, 0, 2) == "zm";
}

// ---------------------------------------------------------------- game modes

// self = player: gun game - the next gun in a shuffled order
zm_dmo_gg_give()
{
    if (!isdefined(level.zm_dmo_gg_list) || level.zm_dmo_gg_list.size == 0)
    {
        return;
    }
    level.zm_dmo_gg_n = level.zm_dmo_gg_list[randomint(level.zm_dmo_gg_list.size)];
    self [[ level.zm_dm_give_named_fn ]](level.zm_dmo_gg_n);
    zm_dmo_count("mode_gg_guns");
    nengine_store_set("devmenu_dbg", "mode_gg_gun", level.zm_dmo_gg_n);
}

// self = player: one in the chamber - reserve ammo always empty
zm_dmo_oitc_loop()
{
    self endon("disconnect");
    wait 2;
    self zm_dmo_oitc_clip(1);
    while (zm_dmo_flag(level.zm_dmo_oitc))
    {
        self zm_dmo_oitc_tick();
        wait 0.25;
    }
}

zm_dmo_oitc_tick()
{
    self.zm_dmo_og = self getcurrentweapon();
    if (isdefined(self.zm_dmo_og) && !isnullweapon(self.zm_dmo_og))
    {
        self setweaponammostock(self.zm_dmo_og, 0);
    }
}

zm_dmo_oitc_clip(n)
{
    self.zm_dmo_og = self getcurrentweapon();
    if (isdefined(self.zm_dmo_og) && !isnullweapon(self.zm_dmo_og))
    {
        self setweaponammoclip(self.zm_dmo_og, n);
        self setweaponammostock(self.zm_dmo_og, 0);
    }
}

// self = player: a kill gives one bullet back
zm_dmo_oitc_reward()
{
    self.zm_dmo_og = self getcurrentweapon();
    if (isdefined(self.zm_dmo_og) && !isnullweapon(self.zm_dmo_og))
    {
        self setweaponammoclip(self.zm_dmo_og, self getweaponammoclip(self.zm_dmo_og) + 1);
        zm_dmo_count("mode_oitc_bullets");
    }
}

// self = player: sharpshooter - random gun every sharp_gap seconds
zm_dmo_sharp_loop()
{
    self endon("disconnect");
    while (zm_dmo_flag(level.zm_dmo_sharp))
    {
        self zm_dmo_gg_give();
        wait zm_dmo_sharp_t();
    }
}

zm_dmo_sharp_t()
{
    level.zm_dmo_st = zm_dmo_num("sharp_gap", 30);
    if (level.zm_dmo_st < 5)
    {
        return 5;
    }
    return level.zm_dmo_st;
}

zm_dmo_count(k)
{
    if (!isdefined(level.zm_dmo_counts))
    {
        level.zm_dmo_counts = [];
    }
    if (!isdefined(level.zm_dmo_counts[k]))
    {
        level.zm_dmo_counts[k] = 0;
    }
    level.zm_dmo_counts[k]++;
    nengine_store_set("devmenu_dbg", k, level.zm_dmo_counts[k]);
}

// ---------------------------------------------------------------- round rules (ideas from BO3 "All-around Enhancement")

// watches the round number; on every new round: roulette gun, heal / revive, rest break, gamble reset
zm_dmo_round_watch()
{
    while (!isdefined(level.zm_dm_round_now_fn))
    {
        wait 1;
    }
    level.zm_dmo_lastround = [[ level.zm_dm_round_now_fn ]]();
    while (1)
    {
        wait 1;
        zm_dmo_round_check();
    }
}

zm_dmo_round_check()
{
    level.zm_dmo_rn = [[ level.zm_dm_round_now_fn ]]();
    if (!isdefined(level.zm_dmo_rn) || !isdefined(level.zm_dmo_lastround) || level.zm_dmo_rn == level.zm_dmo_lastround)
    {
        level.zm_dmo_lastround = level.zm_dmo_rn;
        return;
    }
    level.zm_dmo_lastround = level.zm_dmo_rn;
    level.zm_dmo_gambled = [];
    zm_dmo_count("round_changes");
    if (!isdefined(level.players) || level.players.size < 1)
    {
        return;
    }
    level.zm_dmo_rp = level.players[0];
    if (zm_dmo_flag(level.zm_dmo_roul) && isdefined(level.zm_dmo_gg_list))
    {
        level.zm_dmo_rp thread zm_dmo_gg_give();
    }
    if (zm_dmo_flag(level.zm_dmo_rheal))
    {
        for (level.zm_dmo_hi = 0; level.zm_dmo_hi < level.players.size; level.zm_dmo_hi++)
        {
            level.zm_dmo_hp = level.players[level.zm_dmo_hi];
            if (isdefined(level.zm_dmo_hp.maxhealth))
            {
                level.zm_dmo_hp.health = level.zm_dmo_hp.maxhealth;
            }
            if (zm_dmo_flag(level.zm_dmo_hp.inlaststand) && isdefined(level.zm_dmw_run))
            {
                // downed: give a self revive so they can get up
                level.zm_dmo_hp [[ level.zm_dmw_run ]]("revives", "");
            }
        }
        zm_dmo_count("round_heals");
    }
    if (isdefined(level.zm_dmo_rest) && level.zm_dmo_rest > 0 && isdefined(level.zm_dmw_run))
    {
        level thread zm_dmo_rest_break();
    }
}

// rest break: spawning paused for zm_dmo_rest seconds at the start of a round
zm_dmo_rest_break()
{
    if (zm_dmo_flag(level.zm_dmo_resting))
    {
        return;
    }
    level.zm_dmo_resting = 1;
    level.zm_dmo_rest_p = level.players[0];
    level.zm_dmo_rest_p [[ level.zm_dmw_run ]]("stopspawns", "");
    if (isdefined(level.zm_dm_tell_fn))
    {
        [[ level.zm_dm_tell_fn ]]("rest break: " + level.zm_dmo_rest + " seconds");
    }
    wait zm_dmo_rest_t();
    level.zm_dmo_rest_p [[ level.zm_dmw_run ]]("stopspawns", "");
    level.zm_dmo_resting = 0;
    zm_dmo_count("rest_breaks");
}

zm_dmo_rest_t()
{
    if (!isdefined(level.zm_dmo_rest) || level.zm_dmo_rest < 3)
    {
        return 3;
    }
    return level.zm_dmo_rest;
}

// super sprinters: from round zm_dmo_ssr every zombie sprints
zm_dmo_sprint_loop()
{
    if (zm_dmo_flag(level.zm_dmo_ss_on))
    {
        return;
    }
    level.zm_dmo_ss_on = 1;
    while (isdefined(level.zm_dmo_ssr) && level.zm_dmo_ssr > 0)
    {
        zm_dmo_sprint_step();
        wait 2;
    }
    level.zm_dmo_ss_on = 0;
}

zm_dmo_sprint_step()
{
    level.zm_dmo_ssn = [[ level.zm_dm_round_now_fn ]]();
    if (!isdefined(level.zm_dmo_ssn) || level.zm_dmo_ssn < level.zm_dmo_ssr)
    {
        return;
    }
    level.zm_dmo_ssl = zm_dmo_list();
    for (level.zm_dmo_ssi = 0; level.zm_dmo_ssi < level.zm_dmo_ssl.size; level.zm_dmo_ssi++)
    {
        level.zm_dmo_ssa = level.zm_dmo_ssl[level.zm_dmo_ssi];
        if (isdefined(level.zm_dmo_ssa) && isalive(level.zm_dmo_ssa) && !zm_dmo_flag(level.zm_dmo_ssa.zm_dmo_ss))
        {
            level.zm_dmo_ssa.zm_dmo_ss = 1;
            level.zm_dmo_ssa namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0("sprint", "phantom_ss", 100);
            zm_dmo_count("super_sprinters");
        }
    }
}

// match timer on the HUD line (minutes:seconds and round)
zm_dmo_timer_loop()
{
    while (zm_dmo_flag(level.zm_dmo_timer))
    {
        zm_dmo_timer_step();
        wait 1;
    }
}

zm_dmo_timer_step()
{
    level.zm_dmo_ts = int((gettime() - level.zm_dmo_timer_t0) / 1000);
    level.zm_dmo_tm = int(level.zm_dmo_ts / 60);
    level.zm_dmo_tsec = level.zm_dmo_ts % 60;
    level.zm_dmo_tz = "";
    if (level.zm_dmo_tsec < 10)
    {
        level.zm_dmo_tz = "0";
    }
    setdvar(@"phantom_hud", "Time " + level.zm_dmo_tm + ":" + level.zm_dmo_tz + level.zm_dmo_tsec + "   Round " + [[ level.zm_dm_round_now_fn ]]());
}

// self = player: the gambler - 1,000 points, once per round, a random outcome
zm_dmo_gamble()
{
    if (!isdefined(level.zm_dmo_gambled))
    {
        level.zm_dmo_gambled = [];
    }
    if (isdefined(level.zm_dmo_gambled[self getentitynumber()]))
    {
        return "^1you already gambled this round";
    }
    if (self namespace_c40c7bec6c50de09::function_8f0a9502ff7321a() < 1000)
    {
        return "^1gambling costs 1000 points";
    }
    level.zm_dmo_gambled[self getentitynumber()] = 1;
    self namespace_c40c7bec6c50de09::function_b660af7031bca4bd(1000);
    zm_dmo_count("gambles");
    self.zm_dmo_roll = randomint(100);
    if (self.zm_dmo_roll < 25)
    {
        self namespace_c40c7bec6c50de09::function_95df551cd7179ba3(2500);
        return "^2JACKPOT^7 - 2500 points";
    }
    if (self.zm_dmo_roll < 45)
    {
        level.zm_dmo_gg_list = [[ level.zm_dm_all_guns_fn ]]();
        self zm_dmo_gg_give();
        return "^3the dice give you a random gun";
    }
    if (self.zm_dmo_roll < 60)
    {
        level.zm_dmo_kpos = self.origin + anglestoforward((0, self.angles[1], 0)) * 80;
        level thread zm_dmo_pinata_drop();
        return "^3a power-up drops";
    }
    if (self.zm_dmo_roll < 75)
    {
        return self zm_dmo_random_perk();
    }
    if (self.zm_dmo_roll < 85)
    {
        self namespace_c40c7bec6c50de09::function_95df551cd7179ba3(1000);
        return "you get your points back";
    }
    return "^1you lost the bet";
}

zm_dmo_perk_keys()
{
    level.zm_dmo_pk2 = [];
    if (!isdefined(level.var_35cae1d5b8f6f7c2))
    {
        return level.zm_dmo_pk2;
    }
    level.zm_dmo_pka = getarraykeys(level.var_35cae1d5b8f6f7c2);
    for (level.zm_dmo_pki = 0; level.zm_dmo_pki < level.zm_dmo_pka.size; level.zm_dmo_pki++)
    {
        if (isstring(level.zm_dmo_pka[level.zm_dmo_pki]) && !issubstr(level.zm_dmo_pka[level.zm_dmo_pki], "choice"))
        {
            level.zm_dmo_pk2[level.zm_dmo_pk2.size] = level.zm_dmo_pka[level.zm_dmo_pki];
        }
    }
    return level.zm_dmo_pk2;
}

// self = player: a perk you don't have yet
zm_dmo_random_perk()
{
    self.zm_dmo_pks = zm_dmo_perk_keys();
    for (self.zm_dmo_pt = 0; self.zm_dmo_pt < 20 && self.zm_dmo_pks.size > 0; self.zm_dmo_pt++)
    {
        self.zm_dmo_pkn = self.zm_dmo_pks[randomint(self.zm_dmo_pks.size)];
        if (!self namespace_377106c4017f7cda::function_e183e1e4f906ec3b(self.zm_dmo_pkn))
        {
            self namespace_377106c4017f7cda::function_a969ec70f9242aa4(self.zm_dmo_pkn, 0);
            return "^3a free perk";
        }
    }
    self namespace_c40c7bec6c50de09::function_95df551cd7179ba3(1000);
    return "you have every perk - points back";
}

// self = player: take every perk away
zm_dmo_take_perks()
{
    self.zm_dmo_pks = zm_dmo_perk_keys();
    self.zm_dmo_pn = 0;
    for (self.zm_dmo_pt = 0; self.zm_dmo_pt < self.zm_dmo_pks.size; self.zm_dmo_pt++)
    {
        if (self namespace_377106c4017f7cda::function_e183e1e4f906ec3b(self.zm_dmo_pks[self.zm_dmo_pt]))
        {
            self namespace_377106c4017f7cda::function_145b00820a9f68b2(self.zm_dmo_pks[self.zm_dmo_pt]);
            self.zm_dmo_pn++;
        }
    }
    return self.zm_dmo_pn;
}

// ---------------------------------------------------------------- Settings > Debug Options (Phantom section)
// The add-on writes dvars phantom_o_*; a changed value is applied here within a second.
zm_dmo_opts_loop()
{
    level.zm_dmo_ol = [];
    // create every Debug Options setting so the menu screen can flip it (an unset one reads "")
    level.zm_dmo_nm = "phantom_o_off phantom_o_autogod phantom_o_timer phantom_o_roul phantom_o_heal phantom_o_rest phantom_o_sprint phantom_o_tough phantom_o_hs phantom_o_melee phantom_o_picon phantom_o_brand";
    level.zm_dmo_nm = level.zm_dmo_nm + " phantom_o_lvltxt phantom_o_lvlx phantom_o_lvly phantom_o_lvl phantom_lvltest phantom_o_sround phantom_o_spoints phantom_o_sperks phantom_o_kpts phantom_o_gg phantom_o_cap phantom_o_zspeed phantom_o_onegun";
    level.zm_dmo_nm = level.zm_dmo_nm + " phantom_o_rot phantom_o_rotn phantom_o_rotspots phantom_o_rotr phantom_o_rotstay";
    level.zm_dmo_names = strtok(level.zm_dmo_nm, " ");
    for (level.zm_dmo_ni = 0; level.zm_dmo_ni < level.zm_dmo_names.size; level.zm_dmo_ni++)
    {
        if (getdvar(level.zm_dmo_names[level.zm_dmo_ni]) == "")
        {
            setdvar(level.zm_dmo_names[level.zm_dmo_ni], "0");
        }
    }
    // options that act on the player wait until the match has started
    while (!isdefined(level.players) || level.players.size < 1)
    {
        wait 1;
    }
    wait 6;
    while (1)
    {
        wait 1;
        zm_dmo_opts_tick();
    }
}

zm_dmo_opt(name)
{
    level.zm_dmo_ov = getdvar(name);
    if (!isdefined(level.zm_dmo_ov) || level.zm_dmo_ov == "")
    {
        return undefined;
    }
    if (isdefined(level.zm_dmo_ol[name]) && level.zm_dmo_ol[name] == level.zm_dmo_ov)
    {
        return undefined;
    }
    level.zm_dmo_ol[name] = level.zm_dmo_ov;
    zm_dmo_count("debug_option_changes");
    return level.zm_dmo_ov;
}

zm_dmo_opts_tick()
{
    level.zm_dmo_o = zm_dmo_opt("phantom_o_autogod");
    if (isdefined(level.zm_dmo_o))
    {
        nengine_store_set("devmenu", "no_auto_god", 1 - int(level.zm_dmo_o));
        nengine_store_save("devmenu", "settings");
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_timer");
    if (isdefined(level.zm_dmo_o) && int(level.zm_dmo_o) != zm_dmo_flag(level.zm_dmo_timer))
    {
        zm_dmo_run("rule_timer", "");
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_roul");
    if (isdefined(level.zm_dmo_o) && int(level.zm_dmo_o) != zm_dmo_flag(level.zm_dmo_roul) && isdefined(level.players) && level.players.size > 0)
    {
        level.players[0] zm_dmo_run("rule_roulette", "");
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_heal");
    if (isdefined(level.zm_dmo_o))
    {
        level.zm_dmo_rheal = int(level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_rest");
    if (isdefined(level.zm_dmo_o))
    {
        zm_dmo_run("rule_rest", level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_sprint");
    if (isdefined(level.zm_dmo_o))
    {
        zm_dmo_run("rule_sprint", level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_tough");
    if (isdefined(level.zm_dmo_o))
    {
        zm_dmo_run("rule_tough", level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_hs");
    if (isdefined(level.zm_dmo_o))
    {
        level.zm_dmo_r_hs = int(level.zm_dmo_o);
    }
    level.zm_dmo_op = level.players[0];
    level.zm_dmo_o = zm_dmo_opt("phantom_o_sround");
    if (isdefined(level.zm_dmo_o) && int(level.zm_dmo_o) > 1 && [[ level.zm_dm_round_now_fn ]]() < int(level.zm_dmo_o))
    {
        level.zm_dmo_sround_want = int(level.zm_dmo_o);
        level thread zm_dmo_sround_retry();
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_spoints");
    if (isdefined(level.zm_dmo_o) && int(level.zm_dmo_o) > 0)
    {
        level.zm_dmo_op namespace_c40c7bec6c50de09::function_40dc4b206b63ac2e(int(level.zm_dmo_o));
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_sperks");
    if (isdefined(level.zm_dmo_o) && level.zm_dmo_o == "1")
    {
        level.zm_dmo_spk = zm_dmo_perk_keys();
        for (level.zm_dmo_spi = 0; level.zm_dmo_spi < level.zm_dmo_spk.size; level.zm_dmo_spi++)
        {
            if (!level.zm_dmo_op namespace_377106c4017f7cda::function_e183e1e4f906ec3b(level.zm_dmo_spk[level.zm_dmo_spi]))
            {
                level.zm_dmo_op namespace_377106c4017f7cda::function_a969ec70f9242aa4(level.zm_dmo_spk[level.zm_dmo_spi], 0);
            }
        }
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_kpts");
    if (isdefined(level.zm_dmo_o))
    {
        level.zm_dmo_kpts = int(level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_cap");
    if (isdefined(level.zm_dmo_o) && isdefined(level.zm_dmw_run))
    {
        level.zm_dmo_op [[ level.zm_dmw_run ]]("cap", level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_zspeed");
    if (isdefined(level.zm_dmo_o) && isdefined(level.zm_dmw_run))
    {
        level.zm_dmo_op [[ level.zm_dmw_run ]]("speed", level.zm_dmo_o);
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_gg");
    if (isdefined(level.zm_dmo_o) && int(level.zm_dmo_o) != zm_dmo_flag(level.zm_dmo_gg))
    {
        level.zm_dmo_op zm_dmo_run("mode_gungame", "");
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_onegun");
    if (isdefined(level.zm_dmo_o))
    {
        if (level.zm_dmo_o == "1")
        {
            level.zm_dmo_op zm_dmo_onegun_start();
        }
        else
        {
            zm_dmo_onegun_stop();
        }
    }
    level.zm_dmo_o = zm_dmo_opt("phantom_o_melee");
    if (isdefined(level.zm_dmo_o))
    {
        level.zm_dmo_r_melee = int(level.zm_dmo_o);
    }
}

// starting round: the game ignores a round change right at match start, so try again until it lands
zm_dmo_sround_retry()
{
    if (zm_dmo_flag(level.zm_dmo_sround_busy))
    {
        return;
    }
    level.zm_dmo_sround_busy = 1;
    for (level.zm_dmo_sri = 0; level.zm_dmo_sri < 6; level.zm_dmo_sri++)
    {
        if ([[ level.zm_dm_round_now_fn ]]() >= level.zm_dmo_sround_want)
        {
            break;
        }
        level thread [[ level.zm_dm_round_jump_fn ]](level.zm_dmo_sround_want);
        zm_dmo_count("start_round_tries");
        wait 15;
    }
    level.zm_dmo_sround_busy = 0;
}

// ---------------------------------------------------------------- ONE GUN ROULETTE
// A crate spawns behind you; press Use (F) at it to roll a random gun (wonder_chance % a wonder
// weapon). That gun is yours for the whole match: Pack-a-Punch it as normal, every other gun you
// pick up is taken away (knives / melee stay).
zm_dmo_onegun_start()
{
    if (zm_dmo_flag(level.zm_dmo_og_on))
    {
        return;
    }
    level.zm_dmo_og_on = 1;
    level.zm_dmo_og_p = self;
    level.zm_dmo_og_root = undefined;
    // crate model: a box / crate / case the map uses, else any prop
    level.zm_dmo_og_model = undefined;
    if (isdefined(level.zm_dm_props_fn))
    {
        [[ level.zm_dm_props_fn ]]();
    }
    if (isdefined(level.zm_dm_mprops))
    {
        for (level.zm_dmo_ogi = 0; level.zm_dmo_ogi < level.zm_dm_mprops.size; level.zm_dmo_ogi++)
        {
            level.zm_dmo_ogm = level.zm_dm_mprops[level.zm_dmo_ogi];
            if (issubstr(level.zm_dmo_ogm, "crate") || issubstr(level.zm_dmo_ogm, "box") || issubstr(level.zm_dmo_ogm, "chest") || issubstr(level.zm_dmo_ogm, "case"))
            {
                level.zm_dmo_og_model = level.zm_dmo_ogm;
                break;
            }
        }
        if (!isdefined(level.zm_dmo_og_model) && level.zm_dm_mprops.size > 0)
        {
            level.zm_dmo_og_model = level.zm_dm_mprops[0];
        }
    }
    self.zm_dmo_oga = self getplayerangles();
    level.zm_dmo_og_pos = self.origin - anglestoforward((0, self.zm_dmo_oga[1], 0)) * 80;
    level.zm_dmo_og_crate = spawn("script_model", level.zm_dmo_og_pos);
    if (isdefined(level.zm_dmo_og_model))
    {
        level.zm_dmo_og_crate setmodel(level.zm_dmo_og_model);
    }
    level.zm_dmo_og_crate.angles = (0, self.zm_dmo_oga[1], 0);
    zm_dmo_og_fx(level.zm_dmo_og_pos + (0, 0, 30));
    self notifyonplayercommand("phantom_og_use", "+activate");
    self notifyonplayercommand("phantom_og_use", "+usereload");
    self thread zm_dmo_onegun_use_loop();
    level thread zm_dmo_onegun_lock_loop();
    zm_dmo_tell("^3ONE GUN ROULETTE^7 - press Use at the crate behind you");
    zm_dmo_count("onegun_started");
}

zm_dmo_og_fx(pos)
{
    if (isdefined(level.zm_dmz_fxat))
    {
        [[ level.zm_dmz_fxat ]]("aether_shroud_teleport", pos, 2);
    }
}

zm_dmo_tell(t)
{
    if (isdefined(level.zm_dm_tell_fn))
    {
        [[ level.zm_dm_tell_fn ]](t);
    }
}

zm_dmo_onegun_stop()
{
    level.zm_dmo_og_on = 0;
    level.zm_dmo_og_root = undefined;
    if (isdefined(level.zm_dmo_og_crate))
    {
        level.zm_dmo_og_crate delete();
    }
}

// self = player: waits for Use presses near the crate
zm_dmo_onegun_use_loop()
{
    self endon("disconnect");
    while (zm_dmo_flag(level.zm_dmo_og_on))
    {
        self waittill("phantom_og_use");
        self zm_dmo_onegun_use();
    }
}

zm_dmo_onegun_use()
{
    if (!zm_dmo_flag(level.zm_dmo_og_on) || !isdefined(level.zm_dmo_og_crate) || isdefined(level.zm_dmo_og_root) || zm_dmo_flag(level.zm_dmo_og_rolling))
    {
        return;
    }
    if (distance(self.origin, level.zm_dmo_og_crate.origin) > 130)
    {
        return;
    }
    level.zm_dmo_og_rolling = 1;
    self thread zm_dmo_onegun_roll();
}

// self = player: a short roll, then the gun for the rest of the match
zm_dmo_onegun_roll()
{
    zm_dmo_tell("^3rolling your gun...");
    zm_dmo_og_fx(level.zm_dmo_og_crate.origin + (0, 0, 40));
    wait 2;
    level.zm_dmo_og_pick = undefined;
    if (randomint(100) < zm_dmo_num("wonder_chance", 15))
    {
        level.zm_dmo_og_ww = strtok("raygun raygunmark2 firefly hornet locust mantis ruby scarab", " ");
        level.zm_dmo_og_pick = "sat_ww_" + level.zm_dmo_og_ww[randomint(level.zm_dmo_og_ww.size)];
    }
    else
    {
        level.zm_dmo_og_list = [[ level.zm_dm_all_guns_fn ]]();
        level.zm_dmo_og_pick = level.zm_dmo_og_list[randomint(level.zm_dmo_og_list.size)];
    }
    self [[ level.zm_dm_give_named_fn ]](level.zm_dmo_og_pick);
    level.zm_dmo_og_root = level.zm_dmo_og_pick;
    level.zm_dmo_og_rolling = 0;
    zm_dmo_og_fx(level.zm_dmo_og_crate.origin + (0, 0, 40));
    zm_dmo_tell("^3your gun for this match:^7 " + level.zm_dmo_og_pick);
    nengine_store_set("devmenu_dbg", "onegun_gun", level.zm_dmo_og_pick);
    zm_dmo_count("onegun_rolls");
}

// takes away every other gun (melee kept); the rolled gun can be Pack-a-Punched as normal
zm_dmo_onegun_lock_loop()
{
    while (zm_dmo_flag(level.zm_dmo_og_on))
    {
        wait 1;
        zm_dmo_onegun_lock_tick();
    }
}

zm_dmo_onegun_lock_tick()
{
    level.zm_dmo_lp = level.zm_dmo_og_p;
    if (!isdefined(level.zm_dmo_og_root) || !isdefined(level.zm_dmo_lp) || !isalive(level.zm_dmo_lp) || isdefined(level.zm_dmo_lp.zm_dm_busy) || !isdefined(level.zm_dmo_lp.primaryinventory))
    {
        return;
    }
    // points history (last 12 s) so a taken gun can be refunded
    level.zm_dmo_lpts = level.zm_dmo_lp namespace_c40c7bec6c50de09::function_8f0a9502ff7321a();
    if (!isdefined(level.zm_dmo_ph))
    {
        level.zm_dmo_ph = [];
    }
    level.zm_dmo_ph2 = [];
    level.zm_dmo_ph2[0] = level.zm_dmo_lpts;
    for (level.zm_dmo_phi = 0; level.zm_dmo_phi < level.zm_dmo_ph.size && level.zm_dmo_phi < 11; level.zm_dmo_phi++)
    {
        level.zm_dmo_ph2[level.zm_dmo_ph2.size] = level.zm_dmo_ph[level.zm_dmo_phi];
    }
    level.zm_dmo_ph = level.zm_dmo_ph2;
    level.zm_dmo_ltook = 0;
    level.zm_dmo_lhave = 0;
    for (level.zm_dmo_li = 0; level.zm_dmo_li < level.zm_dmo_lp.primaryinventory.size; level.zm_dmo_li++)
    {
        level.zm_dmo_lw = level.zm_dmo_lp.primaryinventory[level.zm_dmo_li];
        if (!isdefined(level.zm_dmo_lw) || isnullweapon(level.zm_dmo_lw) || !isdefined(level.zm_dmo_lw.basename))
        {
            continue;
        }
        level.zm_dmo_lb = level.zm_dmo_lw.basename;
        if (issubstr(level.zm_dmo_lb, "_me_") || issubstr(level.zm_dmo_lb, "fists") || issubstr(level.zm_dmo_lb, "knife"))
        {
            continue;
        }
        if (issubstr(level.zm_dmo_lb, level.zm_dmo_og_root))
        {
            level.zm_dmo_lhave = 1;
            continue;
        }
        level.zm_dmo_lp takeweapon(level.zm_dmo_lw);
        level.zm_dmo_ltook = 1;
        zm_dmo_count("onegun_taken");
    }
    // refund: the biggest points drop in the last 12 s (a wall buy or a box spin), up to 5000
    if (level.zm_dmo_ltook)
    {
        level.zm_dmo_lmax = level.zm_dmo_lpts;
        for (level.zm_dmo_phi = 0; level.zm_dmo_phi < level.zm_dmo_ph.size; level.zm_dmo_phi++)
        {
            if (level.zm_dmo_ph[level.zm_dmo_phi] > level.zm_dmo_lmax)
            {
                level.zm_dmo_lmax = level.zm_dmo_ph[level.zm_dmo_phi];
            }
        }
        level.zm_dmo_lref = int(min(level.zm_dmo_lmax - level.zm_dmo_lpts, 5000));
        if (level.zm_dmo_lref > 0)
        {
            level.zm_dmo_lp namespace_c40c7bec6c50de09::function_95df551cd7179ba3(level.zm_dmo_lref);
            zm_dmo_count("onegun_refunds");
            zm_dmo_tell("^1one gun only^7 - that gun was taken, " + level.zm_dmo_lref + " points refunded");
        }
        else
        {
            zm_dmo_tell("^1one gun only^7 - that gun was taken");
        }
        level.zm_dmo_ph = [];
    }
    // the rolled gun always comes back (after a respawn, or if it was lost)
    if (!level.zm_dmo_lhave)
    {
        level.zm_dmo_lp [[ level.zm_dm_give_named_fn ]](level.zm_dmo_og_root);
        zm_dmo_count("onegun_given_back");
    }
}
