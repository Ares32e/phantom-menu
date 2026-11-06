// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_boss - Phantom menu BOSS CREATOR: build your own boss from any enemy the map has
// loaded (health, speed, two effects from every loaded effect, abilities, rage, name) and save it
// to 3 slots. Reached from the main menu with action "boss <action> [value]" (level.zm_dmb_run);
// row labels come from tokens $bc_<x> (level.zm_dmb_token).
// State on level / entity fields (Kronos GSC loses locals after calls and waits).

#using scripts\common\utility;
#using script_4db5d44a376c1c35;
#using script_6c2f6a14fa53759e;
#using script_7af4b8f37e520205;

autoexec zm_dmb_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmb_init_is_zombies())
    {
        return;
    }
    level.zm_dmb_run = &zm_dmb_run;
    // boss bar for the add-on (Lua can't create dvars)
    setdvar(@"phantom_boss", "");
    level.zm_dmb_token = &zm_dmb_token;
    level.zm_dmb_bosses = [];
    level.zm_dmb_names = strtok("The Butcher|Gorefather|Aether King|Night Warden|Skull Reaper|Plague Lord|Iron Maw|The Harbinger|Void Titan|Doom Bringer", "|");
    level.zm_dmb_hps = [];
    level.zm_dmb_hps[0] = 5;
    level.zm_dmb_hps[1] = 10;
    level.zm_dmb_hps[2] = 25;
    level.zm_dmb_hps[3] = 50;
    level.zm_dmb_hps[4] = 100;
    level.zm_dmb_hps[5] = 500;
    level.zm_dmb_speeds = strtok("normal walk run sprint", " ");
    level.zm_dmb_hls = strtok("red orange yellow green cyan blue purple off", " ");
    level.zm_dmb_pscales = [];
    level.zm_dmb_pscales[0] = 1;
    level.zm_dmb_pscales[1] = 1.5;
    level.zm_dmb_pscales[2] = 2;
    level.zm_dmb_pscales[3] = 3;
    level.zm_dmb_pscales[4] = 5;
    level.zm_dmb_pscales[5] = 0.5;
    level.zm_dmb_pscales[6] = 0.75;
    // quick effect presets; any loaded effect can be picked on the Boss effects page
    level.zm_dmb_fxp = strtok("none|dark_flare_ball_effect|vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_trail|lightning_strike|flash_freeze_shatter_fx|shadow_vortex_warp_air_fx|aether_energy_trail|chain_lightning_bolt", "|");
    zm_dmb_cfg_default();
}

zm_dmb_cfg_default()
{
    level.zm_dmb_c = spawnstruct();
    level.zm_dmb_c.base = "";
    level.zm_dmb_c.hp = 2;
    level.zm_dmb_c.speed = 3;
    level.zm_dmb_c.fx1 = "dark_flare_ball_effect";
    level.zm_dmb_c.fx2 = "none";
    level.zm_dmb_c.name = 0;
    level.zm_dmb_c.model = "";
    level.zm_dmb_c.pscale = 0;
    level.zm_dmb_c.hl = 0;
    level.zm_dmb_c.ab = [];
    level.zm_dmb_c.ab["min"] = 1;
    level.zm_dmb_c.ab["tp"] = 1;
    level.zm_dmb_c.ab["shock"] = 1;
    level.zm_dmb_c.ab["light"] = 0;
    level.zm_dmb_c.ab["met"] = 0;
    level.zm_dmb_c.ab["heal"] = 0;
    level.zm_dmb_c.ab["rage"] = 1;
}

zm_dmb_dbg(k, v)
{
    nengine_store_set("devmenu_dbg", k, v);
}

zm_dmb_onoff(v)
{
    if (isdefined(v) && v)
    {
        return "^2ON";
    }
    return "^1OFF";
}

// loaded enemy types (the menu's spawn list), the base cycles through them
zm_dmb_types()
{
    if (isdefined(level.zm_dm_spawn_types_fn))
    {
        [[ level.zm_dm_spawn_types_fn ]]();
    }
    if (!isdefined(level.zm_dm_spawn_list))
    {
        return [];
    }
    return level.zm_dm_spawn_list;
}

zm_dmb_short(t)
{
    level.zm_dbs_w = strtok(t, "_");
    level.zm_dbs_s = "";
    for (level.zm_dbs_i = 0; level.zm_dbs_i < level.zm_dbs_w.size; level.zm_dbs_i++)
    {
        level.zm_dbs_x = level.zm_dbs_w[level.zm_dbs_i];
        if (level.zm_dbs_x == "sat" || level.zm_dbs_x == "spawner" || level.zm_dbs_x == "zombie" || level.zm_dbs_x == "zm" || level.zm_dbs_x == "ob")
        {
            continue;
        }
        if (level.zm_dbs_s != "")
        {
            level.zm_dbs_s = level.zm_dbs_s + " ";
        }
        level.zm_dbs_s = level.zm_dbs_s + level.zm_dbs_x;
    }
    if (level.zm_dbs_s == "")
    {
        return "zombie";
    }
    return level.zm_dbs_s;
}

