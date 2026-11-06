// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_forge - Phantom menu Forge + Map Builder link.
// Forge: grab a map object you look at (script models / brush models), carry it in front of you,
// rotate / move it, drop it. Copy = a new prop with the same model; "save" writes a copy into the
// zm_sandbox mod (sandbox settings p1..pN), so it comes back every match and the Map Builder sees it.
// Moved ORIGINAL map objects are not saved (they reset next match).
// Map Builder link: drives zm_sandbox (store "sandbox") and zm_zmap (store "zmap") settings.
// All state on level / player fields (Kronos GSC loses locals after calls / waits).

// game outline system (enable for one player / disable)
#using script_7af4b8f37e520205;

autoexec zm_dmf_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmf_init_is_zombies())
    {
        return;
    }
    level.zm_dmf_run = &zm_dmf_run;
    level.zm_dmf_saved = [];
    nengine_store_set("devmenu_dbg", "forge", "linked");
}

// self = player. a = action, v = value string. Returns a message.
zm_dmf_run(a, v)
{
    self.zm_dmf_a = a;
    self.zm_dmf_v = v;
    // ---------------- Forge
    if (a == "aimgrab")
    {
        self.zm_dmf_aim = 1 - zm_dmf_flag(self.zm_dmf_aim);
        if (self.zm_dmf_aim)
        {
            self zm_dmf_aim_start();
            return "aim grab ON - aim at an object to pick it up, stop aiming to drop it";
        }
        self zm_dmf_outline_clear();
        return "aim grab OFF";
    }
    if (a == "spawnmodel")
    {
        // Map props page: a new copy of any model the map uses, held in front of you like Copy
        if (isdefined(self.zm_dmf_held))
        {
            return "^1place what you're holding first";
        }
        self.zm_dmf_pa0 = self getplayerangles();
        self.zm_dmf_new = spawn("script_model", self geteye() + anglestoforward(self.zm_dmf_pa0) * 200);
        self.zm_dmf_new setmodel(self.zm_dmf_v);
        self.zm_dmf_new.angles = (0, self.zm_dmf_pa0[1], 0);
        self.zm_dmf_new.zm_dmf_model = self.zm_dmf_v;
        self.zm_dmf_held = self.zm_dmf_new;
        self.zm_dmf_held_copy = 1;
        self.zm_dmf_dist = 200;
        self.zm_dmf_zoff = 0;
        self.zm_dmf_ang = self.zm_dmf_held.angles;
        self.zm_dmf_yaw0 = self.zm_dmf_pa0[1];
        self thread zm_dmf_hold_loop();
        zm_dmf_count("forge_spawned");
        return "spawned " + self.zm_dmf_v + " - look around to move it, then Place or Save (Forge page)";
    }
    if (a == "grab" || a == "copy")
    {
        if (isdefined(self.zm_dmf_held))
        {
            return "^1place what you're holding first";
        }
        self.zm_dmf_t = self zm_dmf_look();
        if (!isdefined(self.zm_dmf_t))
        {
            return "^1no movable object where you're looking";
        }
        self.zm_dmf_isbrush = 0;
        if (isdefined(self.zm_dmf_t.classname) && self.zm_dmf_t.classname == "script_brushmodel")
        {
            self.zm_dmf_isbrush = 1;
        }
        if (a == "copy")
        {
            if (self.zm_dmf_isbrush || !isdefined(self.zm_dmf_t.model) || self.zm_dmf_t.model == "" || issubstr(self.zm_dmf_t.model, "*"))
            {
                return "^1this object can't be copied (no model name)";
            }
            self.zm_dmf_new = spawn("script_model", self.zm_dmf_t.origin);
            self.zm_dmf_new setmodel(self.zm_dmf_t.model);
            self.zm_dmf_new.angles = self.zm_dmf_t.angles;
            self.zm_dmf_new.zm_dmf_model = self.zm_dmf_t.model;
            self.zm_dmf_held = self.zm_dmf_new;
            self.zm_dmf_held_copy = 1;
        }
        else
        {
            self.zm_dmf_held = self.zm_dmf_t;
            self.zm_dmf_held_copy = 0;
            if (!isdefined(self.zm_dmf_t.zm_dmf_home))
            {
                self.zm_dmf_t.zm_dmf_home = self.zm_dmf_t.origin;
                self.zm_dmf_t.zm_dmf_home_ang = self.zm_dmf_t.angles;
            }
            self.zm_dmf_last_orig = self.zm_dmf_t;
        }
        self.zm_dmf_dist = distance(self geteye(), self.zm_dmf_held.origin);
        if (self.zm_dmf_dist < 80)
        {
            self.zm_dmf_dist = 80;
        }
        if (self.zm_dmf_dist > 600)
        {
            self.zm_dmf_dist = 600;
        }
        self.zm_dmf_zoff = 0;
        self.zm_dmf_ang = self.zm_dmf_held.angles;
        self.zm_dmf_pa0 = self getplayerangles();
        self.zm_dmf_yaw0 = self.zm_dmf_pa0[1];
        self thread zm_dmf_hold_loop();
        zm_dmf_count("forge_grabs");
        if (a == "copy")
        {
            return "copied - look around to move it, then Place or Save";
        }
        return "grabbed - look around to move it, then Place";
    }
    if (a == "drop")
    {
        if (!isdefined(self.zm_dmf_held))
        {
            return "^1you're not holding anything";
        }
        if (self.zm_dmf_held_copy)
        {
            self.zm_dmf_last_copy_placed = self.zm_dmf_held;
        }
        self.zm_dmf_held = undefined;
        if (self.zm_dmf_held_copy)
        {
            return "placed (copy is gone next match unless you Save it)";
        }
        return "placed (map objects reset next match)";
    }
    if (a == "rot")
    {
        if (!isdefined(self.zm_dmf_held))
        {
            return "^1you're not holding anything";
        }
        self.zm_dmf_ang = (self.zm_dmf_ang[0], self.zm_dmf_ang[1] + float(self.zm_dmf_v), self.zm_dmf_ang[2]);
        return "rotated " + self.zm_dmf_v;
    }
    if (a == "dist")
    {
        if (!isdefined(self.zm_dmf_held))
        {
            return "^1you're not holding anything";
        }
        self.zm_dmf_dist = self.zm_dmf_dist + float(self.zm_dmf_v);
        if (self.zm_dmf_dist < 40)
        {
            self.zm_dmf_dist = 40;
        }
        return "distance " + int(self.zm_dmf_dist);
    }
    if (a == "up")
    {
        if (!isdefined(self.zm_dmf_held))
        {
            return "^1you're not holding anything";
        }
        self.zm_dmf_zoff = self.zm_dmf_zoff + float(self.zm_dmf_v);
        return "height " + int(self.zm_dmf_zoff);
    }
    if (a == "save")
    {
        return self zm_dmf_save();
    }
    if (a == "undo")
    {
        return self zm_dmf_undo();
    }
    if (a == "hide")
    {
        self.zm_dmf_t = self zm_dmf_look();
        if (!isdefined(self.zm_dmf_t))
        {
            return "^1no object where you're looking";
        }
        self.zm_dmf_t hide();
        self.zm_dmf_t notsolid();
        self.zm_dmf_last_hidden = self.zm_dmf_t;
        return "object hidden (back next match)";
    }
    if (a == "unhide")
    {
        if (!isdefined(self.zm_dmf_last_hidden))
        {
            return "^1nothing hidden";
        }
        self.zm_dmf_last_hidden show();
        self.zm_dmf_last_hidden solid();
        self.zm_dmf_last_hidden = undefined;
        return "object back";
    }
    if (a == "classes")
    {
        // what kinds of entities this map has (dbg forge_classes)
        level.zm_dmf_cls = [];
        level.zm_dmf_all = getentarray();
        for (level.zm_dmf_j = 0; level.zm_dmf_j < level.zm_dmf_all.size; level.zm_dmf_j++)
        {
            level.zm_dmf_e = level.zm_dmf_all[level.zm_dmf_j];
            if (!isdefined(level.zm_dmf_e) || !isdefined(level.zm_dmf_e.classname))
            {
                continue;
            }
            level.zm_dmf_cn = level.zm_dmf_e.classname;
            if (isdefined(level.zm_dmf_e.model) && level.zm_dmf_e.model != "")
            {
                level.zm_dmf_cn = level.zm_dmf_cn + "+m";
            }
            if (!isdefined(level.zm_dmf_cls[level.zm_dmf_cn]))
            {
                level.zm_dmf_cls[level.zm_dmf_cn] = 0;
            }
            level.zm_dmf_cls[level.zm_dmf_cn]++;
        }
        level.zm_dmf_ck = getarraykeys(level.zm_dmf_cls);
        level.zm_dmf_out = "";
        for (level.zm_dmf_j = 0; level.zm_dmf_j < level.zm_dmf_ck.size; level.zm_dmf_j++)
        {
            level.zm_dmf_out = level.zm_dmf_out + level.zm_dmf_ck[level.zm_dmf_j] + " " + level.zm_dmf_cls[level.zm_dmf_ck[level.zm_dmf_j]] + "|";
        }
        nengine_store_set("devmenu_dbg", "forge_classes", level.zm_dmf_out);
        return level.zm_dmf_all.size + " entities";
    }
    if (a == "info")
    {
        self.zm_dmf_t = self zm_dmf_look();
        if (!isdefined(self.zm_dmf_t))
        {
            return "^1no object where you're looking";
        }
        self.zm_dmf_s = "" + self.zm_dmf_t.classname;
        if (isdefined(self.zm_dmf_t.model))
        {
            self.zm_dmf_s = self.zm_dmf_s + " " + self.zm_dmf_t.model;
        }
        nengine_store_set("devmenu_dbg", "forge_info", self.zm_dmf_s);
        return self.zm_dmf_s;
    }
    // ---------------- Map Builder link
    if (a == "sbon")
    {
        level.zm_dmf_en = zm_dmf_sbnum("enabled", 1);
        nengine_store_set("sandbox", "enabled", 1 - level.zm_dmf_en);
        nengine_store_save("sandbox", "settings");
        if (level.zm_dmf_en)
        {
            return "Map Builder props OFF";
        }
        return "Map Builder props ON";
    }
    if (a == "sbscan")
    {
        nengine_store_set("sandbox", "run", "scan");
        nengine_store_save("sandbox", "settings");
        return "sending this map's models to the Map Builder...";
    }
    if (a == "sbcollide")
    {
        level.zm_dmf_c = zm_dmf_sbnum("collide", 3) + 1;
        if (level.zm_dmf_c > 3)
        {
            level.zm_dmf_c = 0;
        }
        nengine_store_set("sandbox", "collide", level.zm_dmf_c);
        nengine_store_save("sandbox", "settings");
        return "prop collision mode " + level.zm_dmf_c + " (0 none, 3 solid)";
    }
    if (a == "sbcount")
    {
        level.zm_dmf_n = 0;
        level.zm_dmf_sl = zm_dmf_sbnum("slots", 50);
        for (level.zm_dmf_i = 1; level.zm_dmf_i <= level.zm_dmf_sl; level.zm_dmf_i++)
        {
            if (zm_dmf_sbstr("p" + level.zm_dmf_i) != "")
            {
                level.zm_dmf_n++;
            }
        }
        return level.zm_dmf_n + " props saved on " + level.zm_dmf_sl + " slots";
    }
    if (a == "sbclear")
    {
        level.zm_dmf_sl = zm_dmf_sbnum("slots", 50);
        for (level.zm_dmf_i = 1; level.zm_dmf_i <= level.zm_dmf_sl; level.zm_dmf_i++)
        {
            nengine_store_set("sandbox", "p" + level.zm_dmf_i, "");
        }
        nengine_store_save("sandbox", "settings");
        level.zm_dmf_saved = [];
        return "all Map Builder props removed";
    }
    if (a == "zmon")
    {
        level.zm_dmf_en = zm_dmf_zmnum("active", 0);
        nengine_store_set("zmap", "active", 1 - level.zm_dmf_en);
        nengine_store_save("zmap", "settings");
        if (level.zm_dmf_en)
        {
            return "zombies map mode OFF";
        }
        return "zombies map mode ON";
    }
    if (a == "zmstart")
    {
        nengine_store_set("zmap", "start", zm_dmf_vec(self.origin));
        nengine_store_save("zmap", "settings");
        return "map start set here";
    }
    if (a == "zmspawner")
    {
        level.zm_dmf_sp = zm_dmf_zmstr("spawners");
        if (level.zm_dmf_sp != "")
        {
            level.zm_dmf_sp = level.zm_dmf_sp + ";";
        }
        nengine_store_set("zmap", "spawners", level.zm_dmf_sp + zm_dmf_vec(self.origin));
        nengine_store_save("zmap", "settings");
        return "zombie spawner added here (" + strtok(level.zm_dmf_sp + zm_dmf_vec(self.origin), ";").size + " total)";
    }
    if (a == "zmspclear")
    {
        nengine_store_set("zmap", "spawners", "");
        nengine_store_save("zmap", "settings");
        return "zombie spawners cleared";
    }
    if (a == "zmarea1")
    {
        level.zm_dmf_c1 = self.origin;
        return "play area: corner 1 set - go to the opposite corner";
    }
    if (a == "zmarea2")
    {
        if (!isdefined(level.zm_dmf_c1))
        {
            return "^1set corner 1 first";
        }
        level.zm_dmf_c2 = self.origin;
        level.zm_dmf_lo = (min(level.zm_dmf_c1[0], level.zm_dmf_c2[0]), min(level.zm_dmf_c1[1], level.zm_dmf_c2[1]), min(level.zm_dmf_c1[2], level.zm_dmf_c2[2]) - 100);
        level.zm_dmf_hi = (max(level.zm_dmf_c1[0], level.zm_dmf_c2[0]), max(level.zm_dmf_c1[1], level.zm_dmf_c2[1]), max(level.zm_dmf_c1[2], level.zm_dmf_c2[2]) + 400);
        nengine_store_set("zmap", "area", zm_dmf_vec(level.zm_dmf_lo) + " " + zm_dmf_vec(level.zm_dmf_hi));
        nengine_store_save("zmap", "settings");
        return "play area set";
    }
    if (a == "zmkeep")
    {
        level.zm_dmf_en = zm_dmf_zmnum("keep_in", 1);
        nengine_store_set("zmap", "keep_in", 1 - level.zm_dmf_en);
        nengine_store_save("zmap", "settings");
        if (level.zm_dmf_en)
        {
            return "zombies may leave the play area";
        }
        return "zombies kept inside the play area";
    }
    return "unknown forge action " + a;
}

