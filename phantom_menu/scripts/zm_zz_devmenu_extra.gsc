// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_extra - Phantom menu extras that need game scripts the main menu doesn't load:
// armor plates / golden armor, rapid fire, rapid + infinite equipment. Own script, reached
// through level function pointers, so if one of these game scripts is missing only these
// options stop working (the menu keeps linking). Game calls are the ones FuzMenu uses.
// State lives on the player (Kronos GSC loses locals across waits / script calls).

#using scripts\common\utility;
#using scripts\mp\zm\systems\zm_armor;
#using script_1f6b7243f8d72fef;
#using script_53d9b43dfecd95ed;
#using script_681a06cc8e9fcb34;
#using script_7b92812967b04687;
#using script_6c2f6a14fa53759e;
#using script_6b0663a111030b30;
#using script_c1369b1abe9a0d1;
#using script_8c8e132af264960;
#using script_1ade2fa7cae9593d;
// include list of the game script that uses the stat overrides (one of these defines them)
#using script_120270bd0a747a35;
#using script_15ce43f40ea0fd2b;
#using script_1667bc66bcc6e6e2;
#using script_16ea1b94f0f381b3;
#using script_1d7912161f42fb0c;
#using script_1f7b0304d26d6272;
#using script_2af91afcd2ee0028;
#using script_2b79931b08683e0a;
#using script_2b867a98ca762b0a;
#using script_3433ee6b63c7e243;
#using script_3774b0533d79d9a0;
#using script_37d8b0e4df36cd3f;
#using script_38eb8f4be20d54f4;
#using script_398091378a840fd8;
#using script_3b64eb40368c1450;
#using script_3ca070ee1ba8337c;
#using script_3e94a066ede97cc2;
#using script_3f51a039c4a1a113;
#using script_49e4a4c208f44b76;
#using script_4c770a9a4ad7659c;
#using script_4e3b2b1d9542e66b;
#using script_5560f3066718e34c;
#using script_5c9b111047cd229f;
#using script_5d265b4fca61f070;
#using script_659c5b2112e17034;
#using script_692b19b8e5f8f9e8;
#using script_6dfd03280678b65d;
#using script_72a196b6c7df2f38;
#using script_77c18cdedec620b3;
#using script_77dca3b46e01eb1e;
#using script_7d535542e36d66f9;
#using script_7e916efe0ee8c563;
#using script_ab66257f363a87c;
#using script_c7fa313d48d792b;

autoexec zm_dmx_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmx_init_is_zombies())
    {
        return;
    }
    level.zm_dmx_armor = &zm_dmx_armor;
    level.zm_dmx_golden = &zm_dmx_golden;
    level.zm_dmx_rapid = &zm_dmx_rapid;
    level.zm_dmx_fastreload = &zm_dmx_fastreload;
    level.zm_dmx_equip_start = &zm_dmx_equip_start;
    nengine_store_set("devmenu_dbg", "extra", "linked");
}

// self = player. n = 1-3 plates (game zm_armor::give_armor).
zm_dmx_armor(n)
{
    self zm_armor::give_armor(n);
    return 1;
}

