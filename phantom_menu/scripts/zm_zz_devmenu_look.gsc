// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_look - Phantom menu looks: operator skins and weapon camos.
// The game's loot table turns loot ID numbers into item names
// (namespace_952965bfef60cff8::function_f54ecb89dfab8e8c, the same call the game's own saved
// builds use), so the menu finds every camo / operator skin by itself each match.
// Reached from the main menu with action "look <action> [value]" (level.zm_dml_run).
// State on level / player fields (Kronos GSC loses locals after calls and waits).

#using scripts\common\utility;
#using scripts\common\weapon;
#using script_1ade2fa7cae9593d;
#using script_2dc447b1dd033a26;

autoexec zm_dml_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dml_init_is_zombies())
    {
        return;
    }
    level.zm_dml_run = &zm_dml_run;
    level.zm_dml_scan_fn = &zm_dml_scan;
    level.zm_dml_skin_label_fn = &zm_dml_skin_label;
    level.zm_dml_op_label_fn = &zm_dml_op_label;
    level thread zm_dml_keep_loop();
    level thread zm_dml_scan_later();
}

// loot scan in the background once the player is in (pages show "scanning" until it is done)
zm_dml_scan_later()
{
    while (!isdefined(level.players) || level.players.size < 1)
    {
        wait 1;
    }
    wait 6;
    zm_dml_scan();
}

zm_dml_run(a, v)
{
    self.zm_dml_v = v;
    if (a == "skin")
    {
        // apply operator skin by loot id, remembered for respawns / next matches
        self zm_dml_apply_skin(int(v));
        if (self.zm_dml_applied)
        {
            nengine_store_set("devmenu", "look_skin", int(v));
            nengine_store_save("devmenu", "settings");
            return "operator skin: " + zm_dml_skin_label(namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(int(v)));
        }
        return "^1this skin can't be used here";
    }
    if (a == "skinrandom")
    {
        zm_dml_scan();
        if (level.zm_dml_skin_ids.size == 0)
        {
            return "^1no operator skins found";
        }
        return self zm_dml_run("skin", "" + level.zm_dml_skin_ids[randomint(level.zm_dml_skin_ids.size)]);
    }
    if (a == "skinreset")
    {
        nengine_store_set("devmenu", "look_skin", 0);
        nengine_store_save("devmenu", "settings");
        if (isdefined(self.zm_dml_orig_skin) && self.zm_dml_orig_skin > 0)
        {
            self zm_dml_apply_skin(self.zm_dml_orig_skin);
        }
        return "back to your own operator";
    }
    if (a == "camo")
    {
        self.zm_dml_camo_ref = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(int(v));
        self thread zm_dml_camo_worker();
        return "camo " + self.zm_dml_camo_ref + " ...";
    }
    if (a == "camonone")
    {
        self.zm_dml_camo_ref = "camo_none";
        self thread zm_dml_camo_worker();
        return "removing camo ...";
    }
    if (a == "camorandom")
    {
        zm_dml_scan();
        if (level.zm_dml_camo_ids.size == 0)
        {
            return "^1no camos found";
        }
        self.zm_dml_camo_ref = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dml_camo_ids[randomint(level.zm_dml_camo_ids.size)]);
        self thread zm_dml_camo_worker();
        return "random camo " + self.zm_dml_camo_ref + " ...";
    }
    if (a == "skincycle")
    {
        // a random operator skin every look_cycle seconds (1)
        level.zm_dml_skincyc = 1 - zm_dml_flag(level.zm_dml_skincyc);
        if (level.zm_dml_skincyc)
        {
            zm_dml_scan();
            self thread zm_dml_skincycle_loop();
        }
        return "random operator skins " + zm_dml_onoff(level.zm_dml_skincyc);
    }
    if (a == "camocycle")
    {
        level.zm_dml_camocyc = 1 - zm_dml_flag(level.zm_dml_camocyc);
        if (level.zm_dml_camocyc)
        {
            zm_dml_scan();
            self thread zm_dml_camocycle_loop();
        }
        return "random camos on your gun " + zm_dml_onoff(level.zm_dml_camocyc);
    }
    if (a == "bundles")
    {
        // bundle (blueprint) versions of the held gun: variant numbers the game has a bundle for
        return "bundles for this gun: " + self zm_dml_bundle_scan();
    }
    if (a == "bundle")
    {
        self.zm_dml_bvar = int(v);
        self thread zm_dml_bundle_worker();
        return "bundle " + v + " ...";
    }
    if (a == "bundlerandom")
    {
        if (self zm_dml_bundle_scan() == 0)
        {
            return "^1this gun has no bundles";
        }
        self.zm_dml_bvar = self.zm_dml_bvars[randomint(self.zm_dml_bvars.size)];
        self thread zm_dml_bundle_worker();
        return "random bundle ...";
    }
    if (a == "bundlecycle")
    {
        level.zm_dml_bcyc = 1 - zm_dml_flag(level.zm_dml_bcyc);
        if (level.zm_dml_bcyc)
        {
            self thread zm_dml_bundlecycle_loop();
        }
        return "random bundles on your gun " + zm_dml_onoff(level.zm_dml_bcyc);
    }
    if (a == "zonetry")
    {
        // experiment: ask the game to load another zone (its own loader, signed game file)
        level thread zm_dml_zonetry(v);
        return "trying to load " + v;
    }
    if (a == "lootfind")
    {
        level thread zm_dml_lootfind(v);
        return "loot search " + v;
    }
    if (a == "probe")
    {
        level thread zm_dml_probe(int(v));
        return "loot probe started";
    }
    if (a == "skins")
    {
        level thread zm_dml_skins(int(strtok(v, "-")[0]), int(strtok(v, "-")[1]));
        return "skin list started";
    }
    if (a == "tryskin")
    {
        self zm_dml_tryskin(int(v));
        return "tried skin " + v;
    }
    return "unknown look action " + a;
}