zm_dmb_fxlabel(f)
{
    if (f == "none")
    {
        return "none";
    }
    if (issubstr(f, "fire"))
    {
        return "fire";
    }
    if (issubstr(f, "lightning"))
    {
        return "lightning";
    }
    if (issubstr(f, "freeze") || issubstr(f, "frost") || issubstr(f, "ice"))
    {
        return "frost";
    }
    if (issubstr(f, "shadow") || issubstr(f, "dark"))
    {
        return "shadow";
    }
    if (issubstr(f, "aether"))
    {
        return "aether";
    }
    return f;
}

// row labels: $bc_base $bc_hp $bc_speed $bc_fx1 $bc_fx2 $bc_name $bc_<ability>
zm_dmb_token(k)
{
    if (k == "bc_base")
    {
        if (level.zm_dmb_c.base == "")
        {
            return "^3pick one";
        }
        return "^3" + zm_dmb_short(level.zm_dmb_c.base);
    }
    if (k == "bc_hp")
    {
        return "^3x" + level.zm_dmb_hps[level.zm_dmb_c.hp];
    }
    if (k == "bc_speed")
    {
        return "^3" + level.zm_dmb_speeds[level.zm_dmb_c.speed];
    }
    if (k == "bc_fx1")
    {
        return "^3" + zm_dmb_fxlabel(level.zm_dmb_c.fx1);
    }
    if (k == "bc_fx2")
    {
        return "^3" + zm_dmb_fxlabel(level.zm_dmb_c.fx2);
    }
    if (k == "bc_model")
    {
        if (level.zm_dmb_c.model == "")
        {
            return "^3its own body";
        }
        return "^3" + level.zm_dmb_c.model;
    }
    if (k == "bc_hl")
    {
        return "^3" + level.zm_dmb_hls[level.zm_dmb_c.hl];
    }
    if (k == "bc_pscale")
    {
        return "^3x" + level.zm_dmb_pscales[level.zm_dmb_c.pscale];
    }
    if (k == "bc_name")
    {
        return "^3" + level.zm_dmb_names[level.zm_dmb_c.name];
    }
    level.zm_dbt_a = getsubstr(k, 3, k.size);
    if (isdefined(level.zm_dmb_c.ab[level.zm_dbt_a]))
    {
        return zm_dmb_onoff(level.zm_dmb_c.ab[level.zm_dbt_a]);
    }
    return "";
}