// The movable object the player looks at (script_model / script_brushmodel within 3000 units,
// closest to the aim line), or undefined.
zm_dmf_look()
{
    self.zm_dmf_lk = undefined;
    self.zm_dmf_lk_bs = 0.96;
    self.zm_dmf_eye = self geteye();
    self.zm_dmf_f = anglestoforward(self getplayerangles());
    // only close things can be grabbed (setting forge_range, default 400 units)
    self.zm_dmf_range = zm_dmf_num("forge_range", 400);
    level.zm_dmf_all = getentarray();
    for (level.zm_dmf_j = 0; level.zm_dmf_j < level.zm_dmf_all.size; level.zm_dmf_j++)
    {
        level.zm_dmf_e = level.zm_dmf_all[level.zm_dmf_j];
        if (!isdefined(level.zm_dmf_e) || !isdefined(level.zm_dmf_e.classname))
        {
            continue;
        }
        // script models / brush models, plus any other map entity that has a model (not players / AI)
        if (level.zm_dmf_e.classname != "script_model" && level.zm_dmf_e.classname != "script_brushmodel" && level.zm_dmf_e.classname != "script_vehicle" && !issubstr(level.zm_dmf_e.classname, "scriptable_"))
        {
            if (!isdefined(level.zm_dmf_e.model) || level.zm_dmf_e.model == "" || isplayer(level.zm_dmf_e) || isai(level.zm_dmf_e))
            {
                continue;
            }
        }
        if (isdefined(self.zm_dmf_held) && level.zm_dmf_e == self.zm_dmf_held)
        {
            continue;
        }
        level.zm_dmf_d = level.zm_dmf_e.origin - self.zm_dmf_eye;
        level.zm_dmf_len = length(level.zm_dmf_d);
        if (level.zm_dmf_len < 20 || level.zm_dmf_len > self.zm_dmf_range)
        {
            continue;
        }
        level.zm_dmf_c = vectordot(level.zm_dmf_d, self.zm_dmf_f) / level.zm_dmf_len;
        // prefer near objects a little: small extra angle allowed close up
        level.zm_dmf_c = level.zm_dmf_c + 30 / (level.zm_dmf_len + 300) * 0.1;
        if (level.zm_dmf_c > self.zm_dmf_lk_bs)
        {
            self.zm_dmf_lk_bs = level.zm_dmf_c;
            self.zm_dmf_lk = level.zm_dmf_e;
        }
    }
    return self.zm_dmf_lk;
}