zm_dml_dbg(k, v)
{
    nengine_store_set("devmenu_dbg", k, v);
}

// debug: what the loot lookup gives back for IDs 1..n, and the player's operator data
zm_dml_probe(n)
{
    if (n <= 0)
    {
        n = 3000;
    }
    level.zm_dlp_n = n;
    level.zm_dlp_def = 0;
    level.zm_dlp_str = 0;
    level.zm_dlp_txt = "";
    level.zm_dlp_cam = 0;
    level.zm_dlp_skn = 0;
    level.zm_dlp_last = 0;
    for (level.zm_dlp_i = 1; level.zm_dlp_i <= level.zm_dlp_n; level.zm_dlp_i++)
    {
        level.zm_dlp_r = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dlp_i);
        if (isdefined(level.zm_dlp_r))
        {
            level.zm_dlp_def++;
            if (isstring(level.zm_dlp_r) && level.zm_dlp_r != "")
            {
                level.zm_dlp_str++;
                level.zm_dlp_last = level.zm_dlp_i;
                if (issubstr(level.zm_dlp_r, "camo"))
                {
                    level.zm_dlp_cam++;
                }
                if (issubstr(level.zm_dlp_r, "_skin"))
                {
                    level.zm_dlp_skn++;
                }
                if (level.zm_dlp_txt.size < 700 && (level.zm_dlp_str < 15 || (issubstr(level.zm_dlp_r, "_skin") && level.zm_dlp_skn < 12) || (issubstr(level.zm_dlp_r, "camo") && level.zm_dlp_cam < 12)))
                {
                    level.zm_dlp_txt = level.zm_dlp_txt + level.zm_dlp_i + "=" + level.zm_dlp_r + " ";
                }
            }
        }
        if (level.zm_dlp_i % 500 == 0)
        {
            waitframe();
        }
    }
    zm_dml_dbg("look_probe", "ids " + level.zm_dlp_n + " defined " + level.zm_dlp_def + " strings " + level.zm_dlp_str + " camo " + level.zm_dlp_cam + " skin " + level.zm_dlp_skn + " last " + level.zm_dlp_last);
    zm_dml_dbg("look_sample", level.zm_dlp_txt);
    level.zm_dlp_p = level.players[0];
    level.zm_dlp_o = "no operator data";
    if (isdefined(level.zm_dlp_p) && isdefined(level.zm_dlp_p.operatorcustomization))
    {
        level.zm_dlp_o = "skin string " + isstring(level.zm_dlp_p.operatorcustomization.skinref);
        if (isdefined(level.zm_dlp_p.operatorcustomization.skinref))
        {
            level.zm_dlp_o = level.zm_dlp_o + " id " + namespace_952965bfef60cff8::function_fae2e7aa6e279966(level.zm_dlp_p.operatorcustomization.skinref);
        }
    }
    level.zm_dlp_ol = operator::function_91f90d6f14a0f260();
    if (isdefined(level.zm_dlp_ol))
    {
        level.zm_dlp_o = level.zm_dlp_o + " | operators " + level.zm_dlp_ol.size;
    }
    zm_dml_dbg("look_op", level.zm_dlp_o);
    nengine_store_save("devmenu_dbg", "state");
}