zm_dmb_run(a, v)
{
    if (a == "base")
    {
        level.zm_dbr_t = zm_dmb_types();
        if (level.zm_dbr_t.size == 0)
        {
            return "^1no enemies loaded here yet";
        }
        level.zm_dbr_k = 0;
        for (level.zm_dbr_i = 0; level.zm_dbr_i < level.zm_dbr_t.size; level.zm_dbr_i++)
        {
            if (level.zm_dbr_t[level.zm_dbr_i] == level.zm_dmb_c.base)
            {
                level.zm_dbr_k = level.zm_dbr_i + 1;
                break;
            }
        }
        level.zm_dmb_c.base = level.zm_dbr_t[level.zm_dbr_k % level.zm_dbr_t.size];
        return "boss base: " + zm_dmb_short(level.zm_dmb_c.base);
    }
    if (a == "setbase")
    {
        level.zm_dmb_c.base = v;
        return "boss base: " + zm_dmb_short(v);
    }
    if (a == "hp")
    {
        level.zm_dmb_c.hp = (level.zm_dmb_c.hp + 1) % level.zm_dmb_hps.size;
        return "boss health x" + level.zm_dmb_hps[level.zm_dmb_c.hp];
    }
    if (a == "speed")
    {
        level.zm_dmb_c.speed = (level.zm_dmb_c.speed + 1) % level.zm_dmb_speeds.size;
        return "boss speed " + level.zm_dmb_speeds[level.zm_dmb_c.speed];
    }
    if (a == "fx1" || a == "fx2")
    {
        // cycle the quick presets
        level.zm_dbr_cur = level.zm_dmb_c.fx1;
        if (a == "fx2")
        {
            level.zm_dbr_cur = level.zm_dmb_c.fx2;
        }
        level.zm_dbr_k = 0;
        for (level.zm_dbr_i = 0; level.zm_dbr_i < level.zm_dmb_fxp.size; level.zm_dbr_i++)
        {
            if (level.zm_dmb_fxp[level.zm_dbr_i] == level.zm_dbr_cur)
            {
                level.zm_dbr_k = level.zm_dbr_i + 1;
                break;
            }
        }
        level.zm_dbr_new = level.zm_dmb_fxp[level.zm_dbr_k % level.zm_dmb_fxp.size];
        if (a == "fx1")
        {
            level.zm_dmb_c.fx1 = level.zm_dbr_new;
        }
        else
        {
            level.zm_dmb_c.fx2 = level.zm_dbr_new;
        }
        return "boss effect " + getsubstr(a, 2, 3) + ": " + zm_dmb_fxlabel(level.zm_dbr_new);
    }
    if (a == "setfx1" || a == "setfx2")
    {
        // any loaded effect, from the Boss effects page
        if (a == "setfx1")
        {
            level.zm_dmb_c.fx1 = v;
        }
        else
        {
            level.zm_dmb_c.fx2 = v;
        }
        return "boss effect: " + v;
    }
    if (a == "model")
    {
        // cycle through the props the map uses ("" = its own body first)
        if (isdefined(level.zm_dm_props_fn))
        {
            [[ level.zm_dm_props_fn ]]();
        }
        if (!isdefined(level.zm_dm_mprops) || level.zm_dm_mprops.size == 0)
        {
            return "^1no props found on this map";
        }
        level.zm_dbr_k = 0;
        for (level.zm_dbr_i = 0; level.zm_dbr_i < level.zm_dm_mprops.size; level.zm_dbr_i++)
        {
            if (level.zm_dm_mprops[level.zm_dbr_i] == level.zm_dmb_c.model)
            {
                level.zm_dbr_k = level.zm_dbr_i + 1;
                break;
            }
        }
        if (level.zm_dbr_k >= level.zm_dm_mprops.size)
        {
            level.zm_dmb_c.model = "";
            return "boss look: its own body";
        }
        level.zm_dmb_c.model = level.zm_dm_mprops[level.zm_dbr_k];
        return "boss look: " + level.zm_dmb_c.model;
    }
    if (a == "setmodel")
    {
        level.zm_dmb_c.model = v;
        if (v == "none")
        {
            level.zm_dmb_c.model = "";
        }
        return "boss look: " + v;
    }
    if (a == "hl")
    {
        level.zm_dmb_c.hl = (level.zm_dmb_c.hl + 1) % level.zm_dmb_hls.size;
        return "boss highlight " + level.zm_dmb_hls[level.zm_dmb_c.hl];
    }
    if (a == "pscale")
    {
        level.zm_dmb_c.pscale = (level.zm_dmb_c.pscale + 1) % level.zm_dmb_pscales.size;
        level.zm_dmb_ps = level.zm_dmb_pscales[level.zm_dmb_c.pscale];
        // live: resize the prop bodies of bosses already out
        for (level.zm_dbz_i = 0; level.zm_dbz_i < level.zm_dmb_bosses.size; level.zm_dbz_i++)
        {
            level.zm_dbz_b = level.zm_dmb_bosses[level.zm_dbz_i];
            if (isdefined(level.zm_dbz_b) && isdefined(level.zm_dbz_b.zm_dmb) && isdefined(level.zm_dbz_b.zm_dmb.prop))
            {
                level.zm_dbz_b.zm_dmb.prop setscale(level.zm_dmb_ps);
            }
        }
        return "prop size x" + level.zm_dmb_ps;
    }
    if (a == "name")
    {
        level.zm_dmb_c.name = (level.zm_dmb_c.name + 1) % level.zm_dmb_names.size;
        return "boss name: " + level.zm_dmb_names[level.zm_dmb_c.name];
    }
    if (isdefined(level.zm_dmb_c.ab[a]))
    {
        level.zm_dmb_c.ab[a] = 1 - level.zm_dmb_c.ab[a];
        return "boss ability " + a + " " + zm_dmb_onoff(level.zm_dmb_c.ab[a]);
    }
    if (a == "spawn")
    {
        return self zm_dmb_spawn();
    }
    if (a == "kill")
    {
        return "removed " + zm_dmb_kill_all() + " custom bosses";
    }
    if (a == "save")
    {
        nengine_store_set("devmenu", "boss_" + v, zm_dmb_pack());
        nengine_store_save("devmenu", "settings");
        return "boss saved to slot " + v;
    }
    if (a == "load")
    {
        level.zm_dbr_s = nengine_store_get("devmenu", "boss_" + v);
        if (!isdefined(level.zm_dbr_s) || !isstring(level.zm_dbr_s) || level.zm_dbr_s == "")
        {
            return "^1slot " + v + " is empty";
        }
        zm_dmb_unpack(level.zm_dbr_s);
        return "boss loaded from slot " + v + ": " + level.zm_dmb_names[level.zm_dmb_c.name];
    }
    if (a == "spawnslot")
    {
        level.zm_dbr_m = self zm_dmb_run("load", v);
        if (getsubstr(level.zm_dbr_m, 0, 1) == "^")
        {
            return level.zm_dbr_m;
        }
        return self zm_dmb_spawn();
    }
    if (a == "reset")
    {
        zm_dmb_cfg_default();
        return "boss creator reset";
    }
    return "unknown boss action " + a;
}