// Keeps the held object in front of the player (distance + height offset), turning with the player.
zm_dmf_hold_loop()
{
    self endon("disconnect");
    while (isdefined(self.zm_dmf_held))
    {
        self zm_dmf_hold_step();
        waitframe();
    }
}

zm_dmf_hold_step()
{
    self.zm_dmf_pa = self getplayerangles();
    self.zm_dmf_hf = anglestoforward((0, self.zm_dmf_pa[1], 0));
    self.zm_dmf_hp = self geteye() + anglestoforward(self.zm_dmf_pa) * self.zm_dmf_dist;
    self.zm_dmf_hp = (self.zm_dmf_hp[0], self.zm_dmf_hp[1], self.zm_dmf_hp[2] - 50 + self.zm_dmf_zoff);
    self.zm_dmf_held.origin = self.zm_dmf_hp;
    self.zm_dmf_held.angles = (self.zm_dmf_ang[0], self.zm_dmf_ang[1] + self.zm_dmf_pa[1] - self.zm_dmf_yaw0, self.zm_dmf_ang[2]);
}

// Save the held copy (or the last placed copy) into the next free sandbox slot.
zm_dmf_save()
{
    if (isdefined(self.zm_dmf_held) && !self.zm_dmf_held_copy)
    {
        return "^1map objects can't be saved - use Copy, then Save";
    }
    if (isdefined(self.zm_dmf_held))
    {
        self.zm_dmf_sv = self.zm_dmf_held;
        self.zm_dmf_held = undefined;
    }
    else
    {
        self.zm_dmf_sv = self.zm_dmf_last_copy_placed;
    }
    if (!isdefined(self.zm_dmf_sv) || !isdefined(self.zm_dmf_sv.zm_dmf_model))
    {
        return "^1copy something first";
    }
    level.zm_dmf_sl = zm_dmf_sbnum("slots", 50);
    level.zm_dmf_free = 0;
    for (level.zm_dmf_i = 1; level.zm_dmf_i <= level.zm_dmf_sl; level.zm_dmf_i++)
    {
        if (zm_dmf_sbstr("p" + level.zm_dmf_i) == "")
        {
            level.zm_dmf_free = level.zm_dmf_i;
            break;
        }
    }
    if (level.zm_dmf_free == 0)
    {
        if (level.zm_dmf_sl >= 1000)
        {
            return "^1all 1000 prop slots are used";
        }
        level.zm_dmf_free = level.zm_dmf_sl + 1;
        nengine_store_set("sandbox", "slots", level.zm_dmf_free);
    }
    self.zm_dmf_spec = self.zm_dmf_sv.zm_dmf_model + " " + zm_dmf_vec(self.zm_dmf_sv.origin) + " " + int(self.zm_dmf_sv.angles[1]) + " " + int(self.zm_dmf_sv.angles[0]) + " " + int(self.zm_dmf_sv.angles[2]);
    nengine_store_set("sandbox", "p" + level.zm_dmf_free, self.zm_dmf_spec);
    nengine_store_save("sandbox", "settings");
    level.zm_dmf_saved[level.zm_dmf_saved.size] = level.zm_dmf_free;
    // the sandbox mod spawns the saved prop itself (with its collision) within a second
    self.zm_dmf_sv delete();
    self.zm_dmf_last_copy_placed = undefined;
    zm_dmf_count("forge_saves");
    nengine_store_set("devmenu_dbg", "forge_last_save", "p" + level.zm_dmf_free + " " + self.zm_dmf_spec);
    return "saved as Map Builder prop " + level.zm_dmf_free + " (stays every match)";
}