// debug: every loot ref ending in _skin between two IDs -> dbg look_skins_N
zm_dml_skins(a, b)
{
    level.zm_dls_txt = "";
    level.zm_dls_part = 0;
    level.zm_dls_n = 0;
    for (level.zm_dls_i = a; level.zm_dls_i <= b; level.zm_dls_i++)
    {
        level.zm_dls_r = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dls_i);
        if (isstring(level.zm_dls_r) && issubstr(level.zm_dls_r, "_skin") && !issubstr(level.zm_dls_r, "firstparty") && !issubstr(level.zm_dls_r, "store_"))
        {
            level.zm_dls_n++;
            level.zm_dls_txt = level.zm_dls_txt + level.zm_dls_i + "=" + level.zm_dls_r + " ";
            if (level.zm_dls_txt.size > 800)
            {
                zm_dml_dbg("look_skins_" + level.zm_dls_part, level.zm_dls_txt);
                level.zm_dls_part++;
                level.zm_dls_txt = "";
            }
        }
        if (level.zm_dls_i % 500 == 0)
        {
            waitframe();
        }
    }
    zm_dml_dbg("look_skins_" + level.zm_dls_part, level.zm_dls_txt);
    zm_dml_dbg("look_skins_n", level.zm_dls_n + " in " + a + "-" + b);
    nengine_store_save("devmenu_dbg", "state");
}

// debug: apply the operator skin with loot id n (operator = skin name up to the 4th part)
zm_dml_tryskin(n)
{
    self.zm_dlt_r = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(n);
    self.zm_dlt_t = strtok(self.zm_dlt_r, "_");
    self.zm_dlt_op = self.zm_dlt_t[0] + "_" + self.zm_dlt_t[1] + "_" + self.zm_dlt_t[2] + "_" + self.zm_dlt_t[3];
    self.zm_dlt_ok = self function_41d9b8754a37a071(self.zm_dlt_r);
    self.zm_dlt_before = namespace_952965bfef60cff8::function_fae2e7aa6e279966(self.operatorcustomization.skinref);
    self operator::function_8a20b5520866f917(self.zm_dlt_op, self.zm_dlt_r);
    self.zm_dlt_after = namespace_952965bfef60cff8::function_fae2e7aa6e279966(self.operatorcustomization.skinref);
    zm_dml_dbg("look_try", self.zm_dlt_r + " op " + self.zm_dlt_op + " accepts " + self.zm_dlt_ok + " skin id " + self.zm_dlt_before + " -> " + self.zm_dlt_after);
    nengine_store_save("devmenu_dbg", "state");
}