// base|hp|speed|fx1|fx2|name|min|tp|shock|light|met|heal|rage
zm_dmb_pack()
{
    level.zm_dbp_s = level.zm_dmb_c.base + "|" + level.zm_dmb_c.hp + "|" + level.zm_dmb_c.speed + "|" + level.zm_dmb_c.fx1 + "|" + level.zm_dmb_c.fx2 + "|" + level.zm_dmb_c.name;
    level.zm_dbp_k = strtok("min tp shock light met heal rage", " ");
    for (level.zm_dbp_i = 0; level.zm_dbp_i < level.zm_dbp_k.size; level.zm_dbp_i++)
    {
        level.zm_dbp_s = level.zm_dbp_s + "|" + level.zm_dmb_c.ab[level.zm_dbp_k[level.zm_dbp_i]];
    }
    level.zm_dbp_m = level.zm_dmb_c.model;
    if (level.zm_dbp_m == "")
    {
        level.zm_dbp_m = "none";
    }
    return level.zm_dbp_s + "|" + level.zm_dbp_m + "|" + level.zm_dmb_c.pscale + "|" + level.zm_dmb_c.hl;
}

zm_dmb_unpack(s)
{
    level.zm_dbu_f = strtok(s, "|");
    if (level.zm_dbu_f.size < 13)
    {
        return;
    }
    level.zm_dmb_c.base = level.zm_dbu_f[0];
    level.zm_dmb_c.hp = int(level.zm_dbu_f[1]);
    level.zm_dmb_c.speed = int(level.zm_dbu_f[2]);
    level.zm_dmb_c.fx1 = level.zm_dbu_f[3];
    level.zm_dmb_c.fx2 = level.zm_dbu_f[4];
    level.zm_dmb_c.name = int(level.zm_dbu_f[5]) % level.zm_dmb_names.size;
    level.zm_dbu_k = strtok("min tp shock light met heal rage", " ");
    for (level.zm_dbu_i = 0; level.zm_dbu_i < level.zm_dbu_k.size; level.zm_dbu_i++)
    {
        level.zm_dmb_c.ab[level.zm_dbu_k[level.zm_dbu_i]] = int(level.zm_dbu_f[6 + level.zm_dbu_i]);
    }
    level.zm_dmb_c.model = "";
    if (level.zm_dbu_f.size > 13 && level.zm_dbu_f[13] != "none")
    {
        level.zm_dmb_c.model = level.zm_dbu_f[13];
    }
    level.zm_dmb_c.hl = 0;
    if (level.zm_dbu_f.size > 15)
    {
        level.zm_dmb_c.hl = int(level.zm_dbu_f[15]) % level.zm_dmb_hls.size;
    }
    level.zm_dmb_c.pscale = 0;
    if (level.zm_dbu_f.size > 14)
    {
        level.zm_dmb_c.pscale = int(level.zm_dbu_f[14]) % level.zm_dmb_pscales.size;
    }
}