// Undo: the held object goes back / held copy is removed; else the last save is removed; else the
// last grabbed map object goes back home.
zm_dmf_undo()
{
    if (isdefined(self.zm_dmf_held))
    {
        self.zm_dmf_h = self.zm_dmf_held;
        self.zm_dmf_held = undefined;
        if (self.zm_dmf_held_copy)
        {
            self.zm_dmf_h delete();
            return "copy removed";
        }
        self.zm_dmf_h.origin = self.zm_dmf_h.zm_dmf_home;
        self.zm_dmf_h.angles = self.zm_dmf_h.zm_dmf_home_ang;
        return "object put back";
    }
    if (level.zm_dmf_saved.size > 0)
    {
        level.zm_dmf_k = level.zm_dmf_saved[level.zm_dmf_saved.size - 1];
        level.zm_dmf_saved[level.zm_dmf_saved.size - 1] = undefined;
        nengine_store_set("sandbox", "p" + level.zm_dmf_k, "");
        nengine_store_save("sandbox", "settings");
        return "removed saved prop " + level.zm_dmf_k;
    }
    if (isdefined(self.zm_dmf_last_orig) && isdefined(self.zm_dmf_last_orig.zm_dmf_home))
    {
        self.zm_dmf_last_orig.origin = self.zm_dmf_last_orig.zm_dmf_home;
        self.zm_dmf_last_orig.angles = self.zm_dmf_last_orig.zm_dmf_home_ang;
        self.zm_dmf_last_orig = undefined;
        return "object put back";
    }
    return "^1nothing to undo";
}