// LOOT SCAN (once per match, on first use): every loot ID up to look_max (140000) through the
// game's loot lookup; operator skins (*_pl_*_skin the engine accepts for you) grouped by
// operator, and weapon camos (camo_*). Lists on level fields for the menu pages.
zm_dml_scan()
{
    if (isdefined(level.zm_dml_scanned))
    {
        return;
    }
    level.zm_dml_scanned = 1;
    level.zm_dml_p = level.players[0];
    level.zm_dml_ops = [];
    level.zm_dml_op_skins = [];
    level.zm_dml_skin_ids = [];
    level.zm_dml_camo_ids = [];
    level.zm_dml_max = 140000;
    for (level.zm_dsc_i = 1; level.zm_dsc_i <= level.zm_dml_max; level.zm_dsc_i++)
    {
        level.zm_dsc_r = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dsc_i);
        if (!isstring(level.zm_dsc_r) || level.zm_dsc_r == "")
        {
            if (level.zm_dsc_i % 2000 == 0)
            {
                waitframe();
            }
            continue;
        }
        if (getsubstr(level.zm_dsc_r, 0, 5) == "camo_" && level.zm_dml_camo_ids.size < 3000)
        {
            level.zm_dml_camo_ids[level.zm_dml_camo_ids.size] = level.zm_dsc_i;
        }
        else if (issubstr(level.zm_dsc_r, "_pl_") && getsubstr(level.zm_dsc_r, level.zm_dsc_r.size - 5, level.zm_dsc_r.size) == "_skin")
        {
            zm_dml_add_skin(level.zm_dsc_i, level.zm_dsc_r);
        }
        if (level.zm_dsc_i % 2000 == 0)
        {
            waitframe();
        }
    }
    level.zm_dml_ready = 1;
    zm_dml_dbg("look_scan", "operators " + level.zm_dml_ops.size + " skins " + level.zm_dml_skin_ids.size + " camos " + level.zm_dml_camo_ids.size);
}

zm_dml_add_skin(id, r)
{
    if (isdefined(level.zm_dml_p) && !level.zm_dml_p function_41d9b8754a37a071(r))
    {
        return;
    }
    level.zm_das_op = zm_dml_op_of(r);
    level.zm_das_k = -1;
    for (level.zm_das_j = 0; level.zm_das_j < level.zm_dml_ops.size; level.zm_das_j++)
    {
        if (level.zm_dml_ops[level.zm_das_j] == level.zm_das_op)
        {
            level.zm_das_k = level.zm_das_j;
            break;
        }
    }
    if (level.zm_das_k < 0)
    {
        level.zm_das_k = level.zm_dml_ops.size;
        level.zm_dml_ops[level.zm_das_k] = level.zm_das_op;
        level.zm_dml_op_skins[level.zm_das_k] = [];
    }
    level.zm_dml_op_skins[level.zm_das_k][level.zm_dml_op_skins[level.zm_das_k].size] = id;
    level.zm_dml_skin_ids[level.zm_dml_skin_ids.size] = id;
}

// operator ref of a skin: name up to the part after "pl" (sat_usa_pl_red_proto_skin -> sat_usa_pl_red)
zm_dml_op_of(r)
{
    level.zm_dmo_t = strtok(r, "_");
    level.zm_dmo_s = "";
    for (level.zm_dmo_i = 0; level.zm_dmo_i < level.zm_dmo_t.size; level.zm_dmo_i++)
    {
        if (level.zm_dmo_s != "")
        {
            level.zm_dmo_s = level.zm_dmo_s + "_";
        }
        level.zm_dmo_s = level.zm_dmo_s + level.zm_dmo_t[level.zm_dmo_i];
        if (level.zm_dmo_i > 0 && level.zm_dmo_t[level.zm_dmo_i - 1] == "pl")
        {
            return level.zm_dmo_s;
        }
    }
    return level.zm_dmo_s;
}

// "Rose - hive" style label (game prefix, country, pl and _skin removed)
zm_dml_skin_label(r)
{
    level.zm_dsl_op = zm_dml_op_of(r);
    level.zm_dsl_t = strtok(level.zm_dsl_op, "_");
    level.zm_dsl_name = level.zm_dsl_t[level.zm_dsl_t.size - 1];
    level.zm_dsl_rest = "";
    if (r.size - 5 > level.zm_dsl_op.size + 1)
    {
        level.zm_dsl_rest = zm_dml_spaces(getsubstr(r, level.zm_dsl_op.size + 1, r.size - 5));
    }
    level.zm_dsl_era = "";
    if (getsubstr(r, 0, 4) == "t10_")
    {
        level.zm_dsl_era = " (BO6)";
    }
    if (level.zm_dsl_rest == "")
    {
        return zm_dml_cap(level.zm_dsl_name) + level.zm_dsl_era;
    }
    return zm_dml_cap(level.zm_dsl_name) + " - " + level.zm_dsl_rest + level.zm_dsl_era;
}