// self = player. Golden armor on / off (game shared fns zombie/set_golden_armor and its off one).
zm_dmx_golden(on)
{
    if (on)
    {
        if (!utility::issharedfuncdefined(#"zombie", #"set_golden_armor"))
        {
            return 0;
        }
        if (!isdefined(self.platecarrierlevel) || self.platecarrierlevel < 3)
        {
            self zm_armor::give_armor(3);
        }
        self utility::callsharedfunc(#"zombie", #"set_golden_armor");
        return 1;
    }
    if (!utility::issharedfuncdefined(#"zombie", #"hash_6ed9310e5ce3c062"))
    {
        return 0;
    }
    self utility::callsharedfunc(#"zombie", #"hash_6ed9310e5ce3c062");
    return 1;
}

// self = player. Rapid fire: player stat overrides (fire time / reload speed), like FuzMenu,
// plus our own: while the trigger is held, extra shots of the held gun (magicbullet from the eye
// along the aim, every rapid_interval seconds), because the overrides alone did nothing in game.
zm_dmx_rapid(on)
{
    if (!isdefined(self.zm_dmx_rf_started))
    {
        self.zm_dmx_rf_started = 1;
        self notifyonplayercommand("zm_dmx_fdown", "+attack");
        self notifyonplayercommand("zm_dmx_fup", "-attack");
        self thread zm_dmx_fire_down_loop();
        self thread zm_dmx_fire_up_loop();
    }
    if (on)
    {
        self namespace_214d79f87f4bf971::function_b2fc2925c70ceb16("phantom_rapid", "fire_time_scale", 5);
        self namespace_214d79f87f4bf971::function_b2fc2925c70ceb16("phantom_rapid", "reload_speed", 0.05);
    }
    else
    {
        self namespace_214d79f87f4bf971::function_a5f16b9e67155bbd("phantom_rapid", "fire_time_scale");
        self namespace_214d79f87f4bf971::function_a5f16b9e67155bbd("phantom_rapid", "reload_speed");
    }
    return 1;
}

zm_dmx_fire_down_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmx_fdown");
        self.zm_dmx_firing = 1;
        // extra magicbullet shots did no damage in game: only with setting rapid_extra 1
        if (zm_dmx_flag(self.zm_dm_rapid) && !zm_dmx_flag(self.zm_dmx_bursting) && zm_dmx_num("rapid_extra", 0) == 1)
        {
            self thread zm_dmx_burst();
        }
    }
}

zm_dmx_fire_up_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("zm_dmx_fup");
        self.zm_dmx_firing = 0;
    }
}

zm_dmx_burst()
{
    self endon("disconnect");
    self.zm_dmx_bursting = 1;
    self.zm_dmx_shots = 0;
    while (zm_dmx_flag(self.zm_dmx_firing) && zm_dmx_flag(self.zm_dm_rapid))
    {
        self.zm_dmx_bw = self getcurrentweapon();
        if (isdefined(self.zm_dmx_bw) && !isnullweapon(self.zm_dmx_bw))
        {
            self.zm_dmx_eye = self geteye();
            self.zm_dmx_f = anglestoforward(self getplayerangles());
            magicbullet(self.zm_dmx_bw, self.zm_dmx_eye + self.zm_dmx_f * 30, self.zm_dmx_eye + self.zm_dmx_f * 8000, self);
            self.zm_dmx_shots++;
        }
        wait zm_dmx_num("rapid_interval", 0.06);
    }
    nengine_store_set("devmenu_dbg", "rapid", "burst " + self.zm_dmx_shots + " shots");
    self.zm_dmx_bursting = 0;
}

// self = player. Starts the equipment watcher once (rapid equipment + infinite equipment).
zm_dmx_equip_start()
{
    if (isdefined(self.zm_dmx_eq_on))
    {
        return;
    }
    self.zm_dmx_eq_on = 1;
    self thread zm_dmx_equip_loop();
    self thread zm_dmx_equip_refill_loop();
}

// Every thrown grenade / tactical: with rapid equipment on, throw extra copies of it (game
// magicbullet with the same weapon, small spread), and give the item back.
zm_dmx_equip_loop()
{
    self endon("disconnect");
    while (1)
    {
        self waittill("grenade_fire", gren, gw);
        self.zm_dmx_w = gw;
        self.zm_dmx_gn = 0;
        if (isdefined(level.zm_dmx_gcount))
        {
            level.zm_dmx_gcount++;
        }
        else
        {
            level.zm_dmx_gcount = 1;
        }
        nengine_store_set("devmenu_dbg", "equip", "grenade_fire seen " + level.zm_dmx_gcount);
        if (zm_dmx_flag(self.zm_dm_requip) && isdefined(self.zm_dmx_w))
        {
            self thread zm_dmx_spray();
        }
        if ((zm_dmx_flag(self.zm_dm_requip) || zm_dmx_flag(self.zm_dm_iequip)) && isdefined(self.zm_dmx_w))
        {
            self givemaxammo(self.zm_dmx_w);
        }
    }
}

zm_dmx_spray()
{
    self endon("disconnect");
    self.zm_dmx_sw = self.zm_dmx_w;
    self.zm_dmx_n = zm_dmx_num("requip_n", 5);
    for (self.zm_dmx_i = 0; self.zm_dmx_i < self.zm_dmx_n; self.zm_dmx_i++)
    {
        wait zm_dmx_num("requip_gap", 0.1);
        self.zm_dmx_eye = self geteye();
        self.zm_dmx_f = anglestoforward(self getplayerangles());
        self.zm_dmx_to = self.zm_dmx_eye + self.zm_dmx_f * 800 + (randomfloatrange(-120, 120), randomfloatrange(-120, 120), randomfloatrange(0, 160));
        self.zm_dmx_mb = magicbullet(self.zm_dmx_sw, self.zm_dmx_eye + self.zm_dmx_f * 30, self.zm_dmx_to, self);
        if (isdefined(self.zm_dmx_mb))
        {
            self.zm_dmx_gn++;
        }
    }
    nengine_store_set("devmenu_dbg", "equip_spray", "made " + self.zm_dmx_gn + " of " + self.zm_dmx_n);
}

// Infinite equipment: tops up grenades / tacticals once a second.
zm_dmx_equip_refill_loop()
{
    self endon("disconnect");
    while (1)
    {
        wait 1;
        if (zm_dmx_flag(self.zm_dm_iequip) || zm_dmx_flag(self.zm_dm_requip))
        {
            self zm_dmx_refill_offhands();
        }
    }
}

zm_dmx_refill_offhands()
{
    self.zm_dmx_off = self getweaponslistoffhands();
    if (!isdefined(self.zm_dmx_off))
    {
        return;
    }
    for (self.zm_dmx_j = 0; self.zm_dmx_j < self.zm_dmx_off.size; self.zm_dmx_j++)
    {
        if (isdefined(self.zm_dmx_off[self.zm_dmx_j]) && !isnullweapon(self.zm_dmx_off[self.zm_dmx_j]))
        {
            self givemaxammo(self.zm_dmx_off[self.zm_dmx_j]);
        }
    }
}

zm_dmx_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

zm_dmx_num(key, def)
{
    v = nengine_store_get("devmenu", key);
    if (!isdefined(v) || (isstring(v) && v == ""))
    {
        return def;
    }
    if (isstring(v))
    {
        return float(v);
    }
    return v;
}

// self = player. Fast reload on its own (player stat override reload_speed, like rapid fire's).
zm_dmx_fastreload(on)
{
    if (on)
    {
        self namespace_214d79f87f4bf971::function_b2fc2925c70ceb16("phantom_reload", "reload_speed", 0.05);
    }
    else
    {
        self namespace_214d79f87f4bf971::function_a5f16b9e67155bbd("phantom_reload", "reload_speed");
    }
    return 1;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmx_init_is_zombies()
{
    level.zm_dmx_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmx_init_gt) || level.zm_dmx_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmx_init_gt, 0, 2) == "zm";
}