zm_dmf_vec(v)
{
    return int(v[0]) + " " + int(v[1]) + " " + int(v[2]);
}

zm_dmf_count(key)
{
    level.zm_dmf_cv = nengine_store_get("devmenu_dbg", key);
    if (!isdefined(level.zm_dmf_cv) || isstring(level.zm_dmf_cv))
    {
        level.zm_dmf_cv = 0;
    }
    nengine_store_set("devmenu_dbg", key, level.zm_dmf_cv + 1);
}

zm_dmf_sbnum(key, def)
{
    level.zm_dmf_nv = nengine_store_get("sandbox", key);
    if (!isdefined(level.zm_dmf_nv) || isstring(level.zm_dmf_nv))
    {
        if (isdefined(level.zm_dmf_nv) && level.zm_dmf_nv != "")
        {
            return int(level.zm_dmf_nv);
        }
        return def;
    }
    return int(level.zm_dmf_nv);
}

zm_dmf_sbstr(key)
{
    level.zm_dmf_sv2 = nengine_store_get("sandbox", key);
    if (!isdefined(level.zm_dmf_sv2) || !isstring(level.zm_dmf_sv2))
    {
        return "";
    }
    return level.zm_dmf_sv2;
}

zm_dmf_zmnum(key, def)
{
    level.zm_dmf_nv = nengine_store_get("zmap", key);
    if (!isdefined(level.zm_dmf_nv) || isstring(level.zm_dmf_nv))
    {
        if (isdefined(level.zm_dmf_nv) && level.zm_dmf_nv != "")
        {
            return int(level.zm_dmf_nv);
        }
        return def;
    }
    return int(level.zm_dmf_nv);
}