// self = player: the boss 400 units in front, with the current settings
zm_dmb_spawn()
{
    if (level.zm_dmb_c.base == "")
    {
        level.zm_dbs_t = zm_dmb_types();
        if (level.zm_dbs_t.size == 0)
        {
            return "^1no enemies loaded here yet";
        }
        level.zm_dmb_c.base = level.zm_dbs_t[0];
    }
    self.zm_dmb_a = self getplayerangles();
    self.zm_dmb_pos = self.origin + anglestoforward((0, self.zm_dmb_a[1], 0)) * 400;
    self.zm_dmb_ai = namespace_85d424ad210ad4c9::function_35dc52fde01c4d08(level.zm_dmb_c.base, self.zm_dmb_pos, (0, self.zm_dmb_a[1] + 180, 0), "axis");
    if (!isdefined(self.zm_dmb_ai))
    {
        return "^1" + zm_dmb_short(level.zm_dmb_c.base) + " can't spawn here right now";
    }
    self.zm_dmb_ai.zm_dmb = spawnstruct();
    self.zm_dmb_ai.zm_dmb.name = level.zm_dmb_names[level.zm_dmb_c.name];
    self.zm_dmb_ai.zm_dmb.fx1 = level.zm_dmb_c.fx1;
    self.zm_dmb_ai.zm_dmb.fx2 = level.zm_dmb_c.fx2;
    self.zm_dmb_ai.zm_dmb.ab = [];
    level.zm_dbs_k = strtok("min tp shock light met heal rage", " ");
    for (level.zm_dbs_i = 0; level.zm_dbs_i < level.zm_dbs_k.size; level.zm_dbs_i++)
    {
        self.zm_dmb_ai.zm_dmb.ab[level.zm_dbs_k[level.zm_dbs_i]] = level.zm_dmb_c.ab[level.zm_dbs_k[level.zm_dbs_i]];
    }
    self.zm_dmb_ai.zm_dmb.target = self;
    self.zm_dmb_ai.zm_dmb.rage = 0;
    // health x multiplier
    if (isdefined(self.zm_dmb_ai.maxhealth) && self.zm_dmb_ai.maxhealth > 0)
    {
        self.zm_dmb_ai.maxhealth = int(min(self.zm_dmb_ai.maxhealth * level.zm_dmb_hps[level.zm_dmb_c.hp], 2000000000));
        self.zm_dmb_ai.health = self.zm_dmb_ai.maxhealth;
    }
    self.zm_dmb_ai.zm_dmb.maxhp = self.zm_dmb_ai.health;
    if (level.zm_dmb_c.speed > 0)
    {
        self.zm_dmb_ai namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0(level.zm_dmb_speeds[level.zm_dmb_c.speed], "phantom_boss", 100);
    }
    if (level.zm_dmb_c.model != "")
    {
        // prop body: the enemy is hidden and the prop rides on it
        self.zm_dmb_ai.zm_dmb.prop = spawn("script_model", self.zm_dmb_ai.origin);
        self.zm_dmb_ai.zm_dmb.prop setmodel(level.zm_dmb_c.model);
        self.zm_dmb_ai.zm_dmb.prop setscale(level.zm_dmb_pscales[level.zm_dmb_c.pscale]);
        self.zm_dmb_ai.zm_dmb.prop.angles = self.zm_dmb_ai.angles;
        self.zm_dmb_ai.zm_dmb.prop linkto(self.zm_dmb_ai);
        self.zm_dmb_ai hide();
        self.zm_dmb_ai.zm_dmb.prop.zm_owner = self.zm_dmb_ai;
        if (!isdefined(level.zm_dmb_allprops))
        {
            level.zm_dmb_allprops = [];
        }
        level.zm_dmb_allprops[level.zm_dmb_allprops.size] = self.zm_dmb_ai.zm_dmb.prop;
    }
    // its name floating above it (HUD text that follows the boss, like the game's waypoints)
    self.zm_dmb_ai.zm_dmb.tag = undefined;
    // floating name label: off by default (BO7 does not draw HUD text on a followed entity)
    if (zm_dmb_num("boss_tag_on", 0) == 1)
    {
        self zm_dmb_make_tag(self.zm_dmb_ai);
    }
    level.zm_dmb_bosses[level.zm_dmb_bosses.size] = self.zm_dmb_ai;
    // highlight: coloured outline through walls on the boss (or on its prop body)
    if (level.zm_dmb_hls[level.zm_dmb_c.hl] != "off")
    {
        self.zm_dmb_ai.zm_dmb.olent = self.zm_dmb_ai;
        if (isdefined(self.zm_dmb_ai.zm_dmb.prop))
        {
            self.zm_dmb_ai.zm_dmb.olent = self.zm_dmb_ai.zm_dmb.prop;
        }
        self.zm_dmb_ai.zm_dmb.olid = namespace_ba924364166f1600::function_a274c8bc03853643(self.zm_dmb_ai.zm_dmb.olent, self, "outline_nodepth_" + level.zm_dmb_hls[level.zm_dmb_c.hl], "level_script");
        zm_dmb_dbg("boss_outline", "" + isdefined(self.zm_dmb_ai.zm_dmb.olid));
    }
    self.zm_dmb_ai thread zm_dmb_life();
    zm_dmb_count("boss_spawned");
    return "^1" + self.zm_dmb_ai.zm_dmb.name + "^7 has appeared!";
}

zm_dmb_count(k)
{
    if (!isdefined(level.zm_dmb_counts))
    {
        level.zm_dmb_counts = [];
    }
    if (!isdefined(level.zm_dmb_counts[k]))
    {
        level.zm_dmb_counts[k] = 0;
    }
    level.zm_dmb_counts[k]++;
    zm_dmb_dbg(k, level.zm_dmb_counts[k]);
}

zm_dmb_fx(name, pos, t)
{
    if (isdefined(name) && name != "none" && isdefined(level.zm_dmz_fxat))
    {
        [[ level.zm_dmz_fxat ]](name, pos, t);
    }
}