zm_dml_op_label(op)
{
    level.zm_dol_t = strtok(op, "_");
    level.zm_dol_x = "";
    if (getsubstr(op, 0, 4) == "t10_")
    {
        level.zm_dol_x = " (BO6)";
    }
    return zm_dml_cap(level.zm_dol_t[level.zm_dol_t.size - 1]) + level.zm_dol_x;
}

zm_dml_cap(w)
{
    if (w.size == 0)
    {
        return w;
    }
    return toupper(getsubstr(w, 0, 1)) + getsubstr(w, 1, w.size);
}

zm_dml_spaces(w)
{
    level.zm_dsp_t = strtok(w, "_");
    level.zm_dsp_s = "";
    for (level.zm_dsp_i = 0; level.zm_dsp_i < level.zm_dsp_t.size; level.zm_dsp_i++)
    {
        if (level.zm_dsp_i > 0)
        {
            level.zm_dsp_s = level.zm_dsp_s + " ";
        }
        level.zm_dsp_s = level.zm_dsp_s + level.zm_dsp_t[level.zm_dsp_i];
    }
    return level.zm_dsp_s;
}

// self = player: apply skin by loot id (operator from its name); zm_dml_applied = it took
zm_dml_apply_skin(id)
{
    self.zm_dml_applied = 0;
    if (!isdefined(self.operatorcustomization) || !isdefined(self.operatorcustomization.skinref))
    {
        return;
    }
    if (!isdefined(self.zm_dml_orig_skin))
    {
        self.zm_dml_orig_skin = namespace_952965bfef60cff8::function_fae2e7aa6e279966(self.operatorcustomization.skinref);
    }
    self.zm_das_r = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(id);
    if (!isstring(self.zm_das_r) || self.zm_das_r == "" || !self function_41d9b8754a37a071(self.zm_das_r))
    {
        return;
    }
    self operator::function_8a20b5520866f917(zm_dml_op_of(self.zm_das_r), self.zm_das_r);
    self.zm_dml_applied = namespace_952965bfef60cff8::function_fae2e7aa6e279966(self.operatorcustomization.skinref) == id;
}

// keeps the chosen skin (setting look_skin) after respawns and in new matches
zm_dml_keep_loop()
{
    while (1)
    {
        wait 2;
        zm_dml_keep_tick();
    }
}

zm_dml_keep_tick()
{
    level.zm_dkt_id = int(nengine_store_get("devmenu", "look_skin"));
    if (!isdefined(level.zm_dkt_id) || level.zm_dkt_id <= 0 || !isdefined(level.players) || level.players.size < 1)
    {
        return;
    }
    level.zm_dkt_p = level.players[0];
    if (!isalive(level.zm_dkt_p) || !isdefined(level.zm_dkt_p.operatorcustomization) || !isdefined(level.zm_dkt_p.operatorcustomization.skinref))
    {
        return;
    }
    if (namespace_952965bfef60cff8::function_fae2e7aa6e279966(level.zm_dkt_p.operatorcustomization.skinref) != level.zm_dkt_id)
    {
        level.zm_dkt_p zm_dml_apply_skin(level.zm_dkt_id);
    }
}