zm_dmf_zmstr(key)
{
    level.zm_dmf_sv2 = nengine_store_get("zmap", key);
    if (!isdefined(level.zm_dmf_sv2) || !isstring(level.zm_dmf_sv2))
    {
        return "";
    }
    return level.zm_dmf_sv2;
}

zm_dmf_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

// ---------------------------------------------------------------- aim grab
// Aim (ADS) at a movable object with the menu closed: it is picked up and follows your aim.
// Stop aiming: it stays exactly where it is (also in mid-air). The object you aim at, and the one
// you hold, get a rainbow outline (game outline system; colour names from setting outline_colors).

zm_dmf_aim_start()
{
    if (isdefined(self.zm_dmf_aim_started))
    {
        return;
    }
    self.zm_dmf_aim_started = 1;
    self notifyonplayercommand("zm_dmf_ads_on", "+speed_throw");
    self notifyonplayercommand("zm_dmf_ads_on", "+toggleads_throw");
    self notifyonplayercommand("zm_dmf_ads_off", "-speed_throw");
    self notifyonplayercommand("zm_dmf_ads_off", "-toggleads_throw");
    self notifyonplayercommand("zm_dmf_wheel_up", "weapnext");
    self notifyonplayercommand("zm_dmf_wheel_up", "+weapnext_inventory");
    self notifyonplayercommand("zm_dmf_wheel_up", "invnext");
    self notifyonplayercommand("zm_dmf_wheel_dn", "weapprev");
    self notifyonplayercommand("zm_dmf_wheel_dn", "+weapprev_inventory");
    self notifyonplayercommand("zm_dmf_wheel_dn", "invprev");
    self thread zm_dmf_wheel_up_loop();
    self thread zm_dmf_wheel_dn_loop();
    self thread zm_dmf_ads_on_loop();
    self thread zm_dmf_ads_off_loop();
    self thread zm_dmf_hover_loop();
}