// self = boss: effects, health bar, abilities until it dies
zm_dmb_life()
{
    self.zm_dmb.t = 0;
    self.zm_dmb_prop = self.zm_dmb.prop;
    level.zm_dmb_lastpos = self.origin;
    while (isdefined(self) && isalive(self))
    {
        self zm_dmb_tick();
        level.zm_dmb_lastpos = self.origin;
        wait 0.5;
    }
    zm_dmb_death();
}

zm_dmb_tick()
{
    self.zm_dmb.t++;
    // effects follow the boss
    if (self.zm_dmb.t % 2 == 0)
    {
        zm_dmb_fx(self.zm_dmb.fx1, self.origin + (0, 0, 40), 1);
        zm_dmb_fx(self.zm_dmb.fx2, self.origin + (0, 0, 70), 1);
    }
    // health bar at the top of the screen (the add-on's HUD line)
    self.zm_dmb.pct = 100;
    if (isdefined(self.zm_dmb.maxhp) && self.zm_dmb.maxhp > 0 && isdefined(self.health))
    {
        self.zm_dmb.pct = int(self.health * 100 / self.zm_dmb.maxhp);
    }
    if (getdvar(@"phantom_menu_lua") == "1")
    {
        setdvar(@"phantom_boss", self.zm_dmb.name + "|" + self.zm_dmb.pct);
    }
    else
    {
        setdvar(@"phantom_hud", self.zm_dmb.name + "  " + self.zm_dmb.pct + "%");
    }
    // rage below half health: sprint + abilities twice as often
    if (self.zm_dmb.ab["rage"] && !self.zm_dmb.rage && self.zm_dmb.pct < 50)
    {
        self.zm_dmb.rage = 1;
        self namespace_56fb43fc0b6ee43e::function_a8ce00e0448cb6f0("sprint", "phantom_boss", 100);
        zm_dmb_fx("shatterblast_explosion_effect_100", self.origin, 2);
        earthquake(0.3, 1, self.origin, 1500);
        if (isdefined(level.zm_dm_tell_fn))
        {
            [[ level.zm_dm_tell_fn ]]("^1" + self.zm_dmb.name + " is ENRAGED!");
        }
        zm_dmb_count("boss_rage");
    }
    self.zm_dmb.gap = 12;
    if (self.zm_dmb.rage)
    {
        self.zm_dmb.gap = 6;
    }
    if (self.zm_dmb.t % self.zm_dmb.gap == 0)
    {
        self zm_dmb_ability();
    }
}

// self = boss: one random ability that is switched on
zm_dmb_ability()
{
    self.zm_dmb.list = [];
    self.zm_dmb.k = strtok("min tp shock light met heal", " ");
    for (self.zm_dmb.i = 0; self.zm_dmb.i < self.zm_dmb.k.size; self.zm_dmb.i++)
    {
        if (self.zm_dmb.ab[self.zm_dmb.k[self.zm_dmb.i]])
        {
            self.zm_dmb.list[self.zm_dmb.list.size] = self.zm_dmb.k[self.zm_dmb.i];
        }
    }
    if (self.zm_dmb.list.size == 0)
    {
        return;
    }
    self.zm_dmb.p = self.zm_dmb.target;
    if (!isdefined(self.zm_dmb.p) || !isalive(self.zm_dmb.p))
    {
        return;
    }
    self.zm_dmb.pick = self.zm_dmb.list[randomint(self.zm_dmb.list.size)];
    zm_dmb_count("boss_ab_" + self.zm_dmb.pick);
    if (self.zm_dmb.pick == "min")
    {
        self zm_dmb_minions();
    }
    else if (self.zm_dmb.pick == "tp")
    {
        // appears right behind you
        zm_dmb_fx("aether_shroud_teleport", self.origin + (0, 0, 30), 2);
        self.zm_dmb.pa = self.zm_dmb.p getplayerangles();
        self forceteleport(self.zm_dmb.p.origin - anglestoforward((0, self.zm_dmb.pa[1], 0)) * 150, (0, self.zm_dmb.pa[1], 0));
        zm_dmb_fx("aether_shroud_teleport", self.origin + (0, 0, 30), 2);
    }
    else if (self.zm_dmb.pick == "shock")
    {
        zm_dmb_fx("shatterblast_explosion_effect_100", self.origin, 2);
        earthquake(0.4, 0.8, self.origin, 900);
        if (distance(self.origin, self.zm_dmb.p.origin) < 350)
        {
            self.zm_dmb.away = vectornormalize(self.zm_dmb.p.origin - self.origin);
            self.zm_dmb.p setvelocity(self.zm_dmb.away * 600 + (0, 0, 380));
            self.zm_dmb.p dodamage(30, self.origin);
        }
    }
    else if (self.zm_dmb.pick == "light" || self.zm_dmb.pick == "met")
    {
        level thread zm_dmb_strike(self.zm_dmb.p.origin, self.zm_dmb.pick, self.zm_dmb.p);
    }
    else if (self.zm_dmb.pick == "heal")
    {
        self.health = int(min(self.zm_dmb.maxhp, self.health + self.zm_dmb.maxhp * 0.08));
        zm_dmb_fx("aether_energy_trail", self.origin + (0, 0, 50), 2);
    }
}