// debug: loot refs containing a word -> dbg look_find_N
zm_dml_lootfind(w)
{
    level.zm_dlf_w = w;
    level.zm_dlf_txt = "";
    level.zm_dlf_part = 0;
    level.zm_dlf_n = 0;
    for (level.zm_dlf_i = 1; level.zm_dlf_i <= 140000; level.zm_dlf_i++)
    {
        level.zm_dlf_r = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dlf_i);
        if (isstring(level.zm_dlf_r) && issubstr(level.zm_dlf_r, level.zm_dlf_w) && level.zm_dlf_part < 8)
        {
            level.zm_dlf_n++;
            level.zm_dlf_txt = level.zm_dlf_txt + level.zm_dlf_i + "=" + level.zm_dlf_r + " ";
            if (level.zm_dlf_txt.size > 800)
            {
                zm_dml_dbg("look_find_" + level.zm_dlf_part, level.zm_dlf_txt);
                level.zm_dlf_part++;
                level.zm_dlf_txt = "";
            }
        }
        if (level.zm_dlf_i % 2000 == 0)
        {
            waitframe();
        }
    }
    zm_dml_dbg("look_find_" + level.zm_dlf_part, level.zm_dlf_txt);
    zm_dml_dbg("look_find_n", level.zm_dlf_n + " for " + level.zm_dlf_w);
    nengine_store_save("devmenu_dbg", "state");
}

zm_dml_zonetry(z)
{
    level.zm_dzt_z = z;
    zm_dml_dbg("look_zone", "asking " + level.zm_dzt_z);
    nengine_store_save("devmenu_dbg", "state");
    loadinfiltransient(level.zm_dzt_z);
    for (level.zm_dzt_i = 0; level.zm_dzt_i < 40; level.zm_dzt_i++)
    {
        wait 0.25;
        if (isinfiltransientloaded(level.zm_dzt_z))
        {
            break;
        }
    }
    zm_dml_dbg("look_zone", level.zm_dzt_z + " loaded " + isinfiltransientloaded(level.zm_dzt_z) + " raygun " + weaponexists("sat_pi_ztronraygun_mp") + " jetgun " + weaponexists("sat_lm_ztronjetgun_mp"));
    nengine_store_save("devmenu_dbg", "state");
}

// self = player: variant numbers 1..60 of the held gun that have a bundle -> self.zm_dml_bvars
zm_dml_bundle_scan()
{
    self.zm_dml_bvars = [];
    self.zm_dml_bg = self getcurrentweapon();
    if (!isdefined(self.zm_dml_bg) || isnullweapon(self.zm_dml_bg))
    {
        return 0;
    }
    self.zm_dml_broot = weapon::function_f541f60718130d5d(self.zm_dml_bg);
    if (!isdefined(self.zm_dml_broot))
    {
        return 0;
    }
    self.zm_dml_bkey = weapon::function_9312097aa84e222d(self.zm_dml_broot);
    // a real bundle: building the gun with that number stamps the number on the finished gun
    self.zm_dml_btxt = "";
    self.zm_dml_bnone16 = [];
    self.zm_dml_bz = [];
    for (self.zm_dml_bi = 0; self.zm_dml_bi < 16; self.zm_dml_bi++)
    {
        self.zm_dml_bnone16[self.zm_dml_bi] = "none";
        self.zm_dml_bz[self.zm_dml_bi] = 0;
    }
    for (self.zm_dml_bi = 1; self.zm_dml_bi <= 60; self.zm_dml_bi++)
    {
        self.zm_dml_bx = weapon::function_2374da6f1b4fad4e(self.zm_dml_bkey, self.zm_dml_bi);
        self.zm_dml_bw = weapon::function_5416d4273f081ce2(self.zm_dml_broot, self.zm_dml_bnone16, "camo_none", "none", self.zm_dml_bi, self.zm_dml_bz, "charm_none", ["sticker_none", "sticker_none", "sticker_none", "sticker_none", "sticker_none"], undefined, undefined, undefined, self.zm_dml_bx);
        if (isdefined(self.zm_dml_bw) && !isnullweapon(self.zm_dml_bw) && isdefined(self.zm_dml_bw.variantid) && self.zm_dml_bw.variantid == self.zm_dml_bi)
        {
            self.zm_dml_bvars[self.zm_dml_bvars.size] = self.zm_dml_bi;
            self.zm_dml_btxt = self.zm_dml_btxt + self.zm_dml_bi + " ";
        }
    }
    zm_dml_dbg("look_bundle_list", self.zm_dml_btxt);
    zm_dml_dbg("look_bundles", self.zm_dml_broot + ": " + self.zm_dml_bvars.size);
    return self.zm_dml_bvars.size;
}