zm_dmf_menu_open()
{
    if (isdefined(level.zm_dm_open) && level.zm_dm_open)
    {
        return 1;
    }
    return 0;
}

zm_dmf_ads_on_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmf_ads_on");
        if (zm_dmf_flag(self.zm_dmf_aim) && !zm_dmf_menu_open() && !isdefined(self.zm_dmf_held))
        {
            self zm_dmf_aim_pick();
        }
    }
}

zm_dmf_ads_off_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmf_ads_off");
        if (zm_dmf_flag(self.zm_dmf_aim_holding) && isdefined(self.zm_dmf_held))
        {
            self.zm_dmf_aim_holding = 0;
            self.zm_dmf_held = undefined;
            zm_dmf_count("forge_aim_drops");
        }
    }
}

zm_dmf_aim_pick()
{
    self.zm_dmf_t = self zm_dmf_look();
    if (!isdefined(self.zm_dmf_t))
    {
        return;
    }
    if (!isdefined(self.zm_dmf_t.zm_dmf_home))
    {
        self.zm_dmf_t.zm_dmf_home = self.zm_dmf_t.origin;
        self.zm_dmf_t.zm_dmf_home_ang = self.zm_dmf_t.angles;
    }
    self.zm_dmf_last_orig = self.zm_dmf_t;
    self.zm_dmf_held = self.zm_dmf_t;
    self.zm_dmf_held_copy = 0;
    self.zm_dmf_aim_holding = 1;
    self.zm_dmf_dist = distance(self geteye(), self.zm_dmf_held.origin);
    // keep the object where it is: hold point = eye + aim * distance, so no jump on pick-up
    self.zm_dmf_zoff = 50;
    self.zm_dmf_ang = self.zm_dmf_held.angles;
    self.zm_dmf_pa0 = self getplayerangles();
    self.zm_dmf_yaw0 = self.zm_dmf_pa0[1];
    self thread zm_dmf_hold_loop();
    zm_dmf_count("forge_aim_grabs");
}

// Outline whatever the player would grab (or holds), cycling rainbow colours.
zm_dmf_hover_loop()
{
    self endon("disconnect");
    while (1)
    {
        self zm_dmf_hover_step();
        wait zm_dmf_num("outline_step", 0.12);
    }
}