// a strike lands where you stood 1 s ago (move!)
zm_dmb_strike(pos, kind, p)
{
    level.zm_dmb_sp = pos;
    level.zm_dmb_sk = kind;
    level.zm_dmb_spl = p;
    zm_dmb_fx("dark_flare_impact_effect", level.zm_dmb_sp, 1);
    wait 1;
    if (level.zm_dmb_sk == "light")
    {
        zm_dmb_fx("lightning_strike", level.zm_dmb_sp, 3);
    }
    else
    {
        zm_dmb_fx("vfx_sat_gameplay_zm_weapons_fld_wf_wild_fire_ball_explo", level.zm_dmb_sp, 3);
    }
    earthquake(0.25, 0.5, level.zm_dmb_sp, 600);
    if (isdefined(level.zm_dmb_spl) && isalive(level.zm_dmb_spl) && distance(level.zm_dmb_spl.origin, level.zm_dmb_sp) < 150)
    {
        level.zm_dmb_spl dodamage(40, level.zm_dmb_sp);
    }
}

// self = boss: 3 helpers of a normal enemy type around it
zm_dmb_minions()
{
    level.zm_dbm_t = zm_dmb_types();
    level.zm_dbm_pick = "";
    for (level.zm_dbm_i = 0; level.zm_dbm_i < level.zm_dbm_t.size; level.zm_dbm_i++)
    {
        if (issubstr(level.zm_dbm_t[level.zm_dbm_i], "base") && !issubstr(level.zm_dbm_t[level.zm_dbm_i], "boss"))
        {
            level.zm_dbm_pick = level.zm_dbm_t[level.zm_dbm_i];
            break;
        }
    }
    if (level.zm_dbm_pick == "" && level.zm_dbm_t.size > 0)
    {
        level.zm_dbm_pick = level.zm_dbm_t[randomint(level.zm_dbm_t.size)];
    }
    if (level.zm_dbm_pick == "")
    {
        return;
    }
    zm_dmb_fx("shadow_vortex_warp_air_fx", self.origin + (0, 0, 40), 2);
    for (level.zm_dbm_i = 0; level.zm_dbm_i < 3; level.zm_dbm_i++)
    {
        level.zm_dbm_pos = self.origin + anglestoforward((0, level.zm_dbm_i * 120, 0)) * 120;
        namespace_85d424ad210ad4c9::function_35dc52fde01c4d08(level.zm_dbm_pick, level.zm_dbm_pos, (0, 0, 0), "axis");
    }
}

zm_dmb_death()
{
    level thread zm_dmb_tags_cleanup();
    setdvar(@"phantom_hud", "");
    setdvar(@"phantom_boss", "");
    zm_dmb_fx("shatterblast_explosion_effect_100", level.zm_dmb_lastpos, 2);
    level thread zm_dmb_props_cleanup();
    zm_dmb_count("boss_killed");
}

zm_dmb_kill_all()
{
    level.zm_dbk_n = 0;
    for (level.zm_dbk_i = 0; level.zm_dbk_i < level.zm_dmb_bosses.size; level.zm_dbk_i++)
    {
        if (isdefined(level.zm_dmb_bosses[level.zm_dbk_i]) && isalive(level.zm_dmb_bosses[level.zm_dbk_i]))
        {
            if (isdefined(level.zm_dmb_bosses[level.zm_dbk_i].zm_dmb) && isdefined(level.zm_dmb_bosses[level.zm_dbk_i].zm_dmb.tag))
            {
                level.zm_dmb_bosses[level.zm_dbk_i].zm_dmb.tag destroy();
                level.zm_dmb_bosses[level.zm_dbk_i].zm_dmb.tag = undefined;
            }
            level.zm_dmb_bosses[level.zm_dbk_i] kill();
            level.zm_dbk_n++;
        }
    }
    level.zm_dmb_bosses = [];
    setdvar(@"phantom_hud", "");
    setdvar(@"phantom_boss", "");
    level thread zm_dmb_prop_sweep_later();
    return level.zm_dbk_n;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmb_init_is_zombies()
{
    level.zm_dmb_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmb_gt) || level.zm_dmb_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmb_gt, 0, 2) == "zm";
}