// self = player: held gun rebuilt as bundle variant zm_dml_bvar (0 = plain) and swapped in
zm_dml_bundle_worker()
{
    if (isdefined(self.zm_dml_camo_busy))
    {
        return;
    }
    self.zm_dml_camo_busy = 1;
    self.zm_dml_cg = self getcurrentweapon();
    if (!isdefined(self.zm_dml_cg) || isnullweapon(self.zm_dml_cg))
    {
        self.zm_dml_camo_busy = undefined;
        return;
    }
    self.zm_dml_broot = weapon::function_f541f60718130d5d(self.zm_dml_cg);
    self.zm_dml_bb = undefined;
    if (self.zm_dml_bvar > 0)
    {
        self.zm_dml_bb = weapon::function_2374da6f1b4fad4e(weapon::function_9312097aa84e222d(self.zm_dml_broot), self.zm_dml_bvar);
    }
    self.zm_dml_batts = [];
    self.zm_dml_bvs = [];
    for (self.zm_dml_bi = 0; self.zm_dml_bi < 16; self.zm_dml_bi++)
    {
        self.zm_dml_batts[self.zm_dml_bi] = "none";
        self.zm_dml_bvs[self.zm_dml_bi] = 0;
    }
    self.zm_dml_cn = weapon::function_5416d4273f081ce2(self.zm_dml_broot, self.zm_dml_batts, "camo_none", "none", self.zm_dml_bvar, self.zm_dml_bvs, "charm_none", ["sticker_none", "sticker_none", "sticker_none", "sticker_none", "sticker_none"], undefined, undefined, undefined, self.zm_dml_bb);
    if (!isdefined(self.zm_dml_cn) || isnullweapon(self.zm_dml_cn))
    {
        self.zm_dml_camo_busy = undefined;
        zm_dml_dbg("look_bundle", "build failed " + self.zm_dml_bvar);
        return;
    }
    self loadweaponsforplayer([self.zm_dml_cn], 1);
    for (self.zm_dml_ct = 0; self.zm_dml_ct < 30; self.zm_dml_ct++)
    {
        if (self hasloadedviewweapons([self.zm_dml_cn]))
        {
            break;
        }
        wait 0.1;
    }
    self takeweapon(self.zm_dml_cg);
    wait 0.1;
    self giveweapon(self.zm_dml_cn, undefined, 0, -1, 0);
    self assignweaponprimaryslot(self.zm_dml_cn);
    self switchtoweapon(self.zm_dml_cn);
    self givemaxammo(self.zm_dml_cn);
    self.zm_dml_bvid = "?";
    if (isdefined(self.zm_dml_cn.variantid))
    {
        self.zm_dml_bvid = "" + self.zm_dml_cn.variantid;
    }
    self.zm_dml_bold = "?";
    if (isdefined(self.zm_dml_cg.variantid))
    {
        self.zm_dml_bold = "" + self.zm_dml_cg.variantid;
    }
    zm_dml_dbg("look_bundle", "ok " + self.zm_dml_broot + " variant " + self.zm_dml_bvar + " has " + self hasweapon(self.zm_dml_cn) + " variantid " + self.zm_dml_bold + " -> " + self.zm_dml_bvid + " bundle " + isdefined(self.zm_dml_bb));
    zm_dml_count("look_bundles_given");
    self.zm_dml_camo_busy = undefined;
}

zm_dml_bundlecycle_loop()
{
    self endon("disconnect");
    while (zm_dml_flag(level.zm_dml_bcyc))
    {
        self zm_dml_bundlecycle_step();
        wait zm_dml_cycle_t();
    }
}

zm_dml_bundlecycle_step()
{
    if (isalive(self) && !isdefined(self.zm_dml_camo_busy) && self zm_dml_bundle_scan() > 0)
    {
        self.zm_dml_bvar = self.zm_dml_bvars[randomint(self.zm_dml_bvars.size)];
        self thread zm_dml_bundle_worker();
    }
}