zm_dmf_hover_step()
{
    if (!zm_dmf_flag(self.zm_dmf_aim) || zm_dmf_menu_open())
    {
        self zm_dmf_outline_clear();
        return;
    }
    if (isdefined(self.zm_dmf_held))
    {
        self.zm_dmf_hov = self.zm_dmf_held;
    }
    else
    {
        self.zm_dmf_hov = self zm_dmf_look();
    }
    if (!isdefined(self.zm_dmf_hov))
    {
        self zm_dmf_outline_clear();
        return;
    }
    self thread zm_dmf_outline_set(self.zm_dmf_hov);
}

// Own thread: if a colour name is wrong only this call fails (dbg outline_ok counts the good ones).
zm_dmf_outline_set(ent)
{
    self.zm_dmf_ol_new = ent;
    self.zm_dmf_cols = strtok(zm_dmf_str("outline_colors", "outline_nodepth_red|outline_nodepth_orange|outline_nodepth_yellow|outline_nodepth_green|outline_nodepth_cyan|outline_nodepth_blue|outline_nodepth_purple"), "|");
    if (!isdefined(self.zm_dmf_coli))
    {
        self.zm_dmf_coli = 0;
    }
    self.zm_dmf_coli = (self.zm_dmf_coli + 1) % self.zm_dmf_cols.size;
    self zm_dmf_outline_clear();
    self.zm_dmf_ol_ent = self.zm_dmf_ol_new;
    self.zm_dmf_ol_id = namespace_ba924364166f1600::function_a274c8bc03853643(self.zm_dmf_ol_ent, self, self.zm_dmf_cols[self.zm_dmf_coli], "level_script");
    zm_dmf_count("outline_ok");
    nengine_store_set("devmenu_dbg", "outline_last", self.zm_dmf_cols[self.zm_dmf_coli]);
}

zm_dmf_outline_clear()
{
    if (isdefined(self.zm_dmf_ol_id) && isdefined(self.zm_dmf_ol_ent))
    {
        namespace_ba924364166f1600::function_a41e6d627e1bfc9c(self.zm_dmf_ol_id, self.zm_dmf_ol_ent);
    }
    self.zm_dmf_ol_id = undefined;
    self.zm_dmf_ol_ent = undefined;
}

zm_dmf_num(key, def)
{
    level.zm_dmf_nn = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dmf_nn) || (isstring(level.zm_dmf_nn) && level.zm_dmf_nn == "") || (!isstring(level.zm_dmf_nn) && level.zm_dmf_nn == 0))
    {
        return def;
    }
    if (isstring(level.zm_dmf_nn))
    {
        return float(level.zm_dmf_nn);
    }
    return level.zm_dmf_nn;
}

zm_dmf_str(key, def)
{
    level.zm_dmf_ss = nengine_store_get("devmenu", key);
    if (!isdefined(level.zm_dmf_ss) || !isstring(level.zm_dmf_ss) || level.zm_dmf_ss == "")
    {
        return def;
    }
    return level.zm_dmf_ss;
}

// Mouse wheel while holding: push the object away / pull it closer (forge_wheel_step units).
zm_dmf_wheel_up_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmf_wheel_up");
        zm_dmf_count("forge_wheel");
        if (isdefined(self.zm_dmf_held))
        {
            self.zm_dmf_dist = self.zm_dmf_dist + zm_dmf_num("forge_wheel_step", 40);
        }
    }
}

zm_dmf_wheel_dn_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmf_wheel_dn");
        zm_dmf_count("forge_wheel");
        if (isdefined(self.zm_dmf_held))
        {
            self.zm_dmf_dist = self.zm_dmf_dist - zm_dmf_num("forge_wheel_step", 40);
            if (self.zm_dmf_dist < 40)
            {
                self.zm_dmf_dist = 40;
            }
        }
    }
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmf_init_is_zombies()
{
    level.zm_dmf_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmf_init_gt) || level.zm_dmf_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmf_init_gt, 0, 2) == "zm";
}