// remove prop bodies of bosses that are gone
zm_dmb_props_cleanup()
{
    wait 1.5;
    for (level.zm_dbc_i = 0; level.zm_dbc_i < level.zm_dmb_bosses.size; level.zm_dbc_i++)
    {
        level.zm_dbc_b = level.zm_dmb_bosses[level.zm_dbc_i];
        if (isdefined(level.zm_dbc_b) && isalive(level.zm_dbc_b))
        {
            continue;
        }
        if (isdefined(level.zm_dbc_b) && isdefined(level.zm_dbc_b.zm_dmb) && isdefined(level.zm_dbc_b.zm_dmb.prop))
        {
            level.zm_dbc_b.zm_dmb.prop delete();
        }
    }
    zm_dmb_prop_sweep();
}

// props whose boss entity is already deleted
zm_dmb_prop_sweep()
{
    if (!isdefined(level.zm_dmb_allprops))
    {
        return;
    }
    for (level.zm_dbw_i = 0; level.zm_dbw_i < level.zm_dmb_allprops.size; level.zm_dbw_i++)
    {
        level.zm_dbw_p = level.zm_dmb_allprops[level.zm_dbw_i];
        if (isdefined(level.zm_dbw_p) && (!isdefined(level.zm_dbw_p.zm_owner) || !isalive(level.zm_dbw_p.zm_owner)))
        {
            level.zm_dbw_p delete();
        }
    }
}

zm_dmb_prop_sweep_later()
{
    wait 1;
    zm_dmb_prop_sweep();
}

zm_dmb_num(key, def)
{
    level.zm_dbn_v = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dbn_v) || (isstring(level.zm_dbn_v) && level.zm_dbn_v == ""))
    {
        return def;
    }
    if (isstring(level.zm_dbn_v))
    {
        return float(level.zm_dbn_v);
    }
    return level.zm_dbn_v;
}

// self = player, b = boss: red name label that follows the boss (setting boss_tag 0 = off,
// boss_tag_z height above its feet, default 110)
zm_dmb_make_tag(b)
{
    zm_dmb_dbg("boss_tag", "1 start");
    nengine_store_save("devmenu_dbg", "state");
    self.zm_dbt_e = newclienthudelem(self);
    zm_dmb_dbg("boss_tag", "2 elem " + isdefined(self.zm_dbt_e));
    nengine_store_save("devmenu_dbg", "state");
    if (!isdefined(self.zm_dbt_e))
    {
        zm_dmb_dbg("boss_tag", "no hud element");
        return;
    }
    self.zm_dbt_e.alignx = "center";
    self.zm_dbt_e.aligny = "middle";
    self.zm_dbt_e.foreground = 1;
    self.zm_dbt_e.hidewheninmenu = 1;
    self.zm_dbt_e.archived = 0;
    self.zm_dbt_e.font = "default";
    self.zm_dbt_e.fontscale = 1.4;
    self.zm_dbt_e.color = (1, 0.25, 0.25);
    self.zm_dbt_e.alpha = 1;
    self.zm_dbt_e.x = 0;
    self.zm_dbt_e.y = 0;
    self.zm_dbt_e.z = zm_dmb_num("boss_tag_z", 110);
    self.zm_dbt_e settext(nengine_text(b.zm_dmb.name));
    zm_dmb_dbg("boss_tag", "3 text");
    nengine_store_save("devmenu_dbg", "state");
    self.zm_dbt_e settargetent(b);
    zm_dmb_dbg("boss_tag", "4 target");
    nengine_store_save("devmenu_dbg", "state");
    self.zm_dbt_e setwaypoint(1, 1, 0, 0);
    zm_dmb_dbg("boss_tag", "5 waypoint");
    nengine_store_save("devmenu_dbg", "state");
    b.zm_dmb.tag = self.zm_dbt_e;
    zm_dmb_dbg("boss_tag", "made for " + b.zm_dmb.name);
}

// remove name labels of bosses that are gone
zm_dmb_tags_cleanup()
{
    for (level.zm_dtc_i = 0; level.zm_dtc_i < level.zm_dmb_bosses.size; level.zm_dtc_i++)
    {
        level.zm_dtc_b = level.zm_dmb_bosses[level.zm_dtc_i];
        if (isdefined(level.zm_dtc_b) && isalive(level.zm_dtc_b))
        {
            continue;
        }
        if (isdefined(level.zm_dtc_b) && isdefined(level.zm_dtc_b.zm_dmb) && isdefined(level.zm_dtc_b.zm_dmb.tag))
        {
            level.zm_dtc_b.zm_dmb.tag destroy();
            level.zm_dtc_b.zm_dmb.tag = undefined;
        }
    }
}