zm_dml_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

zm_dml_onoff(v)
{
    if (v)
    {
        return "ON";
    }
    return "OFF";
}

// seconds between random looks (setting look_cycle, default 1, never below 0.5)
zm_dml_cycle_t()
{
    level.zm_dct_v = float(nengine_store_get("devmenu", "look_cycle"));
    if (!isdefined(level.zm_dct_v) || level.zm_dct_v < 0.5)
    {
        return 1;
    }
    return level.zm_dct_v;
}

zm_dml_skincycle_loop()
{
    self endon("disconnect");
    while (zm_dml_flag(level.zm_dml_skincyc))
    {
        self zm_dml_skincycle_step();
        wait zm_dml_cycle_t();
    }
}

zm_dml_skincycle_step()
{
    if (level.zm_dml_skin_ids.size > 0 && isalive(self))
    {
        self zm_dml_apply_skin(level.zm_dml_skin_ids[randomint(level.zm_dml_skin_ids.size)]);
        zm_dml_count("look_skin_cycles");
    }
}

zm_dml_camocycle_loop()
{
    self endon("disconnect");
    while (zm_dml_flag(level.zm_dml_camocyc))
    {
        self zm_dml_camocycle_step();
        wait zm_dml_cycle_t();
    }
}

zm_dml_camocycle_step()
{
    if (level.zm_dml_camo_ids.size > 0 && isalive(self) && !isdefined(self.zm_dml_camo_busy))
    {
        self.zm_dml_camo_ref = namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dml_camo_ids[randomint(level.zm_dml_camo_ids.size)]);
        self thread zm_dml_camo_worker();
        zm_dml_count("look_camo_cycles");
    }
}

zm_dml_count(k)
{
    if (!isdefined(level.zm_dml_counts))
    {
        level.zm_dml_counts = [];
    }
    if (!isdefined(level.zm_dml_counts[k]))
    {
        level.zm_dml_counts[k] = 0;
    }
    level.zm_dml_counts[k]++;
    zm_dml_dbg(k, level.zm_dml_counts[k]);
}

// self = player: held gun rebuilt with camo zm_dml_camo_ref and swapped in
zm_dml_camo_worker()
{
    if (isdefined(self.zm_dml_camo_busy))
    {
        return;
    }
    self.zm_dml_camo_busy = 1;
    self.zm_dml_cg = self getcurrentweapon();
    if (!isdefined(self.zm_dml_cg) || isnullweapon(self.zm_dml_cg))
    {
        self.zm_dml_camo_busy = undefined;
        zm_dml_dbg("look_camo", "no gun");
        return;
    }
    self.zm_dml_cn = self.zm_dml_cg withcamo(self.zm_dml_camo_ref);
    if (!isdefined(self.zm_dml_cn) || isnullweapon(self.zm_dml_cn))
    {
        self.zm_dml_camo_busy = undefined;
        zm_dml_dbg("look_camo", "withcamo failed " + self.zm_dml_camo_ref);
        return;
    }
    self loadweaponsforplayer([self.zm_dml_cn], 1);
    for (self.zm_dml_ct = 0; self.zm_dml_ct < 30; self.zm_dml_ct++)
    {
        if (self hasloadedviewweapons([self.zm_dml_cn]))
        {
            break;
        }
        wait 0.1;
    }
    self takeweapon(self.zm_dml_cg);
    wait 0.1;
    self giveweapon(self.zm_dml_cn, undefined, 0, -1, 0);
    self assignweaponprimaryslot(self.zm_dml_cn);
    self switchtoweapon(self.zm_dml_cn);
    self givemaxammo(self.zm_dml_cn);
    zm_dml_dbg("look_camo", "ok " + self.zm_dml_camo_ref + " has " + self hasweapon(self.zm_dml_cn));
    self.zm_dml_camo_busy = undefined;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dml_init_is_zombies()
{
    level.zm_dml_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dml_init_gt) || level.zm_dml_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dml_init_gt, 0, 2) == "zm";
}
