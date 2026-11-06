// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu - Phantom menu: in-game Zombies mod menu (Kronos).
//   Spawn any zombie / boss type the map has loaded, and play any AI animation
//   on any AI (the one you look at, the nearest, everything you spawned, or all AI).
//
// Controls (default):
//   Open / close   Aim + Knife together
//   Up / Down      Aim / Shoot
//   Select         Use
//   Back           Knife (back from the main page = close)
//
// Settings: kronos\devmenu\settings.json, read every 0.5 s, all live:
//   ui            "hud" = on-screen panel (falls back to a centre line if it can't be drawn),
//                 "print" = centre line only
//   panel_right 1 (right side) / 0 (left)   panel_x 20   panel_y 70   lines 12 (rows shown)
//   freeze        0 = you can move while the menu is open (1 = frozen)
//   spawn_count 1  spawn_dist 300  spawn_scale 1
//   target        "look", "nearest", "spawned" or "all" (also changeable in the menu)
//   anim_time     seconds an animation holds the AI (0 = until it ends by itself, max 30)
//   anim_loop     1 = replay the animation every anim_time seconds
//   anim_rate     playback speed (1 = normal)
//   types         optional "type|type|..." list for the spawn page (default: 223 known types)
//   anim_filter   optional text; only animations containing it are listed
//   run           one-off command, then emptied:
//                 open, close, up, down, select, back,
//                 "spawn <type> [count]", "anim <name or number>", "stop", "clear"
// Debug: kronos\devmenu_dbg\state.json (reloads, ticks, last, anims, ...)
//
// Animations come from zm_zz_devmenu_anims.gsc (level.zm_dm_anims). Kronos GSC loses
// local variables across a wait, so all state is on level / entity fields.

#using scripts\common\utility;
#using scripts\common\weapon;
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
#using script_77dca3b46e01eb1e;
#using script_1ade2fa7cae9593d;

autoexec zm_dm_init()
{
    level.zm_dm_give_named_fn = &zm_dm_give_named;
    level.zm_dm_spawn_types_fn = &zm_dm_spawn_types;
    level.zm_dm_props_fn = &zm_dm_props_scan;
    level.zm_dm_tell_fn = &zm_dm_tell;
    level.zm_dm_round_now_fn = &zm_dm_round_now;
    level.zm_dm_round_jump_fn = &zm_dm_round_jump;
    level.zm_dm_all_guns_fn = &zm_dm_all_guns;
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dm_init_is_zombies())
    {
        return;
    }
    // Round entry (Rounds > Type a round): the number being typed, keyboard typing on/off.
    // The phantom_bg Lua add-on reads number keys while phantom_typing is "1" and writes
    // phantom_typed = "seq|#text|state" (state 0 typing, 1 Enter, 2 Esc). Lua can only change
    // dvars that exist, so they are created here.
    level.zm_dm_entry = "";
    level.zm_dm_typing = 0;
    level.zm_dm_typed_last = "";
    setdvar(@"phantom_typing", "0");
    setdvar(@"phantom_typed", "");
    // gun picture box (phantom_bg add-on): "<image>|<row y>" while a gun row is selected
    setdvar(@"phantom_pic", "");
    // visible menu page for the add-on, which draws the row texts (no text slots used)
    setdvar(@"phantom_menu", "");
    // the add-on sets "1" while it can draw the menu text / messages; "" = it can't (old add-on)
    setdvar(@"phantom_menu_lua", "");
    // credit text for the add-on (it draws it with the scanning effect)
    setdvar(@"phantom_credit", "");
    // controls line for the add-on: "<y>|<text>"
    setdvar(@"phantom_foot", "");
    // centre messages for the add-on: "<number>|<text>" (shown by the UI: no text slots)
    setdvar(@"phantom_tell", "");
    // loading screen progress for the add-on (0-100): init 5, player in 35, pages 60, controls 80,
    // player walking after the intro 100 = ready
    level.zm_dm_load_id = "" + randomint(1000000);
    level.zm_dm_load100_t = 0;
    setdvar(@"phantom_load", level.zm_dm_load_id + "|5");
    // the add-on sets "1" when its loading bar has really reached the end
    setdvar(@"phantom_load_done", "");
    // loading screen colours "bar start|bar end|letters|glow" (hex), from the preset in use
    level.zm_dm_lc = zm_dm_str("load_colors", "");
    if (level.zm_dm_lc == "" || level.zm_dm_lc == "0")
    {
        level.zm_dm_lc = "6a1bff|38b6ff|e6d8ff|a04dff";
    }
    setdvar(@"phantom_load_colors", level.zm_dm_lc);
    // fonts: the add-on lists BO7's UI fonts in phantom_fonts ("a|b|c"); the menu text uses the one
    // named in phantom_font (setting menu_font, "" = the add-on's default)
    setdvar(@"phantom_fonts", "");
    level.zm_dm_font_now = zm_dm_str("menu_font", "");
    if (level.zm_dm_font_now == "0")
    {
        level.zm_dm_font_now = "";
    }
    setdvar(@"phantom_font", level.zm_dm_font_now);
    // the add-on writes "1" (logo file is the original), "0" (changed) or "?" (could not check)
    setdvar(@"phantom_logo_ok", "");
    level.zm_dm_ticks = 0;
    level.zm_dm_time = 0;
    level.zm_dm_open = 0;
    level.zm_dm_page = "main";
    level.zm_dm_sel = 0;
    level.zm_dm_stack = [];
    level.zm_dm_spawned = [];
    level.zm_dm_playing = [];
    level.zm_dm_hud = [];
    level.zm_dm_prev_use = 0;
    level.zm_dm_prev_melee = 0;
    level.zm_dm_prev_ads = 0;
    level.zm_dm_prev_fire = 0;
    level.zm_dm_combo = 0;
    level.zm_dm_target = "look";
    level.zm_dm_cat = "";
    level.zm_dm_cats_built = 0;
    level.zm_dm_last = "";
    level.zm_dm_speeds = [];
    level.zm_dm_speeds[0] = 1;
    level.zm_dm_speeds[1] = 1.5;
    level.zm_dm_speeds[2] = 2;
    level.zm_dm_speeds[3] = 3;
    level.zm_dm_jumps = [];
    level.zm_dm_jumps[0] = 1;
    level.zm_dm_jumps[1] = 1.5;
    level.zm_dm_jumps[2] = 2;
    level.zm_dm_jumps[3] = 3;
    level.zm_dm_jumps[4] = 4;
    level.zm_dm_gravs = [];
    level.zm_dm_gravs[0] = 1;
    level.zm_dm_gravs[1] = 0.5;
    level.zm_dm_gravs[2] = 0.25;
    level.zm_dm_gravs[3] = 0.15;
    zm_dm_theme_add("red", (0.85, 0.15, 0.15));
    zm_dm_theme_add("blue", (0.1, 0.5, 1));
    zm_dm_theme_add("green", (0.2, 0.8, 0.3));
    zm_dm_theme_add("purple", (0.6, 0.3, 0.9));
    zm_dm_theme_add("orange", (1, 0.55, 0.1));
    zm_dm_theme_add("gold", (0.95, 0.8, 0.2));
    nengine_store_clear("devmenu_dbg");
    nengine_store_load("devmenu", "settings");
    reloads = nengine_store_get("devmenu", "reloads");
    if (!isdefined(reloads) || isstring(reloads))
    {
        reloads = 0;
    }
    reloads++;
    nengine_store_set("devmenu", "reloads", reloads);
    nengine_store_set("devmenu", "run", "");
    // defaults version: bump when new settings are added, so keys that read as 0 get their default
    level.zm_dm_defaults_fix = 0;
    level.zm_dm_dv = nengine_store_get("devmenu", "defaults_ver");
    if (!isdefined(level.zm_dm_dv) || isstring(level.zm_dm_dv) || level.zm_dm_dv != 3)
    {
        level.zm_dm_defaults_fix = 1;
        nengine_store_set("devmenu", "defaults_ver", 3);
    }
    zm_dm_default("ui", "hud");
    zm_dm_default("panel_x", 20);
    zm_dm_default("panel_y", 70);
    zm_dm_default("lines", 12);
    zm_dm_default("freeze", 0);
    zm_dm_default("spawn_count", 1);
    zm_dm_default("spawn_dist", 300);
    zm_dm_default("spawn_scale", 1);
    zm_dm_default("target", "look");
    zm_dm_default("anim_time", 4);
    zm_dm_default("anim_loop", 0);
    zm_dm_default("anim_rate", 1);
    zm_dm_default("types", "");
    zm_dm_default("anim_filter", "");
    // Panel look (zm_zz_devmenu_hud.gsc). Written here because the panel script read missing
    // keys as 0 (blank panel: width 0, text size 0) instead of using its own defaults.
    zm_dm_default("panel_right", 1);
    zm_dm_default("hud_w", 200);
    zm_dm_default("hud_row_h", 14);
    zm_dm_default("hud_text", 1);
    zm_dm_default("hud_char_w", 5.6);
    zm_dm_default("hud_top", 92);
    zm_dm_default("hud_text_dy", 0);
    zm_dm_default("hud_bg_a", 0.85);
    zm_dm_default("hud_open", 0.3);
    zm_dm_default("hud_close", 0.2);
    zm_dm_default("hud_bg_fade_in", 0.6);
    zm_dm_default("hud_bg_fade_pow", 2);
    zm_dm_default("hud_bg_close_delay", 0);
    zm_dm_default("hud_bg_lag", 0.04);
    zm_dm_default("hud_bg_motion", 0);
    zm_dm_default("hud_bg_frame_lua", 1);
    zm_dm_default("round_mode", 0);
    zm_dm_default("tell_center", 1);
    zm_dm_default("hint_w", 150);
    zm_dm_default("hint_line_h", 11);
    zm_dm_default("hint_text", 0.85);
    zm_dm_default("hint_dy", 0);
    zm_dm_default("hud_typing", 1);
    zm_dm_default("hud_logo_y", 8);
    zm_dm_default("hud_full", 0);
    zm_dm_default("hud_bg_image", "phantom_bg");
    zm_dm_default("hud_bg_img_a", 1);
    zm_dm_default("hud_bg_tint", 0.45);
    zm_dm_default("hud_type_step", 2);
    zm_dm_default("hud_type_budget", 300);
    zm_dm_default("hud_row_delay", 0.2);
    zm_dm_default("hud_row_slide", 0.25);
    zm_dm_default("hud_font_rows", "default");
    zm_dm_default("hud_bulge", 14);
    zm_dm_default("tell_center", 1);
    zm_dm_default("requip_n", 5);
    zm_dm_default("requip_gap", 0.1);
    zm_dm_default("rapid_interval", 0.06);
    zm_dm_default("rapid_extra", 0);
    zm_dm_default("hud_refresh", 1);
    zm_dm_default("hud_bulge_step", 4);
    zm_dm_default("hud_scroll_t", 0.12);
    zm_dm_default("hud_type_pages", 0);
    zm_dm_default("hud_lua_scale", 2.25);
    zm_dm_default("hud_lua_dx", 0);
    zm_dm_default("hud_lua_dy", 0);
    zm_dm_default("hud_lua_prio", -1000);
    zm_dm_default("hud_bg_gsc", 0);
    zm_dm_default("lines", 14);
    nengine_store_save("devmenu", "settings");
    zm_dm_types_default();
    zm_dm_dbg("reloads", reloads);
    zm_dm_dbg("init", 1);
    level namespace_42ffbe510c7bd5b1::function_3e93ae4f7823fe81(#"player_spawned", &zm_dm_spawned_cb);
}

zm_dm_theme_add(name, color)
{
    if (!isdefined(level.zm_dm_theme_names))
    {
        level.zm_dm_theme_names = [];
        level.zm_dm_theme_colors = [];
    }
    i = level.zm_dm_theme_names.size;
    level.zm_dm_theme_names[i] = name;
    level.zm_dm_theme_colors[i] = color;
}

zm_dm_default(key, value)
{
    if (isdefined(level.zm_dm_defaults_fix) && level.zm_dm_defaults_fix)
    {
        v = nengine_store_get("devmenu", key);
        if (!isdefined(v) || (isstring(v) && v == "") || (!isstring(v) && v == 0 && !(!isstring(value) && value == 0)))
        {
            nengine_store_set("devmenu", key, value);
        }
        return;
    }
    // Kronos returns "" (not undefined) for a key that isn't in the file.
    v = nengine_store_get("devmenu", key);
    if (!isdefined(v) || (isstring(v) && v == "" && !(isstring(value) && value == "")))
    {
        nengine_store_set("devmenu", key, value);
    }
}

zm_dm_dbg(key, value)
{
    if (!isdefined(value))
    {
        value = "undefined";
    }
    // Saved to disk at most once a second by zm_dm_dbg_flush (disk writes stall the game's
    // server frame, which shows up as packet burst).
    nengine_store_set("devmenu_dbg", key, value);
    level.zm_dm_dbg_dirty = 1;
}

zm_dm_dbg_flush()
{
    if (isdefined(level.zm_dm_dbg_dirty) && level.zm_dm_dbg_dirty)
    {
        level.zm_dm_dbg_dirty = 0;
        nengine_store_save("devmenu_dbg", "state");
    }
}

zm_dm_str(key, def)
{
    v = nengine_store_get("devmenu", key);
    if (!isdefined(v))
    {
        return def;
    }
    if (isstring(v))
    {
        if (v == "")
        {
            return def;
        }
        return v;
    }
    return "" + v;
}

zm_dm_num(key, def)
{
    v = nengine_store_get("devmenu", key);
    if (!isdefined(v))
    {
        return def;
    }
    if (isstring(v))
    {
        if (v == "")
        {
            return def;
        }
        return float(v);
    }
    return v;
}

zm_dm_spawned_cb(params)
{
    if (isdefined(self.zm_dm) || !self function_b36623eefe0028c8())
    {
        return;
    }
    self.zm_dm = 1;
    // where you started (Teleports > Return to spawn)
    self.zm_dm_spawn_origin = self.origin;
    if (!isdefined(level.zm_dm_running))
    {
        level.zm_dm_running = 1;
        level.zm_dm_player = self;
        zm_dm_dbg("spawned", 1);
        n = 0;
        if (isdefined(level.zm_dm_anims))
        {
            n = level.zm_dm_anims.size;
        }
        zm_dm_dbg("anims", n);
        level.zm_dm_anim_count = n;
        zm_dm_load_step(35);
        self thread zm_dm_welcome();
        level thread zm_dm_load_timeout();
        level thread zm_dm_loop();
    }
}

// Intro teleports the player, so wait for real walking (or a button) before the hint.
// State on self: locals are not trusted across a wait in Kronos GSC.
zm_dm_welcome()
{
    if (getdvar("phantom_o_off") == "1")
    {
        return;
    }
    self.zm_dm_w_prev = self.origin;
    self.zm_dm_w_steps = 0;
    for (self.zm_dm_w_i = 0; self.zm_dm_w_i < 600 && self.zm_dm_w_steps < 5; self.zm_dm_w_i++)
    {
        wait 0.05;
        if (!isdefined(self))
        {
            return;
        }
        self zm_dm_welcome_step();
    }
    wait 0.5;
    zm_dm_load_step(100);
    // the add-on shows the loading screen + "ready" itself; old text only without it
    if (isdefined(self) && getdvar(@"phantom_menu_lua") != "1")
    {
        self iprintlnbold("^5Phantom menu^7 ready");
        self iprintln("^3Aim + Knife^7 to open (" + level.zm_dm_anim_count + " animations)");
    }
}

// loading progress only goes up
zm_dm_load_step(n)
{
    if (!isdefined(level.zm_dm_load_n) || n > level.zm_dm_load_n)
    {
        level.zm_dm_load_n = n;
        if (n >= 100)
        {
            level.zm_dm_load100_t = gettime();
        }
        if (getdvar("phantom_o_off") == "1")
        {
            // menu turned off: no loading screen either
            setdvar(@"phantom_load", "");
        }
        else
        {
            setdvar(@"phantom_load", level.zm_dm_load_id + "|" + n);
        }
    }
}

zm_dm_welcome_step()
{
    if (self adsbuttonpressed() || self attackbuttonpressed() || self usebuttonpressed() || self meleebuttonpressed())
    {
        self.zm_dm_w_steps = 5;
        return;
    }
    d = self.origin - self.zm_dm_w_prev;
    self.zm_dm_w_prev = self.origin;
    moved = d[0] * d[0] + d[1] * d[1];
    if (moved > 2 && moved < 2500)
    {
        self.zm_dm_w_steps++;
    }
    else
    {
        self.zm_dm_w_steps = 0;
    }
}

// ---------------------------------------------------------------- main loop

zm_dm_loop()
{
    while (1)
    {
        level zm_dm_tick();
        wait 0.05;
    }
}

zm_dm_tick()
{
    level.zm_dm_ticks++;
    level.zm_dm_time = level.zm_dm_time + 0.05;
    if (level.zm_dm_ticks % 20 == 0)
    {
        zm_dm_dbg("ticks", level.zm_dm_ticks);
        level thread zm_dm_dbg_flush();
    }
    // Each part runs as its own thread (they have no waits, so they finish this tick).
    // A script error then only ends that one call, not the menu loop.
    // Settings + pages files: read once a second (file reads also stall the frame).
    if (level.zm_dm_ticks % 20 == 10)
    {
        level thread zm_dm_settings();
    }
    level thread zm_dm_buttons();
    if (level.zm_dm_typing)
    {
        level thread zm_dm_typing_tick();
    }
    level thread zm_dm_hint_tick();
    level thread zm_dm_anim_upkeep();
    level thread zm_dm_player_tick();
    if (zm_dm_flag(level.zm_dm_speedrun) && gettime() - level.zm_dm_speedrun_t > zm_dm_pic_num("speedrun_gap", 10) * 1000)
    {
        level.zm_dm_speedrun_t = gettime();
        level thread zm_dm_round_jump(zm_dm_round_now() + 1);
    }
    if (level.zm_dm_ticks % 100 == 40)
    {
        level thread zm_dm_autodetect();
    }
    if (level.zm_dm_ticks == 80)
    {
        // weapon scan once per match (so after every game launch and every map)
        level thread zm_dm_wscan();
    }
    if (level.zm_dm_ticks % 20 == 15 && isdefined(level.zm_dm_wave))
    {
        level thread zm_dm_wave_tick();
    }
    if (level.zm_dm_ticks % 20 == 5 && zm_dm_num("probe", 0) == 1)
    {
        level thread zm_dm_probe_hp();
        level thread zm_dm_probe_gun();
        level thread zm_dm_probe_game();
        level thread zm_dm_probe_move();
    }
    if (level.zm_dm_ticks == 100)
    {
        level thread zm_dm_probe_lists();
    }
}

// ---------------------------------------------------------------- probe (debug only)
// Writes what the game says right now, so every menu action can be checked from the
// debug file: probe_hp, probe_gun, probe_game, probe_move, pu_names, w_known.

zm_dm_probe_hp()
{
    p = level.zm_dm_player;
    if (!isdefined(p))
    {
        return;
    }
    zm_dm_dbg("probe_hp", "hp " + zm_dm_s(p.health) + "/" + zm_dm_s(p.maxhealth) + " takedamage " + zm_dm_s(p.takedamage) + " laststand " + zm_dm_flag(p.inlaststand) + " ignoreme " + zm_dm_s(p.ignoreme) + " god " + zm_dm_flag(p.zm_dm_god));
}

zm_dm_probe_gun()
{
    p = level.zm_dm_player;
    if (!isdefined(p))
    {
        return;
    }
    // Built up in level fields (Kronos quirk: locals can come back empty).
    level.zm_pg_w = p getcurrentweapon();
    level.zm_pg_s = "none";
    if (isdefined(level.zm_pg_w) && !isnullweapon(level.zm_pg_w))
    {
        level.zm_pg_s = zm_dm_s(level.zm_pg_w.basename);
        level.zm_pg_idx = p zm_dm_gun_index(level.zm_pg_w);
        level.zm_pg_s = level.zm_pg_s + " slot " + zm_dm_s(level.zm_pg_idx) + " pap " + zm_dm_pap_level(p);
        if (isdefined(level.zm_pg_idx) && isdefined(p.var_1a87a9e7cf39ff69) && isdefined(p.var_1a87a9e7cf39ff69[level.zm_pg_idx]))
        {
            level.zm_pg_s = level.zm_pg_s + " rarity " + zm_dm_s(p.var_1a87a9e7cf39ff69[level.zm_pg_idx].rarity);
        }
        level.zm_pg_s = level.zm_pg_s + " clip " + zm_dm_s(p getweaponammoclip(level.zm_pg_w)) + " stock " + zm_dm_s(p getweaponammostock(level.zm_pg_w));
    }
    level.zm_pg_n = 0;
    level.zm_pg_all = "";
    if (isdefined(p.primaryinventory))
    {
        for (level.zm_pg_i = 0; level.zm_pg_i < p.primaryinventory.size; level.zm_pg_i++)
        {
            level.zm_pg_g = p.primaryinventory[level.zm_pg_i];
            if (isdefined(level.zm_pg_g) && !isnullweapon(level.zm_pg_g))
            {
                level.zm_pg_n++;
                level.zm_pg_all = level.zm_pg_all + " " + zm_dm_s(level.zm_pg_g.basename);
            }
        }
    }
    zm_dm_dbg("probe_gun", level.zm_pg_s + " | carried " + level.zm_pg_n + ":" + level.zm_pg_all);
}

zm_dm_probe_game()
{
    p = level.zm_dm_player;
    if (!isdefined(p))
    {
        return;
    }
    pts = p namespace_c40c7bec6c50de09::function_8f0a9502ff7321a();
    ai = getaiarray();
    n = 0;
    if (isdefined(ai))
    {
        n = ai.size;
    }
    st = "?";
    if (isdefined(level.var_6781718da4f78d1c) && isdefined(level.var_6781718da4f78d1c.state))
    {
        st = level.var_6781718da4f78d1c.state;
    }
    zm_dm_dbg("probe_game", "points " + zm_dm_s(pts) + " round " + zm_dm_round_now() + " state " + st + " ai " + n + " spawned " + zm_dm_alive_spawned() + " playing " + level.zm_dm_playing.size);
}

zm_dm_probe_move()
{
    p = level.zm_dm_player;
    if (!isdefined(p))
    {
        return;
    }
    o = p.origin;
    zm_dm_dbg("probe_move", "pos " + int(o[0]) + " " + int(o[1]) + " " + int(o[2]) + " ground " + zm_dm_s(p isonground()) + " speed " + zm_dm_pval(p.zm_dm_speed) + " jump " + zm_dm_pval(p.zm_dm_jump) + " grav " + zm_dm_pval(p.zm_dm_grav));
}

zm_dm_s(v)
{
    if (!isdefined(v))
    {
        return "undef";
    }
    return "" + v;
}

// Once: power-ups in the map's table, and which menu weapons this map knows.
zm_dm_probe_lists()
{
    s = "";
    if (utility::issharedfuncdefined(#"powerups", #"hash_a25fdc7ee24539fb"))
    {
        root = utility::callsharedfunc(#"powerups", #"hash_a25fdc7ee24539fb");
        if (isdefined(root) && isdefined(root.powerups))
        {
            names = ["double_points", "full_ammo", "full_armor", "full_power", "free_perk", "fire_sale", "nuke", "bonus_points_team", "insta_kill", "carpenter", "max_ammo"];
            for (zm_fi2 = 0; zm_fi2 < names.size; zm_fi2++)
            {
                k = names[zm_fi2];
                if (isdefined(root.powerups[k]))
                {
                    s = s + k + " ";
                }
            }
            s = s + "(" + root.powerups.size + " in table)";
        }
    }
    zm_dm_dbg("pu_names", s);
    zm_dm_weapons_init();
    ok = 0;
    bad = "";
    for (zm_fi3 = 0; zm_fi3 < level.zm_dm_wcat_ids.size; zm_fi3++)
    {
        id = level.zm_dm_wcat_ids[zm_fi3];
        for (zm_fi4 = 0; zm_fi4 < level.zm_dm_wlist[id].size; zm_fi4++)
        {
            n = level.zm_dm_wlist[id][zm_fi4];
            if (isdefined(zm_dm_weapon_name(id, n)))
            {
                ok++;
            }
            else
            {
                bad = bad + id + "_" + n + " ";
            }
        }
    }
    zm_dm_dbg("w_known", ok + " ok; missing: " + bad);
}

zm_dm_settings()
{
    nengine_store_load("devmenu", "settings");
    level.zm_dm_target = zm_dm_str("target", level.zm_dm_target);
    zm_dm_pages_reload();
    cmd = nengine_store_get("devmenu", "run");
    zm_dm_dbg("settings_tick", level.zm_dm_ticks);
    if (!isdefined(cmd) || !isstring(cmd) || cmd == "")
    {
        return;
    }
    nengine_store_set("devmenu", "run", "");
    nengine_store_save("devmenu", "settings");
    zm_dm_command(cmd);
    zm_dm_dbg("last_run", cmd + " -> " + level.zm_dm_last);
}

zm_dm_command(cmd)
{
    w = strtok(cmd, " ");
    if (w.size == 0)
    {
        return;
    }
    c = w[0];
    if (c == "open")
    {
        zm_dm_set_open(1);
    }
    else if (c == "close")
    {
        zm_dm_set_open(0);
    }
    else if (c == "up")
    {
        zm_dm_move(-1);
    }
    else if (c == "down")
    {
        zm_dm_move(1);
    }
    else if (c == "select")
    {
        zm_dm_select();
    }
    else if (c == "back")
    {
        zm_dm_back();
    }
    else if (c == "spawn" && w.size > 1)
    {
        count = int(zm_dm_num("spawn_count", 1));
        if (w.size > 2)
        {
            count = int(w[2]);
        }
        zm_dm_spawn(w[1], count);
    }
    else if (c == "anim" && w.size > 1)
    {
        zm_dm_anim_by_text(w[1]);
    }
    else if (c == "stop")
    {
        zm_dm_stop_all();
    }
    else if (c == "clear")
    {
        zm_dm_clear();
    }
    else if (c == "do" && w.size > 1)
    {
        // Run any menu action directly, e.g. "do wgive ar kiwi", "do pap 4", "do pu nuke".
        a = [];
        for (i = 1; i < w.size; i++)
        {
            a[a.size] = w[i];
        }
        zm_dm_do(a);
    }
    else
    {
        zm_dm_say("unknown command: " + cmd);
    }
}

// ---------------------------------------------------------------- buttons

// Watches every player: whoever presses Aim + Knife owns the menu (zm_squads can put
// several players in the match, and the first one to spawn isn't always you).
zm_dm_buttons()
{
    ps = level.players;
    if (!isdefined(ps))
    {
        return;
    }
    if (level.zm_dm_ticks % 40 == 0)
    {
        zm_dm_players_dbg(ps);
    }
    // Each player gets their own input loop, running on the player entity itself.
    // (Reading buttons from the shared level loop never registered a press.)
    for (i = 0; i < ps.size; i++)
    {
        p = ps[i];
        if (isdefined(p) && !isdefined(p.zm_dm_input))
        {
            p.zm_dm_input = 1;
            zm_dm_dbg("input_started", zm_dm_pname(p));
            zm_dm_load_step(80);
            p thread zm_dm_input_loop();
        }
    }
}

// self = player. Main input: button EVENTS (notifyonplayercommand), because the
// ...buttonpressed() checks always returned 0 in BO7 tests. Old polling only runs when
// setting input = "poll" or "both".
zm_dm_input_loop()
{
    self notifyonplayercommand("zm_dm_ads", "+speed_throw");
    self notifyonplayercommand("zm_dm_ads", "+toggleads_throw");
    self notifyonplayercommand("zm_dm_melee", "+melee");
    self notifyonplayercommand("zm_dm_melee", "+melee_zoom");
    self notifyonplayercommand("zm_dm_fire", "+attack");
    self notifyonplayercommand("zm_dm_use", "+activate");
    self notifyonplayercommand("zm_dm_use", "+usereload");
    // controllers: other melee / use bindings, and the D-pad (actionslot 1-4) to move in the menu
    self notifyonplayercommand("zm_dm_melee", "+melee_breath");
    self notifyonplayercommand("zm_dm_use", "+reload");
    self notifyonplayercommand("zm_dm_dpad_up", "+actionslot 1");
    self notifyonplayercommand("zm_dm_dpad_down", "+actionslot 2");
    self notifyonplayercommand("zm_dm_dpad_left", "+actionslot 3");
    self notifyonplayercommand("zm_dm_dpad_right", "+actionslot 4");
    self thread zm_dm_wait_dpad_up();
    self thread zm_dm_wait_dpad_down();
    self thread zm_dm_wait_dpad_left();
    self thread zm_dm_wait_dpad_right();
    self.zm_dm_ev_ads = -100;
    self.zm_dm_ev_melee = -100;
    self thread zm_dm_wait_ads();
    self thread zm_dm_wait_melee();
    self thread zm_dm_wait_fire();
    self thread zm_dm_wait_use();
    zm_dm_dbg("input", "events registered");
    while (isdefined(self))
    {
        mode = zm_dm_str("input", "cmd");
        if (mode == "poll" || mode == "both")
        {
            self zm_dm_buttons_for(self);
        }
        wait 0.05;
    }
}

// One waiting thread per event, no locals (Kronos loses locals across a wait).
zm_dm_wait_ads()
{
    while (isdefined(self))
    {
        self waittill("zm_dm_ads");
        self zm_dm_cmd_event("ads");
    }
}

zm_dm_wait_melee()
{
    while (isdefined(self))
    {
        self waittill("zm_dm_melee");
        self zm_dm_cmd_event("melee");
    }
}

zm_dm_wait_fire()
{
    while (isdefined(self))
    {
        self waittill("zm_dm_fire");
        self zm_dm_cmd_event("fire");
    }
}

zm_dm_wait_use()
{
    while (isdefined(self))
    {
        self waittill("zm_dm_use");
        self zm_dm_cmd_event("use");
    }
}

// self = player. Aim + Knife within 10 ticks (0.5 s) of each other = open / close.
// Open menu (owner only): Aim up, Shoot down, Use select, Knife back.
zm_dm_cmd_event(what)
{
    t = level.zm_dm_ticks;
    // one button press can arrive as two commands (e.g. +melee and +melee_zoom, +speed_throw and
    // +toggleads_throw): the same kind of event again within 2 ticks is the same press
    if (isdefined(self.zm_dm_ev_last_what) && self.zm_dm_ev_last_what == what && t - self.zm_dm_ev_last_t <= 2)
    {
        return;
    }
    self.zm_dm_ev_last_what = what;
    self.zm_dm_ev_last_t = t;
    zm_dm_dbg("cmd", what + " @" + t + " " + zm_dm_pname(self));
    if (what == "ads")
    {
        self.zm_dm_ev_ads = t;
        if (t - self.zm_dm_ev_melee <= zm_dm_combo_window())
        {
            self zm_dm_cmd_combo();
            return;
        }
        if (level.zm_dm_open && self == level.zm_dm_player)
        {
            zm_dm_move(-1);
        }
        return;
    }
    if (what == "melee")
    {
        self.zm_dm_ev_melee = t;
        if (t - self.zm_dm_ev_ads <= zm_dm_combo_window())
        {
            self zm_dm_cmd_combo();
            return;
        }
        if (level.zm_dm_open && self == level.zm_dm_player)
        {
            zm_dm_knife_back();
        }
        return;
    }
    if (!level.zm_dm_open || self != level.zm_dm_player)
    {
        return;
    }
    if (what == "fire" || what == "ddown")
    {
        zm_dm_move(1);
    }
    else if (what == "dup")
    {
        zm_dm_move(-1);
    }
    else if (what == "dright")
    {
        zm_dm_select();
    }
    else if (what == "dleft")
    {
        zm_dm_knife_back();
    }
    else if (what == "use")
    {
        zm_dm_select();
    }
}

zm_dm_cmd_combo()
{
    // both events used up, so the second key of the combo doesn't also act
    self.zm_dm_ev_ads = -100;
    self.zm_dm_ev_melee = -100;
    if (!isdefined(level.zm_dm_player) || self != level.zm_dm_player)
    {
        zm_dm_take_over(self);
        zm_dm_set_open(1);
        return;
    }
    zm_dm_set_open(!level.zm_dm_open);
}

zm_dm_pname(p)
{
    if (isdefined(p) && isdefined(p.name) && isstring(p.name))
    {
        return p.name;
    }
    return "?";
}

zm_dm_players_dbg(ps)
{
    s = "" + ps.size + ":";
    for (i = 0; i < ps.size; i++)
    {
        p = ps[i];
        if (!isdefined(p))
        {
            continue;
        }
        n = zm_dm_pname(p);
        s = s + " " + n + " (" + int(p.origin[0]) + " " + int(p.origin[1]) + ")";
        if (isdefined(level.zm_dm_player) && p == level.zm_dm_player)
        {
            s = s + "*";
        }
    }
    zm_dm_dbg("players", s);
}

// Debug: writes each step name once, so the file shows how far the button code gets.
zm_dm_bstep(name)
{
    if (!isdefined(level.zm_dm_bsteps))
    {
        level.zm_dm_bsteps = [];
    }
    if (isdefined(level.zm_dm_bsteps[name]))
    {
        return;
    }
    level.zm_dm_bsteps[name] = 1;
    zm_dm_dbg("bstep", name);
}

zm_dm_buttons_for(p)
{
    zm_dm_bstep("0 start");
    if (!isdefined(p.zm_dm_prev_use))
    {
        p.zm_dm_prev_use = 0;
        p.zm_dm_prev_melee = 0;
        p.zm_dm_prev_ads = 0;
        p.zm_dm_prev_fire = 0;
        p.zm_dm_combo = 0;
    }
    zm_dm_bstep("1 setup");
    // Aim + Knife = open/close. In the menu: Aim up, Shoot down, Use select, Knife back.
    // Aim and Knife act when released, and only if the other one wasn't pressed
    // meanwhile, so the open combo doesn't also move up or go back.
    use = 0;
    melee = 0;
    ads = 0;
    fire = 0;
    if (p usebuttonpressed())
    {
        use = 1;
    }
    if (p meleebuttonpressed())
    {
        melee = 1;
    }
    if (p adsbuttonpressed())
    {
        ads = 1;
    }
    if (p attackbuttonpressed())
    {
        fire = 1;
    }
    zm_dm_bstep("2 read");
    if (level.zm_dm_ticks % 20 == 0)
    {
        zm_dm_dbg("raw", "use " + use + " knife " + melee + " aim " + ads + " shoot " + fire + " @" + level.zm_dm_ticks);
    }
    use_new = use && !p.zm_dm_prev_use;
    melee_new = melee && !p.zm_dm_prev_melee;
    ads_new = ads && !p.zm_dm_prev_ads;
    fire_new = fire && !p.zm_dm_prev_fire;
    melee_up = !melee && p.zm_dm_prev_melee;
    ads_up = !ads && p.zm_dm_prev_ads;
    zm_dm_bstep("3 edges");
    if (use_new || melee_new || ads_new || fire_new || melee_up || ads_up)
    {
        zm_dm_dbg("btn", "use " + use + " knife " + melee + " aim " + ads + " shoot " + fire + " @" + level.zm_dm_ticks + " " + zm_dm_pname(p));
    }
    p.zm_dm_prev_use = use;
    p.zm_dm_prev_melee = melee;
    p.zm_dm_prev_ads = ads;
    p.zm_dm_prev_fire = fire;
    if (ads && melee && (ads_new || melee_new))
    {
        p.zm_dm_combo = 1;
        if (!isdefined(level.zm_dm_player) || p != level.zm_dm_player)
        {
            zm_dm_take_over(p);
            zm_dm_set_open(1);
            return;
        }
        zm_dm_set_open(!level.zm_dm_open);
        return;
    }
    if (!ads && !melee)
    {
        was_combo = p.zm_dm_combo;
        p.zm_dm_combo = 0;
        if (was_combo)
        {
            return;
        }
    }
    if (!level.zm_dm_open || p != level.zm_dm_player)
    {
        return;
    }
    if (ads_up && !melee && !p.zm_dm_combo)
    {
        zm_dm_move(-1);
    }
    else if (fire_new)
    {
        zm_dm_move(1);
    }
    else if (use_new)
    {
        zm_dm_select();
    }
    else if (melee_up && !ads && !p.zm_dm_combo)
    {
        zm_dm_back();
    }
}

// Makes p the menu owner: the old owner's on-screen text is cleared and new text is made for p.
zm_dm_take_over(p)
{
    if (isdefined(level.zm_dm_player))
    {
        level.zm_dm_player setmovespeedscale(1);
    }
    zm_dm_hud_hide();
    level.zm_dm_hud = [];
    level.zm_dm_hud_broken = undefined;
    level.zm_dm_hud_running = undefined;
    level.zm_dm_player = p;
    zm_dm_dbg("owner", zm_dm_pname(p));
}

// ---------------------------------------------------------------- menu pages

zm_dm_set_open(on)
{
    // switched off by the player in Settings > Debug Options > Phantom Options
    if (on && getdvar("phantom_o_off") == "1")
    {
        level.zm_dm_open = 0;
        return;
    }
    // the menu opens only once the loading screen has finished (progress 100)
    if (on && (!isdefined(level.zm_dm_load_n) || level.zm_dm_load_n < 100 || (getdvar(@"phantom_menu_lua") == "1" && getdvar(@"phantom_load_done") != "1" && gettime() - level.zm_dm_load100_t < 15000)))
    {
        level.zm_dm_open = 0;
        zm_dm_tell("menu still loading - wait for READY");
        return;
    }
    // the menu only opens with its original credit in place
    if (on && (!isdefined(level.zm_dmh_credit) || level.zm_dmh_credit != "Made by Ares" || getdvar(@"phantom_logo_ok") == "0"))
    {
        level.zm_dm_open = 0;
        if (isdefined(level.zm_dm_player))
        {
            level.zm_dm_player thread zm_dm_tamper_popup();
        }
        return;
    }
    p = level.zm_dm_player;
    level.zm_dm_open = on;
    zm_dm_dbg("open", on);
    if (on)
    {
        if (level.zm_dm_page == "")
        {
            level.zm_dm_page = "main";
        }
        zm_dm_dbg("step", "open: build");
        zm_dm_build();
        zm_dm_dbg("step", "open: draw");
        zm_dm_draw();
        zm_dm_say("open");
        if (isdefined(p) && zm_dm_num("freeze", 0) == 1)
        {
            zm_dm_dbg("step", "open: freeze");
            p setmovespeedscale(0);
        }
        zm_dm_dbg("step", "open: done");
    }
    else
    {
        if (isdefined(p))
        {
            p setmovespeedscale(zm_dm_pval(p.zm_dm_speed));
        }
        zm_dm_hud_hide();
        zm_dm_say("closed");
        zm_dm_dbg("step", "closed");
    }
}

zm_dm_go(page)
{
    level.zm_dm_stack[level.zm_dm_stack.size] = level.zm_dm_page + "|" + level.zm_dm_sel + "|" + level.zm_dm_cat;
    level.zm_dm_page = page;
    level.zm_dm_sel = 0;
    zm_dm_build();
    zm_dm_draw();
}

zm_dm_back()
{
    if (level.zm_dm_stack.size == 0)
    {
        zm_dm_set_open(0);
        return;
    }
    top = level.zm_dm_stack[level.zm_dm_stack.size - 1];
    level.zm_dm_stack[level.zm_dm_stack.size - 1] = undefined;
    t = strtok(top, "|");
    level.zm_dm_page = t[0];
    level.zm_dm_sel = int(t[1]);
    level.zm_dm_cat = "";
    if (t.size > 2)
    {
        level.zm_dm_cat = t[2];
    }
    zm_dm_build();
    zm_dm_draw();
}

zm_dm_move(d)
{
    if (!level.zm_dm_open || level.zm_dm_labels.size == 0)
    {
        return;
    }
    zm_dm_cheat_key(d);
    level.zm_dm_sel = level.zm_dm_sel + d;
    if (level.zm_dm_sel < 0)
    {
        level.zm_dm_sel = level.zm_dm_labels.size - 1;
    }
    if (level.zm_dm_sel >= level.zm_dm_labels.size)
    {
        level.zm_dm_sel = 0;
    }
    zm_dm_draw();
}

// ---------------------------------------------------------------- live pages file
// kronos\devmenu_pages\pages.json (store devmenu_pages), re-read every 0.5 s. Edit it while
// you play: change "version" and the open menu redraws at once. Keys:
//   page_<id>     "TITLE~Label|action~Label|action..." replaces built-in page <id>
//   add_<id>      "Label|action~..." extra rows added to the end of page <id>
//   weapons_<cat> "kiwi falcon ..." weapon names for a weapon type page (ar, sm, ...)
//   spawn_types   "type|type|..." enemy list for the Spawn page (Map Builder ai_types.txt)
// A label may end in $token to show a live value: god ammo ignore speed jump grav round
// pap target spawned theme side rows textmode points.
// Actions are the menu's own words (go <page>, toggle god, pu nuke, wgive ar kiwi,
// spawn <type>, round 10, roundrel 1, pap 2, rarity 5, dvar <name> <value>, say <text> ...).

zm_dm_pages_reload()
{
    nengine_store_load("devmenu_pages", "pages");
    v = nengine_store_get("devmenu_pages", "version");
    if ((!isdefined(v) || ("" + v) == "") && isdefined(level.zm_dmp) && isdefined(level.zm_dmp["version"]))
    {
        v = level.zm_dmp["version"];
    }
    if (!isdefined(v))
    {
        return;
    }
    v = "" + v;
    if (v == "" || (isdefined(level.zm_dm_pages_ver) && level.zm_dm_pages_ver == v))
    {
        return;
    }
    level.zm_dm_pages_ver = v;
    zm_dm_load_step(60);
    level.zm_dm_spawn_list = undefined;
    zm_dm_dbg("pages_version", v);
    if (level.zm_dm_open)
    {
        zm_dm_build();
        zm_dm_draw();
    }
}

zm_dm_pg(key)
{
    v = nengine_store_get("devmenu_pages", key);
    if (!isdefined(v) || !isstring(v) || v == "")
    {
        // built-in pages (zm_zz_devmenu_pages.gsc, Workshop build) when there is no pages file
        if (isdefined(level.zm_dmp) && isdefined(level.zm_dmp[key]))
        {
            return level.zm_dmp[key];
        }
        return "";
    }
    return v;
}

// Adds "Label|action~Label|action" rows. Page links (go ...) get the arrow.
zm_dm_add_rows(s)
{
    rows = strtok(s, "~");
    for (zm_fi5 = 0; zm_fi5 < rows.size; zm_fi5++)
    {
        row = rows[zm_fi5];
        parts = strtok(row, "|");
        if (parts.size == 0)
        {
            continue;
        }
        act = "none";
        if (parts.size > 1)
        {
            act = parts[1];
        }
        label = zm_dm_label(parts[0]);
        w = strtok(act, " ");
        if (w.size > 1 && (w[0] == "go" || w[0] == "wcat"))
        {
            label = label + zm_dm_arrow();
        }
        zm_dm_item(label, act);
    }
}

// "Text$token" -> "Text" + live value of token.
zm_dm_label(s)
{
    if (!issubstr(s, "$"))
    {
        return s;
    }
    t = strtok(s, "$");
    if (t.size < 2)
    {
        return s;
    }
    return t[0] + zm_dm_token(t[1]);
}

zm_dm_token(k)
{
    if (getsubstr(k, 0, 3) == "bc_" && isdefined(level.zm_dmb_token))
    {
        return [[ level.zm_dmb_token ]](k);
    }
    p = level.zm_dm_player;
    if (k == "god")
    {
        return zm_dm_onoff(p.zm_dm_god);
    }
    if (k == "ammo")
    {
        return zm_dm_onoff(p.zm_dm_ammo);
    }
    if (k == "rapid")
    {
        return zm_dm_onoff(p.zm_dm_rapid);
    }
    if (k == "requip")
    {
        return zm_dm_onoff(p.zm_dm_requip);
    }
    if (k == "iequip")
    {
        return zm_dm_onoff(p.zm_dm_iequip);
    }
    if (k == "golden")
    {
        return zm_dm_onoff(p.zm_dm_golden);
    }
    if (k == "bg")
    {
        return "^3" + zm_dm_bg_label(zm_dm_str("hud_bg_image", ""));
    }
    if (k == "ignore")
    {
        return zm_dm_onoff(p.zm_dm_ignore);
    }
    if (k == "speed")
    {
        return "^3x" + zm_dm_pval(p.zm_dm_speed);
    }
    if (k == "jump")
    {
        return "^3x" + zm_dm_pval(p.zm_dm_jump);
    }
    if (k == "grav")
    {
        return "^3" + zm_dm_grav_name(p.zm_dm_grav);
    }
    if (k == "round")
    {
        return "" + zm_dm_round_now();
    }
    if (k == "entry")
    {
        if (level.zm_dm_typing)
        {
            return "^3" + level.zm_dm_entry + "_";
        }
        if (level.zm_dm_entry == "")
        {
            return "^30";
        }
        return "^3" + level.zm_dm_entry;
    }
    if (k == "pap")
    {
        return "" + zm_dm_pap_level(p);
    }
    if (k == "target")
    {
        return "^3" + zm_dm_target_name(level.zm_dm_target);
    }
    if (k == "spawned")
    {
        return "" + zm_dm_alive_spawned();
    }
    if (k == "font")
    {
        if (zm_dm_str("menu_font", "") == "" || zm_dm_str("menu_font", "") == "0")
        {
            return "^3default";
        }
        return "^3" + zm_dm_str("menu_font", "");
    }
    if (k == "theme")
    {
        if (zm_dm_str("accent_rgb", "") != "" && zm_dm_str("accent_rgb", "") != "0" && zm_dm_str("preset_name", "") != "")
        {
            return "^3" + zm_dm_str("preset_name", "");
        }
        return "^3" + level.zm_dm_theme_names[zm_dm_theme()];
    }
    if (k == "side")
    {
        if (zm_dm_num("panel_right", 1) == 1)
        {
            return "^3right";
        }
        return "^3left";
    }
    if (k == "rows")
    {
        return "^3" + int(zm_dm_num("lines", 12));
    }
    if (k == "textmode")
    {
        return zm_dm_onoff(zm_dm_str("ui", "hud") == "print");
    }
    if (k == "points")
    {
        return zm_dm_s(p namespace_c40c7bec6c50de09::function_8f0a9502ff7321a());
    }
    return "";
}

// Enemy types for the Spawn page: pages file spawn_types, else setting types, else the
// built-in Map Builder list. Types this map can't spawn are hidden (the game's own check
// function_820a32d71b618d4b, the same one its spawn function uses), unless spawn_all = 1.
zm_dm_spawn_types()
{
    if (isdefined(level.zm_dm_spawn_list) && level.zm_dm_spawn_all == zm_dm_num("spawn_all", 0))
    {
        zm_dm_auto_merge();
        return;
    }
    s = zm_dm_pg("spawn_types_0");
    if (s != "")
    {
        all = [];
        for (ci = 0; ci < 100; ci++)
        {
            s = zm_dm_pg("spawn_types_" + ci);
            if (s == "")
            {
                break;
            }
            part = strtok(s, "|");
            for (zm_pj = 0; zm_pj < part.size; zm_pj++)
            {
                all[all.size] = part[zm_pj];
            }
        }
    }
    else
    {
        zm_dm_types_refresh();
        all = level.zm_dm_types;
    }
    level.zm_dm_spawn_all = zm_dm_num("spawn_all", 0);
    level.zm_dm_spawn_list = [];
    for (zm_fi6 = 0; zm_fi6 < all.size; zm_fi6++)
    {
        t = all[zm_fi6];
        if (level.zm_dm_spawn_all == 1 || zm_dm_can_spawn(t))
        {
            level.zm_dm_spawn_list[level.zm_dm_spawn_list.size] = t;
        }
    }
    zm_dm_auto_merge();
    zm_dm_dbg("spawnable", level.zm_dm_spawn_list.size + " of " + all.size);
    level.zm_sn_part = 0;
    level.zm_sn_text = "";
    for (level.zm_sn_i = 0; level.zm_sn_i < level.zm_dm_spawn_list.size; level.zm_sn_i++)
    {
        level.zm_sn_text = level.zm_sn_text + level.zm_dm_spawn_list[level.zm_sn_i] + "|";
        if (level.zm_sn_i % 20 == 19)
        {
            zm_dm_dbg("spawnable_" + level.zm_sn_part, level.zm_sn_text);
            level.zm_sn_part++;
            level.zm_sn_text = "";
        }
    }
    if (level.zm_sn_text != "")
    {
        zm_dm_dbg("spawnable_" + level.zm_sn_part, level.zm_sn_text);
    }
}

// Spawn page category of an enemy type, from its name.
// Custom waves: when the round number changes, spawn wave_n (+1 per 5 rounds) enemies of the
// chosen kind around the player (random types of that kind this map can spawn right now).
zm_dm_wave_tick()
{
    level.zm_wv_r = zm_dm_round_now();
    if (!isdefined(level.zm_dm_wave) || !isdefined(level.zm_dm_player) || level.zm_wv_r == level.zm_dm_wave_last)
    {
        return;
    }
    level.zm_dm_wave_last = level.zm_wv_r;
    zm_dm_spawn_types();
    level.zm_wv_types = [];
    for (level.zm_wv_i = 0; level.zm_wv_i < level.zm_dm_spawn_list.size; level.zm_wv_i++)
    {
        level.zm_wv_t = level.zm_dm_spawn_list[level.zm_wv_i];
        if (!zm_dm_can_spawn(level.zm_wv_t))
        {
            continue;
        }
        if (level.zm_dm_wave == "mix" || zm_dm_spawn_cat(level.zm_wv_t) == level.zm_dm_wave)
        {
            level.zm_wv_types[level.zm_wv_types.size] = level.zm_wv_t;
        }
    }
    if (level.zm_wv_types.size == 0)
    {
        zm_dm_tell("^1custom wave: no " + level.zm_dm_wave + " enemies can spawn here right now");
        return;
    }
    level.zm_wv_n = int(zm_dm_num("wave_n", 3));
    if (level.zm_wv_n <= 0)
    {
        level.zm_wv_n = 3;
    }
    if (!isstring(level.zm_wv_r))
    {
        level.zm_wv_n = level.zm_wv_n + int(level.zm_wv_r / 5);
    }
    if (level.zm_wv_n > 24)
    {
        level.zm_wv_n = 24;
    }
    level.zm_dm_sp_scale = zm_dm_num("spawn_scale", 1);
    level.zm_dm_ok = 0;
    for (level.zm_wv_k = 0; level.zm_wv_k < level.zm_wv_n; level.zm_wv_k++)
    {
        level.zm_dm_sp_type = level.zm_wv_types[randomint(level.zm_wv_types.size)];
        level.zm_dm_sp_dist = randomfloatrange(250, 450);
        level.zm_wv_yaw = 0;
        if (isdefined(level.zm_dm_player.angles))
        {
            level.zm_wv_yaw = level.zm_dm_player.angles[1];
        }
        zm_dm_spawn_one_at(level.zm_wv_yaw + randomfloatrange(-70, 70));
    }
    zm_dm_tell("^5custom wave:^7 " + level.zm_dm_ok + " " + level.zm_dm_wave + " enemies");
}

// One AI at the given yaw around the player (custom waves).
zm_dm_spawn_one_at(yaw)
{
    level.zm_so_yaw = yaw;
    level.zm_so_pos = level.zm_dm_player.origin + anglestoforward((0, level.zm_so_yaw, 0)) * level.zm_dm_sp_dist;
    level.zm_so_ai = namespace_85d424ad210ad4c9::function_35dc52fde01c4d08(level.zm_dm_sp_type, level.zm_so_pos, (0, level.zm_so_yaw + 180, 0), "axis");
    if (isdefined(level.zm_so_ai))
    {
        level.zm_dm_ok++;
        level.zm_dm_spawned[level.zm_dm_spawned.size] = level.zm_so_ai;
    }
    else
    {
        zm_dm_dbg("wave_fail", level.zm_dm_sp_type + " at " + level.zm_so_pos);
    }
}

zm_dm_spawn_cat(t)
{
    if (issubstr(t, "boss") || issubstr(t, "mega") || issubstr(t, "champion"))
    {
        return "boss";
    }
    if (issubstr(t, "hvt"))
    {
        return "hvt";
    }
    if (issubstr(t, "hound") || issubstr(t, "dog") || issubstr(t, "hellping"))
    {
        return "hound";
    }
    if (issubstr(t, "armored"))
    {
        return "armored";
    }
    if (issubstr(t, "zombie_base"))
    {
        return "normal";
    }
    return "elite";
}

zm_dm_can_spawn(t)
{
    if (isdefined(level.var_1e2c07e345d293d1))
    {
        t = [[ level.var_1e2c07e345d293d1 ]](t);
    }
    if (function_820a32d71b618d4b(t))
    {
        return 1;
    }
    return 0;
}

// Fills level.zm_dm_title, zm_dm_labels (text) and zm_dm_values (what select does):
// from the pages file when it has the page, else the built-in page; then add_<page> rows.
zm_dm_build()
{
    level.zm_dm_labels = [];
    level.zm_dm_label_istr = [];
    level.zm_dm_values = [];
    page = level.zm_dm_page;
    fp = zm_dm_pg("page_" + page);
    if (fp != "")
    {
        rows = strtok(fp, "~");
        level.zm_dm_title = zm_dm_label(rows[0]);
        rest = "";
        for (i = 1; i < rows.size; i++)
        {
            rest = rest + rows[i] + "~";
        }
        zm_dm_add_rows(rest);
    }
    else
    {
        zm_dm_build_builtin(page);
    }
    extra = zm_dm_pg("add_" + page);
    if (extra != "")
    {
        zm_dm_add_rows(extra);
    }
    if (page == "main" && zm_dm_num("secret_unlocked", 0) == 1)
    {
        zm_dm_item("^5??? SECRET ???", "go secret");
    }
    if (level.zm_dm_labels.size == 0)
    {
        zm_dm_item("(empty page)", "none");
    }
    if (level.zm_dm_sel >= level.zm_dm_labels.size)
    {
        level.zm_dm_sel = 0;
    }
}

zm_dm_build_builtin(page)
{
    if (page == "main")
    {
        level.zm_dm_title = "MAIN";
        zm_dm_item("Player" + zm_dm_arrow(), "go player");
        zm_dm_item("Points" + zm_dm_arrow(), "go points");
        zm_dm_item("Rounds" + zm_dm_arrow(), "go rounds");
        zm_dm_item("Power-ups" + zm_dm_arrow(), "go powerups");
        zm_dm_item("Perks" + zm_dm_arrow(), "go perks");
        zm_dm_item("Weapons" + zm_dm_arrow(), "go weapons");
        zm_dm_item("Spawn zombies" + zm_dm_arrow(), "go spawn");
        zm_dm_item("Animations" + zm_dm_arrow(), "go cats");
        zm_dm_item("Zombies" + zm_dm_arrow(), "go zombies");
        zm_dm_item("Settings" + zm_dm_arrow(), "go settings");
        zm_dm_item("Close", "close");
    }
    else if (page == "player")
    {
        p = level.zm_dm_player;
        level.zm_dm_title = "PLAYER";
        zm_dm_item("God mode" + zm_dm_onoff(p.zm_dm_god), "toggle god");
        zm_dm_item("Zombies ignore me" + zm_dm_onoff(p.zm_dm_ignore), "toggle ignore");
        zm_dm_item("Infinite ammo" + zm_dm_onoff(p.zm_dm_ammo), "toggle ammo");
        zm_dm_item("Refill ammo", "refill");
        zm_dm_item("Speed: ^3x" + zm_dm_pval(p.zm_dm_speed), "cycle speed");
        zm_dm_item("Jump height: ^3x" + zm_dm_pval(p.zm_dm_jump), "cycle jump");
        zm_dm_item("Gravity: ^3" + zm_dm_grav_name(p.zm_dm_grav), "cycle grav");
        zm_dm_item("Save position", "savepos");
        saved = "  ^8(none saved)";
        if (isdefined(p.zm_dm_savepos))
        {
            saved = "";
        }
        zm_dm_item("Load position" + saved, "loadpos");
    }
    else if (page == "points")
    {
        level.zm_dm_title = "POINTS";
        zm_dm_item("+1,000 points", "points add 1000");
        zm_dm_item("+10,000 points", "points add 10000");
        zm_dm_item("+100,000 points", "points add 100000");
        zm_dm_item("Set to 1,000,000", "points set 1000000");
        zm_dm_item("Set to 0", "points set 0");
        zm_dm_item("Show my points", "points show 0");
    }
    else if (page == "rounds")
    {
        r = zm_dm_round_now();
        level.zm_dm_title = "ROUNDS (now " + r + ")";
        zm_dm_item("Next round", "round " + (r + 1));
        zm_dm_item("Skip 5 rounds", "round " + (r + 5));
        zm_dm_item("Skip 10 rounds", "round " + (r + 10));
        zm_dm_item("Go to round 10", "round 10");
        zm_dm_item("Go to round 20", "round 20");
        zm_dm_item("Go to round 30", "round 30");
        zm_dm_item("Go to round 50", "round 50");
        zm_dm_item("Go to round 100", "round 100");
    }
    else if (page == "weapons")
    {
        zm_dm_weapons_init();
        level.zm_dm_title = "WEAPONS";
        for (i = 0; i < level.zm_dm_wcat_ids.size; i++)
        {
            id = level.zm_dm_wcat_ids[i];
            zm_dm_item(level.zm_dm_wcat_names[i] + " (" + level.zm_dm_wlist[id].size + ")" + zm_dm_arrow(), "wcat " + id);
        }
        zm_dm_item("Pack-a-Punch +1 (now " + zm_dm_pap_level(level.zm_dm_player) + ")", "papup");
        zm_dm_item("Pack-a-Punch I", "pap 1");
        zm_dm_item("Pack-a-Punch II", "pap 2");
        zm_dm_item("Pack-a-Punch III", "pap 3");
        zm_dm_item("Pack-a-Punch IV", "pap 4");
        zm_dm_item("Rarity: Common", "rarity 0");
        zm_dm_item("Rarity: Uncommon", "rarity 1");
        zm_dm_item("Rarity: Rare", "rarity 2");
        zm_dm_item("Rarity: Epic", "rarity 3");
        zm_dm_item("Rarity: Legendary", "rarity 4");
        zm_dm_item("Rarity: Ultra", "rarity 5");
        zm_dm_item("Refill ammo", "refill");
        zm_dm_item("Remove held weapon", "wtake");
    }
    else if (page == "wlist")
    {
        id = level.zm_dm_wcat;
        level.zm_dm_title = "WEAPONS: " + id;
        list = level.zm_dm_wlist[id];
        fl = zm_dm_pg("weapons_" + id);
        if (fl != "")
        {
            list = strtok(fl, " ");
        }
        if (!isdefined(list))
        {
            list = [];
        }
        // real in-game names: each gun's own display name (a game text label, weapon.displayname),
        // read in the background the first time the category opens; until then the code name shows
        level.zm_wl_id = id;
        level.zm_wl_list = list;
        // in-game names as plain text (pages key wnames_<cat>, same order as the list)
        level.zm_wl_names = strtok(zm_dm_pg("wnames_" + level.zm_wl_id), "|");
        for (level.zm_wl_i = 0; level.zm_wl_i < level.zm_wl_list.size; level.zm_wl_i++)
        {
            level.zm_wl_lab = level.zm_wl_list[level.zm_wl_i];
            if (level.zm_wl_i < level.zm_wl_names.size && level.zm_wl_names[level.zm_wl_i] != "")
            {
                level.zm_wl_lab = level.zm_wl_names[level.zm_wl_i];
            }
            zm_dm_item(level.zm_wl_lab, "wgive " + level.zm_wl_id + " " + level.zm_wl_list[level.zm_wl_i]);
            // guns the game has no name for keep their code name (setting wdisp_skip, "cat name|...")
            if (isdefined(level.zm_dm_wdisp) && isdefined(level.zm_dm_wdisp[level.zm_wl_id + " " + level.zm_wl_list[level.zm_wl_i]]) && !issubstr("|" + zm_dm_str("wdisp_skip", "ar finch") + "|", "|" + level.zm_wl_id + " " + level.zm_wl_list[level.zm_wl_i] + "|"))
            {
                level.zm_dm_label_istr[level.zm_dm_labels.size - 1] = level.zm_dm_wdisp[level.zm_wl_id + " " + level.zm_wl_list[level.zm_wl_i]];
            }
        }
        if (!isdefined(level.zm_dm_wdisp_done) || !isdefined(level.zm_dm_wdisp_done[level.zm_wl_id]))
        {
            level thread zm_dm_wdisp_fill(level.zm_wl_id, level.zm_wl_list);
        }
    }
    else if (page == "perks")
    {
        // Read from the game's own perk table while the match runs (keys = perk names).
        zm_dm_perks_refresh();
        level.zm_dm_title = "PERKS (" + level.zm_dm_perks.size + ")";
        if (level.zm_dm_perks.size == 0)
        {
            zm_dm_item("No perks found on this map", "none");
        }
        else
        {
            zm_dm_item("Give all perks", "perkall");
            zm_dm_item("Eternal perks (kept when downed)", "perketernal");
        }
        for (i = 0; i < level.zm_dm_perks.size; i++)
        {
            k = level.zm_dm_perks[i];
            zm_dm_item(zm_dm_perk_label(k), "perk " + i);
        }
    }
    else if (page == "powerups")
    {
        level.zm_dm_title = "POWER-UPS";
        zm_dm_item("Double points", "pu double_points");
        zm_dm_item("Max ammo", "pu full_ammo");
        zm_dm_item("Max armor", "pu full_armor");
        zm_dm_item("Full power", "pu full_power");
        zm_dm_item("Free perk", "pu free_perk");
        zm_dm_item("Fire sale", "pu fire_sale");
        zm_dm_item("Nuke", "pu nuke");
        zm_dm_item("Bonus points", "pu bonus_points_team");
    }
    else if (page == "zombies")
    {
        level.zm_dm_title = "ZOMBIES";
        zm_dm_item("Target: ^3" + zm_dm_target_name(level.zm_dm_target), "target");
        zm_dm_item("Stop animations", "stop");
        zm_dm_item("Freeze / unfreeze target", "freeze");
        zm_dm_item("Kill target", "kill");
        zm_dm_item("Kill all zombies", "killall");
        zm_dm_item("Delete spawned AI (" + zm_dm_alive_spawned() + ")", "clear");
    }
    else if (page == "settings")
    {
        level.zm_dm_title = "SETTINGS";
        side = "left";
        if (zm_dm_num("panel_right", 1) == 1)
        {
            side = "right";
        }
        zm_dm_item("Colour: ^3" + level.zm_dm_theme_names[zm_dm_theme()], "theme");
        zm_dm_item("Side: ^3" + side, "side");
        zm_dm_item("Rows: ^3" + int(zm_dm_num("lines", 12)), "rows");
        zm_dm_item("Text mode (no panel)" + zm_dm_onoff(zm_dm_str("ui", "hud") == "print"), "textmode");
    }
    else if (page == "spawn")
    {
        // Categories (only what this map can spawn right now), each opening its own list.
        level.zm_dm_spawn_list = undefined;
        zm_dm_spawn_types();
        level.zm_dm_title = "SPAWN - " + level.zm_dm_spawn_list.size + " types on this map";
        if (level.zm_dm_spawn_list.size == 0)
        {
            zm_dm_item("Nothing from the list can spawn here right now", "none");
        }
        level.zm_sc_ids = ["boss", "hvt", "elite", "armored", "normal", "hound"];
        level.zm_sc_names = ["Bosses", "HVTs (high value targets)", "Elite zombies", "Armored zombies", "Normal zombies", "Hounds"];
        for (level.zm_sc_c = 0; level.zm_sc_c < level.zm_sc_ids.size; level.zm_sc_c++)
        {
            level.zm_sc_n = 0;
            for (level.zm_sc_j = 0; level.zm_sc_j < level.zm_dm_spawn_list.size; level.zm_sc_j++)
            {
                if (zm_dm_spawn_cat(level.zm_dm_spawn_list[level.zm_sc_j]) == level.zm_sc_ids[level.zm_sc_c])
                {
                    level.zm_sc_n++;
                }
            }
            if (level.zm_sc_n > 0)
            {
                zm_dm_item(level.zm_sc_names[level.zm_sc_c] + " (" + level.zm_sc_n + ")" + zm_dm_arrow(), "spawncat " + level.zm_sc_ids[level.zm_sc_c]);
            }
        }
    }
    else if (page == "fxall")
    {
        // every effect on this map, in groups of 25 (fun script reads the game's effect tables)
        level.zm_dm_fxc = 0;
        if (isdefined(level.zm_dmz_fxnames_fn))
        {
            level.zm_dm_fxc = [[ level.zm_dmz_fxnames_fn ]]();
        }
        level.zm_dm_title = "EFFECTS (" + level.zm_dm_fxc + ")";
        if (level.zm_dm_fxc == 0)
        {
            zm_dm_item("No effects found", "none");
        }
        for (level.zm_dm_fxi = 0; level.zm_dm_fxi < level.zm_dm_fxc; level.zm_dm_fxi = level.zm_dm_fxi + 25)
        {
            level.zm_dm_fxe = level.zm_dm_fxi + 25;
            if (level.zm_dm_fxe > level.zm_dm_fxc)
            {
                level.zm_dm_fxe = level.zm_dm_fxc;
            }
            zm_dm_item("Effects " + (level.zm_dm_fxi + 1) + " - " + level.zm_dm_fxe + zm_dm_arrow(), "fxgroup " + level.zm_dm_fxi);
        }
    }
    else if (page == "fxgrp")
    {
        level.zm_dm_title = "EFFECTS - GROUP " + (int(level.zm_dm_fxg / 25) + 1);
        for (level.zm_dm_fxi = level.zm_dm_fxg; level.zm_dm_fxi < level.zm_dm_fxg + 25 && level.zm_dm_fxi < level.zm_dmz_fx_names.size; level.zm_dm_fxi++)
        {
            // fixed row labels: every new menu text uses one of the game's limited text slots for the
            // whole session, 370 effect names would use them up; the name shows when it plays
            if (getdvar(@"phantom_menu_lua") == "1")
            {
                // add-on text has no text-slot limit: real names
                zm_dm_item(level.zm_dmz_fx_names[level.zm_dm_fxi], "zz fxplay " + level.zm_dmz_fx_names[level.zm_dm_fxi]);
            }
            else
            {
                zm_dm_item("Effect " + (level.zm_dm_fxi - level.zm_dm_fxg + 1), "zz fxplay " + level.zm_dmz_fx_names[level.zm_dm_fxi]);
            }
        }
    }
    else if (page == "mapscan")
    {
        // everything found on the map that is loaded right now (works on any map, new ones too)
        zm_dm_autodetect();
        level.zm_dm_spawn_list = undefined;
        zm_dm_spawn_types();
        zm_dm_props_scan();
        level.zm_ms_fx = 0;
        if (isdefined(level.zm_dmz_fxnames_fn))
        {
            level.zm_ms_fx = [[ level.zm_dmz_fxnames_fn ]]();
        }
        level.zm_ms_loc = 0;
        if (isdefined(level.zm_dmw_zones_fn))
        {
            level.zm_ms_loc = [[ level.zm_dmw_zones_fn ]]();
        }
        level.zm_dm_title = "MAP SCAN";
        zm_dm_item("Map: " + level.script, "none");
        zm_dm_item("Enemies you can spawn here: " + level.zm_dm_spawn_list.size + zm_dm_arrow(), "go spawn");
        zm_dm_item("Enemy types seen this match: " + level.zm_dm_auto_types.size, "none");
        zm_dm_item("Map props to spawn: " + level.zm_dm_mprops.size + zm_dm_arrow(), "go mprops");
        zm_dm_item("Effects: " + level.zm_ms_fx + zm_dm_arrow(), "go fxall");
        zm_dm_item("Locations: " + level.zm_ms_loc + zm_dm_arrow(), "go maplist");
        zm_dm_item("Rescan", "go mapscan");
        zm_dm_dbg("mapscan", level.script + " spawn " + level.zm_dm_spawn_list.size + " seen " + level.zm_dm_auto_types.size + " new " + level.zm_dm_auto_new + " props " + level.zm_dm_mprops.size + " fx " + level.zm_ms_fx + " loc " + level.zm_ms_loc);
    }
    else if (page == "wnew")
    {
        zm_dm_wscan();
        level.zm_dm_title = "NEW WEAPONS (" + level.zm_dm_wnew.size + ")";
        if (level.zm_dm_wnew.size == 0)
        {
            zm_dm_item("Nothing new on this map - every gun is in the menu", "none");
        }
        for (level.zm_wn_i = 0; level.zm_wn_i < level.zm_dm_wnew.size; level.zm_wn_i++)
        {
            zm_dm_item(zm_dm_wnew_label(level.zm_dm_wnew[level.zm_wn_i]), "wfull " + level.zm_dm_wnew[level.zm_wn_i]);
        }
        zm_dm_item("Rescan", "go wnew");
    }
    else if (page == "vehs")
    {
        level.zm_dm_title = "VEHICLES";
        if (!isdefined(level.zm_dmv_refs))
        {
            zm_dm_item("Vehicles script not loaded", "none");
        }
        else
        {
            zm_dm_item("Remove my vehicles", "veh clear");
            level.zm_vl_ok = zm_dm_str("veh_ok_list", "");
            for (level.zm_vl_i = 0; level.zm_vl_i < level.zm_dmv_refs.size; level.zm_vl_i++)
            {
                // only vehicles known to spawn (setting veh_ok_list " 1 5 9 "), or all when the list is empty
                if (level.zm_vl_ok != "" && !issubstr(" " + level.zm_vl_ok + " ", " " + (level.zm_vl_i + 1) + " "))
                {
                    continue;
                }
                level.zm_vl_l = level.zm_dmv_name[level.zm_vl_i];
                if (level.zm_vl_l == "")
                {
                    level.zm_vl_l = "Vehicle " + (level.zm_vl_i + 1);
                }
                zm_dm_item(level.zm_vl_l, "veh spawn " + level.zm_vl_i);
            }
        }
    }
    else if (page == "bfx")
    {
        // every loaded effect for a boss effect slot, in groups of 25
        level.zm_bx_c = 0;
        if (isdefined(level.zm_dmz_fxnames_fn))
        {
            level.zm_bx_c = [[ level.zm_dmz_fxnames_fn ]]();
        }
        level.zm_dm_title = "BOSS EFFECT " + level.zm_dm_bfxslot;
        zm_dm_item("No effect", "boss setfx" + level.zm_dm_bfxslot + " none");
        for (level.zm_bx_i = 0; level.zm_bx_i < level.zm_bx_c; level.zm_bx_i = level.zm_bx_i + 25)
        {
            level.zm_bx_e = level.zm_bx_i + 25;
            if (level.zm_bx_e > level.zm_bx_c)
            {
                level.zm_bx_e = level.zm_bx_c;
            }
            zm_dm_item("Effects " + (level.zm_bx_i + 1) + " - " + level.zm_bx_e + zm_dm_arrow(), "bfxgo " + level.zm_bx_i);
        }
    }
    else if (page == "bfxgrp")
    {
        level.zm_dm_title = "BOSS EFFECT " + level.zm_dm_bfxslot;
        for (level.zm_bx_i = level.zm_dm_bfxg; level.zm_bx_i < level.zm_dm_bfxg + 25 && level.zm_bx_i < level.zm_dmz_fx_names.size; level.zm_bx_i++)
        {
            zm_dm_item(level.zm_dmz_fx_names[level.zm_bx_i], "boss setfx" + level.zm_dm_bfxslot + " " + level.zm_dmz_fx_names[level.zm_bx_i]);
        }
    }
    else if (page == "bmodel")
    {
        zm_dm_props_scan();
        level.zm_dm_title = "BOSS LOOK";
        zm_dm_item("Its own body", "boss setmodel none");
        for (level.zm_bm_i = 0; level.zm_bm_i < level.zm_dm_mprops.size; level.zm_bm_i++)
        {
            zm_dm_item(level.zm_dm_mprops[level.zm_bm_i], "boss setmodel " + level.zm_dm_mprops[level.zm_bm_i]);
        }
    }
    else if (page == "bbase")
    {
        zm_dm_spawn_types();
        level.zm_dm_title = "BOSS BASE ENEMY";
        for (level.zm_bb_i = 0; level.zm_bb_i < level.zm_dm_spawn_list.size; level.zm_bb_i++)
        {
            zm_dm_item(zm_dm_short_type(level.zm_dm_spawn_list[level.zm_bb_i]), "boss setbase " + level.zm_dm_spawn_list[level.zm_bb_i]);
        }
    }
    else if (page == "bundles")
    {
        level.zm_dm_title = "BUNDLES FOR MY GUN";
        level.zm_bd_p = level.zm_dm_player;
        level.zm_bd_n = 0;
        if (isdefined(level.zm_dml_run))
        {
            level.zm_bd_p [[ level.zm_dml_run ]]("bundles", "");
            if (isdefined(level.zm_bd_p.zm_dml_bvars))
            {
                level.zm_bd_n = level.zm_bd_p.zm_dml_bvars.size;
            }
        }
        zm_dm_item("Plain version", "look bundle 0");
        if (level.zm_bd_n == 0)
        {
            zm_dm_item("No bundles for the gun you are holding", "none");
        }
        for (level.zm_bd_i = 0; level.zm_bd_i < level.zm_bd_n; level.zm_bd_i++)
        {
            zm_dm_item("Bundle " + level.zm_bd_p.zm_dml_bvars[level.zm_bd_i], "look bundle " + level.zm_bd_p.zm_dml_bvars[level.zm_bd_i]);
        }
    }
    else if (page == "ops" || page == "opskin" || page == "camos" || page == "camogrp")
    {
        zm_dm_looks_page(page);
    }
    else if (page == "mprops")
    {
        zm_dm_props_scan();
        level.zm_dm_title = "MAP PROPS (" + level.zm_dm_mprops.size + ")";
        if (level.zm_dm_mprops.size == 0)
        {
            zm_dm_item("No props found", "none");
        }
        for (level.zm_mp_i = 0; level.zm_mp_i < level.zm_dm_mprops.size; level.zm_mp_i++)
        {
            zm_dm_item(level.zm_dm_mprops[level.zm_mp_i], "zf spawnmodel " + level.zm_dm_mprops[level.zm_mp_i]);
        }
    }
    else if (page == "maplist")
    {
        // map locations from the game's zone list (world script)
        level.zm_dm_mlc = 0;
        if (isdefined(level.zm_dmw_zones_fn))
        {
            level.zm_dm_mlc = [[ level.zm_dmw_zones_fn ]]();
        }
        level.zm_dm_title = "MAP LOCATIONS (" + level.zm_dm_mlc + ")";
        if (level.zm_dm_mlc == 0 || !isdefined(level.zm_dmw_zone_names))
        {
            zm_dm_item("No locations found on this map", "none");
        }
        else
        {
            for (level.zm_dm_mli = 0; level.zm_dm_mli < level.zm_dmw_zone_names.size; level.zm_dm_mli++)
            {
                zm_dm_item(level.zm_dmw_zone_names[level.zm_dm_mli], "zw tpzone " + level.zm_dm_mli);
            }
        }
    }
    else if (page == "spawnlist")
    {
        zm_dm_spawn_types();
        level.zm_dm_title = "SPAWN - " + level.zm_dm_scat;
        for (level.zm_sc_j = 0; level.zm_sc_j < level.zm_dm_spawn_list.size; level.zm_sc_j++)
        {
            if (zm_dm_spawn_cat(level.zm_dm_spawn_list[level.zm_sc_j]) == level.zm_dm_scat)
            {
                zm_dm_item(zm_dm_short_type(level.zm_dm_spawn_list[level.zm_sc_j]), "spawn " + level.zm_dm_spawn_list[level.zm_sc_j]);
            }
        }
    }
    else if (page == "cats")
    {
        zm_dm_cats_build();
        level.zm_dm_title = "^5Animations^7 (" + level.zm_dm_cats.size + " groups)";
        if (level.zm_dm_cats.size == 0)
        {
            zm_dm_item("No animations loaded (zm_zz_devmenu_anims)", "none");
        }
        // groups that fit the targeted zombie first (green), then the rest
        level.zm_ct_ai = undefined;
        if (level.zm_dm_target == "look" || level.zm_dm_target == "nearest")
        {
            level.zm_ct_l = zm_dm_targets();
            if (isdefined(level.zm_ct_l) && level.zm_ct_l.size > 0)
            {
                level.zm_ct_ai = level.zm_ct_l[0];
            }
        }
        for (level.zm_ct_pass = 0; level.zm_ct_pass < 2; level.zm_ct_pass++)
        {
            for (level.zm_ct_i = 0; level.zm_ct_i < level.zm_dm_cats.size; level.zm_ct_i++)
            {
                level.zm_ct_c = level.zm_dm_cats[level.zm_ct_i];
                level.zm_ct_fit = isdefined(level.zm_ct_ai) && zm_dm_anim_fits(level.zm_ct_ai, "ai_" + level.zm_ct_c + "_x");
                if ((level.zm_ct_pass == 0) != level.zm_ct_fit)
                {
                    continue;
                }
                if (level.zm_ct_fit)
                {
                    zm_dm_item("^2" + level.zm_ct_c + " (" + level.zm_dm_cat_list[level.zm_ct_c].size + ")", "cat " + level.zm_ct_c);
                }
                else
                {
                    zm_dm_item(level.zm_ct_c + " (" + level.zm_dm_cat_list[level.zm_ct_c].size + ")", "cat " + level.zm_ct_c);
                }
            }
        }
    }
    else if (page == "anims")
    {
        level.zm_dm_title = "^5" + level.zm_dm_cat + "^7 -> " + zm_dm_target_name(level.zm_dm_target);
        if (isdefined(level.zm_dm_cat_list) && isdefined(level.zm_dm_cat_list[level.zm_dm_cat]))
        {
            list = level.zm_dm_cat_list[level.zm_dm_cat];
            for (i = 0; i < list.size; i++)
            {
                k = list[i];
                zm_dm_item(zm_dm_short_anim(level.zm_dm_anim_names[k]), "anim " + k);
            }
        }
    }
    if (level.zm_dm_sel >= level.zm_dm_labels.size)
    {
        level.zm_dm_sel = 0;
    }
}

zm_dm_item(label, value)
{
    i = level.zm_dm_labels.size;
    level.zm_dm_labels[i] = label;
    level.zm_dm_values[i] = value;
}

zm_dm_select()
{
    if (!level.zm_dm_open || level.zm_dm_values.size == 0)
    {
        return;
    }
    v = level.zm_dm_values[level.zm_dm_sel];
    zm_dm_dbg("selected", v);
    zm_dm_do(strtok(v, " "));
}

// One action (word list). Used by menu rows, the pages file and remote "do <action>".
// Several actions in one row: separate them with ";" (e.g. "pap 4;rarity 5").
zm_dm_do(w)
{
    if (!isdefined(w) || w.size == 0)
    {
        return;
    }
    line = "";
    for (zm_fi8 = 0; zm_fi8 < w.size; zm_fi8++)
    {
        x = w[zm_fi8];
        line = line + x + " ";
    }
    if (issubstr(line, ";"))
    {
        parts = strtok(line, ";");
        for (zm_fi9 = 0; zm_fi9 < parts.size; zm_fi9++)
        {
            part = parts[zm_fi9];
            zm_dm_do(strtok(part, " "));
        }
        return;
    }
    c = w[0];
    if (c == "none")
    {
        return;
    }
    if (c == "go")
    {
        zm_dm_go(w[1]);
        return;
    }
    if (c == "back")
    {
        zm_dm_back();
        return;
    }
    if (c == "cat")
    {
        level.zm_dm_stack[level.zm_dm_stack.size] = level.zm_dm_page + "|" + level.zm_dm_sel + "|" + level.zm_dm_cat;
        level.zm_dm_cat = w[1];
        level.zm_dm_page = "anims";
        level.zm_dm_sel = 0;
        zm_dm_build();
        zm_dm_draw();
        return;
    }
    if (c == "spawn")
    {
        zm_dm_spawn(w[1], int(zm_dm_num("spawn_count", 1)));
    }
    else if (c == "anim")
    {
        zm_dm_play_index(int(w[1]));
    }
    else if (c == "target")
    {
        zm_dm_next_target();
    }
    else if (c == "stop")
    {
        zm_dm_stop_all();
    }
    else if (c == "freeze")
    {
        zm_dm_freeze_targets();
    }
    else if (c == "clear")
    {
        zm_dm_clear();
    }
    else if (c == "close")
    {
        zm_dm_set_open(0);
        return;
    }
    else
    {
        zm_dm_select_more(w);
    }
    zm_dm_build();
    zm_dm_draw();
}

// Player / zombies / settings actions for the menu owner (level.zm_dm_player).
zm_dm_select_more(w)
{
    if (zm_dm_select_new(w))
    {
        return;
    }
    p = level.zm_dm_player;
    c = w[0];
    if (c == "toggle" && w[1] == "god")
    {
        p.zm_dm_god = 1 - zm_dm_flag(p.zm_dm_god);
        p zm_dm_god_apply();
        if (p.zm_dm_god)
        {
            zm_dm_tell("god mode on");
        }
        else
        {
            zm_dm_tell("god mode off");
        }
    }
    else if (c == "toggle" && w[1] == "ammo")
    {
        // The game's own infinite ammo (setinfiniteammo, as FuzMenu uses).
        level.zm_dm_player.zm_dm_ammo = 1 - zm_dm_flag(level.zm_dm_player.zm_dm_ammo);
        level.zm_dm_player setinfiniteammo(level.zm_dm_player.zm_dm_ammo);
        if (level.zm_dm_player.zm_dm_ammo)
        {
            level.zm_dm_player zm_dm_refill_self();
        }
        zm_dm_tell("infinite ammo " + zm_dm_onoff(level.zm_dm_player.zm_dm_ammo));
    }
    else if (c == "refill")
    {
        level.zm_dm_player zm_dm_refill_self();
        zm_dm_tell("ammo refilled");
    }
    else if (c == "cycle" && w[1] == "speed")
    {
        p.zm_dm_speed = zm_dm_next_val(zm_dm_pval(p.zm_dm_speed), level.zm_dm_speeds);
        p setmovespeedscale(p.zm_dm_speed);
        zm_dm_tell("speed x" + p.zm_dm_speed);
    }
    else if (c == "cycle" && w[1] == "jump")
    {
        // Game's own jump height scale on the player (function_92305205d36aa2e1).
        p.zm_dm_jump = zm_dm_next_val(zm_dm_pval(p.zm_dm_jump), level.zm_dm_jumps);
        p function_92305205d36aa2e1(p.zm_dm_jump);
        zm_dm_tell("jump height x" + p.zm_dm_jump);
    }
    else if (c == "cycle" && w[1] == "grav")
    {
        // Game's own gravity scale on the player (function_b628f3a02e5332e6).
        p.zm_dm_grav = zm_dm_next_val(zm_dm_pval(p.zm_dm_grav), level.zm_dm_gravs);
        p function_b628f3a02e5332e6(p.zm_dm_grav);
        zm_dm_tell("gravity " + zm_dm_grav_name(p.zm_dm_grav));
    }
    else if (c == "toggle" && (w[1] == "rapid" || w[1] == "requip" || w[1] == "iequip" || w[1] == "golden"))
    {
        zm_dm_extra_toggle(w[1]);
    }
    else if (c == "armor" && w.size > 1)
    {
        if (!isdefined(level.zm_dmx_armor))
        {
            zm_dm_tell("^1armor isn't available (extra script not loaded)");
        }
        else
        {
            level.zm_dm_player [[ level.zm_dmx_armor ]](int(w[1]));
            zm_dm_tell("armor: " + w[1] + " plate(s)");
        }
    }
    else if (c == "zw" && w.size > 1)
    {
        // Zombies + World options (zm_zz_devmenu_world.gsc)
        if (!isdefined(level.zm_dmw_run))
        {
            zm_dm_tell("^1not available (world script not loaded)");
        }
        else
        {
            level.zm_zw_v = "";
            if (w.size > 2)
            {
                level.zm_zw_v = w[2];
            }
            level.zm_zw_msg = level.zm_dm_player [[ level.zm_dmw_run ]](w[1], level.zm_zw_v);
            if (isdefined(level.zm_zw_msg))
            {
                zm_dm_tell(level.zm_zw_msg);
            }
        }
    }
    else if (c == "bgnext")
    {
        zm_dm_bg_next();
    }
    else if (c == "toggle" && w[1] == "ignore")
    {
        p.zm_dm_ignore = 1 - zm_dm_flag(p.zm_dm_ignore);
        p.ignoreme = p.zm_dm_ignore;
        zm_dm_tell("zombies ignore me" + zm_dm_onoff(p.zm_dm_ignore));
    }
    else if (c == "savepos")
    {
        p.zm_dm_savepos = p.origin;
        p.zm_dm_saveang = p getplayerangles();
        zm_dm_tell("position saved");
    }
    else if (c == "loadpos")
    {
        if (isdefined(p.zm_dm_savepos))
        {
            p setorigin(p.zm_dm_savepos);
            p setplayerangles(p.zm_dm_saveang);
            zm_dm_tell("position loaded");
        }
        else
        {
            zm_dm_tell("no position saved yet");
        }
    }
    else if (c == "points")
    {
        // The game's own points functions (script_2301d27669c5a079, registered as shared
        // functions points / add_points, set_points, get_points). They run on the player.
        n = int(w[2]);
        if (w[1] == "add")
        {
            p namespace_c40c7bec6c50de09::function_95df551cd7179ba3(n);
        }
        else if (w[1] == "set")
        {
            p namespace_c40c7bec6c50de09::function_40dc4b206b63ac2e(n);
        }
        now = p namespace_c40c7bec6c50de09::function_8f0a9502ff7321a();
        if (!isdefined(now))
        {
            now = "?";
        }
        zm_dm_tell("points: " + now);
    }
    else if (c == "wcat")
    {
        level.zm_dm_stack[level.zm_dm_stack.size] = level.zm_dm_page + "|" + level.zm_dm_sel + "|" + level.zm_dm_cat;
        level.zm_dm_wcat = w[1];
        level.zm_dm_page = "wlist";
        level.zm_dm_sel = 0;
    }
    else if (c == "wgive")
    {
        zm_dm_give_weapon(p, w[1], w[2]);
    }
    else if (c == "pap" || c == "papup")
    {
        if (isdefined(p.zm_dm_busy))
        {
            zm_dm_tell("still busy with the last weapon change");
        }
        else
        {
            if (c == "papup")
            {
                p.zm_dm_pap_tier = zm_dm_pap_level(p) + 1;
            }
            else
            {
                p.zm_dm_pap_tier = int(w[1]);
            }
            p thread zm_dm_pap_worker();
        }
    }
    else if (c == "rarity")
    {
        p.zm_dm_rarity_want = int(w[1]);
        p zm_dm_rarity();
    }
    else if (c == "wtake")
    {
        cur = p getcurrentweapon();
        if (!isdefined(cur) || isnullweapon(cur))
        {
            cur = p.currentweapon;
        }
        if (isdefined(cur) && !isnullweapon(cur))
        {
            p takeweapon(cur);
            p zm_dm_switch_any();
            zm_dm_tell("removed held weapon");
        }
        else
        {
            zm_dm_tell("^1no weapon in your hands");
        }
    }
    else if (c == "perk")
    {
        i = int(w[1]);
        if (isdefined(level.zm_dm_perks[i]))
        {
            zm_dm_give_perk(p, level.zm_dm_perks[i]);
        }
    }
    else if (c == "perkall")
    {
        zm_dm_perks_refresh();
        if (level.zm_dm_perks.size == 0)
        {
            zm_dm_tell("^1no perks found on this map");
        }
        for (i = 0; i < level.zm_dm_perks.size; i++)
        {
            zm_dm_give_perk(p, level.zm_dm_perks[i]);
        }
    }
    else if (c == "perketernal")
    {
        // All perks, made eternal (kept when you go down): game loot_perks functions.
        zm_dm_perks_refresh();
        level.zm_dm_player thread zm_dm_eternal_worker();
    }
    else if (c == "round")
    {
        zm_dm_round_jump(int(w[1]));
    }
    else if (c == "entry" && w.size > 1)
    {
        zm_dm_entry_cmd(w);
    }
    else if (c == "store" && w.size > 4)
    {
        // store <store> <file> <key> <value words...>: write another mod's setting, e.g.
        // "store spawnmenu settings run spawn <type> 1 300" drives zm_zspawn.
        level.zm_dm_st_v = w[4];
        for (level.zm_dm_st_i = 5; level.zm_dm_st_i < w.size; level.zm_dm_st_i++)
        {
            level.zm_dm_st_v = level.zm_dm_st_v + " " + w[level.zm_dm_st_i];
        }
        nengine_store_load(w[1], w[2]);
        nengine_store_set(w[1], w[3], level.zm_dm_st_v);
        nengine_store_save(w[1], w[2]);
        zm_dm_tell(w[1] + " " + w[3] + " = " + level.zm_dm_st_v);
    }
    else if (c == "tp" && w.size > 3)
    {
        p setorigin((float(w[1]), float(w[2]), float(w[3])));
        zm_dm_tell("teleported");
    }
    else if (c == "roundrel")
    {
        zm_dm_round_jump(zm_dm_round_now() + int(w[1]));
    }
    else if (c == "dvar" && w.size > 2)
    {
        setdvar(w[1], w[2]);
        zm_dm_tell("dvar " + w[1] + " = " + w[2]);
    }
    else if (c == "say")
    {
        t = "";
        for (i = 1; i < w.size; i++)
        {
            t = t + w[i] + " ";
        }
        zm_dm_tell(t);
    }
    else if (c == "spawnn" && w.size > 2)
    {
        zm_dm_spawn(w[1], int(w[2]));
    }
    else if (c == "pu")
    {
        // Game power-up drop (powerups / dropPowerup) on top of you, so it is picked up at
        // once. Only names in the map's power-up table (powerups / hash_a25fdc7ee24539fb).
        if (!zm_dm_powerup_known(w[1]))
        {
            zm_dm_tell("^1power-up not on this map:^7 " + w[1]);
        }
        else
        {
            level thread zm_dm_drop(w[1], p.origin + (0, 0, 40));
            zm_dm_tell("power-up " + w[1]);
        }
    }
    else if (c == "kill")
    {
        level.zm_dm_kill_list = zm_dm_targets();
        level thread zm_dm_kill_worker();
    }
    else if (c == "killall")
    {
        level.zm_dm_kill_list = zm_dm_zombies();
        level thread zm_dm_kill_worker();
    }
    else if (c == "deltarget")
    {
        zm_dm_delete_targets();
    }
    else if (c == "freezeall")
    {
        level.zm_dm_freeze_all = 1 - zm_dm_flag(level.zm_dm_freeze_all);
        if (level.zm_dm_freeze_all)
        {
            level thread zm_dm_freeze_all_loop();
            zm_dm_tell("all zombies frozen");
        }
        else
        {
            zm_dm_unfreeze_all();
            zm_dm_tell("all zombies unfrozen");
        }
    }
    else if (c == "spawncat")
    {
        level.zm_dm_stack[level.zm_dm_stack.size] = level.zm_dm_page + "|" + level.zm_dm_sel + "|" + level.zm_dm_cat;
        level.zm_dm_scat = w[1];
        level.zm_dm_page = "spawnlist";
        level.zm_dm_sel = 0;
    }
    else if (c == "theme")
    {
        t = zm_dm_theme() + 1;
        if (t >= level.zm_dm_theme_colors.size)
        {
            t = 0;
        }
        zm_dm_store("theme", t);
        nengine_store_set("devmenu", "accent_rgb", "");
        nengine_store_set("devmenu", "preset_name", "");
        nengine_store_save("devmenu", "settings");
    }
    else if (c == "side")
    {
        r = 1;
        if (zm_dm_num("panel_right", 1) == 1)
        {
            r = 0;
        }
        zm_dm_store("panel_right", r);
    }
    else if (c == "rows")
    {
        r = int(zm_dm_num("lines", 12)) + 2;
        if (r > 16)
        {
            r = 6;
        }
        zm_dm_store("lines", r);
    }
    else if (c == "textmode")
    {
        if (zm_dm_str("ui", "hud") == "print")
        {
            zm_dm_store("ui", "hud");
        }
        else
        {
            zm_dm_store("ui", "print");
            zm_dm_hud_hide();
        }
    }
}

// Weapon lists by type, from the weapon model files in cod25 (mp_av_sat_vm_<type>_<name>_*),
// without part files (stock, muzzle, mag ...). Full name tried: sat_<type>_<name>_mp,
// then _zm, then sat_<type>_<name>.
zm_dm_weapons_init()
{
    if (isdefined(level.zm_dm_wlist))
    {
        return;
    }
    level.zm_dm_wlist = [];
    level.zm_dm_wcat_ids = [];
    level.zm_dm_wcat_names = [];
    zm_dm_wcat_add("ar", "Assault rifles", "albatross condor eagle egret emu falcon finch hawk heron kite kiwi macaw vulture wren");
    zm_dm_wcat_add("sm", "SMGs", "bear bengal civet cobra gecko hyena komodo mammoth marmot orca otter puma serval stoat zebra");
    zm_dm_wcat_add("lm", "LMGs", "hades hildr typhon zeus");
    zm_dm_wcat_add("sh", "Shotguns", "akita corso husky shepherd terrier");
    zm_dm_wcat_add("dm", "Marksman rifles", "kara oman samar scotia solomon tasman");
    zm_dm_wcat_add("sn", "Sniper rifles", "aden baltic caspian coral drake");
    zm_dm_wcat_add("pi", "Pistols", "alcor atlas orion timir handcannon");
    zm_dm_wcat_add("la", "Launchers", "fang polis");
    zm_dm_wcat_add("me", "Melee", "ballisticknife castor elnath knife maru nashira saiph shockbaton wasat");
    zm_dm_wcat_add("ww", "Wonder weapons", "raygun raygunmark2 firefly hornet locust mantis ruby scarab");
}

zm_dm_wcat_add(id, title, names)
{
    i = level.zm_dm_wcat_ids.size;
    level.zm_dm_wcat_ids[i] = id;
    level.zm_dm_wcat_names[i] = title;
    level.zm_dm_wlist[id] = strtok(names, " ");
}

// self = player. God mode the way the game allows it: takedamage off (when the game's
// damage flag level.var_c998633bab11f3f8 is on) and health kept at max. Not while downed.
zm_dm_god_apply()
{
    on = zm_dm_flag(self.zm_dm_god);
    if (isdefined(level.var_c998633bab11f3f8) && level.var_c998633bab11f3f8)
    {
        if (on)
        {
            self.takedamage = 0;
        }
        else
        {
            self.takedamage = 1;
        }
    }
    if (on && !zm_dm_flag(self.inlaststand) && isdefined(self.maxhealth))
    {
        if (!isdefined(self.health) || self.health < self.maxhealth)
        {
            self.health = self.maxhealth;
        }
    }
}

// ---------------------------------------------------------------- weapons
// Weapon names: the game knows a gun when weaponexists(name) or level.weaponmapdata[name]
// is set. Tried in order: sat_<type>_<name>, then _zm, then _mp (Ray Guns are _mp).
zm_dm_weapon_known(name)
{
    if (isdefined(level.weaponmapdata) && isdefined(level.weaponmapdata[name]))
    {
        return 1;
    }
    if (weaponexists(name))
    {
        return 1;
    }
    return 0;
}

zm_dm_weapon_name(cat, n)
{
    base = "sat_" + cat + "_" + n;
    if (zm_dm_weapon_known(base))
    {
        return base;
    }
    if (zm_dm_weapon_known(base + "_zm"))
    {
        return base + "_zm";
    }
    if (zm_dm_weapon_known(base + "_mp"))
    {
        return base + "_mp";
    }
    return undefined;
}

zm_dm_give_weapon(p, cat, n)
{
    name = zm_dm_weapon_name(cat, n);
    if (!isdefined(name))
    {
        zm_dm_tell("^1not on this map:^7 sat_" + cat + "_" + n);
        return;
    }
    if (isdefined(p.zm_dm_busy))
    {
        zm_dm_tell("still busy with the last weapon change");
        return;
    }
    p.zm_dm_wname = name;
    zm_dm_tell("loading " + name + " ...");
    p thread zm_dm_give_worker();
}

// self = player. weapons::buildweapon(name, default attachments), done in its own thread
// (the build may wait a frame), result read back from a field.
zm_dm_build_worker()
{
    self.zm_dm_wbuilt = weapon::buildweapon(self.zm_dm_wname, getweapondefaultattachments(self.zm_dm_wname));
}

// self = player. Build, stream the gun in (up to 3 s), make room (3 guns max; melee doesn't
// count), give, put in a primary slot, switch, fill ammo, then check it really arrived.
// Every value lives on self: Kronos GSC loses locals across a wait.
zm_dm_give_worker()
{
    self.zm_dm_busy = 1;
    self.zm_dm_wbuilt = undefined;
    self thread zm_dm_build_worker();
    waitframe();
    waitframe();
    if (!isdefined(self.zm_dm_wbuilt) || isnullweapon(self.zm_dm_wbuilt) || (isdefined(level.weaponnone) && self.zm_dm_wbuilt == level.weaponnone))
    {
        zm_dm_tell("^1could not build^7 " + self.zm_dm_wname);
        zm_dm_dbg("wgive", "build failed " + self.zm_dm_wname);
        self.zm_dm_busy = undefined;
        return;
    }
    self loadweaponsforplayer([self.zm_dm_wbuilt], 1);
    for (self.zm_dm_wtry = 0; self.zm_dm_wtry < 30; self.zm_dm_wtry++)
    {
        if (self hasloadedviewweapons([self.zm_dm_wbuilt]))
        {
            break;
        }
        wait 0.1;
    }
    // Melee wonder weapons (Jotunn Star) go to the melee slot.
    if (weapon::function_6b74ecd475e99b4(self.zm_dm_wbuilt) || issubstr(self.zm_dm_wname, "ww_locust"))
    {
        self.zm_dm_wold = self.var_cc1262e66dbb1c79;
        if (isdefined(self.zm_dm_wold) && !isnullweapon(self.zm_dm_wold) && self.zm_dm_wold != self.zm_dm_wbuilt)
        {
            self takeweapon(self.zm_dm_wold);
        }
        self giveweapon(self.zm_dm_wbuilt, undefined, 0, -1, 0);
        self weapon::function_b4c9549dee5d0fc5(self.zm_dm_wbuilt);
    }
    else
    {
        self zm_dm_make_room();
        if (isdefined(self.zm_dm_wdrop))
        {
            self takeweapon(self.zm_dm_wdrop);
            wait 0.1;
        }
        self giveweapon(self.zm_dm_wbuilt, undefined, 0, -1, 0);
        self assignweaponprimaryslot(self.zm_dm_wbuilt);
        self switchtoweapon(self.zm_dm_wbuilt);
    }
    self zm_dm_fill(self.zm_dm_wbuilt);
    wait 0.25;
    if (!self hasweapon(self.zm_dm_wbuilt))
    {
        // Still full: swap out whatever is in your hands and try once more.
        self.zm_dm_wold = self getcurrentweapon();
        if (isdefined(self.zm_dm_wold) && !isnullweapon(self.zm_dm_wold))
        {
            self takeweapon(self.zm_dm_wold);
            wait 0.1;
        }
        self giveweapon(self.zm_dm_wbuilt, undefined, 0, -1, 0);
        self assignweaponprimaryslot(self.zm_dm_wbuilt);
        self switchtoweapon(self.zm_dm_wbuilt);
        self zm_dm_fill(self.zm_dm_wbuilt);
        wait 0.25;
    }
    if (self hasweapon(self.zm_dm_wbuilt))
    {
        zm_dm_tell("weapon " + self.zm_dm_wname);
        zm_dm_dbg("wgive", "ok " + self.zm_dm_wname);
    }
    else
    {
        zm_dm_tell("^1weapon not taken:^7 " + self.zm_dm_wname);
        zm_dm_dbg("wgive", "not held " + self.zm_dm_wname);
    }
    self.zm_dm_busy = undefined;
}

// self = player. Sets self.zm_dm_wdrop to the gun to take before a new one (the held gun
// when you already carry 3), else undefined. getweaponslistprimaries returns nothing in
// BO7, so guns come from primaryinventory (melee "_me_" left out).
zm_dm_make_room()
{
    self.zm_dm_wdrop = undefined;
    if (!isdefined(self.primaryinventory) || self hasweapon(self.zm_dm_wbuilt))
    {
        return;
    }
    // Fields, not locals (Kronos quirk); FuzMenu does the same here.
    self.zm_dm_guns = [];
    for (self.zm_dm_gi = 0; self.zm_dm_gi < self.primaryinventory.size; self.zm_dm_gi++)
    {
        self.zm_dm_g = self.primaryinventory[self.zm_dm_gi];
        if (isdefined(self.zm_dm_g) && !isnullweapon(self.zm_dm_g) && isdefined(self.zm_dm_g.basename) && !issubstr(self.zm_dm_g.basename, "_me_"))
        {
            self.zm_dm_guns[self.zm_dm_guns.size] = self.zm_dm_g;
        }
    }
    zm_dm_dbg("guns", self.zm_dm_guns.size);
    if (self.zm_dm_guns.size < 3)
    {
        return;
    }
    self.zm_dm_wdrop = self.zm_dm_guns[0];
    self.zm_dm_wcur = self getcurrentweapon();
    for (self.zm_dm_gi = 0; self.zm_dm_gi < self.zm_dm_guns.size; self.zm_dm_gi++)
    {
        if (self.zm_dm_guns[self.zm_dm_gi] == self.zm_dm_wcur)
        {
            self.zm_dm_wdrop = self.zm_dm_wcur;
        }
    }
}

// self = player. After taking the held gun, switch to any gun still carried.
zm_dm_switch_any()
{
    if (!isdefined(self.primaryinventory))
    {
        return;
    }
    for (zm_fi12 = 0; zm_fi12 < self.primaryinventory.size; zm_fi12++)
    {
        g = self.primaryinventory[zm_fi12];
        if (isdefined(g) && !isnullweapon(g))
        {
            self switchtoweapon(g);
            return;
        }
    }
}

// self = player. Full clip + full stock (and the underbarrel / alt mode).
zm_dm_fill(w)
{
    if (!isdefined(w) || isnullweapon(w))
    {
        return;
    }
    self zm_dm_fill_one(w);
    alt = w getaltweapon();
    if (isdefined(alt) && !isnullweapon(alt))
    {
        self zm_dm_fill_one(alt);
    }
}

zm_dm_fill_one(w)
{
    self givemaxammo(w);
    clip = weaponclipsize(w);
    if (isdefined(clip) && clip > 0)
    {
        self setweaponammoclip(w, clip);
    }
    stock = utility::get_max_stock_ammo(w);
    if (isdefined(stock) && stock > 0)
    {
        self setweaponammostock(w, stock);
    }
}

// self = player. The gun Pack-a-Punch / rarity act on: the held gun when it is a real
// carried gun, else the first carried gun.
zm_dm_pick_gun()
{
    // fields, not locals: a local can come back empty after the zm_dm_gun_index call (Kronos quirk),
    // which made Pack-a-Punch fall back to the first gun instead of the held one
    self.zm_dm_pg_w = self getcurrentweapon();
    if (isdefined(self.zm_dm_pg_w) && !isnullweapon(self.zm_dm_pg_w))
    {
        self.zm_dm_pg_i = self zm_dm_gun_index(self.zm_dm_pg_w);
        if (isdefined(self.zm_dm_pg_i))
        {
            return self.zm_dm_pg_w;
        }
    }
    if (isdefined(self.primaryinventory))
    {
        for (self.zm_dm_pg_j = 0; self.zm_dm_pg_j < self.primaryinventory.size; self.zm_dm_pg_j++)
        {
            if (isdefined(self.primaryinventory[self.zm_dm_pg_j]) && !isnullweapon(self.primaryinventory[self.zm_dm_pg_j]))
            {
                return self.primaryinventory[self.zm_dm_pg_j];
            }
        }
    }
    return undefined;
}

// self = player. Slot of w in primaryinventory, or undefined.
zm_dm_gun_index(w)
{
    self.zm_dm_gi_w = w;
    if (!isdefined(self.primaryinventory))
    {
        return undefined;
    }
    for (self.zm_dm_gi_k = 0; self.zm_dm_gi_k < self.primaryinventory.size; self.zm_dm_gi_k++)
    {
        if (isdefined(self.primaryinventory[self.zm_dm_gi_k]) && !isnullweapon(self.primaryinventory[self.zm_dm_gi_k]) && (self.primaryinventory[self.zm_dm_gi_k] == self.zm_dm_gi_w || issameweapon(self.primaryinventory[self.zm_dm_gi_k], self.zm_dm_gi_w)))
        {
            return self.zm_dm_gi_k;
        }
    }
    return undefined;
}

// Pack-a-Punch level (0-4) of the gun p holds: game pack_a_punch / get_pap_level.
zm_dm_pap_level(p)
{
    if (!isdefined(p))
    {
        return 0;
    }
    p.zm_dm_pl_p = p;
    p.zm_dm_pl_w = p zm_dm_pick_gun();
    if (!isdefined(p.zm_dm_pl_w))
    {
        return 0;
    }
    p.zm_dm_pl_lv = p utility::callsharedfunc(#"pack_a_punch", #"get_pap_level", p.zm_dm_pl_w);
    if (!isdefined(p.zm_dm_pl_lv) || p.zm_dm_pl_lv < 0)
    {
        return 0;
    }
    return p.zm_dm_pl_lv;
}

// self = player. Game pack_a_punch / pap_weapon(gun, current level, 0, undefined,
// undefined, 0, 0, target tier) gives back the upgraded gun.
zm_dm_pap_call()
{
    self.zm_dm_papnew = self utility::callsharedfunc(#"pack_a_punch", #"pap_weapon", self.zm_dm_papgun, self.zm_dm_paplv, 0, undefined, undefined, 0, 0, self.zm_dm_pap_tier);
}

// self = player. Fallback: pack_a_punch / rebuild_pap_weapon(base gun, tier, ammo mod).
zm_dm_pap_rebuild()
{
    self.zm_dm_papmod = undefined;
    if (utility::issharedfuncdefined(#"ammo_mod", #"hash_cf1012c4d313de70"))
    {
        self.zm_dm_papmod = self utility::callsharedfunc(#"ammo_mod", #"hash_cf1012c4d313de70", self.zm_dm_papbase);
    }
    self.zm_dm_papnew = self utility::callsharedfunc(#"pack_a_punch", #"rebuild_pap_weapon", self.zm_dm_papbase, self.zm_dm_pap_tier, self.zm_dm_papmod);
}

// self = player. Pack-a-Punch the gun to self.zm_dm_pap_tier (1-4).
zm_dm_pap_worker()
{
    self.zm_dm_busy = 1;
    if (self.zm_dm_pap_tier > 4)
    {
        self.zm_dm_pap_tier = 4;
    }
    if (!utility::issharedfuncdefined(#"pack_a_punch", #"pap_weapon"))
    {
        zm_dm_tell("^1Pack-a-Punch is not on this map");
        self.zm_dm_busy = undefined;
        return;
    }
    if (!isdefined(self.var_66c0acd81fb4e585))
    {
        self.var_66c0acd81fb4e585 = [];
    }
    level.var_eda995bb839c4aa = 4;
    self.zm_dm_papgun = self zm_dm_pick_gun();
    if (!isdefined(self.zm_dm_papgun))
    {
        zm_dm_tell("^1no gun to Pack-a-Punch");
        self.zm_dm_busy = undefined;
        return;
    }
    self.zm_dm_paplv = zm_dm_pap_level(self);
    if (self.zm_dm_paplv >= self.zm_dm_pap_tier)
    {
        zm_dm_tell("already Pack-a-Punch " + self.zm_dm_paplv);
        self.zm_dm_busy = undefined;
        return;
    }
    self.zm_dm_papnew = undefined;
    self thread zm_dm_pap_call();
    waitframe();
    waitframe();
    if (isdefined(self.zm_dm_papnew) && !isnullweapon(self.zm_dm_papnew))
    {
        self assignweaponprimaryslot(self.zm_dm_papnew);
        self switchtoweapon(self.zm_dm_papnew);
        self zm_dm_fill(self.zm_dm_papnew);
        wait 0.1;
    }
    else if (utility::issharedfuncdefined(#"pack_a_punch", #"rebuild_pap_weapon"))
    {
        self.zm_dm_papbase = self.zm_dm_papgun getnoaltweapon();
        if (!isdefined(self.zm_dm_papbase) || isnullweapon(self.zm_dm_papbase))
        {
            self.zm_dm_papbase = self.zm_dm_papgun;
        }
        self.zm_dm_papnew = undefined;
        self thread zm_dm_pap_rebuild();
        waitframe();
        waitframe();
        if (isdefined(self.zm_dm_papnew) && !isnullweapon(self.zm_dm_papnew))
        {
            self takeweapon(self.zm_dm_papgun);
            self giveweapon(self.zm_dm_papnew, undefined, 0, -1, 1);
            self assignweaponprimaryslot(self.zm_dm_papnew);
            self zm_dm_fill(self.zm_dm_papnew);
            self switchtoweapon(self.zm_dm_papnew);
            self utility::callsharedfunc(#"pack_a_punch", #"set_pap_level", self.zm_dm_papnew, self.zm_dm_pap_tier, 1, self.zm_dm_papbase);
        }
    }
    if (!isdefined(self.zm_dm_papnew) || isnullweapon(self.zm_dm_papnew))
    {
        zm_dm_tell("^1Pack-a-Punch failed");
        zm_dm_dbg("pap", "failed tier " + self.zm_dm_pap_tier);
    }
    else
    {
        zm_dm_tell("Pack-a-Punch " + self.zm_dm_pap_tier);
        zm_dm_dbg("pap", "ok tier " + self.zm_dm_pap_tier);
    }
    self.zm_dm_busy = undefined;
}

// self = player. Rarity 0 Common .. 5 Ultra of the held gun: game shared function
// zombie / hash_e546039029657cd5 (max rarity level.var_48e2b36291b57f44 must allow 5).
// Checked through the player's per-slot weapon data (var_1a87a9e7cf39ff69[slot].rarity).
zm_dm_rarity()
{
    r = self.zm_dm_rarity_want;
    if (!utility::issharedfuncdefined(#"zombie", #"hash_e546039029657cd5"))
    {
        zm_dm_tell("^1rarity is not on this map");
        return;
    }
    w = self zm_dm_pick_gun();
    if (!isdefined(w))
    {
        zm_dm_tell("^1no gun for rarity");
        return;
    }
    level.var_48e2b36291b57f44 = 5;
    self utility::callsharedfunc(#"zombie", #"hash_e546039029657cd5", w, r, 1);
    idx = self zm_dm_gun_index(w);
    now = "?";
    if (isdefined(idx) && isdefined(self.var_1a87a9e7cf39ff69) && isdefined(self.var_1a87a9e7cf39ff69[idx]) && isdefined(self.var_1a87a9e7cf39ff69[idx].rarity))
    {
        now = self.var_1a87a9e7cf39ff69[idx].rarity;
    }
    zm_dm_tell("rarity " + zm_dm_rarity_name(r) + " (game says " + now + ")");
    zm_dm_dbg("rarity", "want " + r + " now " + now);
}

zm_dm_rarity_name(r)
{
    names = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Ultra"];
    if (r >= 0 && r < names.size)
    {
        return names[r];
    }
    return "" + r;
}

// Perk names = keys of the game's perk table level.var_35cae1d5b8f6f7c2. Choice / random
// slots are left out (they are not a perk you can be given).
zm_dm_perks_refresh()
{
    level.zm_dm_perks = [];
    if (!isdefined(level.var_35cae1d5b8f6f7c2))
    {
        return;
    }
    keys = getarraykeys(level.var_35cae1d5b8f6f7c2);
    for (i = 0; i < keys.size; i++)
    {
        k = keys[i];
        if (isstring(k) && !issubstr(k, "choice"))
        {
            level.zm_dm_perks[level.zm_dm_perks.size] = k;
        }
    }
}

zm_dm_perk_label(k)
{
    if (issubstr(k, "specialty_"))
    {
        k = removesubstr(k, "specialty_");
    }
    return k;
}

// Game give_perk / has_perk (loot_perks shared functions), run on the player.
zm_dm_give_perk(p, k)
{
    if (p namespace_377106c4017f7cda::function_e183e1e4f906ec3b(k))
    {
        zm_dm_tell("already have " + zm_dm_perk_label(k));
        return;
    }
    p namespace_377106c4017f7cda::function_a969ec70f9242aa4(k, 0);
    zm_dm_tell("perk " + zm_dm_perk_label(k));
}

// Current round: level.round_number, else the round system's own number
// (level.var_6781718da4f78d1c, field var_392f37fdba9f6777 / roundnumber).
zm_dm_round_now()
{
    if (isdefined(level.round_number))
    {
        return level.round_number;
    }
    rs = level.var_6781718da4f78d1c;
    if (isdefined(rs) && isdefined(rs.var_392f37fdba9f6777))
    {
        return rs.var_392f37fdba9f6777;
    }
    if (isdefined(rs) && isdefined(rs.roundnumber))
    {
        return rs.roundnumber;
    }
    return 0;
}

// Round skip by round state (round system .state): 1 = round running -> set the next-round
// override level.var_dc917abcf5b8f749 and end the round (spawner state 2, or the game's
// round-end notify); otherwise (between rounds) set the round number directly.
zm_dm_round_jump(n)
{
    if (n < 1)
    {
        n = 1;
    }
    // The game's own "set next round" (namespace_7942a9cf653f89, script_77dca3b46e01eb1e):
    // its dev "previous round" and skip-to-round commands call it with any number, so it
    // goes back as well as forward. Setting round_mode 1 = the old way below.
    if (zm_dm_num("round_mode", 0) == 0)
    {
        level.zm_dm_rj_target = n;
        level.zm_dm_rj_tries = 0;
        level.zm_dm_rj_from = zm_dm_round_now();
        level thread namespace_7942a9cf653f89::function_68bdb49c82c0f892(n);
        zm_dm_tell("^3going to round " + n + "...");
        zm_dm_dbg("round_jump", n + " game (from " + level.zm_dm_rj_from + ")");
        level notify("zm_dm_rj_new");
        level thread zm_dm_round_watch();
        return;
    }
    rs = level.var_6781718da4f78d1c;
    if (!isdefined(rs))
    {
        zm_dm_tell("^1round system not found");
        return;
    }
    st = 0;
    if (isdefined(rs.state))
    {
        st = rs.state;
    }
    if (st == 1 && isdefined(level.var_a009ab14ee0d3223))
    {
        level.var_dc917abcf5b8f749 = n;
        level.var_a009ab14ee0d3223.state = 2;
    }
    else if (st == 1)
    {
        level.var_dc917abcf5b8f749 = n;
        rs notify(#"hash_ebf555762278f138");
    }
    else
    {
        rs.roundnumber = n;
        level.round_number = n;
        if (st == 2)
        {
            level.var_dc917abcf5b8f749 = n;
        }
    }
    zm_dm_tell("going to round " + n + " (state " + st + ")");
    zm_dm_dbg("round_jump", n + " state " + st);
}

zm_dm_powerup_known(name)
{
    if (!utility::issharedfuncdefined(#"powerups", #"dropPowerup") || !utility::issharedfuncdefined(#"powerups", #"hash_a25fdc7ee24539fb"))
    {
        return 0;
    }
    root = utility::callsharedfunc(#"powerups", #"hash_a25fdc7ee24539fb");
    if (!isdefined(root) || !isdefined(root.powerups) || !isdefined(root.powerups[name]))
    {
        return 0;
    }
    return 1;
}

zm_dm_drop(name, origin)
{
    utility::callsharedfunc(#"powerups", #"dropPowerup", name, origin, undefined, undefined, undefined, 0);
}

// Rapid fire / rapid equipment / infinite equipment / golden armor (extra script, fields only).
zm_dm_extra_toggle(k)
{
    level.zm_xt_p = level.zm_dm_player;
    if (!isdefined(level.zm_dmx_rapid))
    {
        zm_dm_tell("^1not available (extra script not loaded)");
        return;
    }
    if (k == "rapid")
    {
        level.zm_xt_p.zm_dm_rapid = 1 - zm_dm_flag(level.zm_xt_p.zm_dm_rapid);
        level.zm_xt_p [[ level.zm_dmx_rapid ]](level.zm_xt_p.zm_dm_rapid);
        zm_dm_tell("rapid fire" + zm_dm_onoff(level.zm_xt_p.zm_dm_rapid));
        return;
    }
    if (k == "golden")
    {
        level.zm_xt_p.zm_dm_golden = 1 - zm_dm_flag(level.zm_xt_p.zm_dm_golden);
        level.zm_xt_ok = level.zm_xt_p [[ level.zm_dmx_golden ]](level.zm_xt_p.zm_dm_golden);
        zm_dm_tell("golden armor" + zm_dm_onoff(level.zm_xt_p.zm_dm_golden));
        return;
    }
    level.zm_xt_p [[ level.zm_dmx_equip_start ]]();
    if (k == "requip")
    {
        level.zm_xt_p.zm_dm_requip = 1 - zm_dm_flag(level.zm_xt_p.zm_dm_requip);
        zm_dm_tell("rapid equipment" + zm_dm_onoff(level.zm_xt_p.zm_dm_requip));
    }
    else
    {
        level.zm_xt_p.zm_dm_iequip = 1 - zm_dm_flag(level.zm_xt_p.zm_dm_iequip);
        zm_dm_tell("infinite equipment" + zm_dm_onoff(level.zm_xt_p.zm_dm_iequip));
    }
}

// Background list from the pages file (bg_list "name|name:frames:ms|..." written by
// toolsaddbg.js), plus "none". Picks the next one; the panel rebuilds with it.
zm_dm_bg_next()
{
    level.zm_bg_list = strtok(zm_dm_pg("bg_list"), "|");
    level.zm_bg_cur = zm_dm_str("hud_bg_image", "");
    level.zm_bg_next = "none";
    if (level.zm_bg_list.size > 0)
    {
        level.zm_bg_next = level.zm_bg_list[0];
    }
    for (level.zm_bg_i = 0; level.zm_bg_i < level.zm_bg_list.size; level.zm_bg_i++)
    {
        if (level.zm_bg_list[level.zm_bg_i] == level.zm_bg_cur)
        {
            if (level.zm_bg_i + 1 < level.zm_bg_list.size)
            {
                level.zm_bg_next = level.zm_bg_list[level.zm_bg_i + 1];
            }
            else
            {
                level.zm_bg_next = "none";
            }
        }
    }
    zm_dm_store("hud_bg_image", level.zm_bg_next);
    zm_dm_tell("background: " + zm_dm_bg_label(level.zm_bg_next));
}

zm_dm_bg_label(v)
{
    if (!isdefined(v) || v == "" || v == "none")
    {
        return "none";
    }
    level.zm_bgl = strtok(v, ":");
    if (level.zm_bgl.size >= 2)
    {
        return level.zm_bgl[0] + " (animated)";
    }
    return level.zm_bgl[0];
}

zm_dm_store(key, value)
{
    nengine_store_set("devmenu", key, value);
    nengine_store_save("devmenu", "settings");
}

zm_dm_flag(v)
{
    if (isdefined(v) && v)
    {
        return 1;
    }
    return 0;
}

zm_dm_pval(v)
{
    if (!isdefined(v))
    {
        return 1;
    }
    return v;
}

// Next value after cur in list (wraps round).
zm_dm_next_val(cur, list)
{
    for (i = 0; i < list.size; i++)
    {
        if (list[i] == cur)
        {
            if (i + 1 < list.size)
            {
                return list[i + 1];
            }
            return list[0];
        }
    }
    return list[0];
}

zm_dm_grav_name(v)
{
    v = zm_dm_pval(v);
    if (v == 1)
    {
        return "normal";
    }
    if (v == 0.5)
    {
        return "low";
    }
    if (v == 0.25)
    {
        return "very low";
    }
    return "moon";
}

zm_dm_arrow()
{
    return "  ^3>";
}

zm_dm_onoff(on)
{
    if (isdefined(on) && on)
    {
        return "  ^2ON";
    }
    return "  ^8OFF";
}

zm_dm_theme()
{
    t = int(zm_dm_num("theme", 0));
    if (t < 0 || t >= level.zm_dm_theme_colors.size)
    {
        return 0;
    }
    return t;
}

zm_dm_refill(p)
{
    p zm_dm_refill_self();
}

// self = player. Fills every carried gun (clip + stock + alt mode) and equipment. All values
// on self: the old version passed them in locals, which Kronos lost on the way (refill did
// nothing in game).
zm_dm_refill_self()
{
    self.zm_rf_list = self.primaryinventory;
    if (isdefined(self.zm_rf_list))
    {
        for (self.zm_rf_i = 0; self.zm_rf_i < self.zm_rf_list.size; self.zm_rf_i++)
        {
            self.zm_rf_w = self.zm_rf_list[self.zm_rf_i];
            if (isdefined(self.zm_rf_w) && !isnullweapon(self.zm_rf_w))
            {
                self zm_dm_fill_field();
            }
        }
    }
    self.zm_rf_w = self getcurrentweapon();
    if (isdefined(self.zm_rf_w) && !isnullweapon(self.zm_rf_w))
    {
        self zm_dm_fill_field();
    }
    self.zm_rf_list = self getweaponslistoffhands();
    if (isdefined(self.zm_rf_list))
    {
        for (self.zm_rf_i = 0; self.zm_rf_i < self.zm_rf_list.size; self.zm_rf_i++)
        {
            if (isdefined(self.zm_rf_list[self.zm_rf_i]) && !isnullweapon(self.zm_rf_list[self.zm_rf_i]))
            {
                self givemaxammo(self.zm_rf_list[self.zm_rf_i]);
            }
        }
    }
}

// self = player, weapon in self.zm_rf_w.
zm_dm_fill_field()
{
    self givemaxammo(self.zm_rf_w);
    self.zm_rf_clip = weaponclipsize(self.zm_rf_w);
    if (!isdefined(self.zm_rf_clip) || self.zm_rf_clip <= 0)
    {
        // weaponclipsize gave nothing (seen: rifle stayed at 0 rounds after refill); the game
        // clamps a too-big clip to the real size
        self.zm_rf_clip = 999;
    }
    self setweaponammoclip(self.zm_rf_w, self.zm_rf_clip);
    self.zm_rf_stock = utility::get_max_stock_ammo(self.zm_rf_w);
    if (isdefined(self.zm_rf_stock) && self.zm_rf_stock > 0)
    {
        self setweaponammostock(self.zm_rf_w, self.zm_rf_stock);
    }
    self.zm_rf_alt = self.zm_rf_w getaltweapon();
    if (isdefined(self.zm_rf_alt) && !isnullweapon(self.zm_rf_alt))
    {
        self givemaxammo(self.zm_rf_alt);
    }
}

// The zombie team's AI (like FuzMenu): getaiarray() alone also returns AI that can't be
// killed (sleeping / scripted / protected), so kill all "killed 38" but 1 died.
zm_dm_zombies()
{
    if (isdefined(level.zombie_team))
    {
        return getaiarray(level.zombie_team);
    }
    return getaiarray("team_two_hundred");
}

zm_dm_protected(ai)
{
    if (zm_dm_flag(ai.b_ignore_cleanup) || zm_dm_flag(ai.magic_bullet_shield) || zm_dm_flag(ai.damageshield))
    {
        return 1;
    }
    return 0;
}

// Kills level.zm_dm_kill_list one per frame (the game's own clean-up flags first).
zm_dm_kill_worker()
{
    level.zm_dm_kill_n = 0;
    level.zm_dm_kill_skip = 0;
    if (!isdefined(level.zm_dm_kill_list))
    {
        level.zm_dm_kill_list = [];
    }
    for (level.zm_dm_kill_i = 0; level.zm_dm_kill_i < level.zm_dm_kill_list.size; level.zm_dm_kill_i++)
    {
        level.zm_dm_kill_ai = level.zm_dm_kill_list[level.zm_dm_kill_i];
        if (!isdefined(level.zm_dm_kill_ai) || !isalive(level.zm_dm_kill_ai))
        {
            continue;
        }
        if (zm_dm_protected(level.zm_dm_kill_ai))
        {
            level.zm_dm_kill_skip++;
            continue;
        }
        if (isdefined(level.zm_dm_kill_ai.zm_dm_anchor))
        {
            level.zm_dm_kill_ai unlink();
            level.zm_dm_kill_ai.zm_dm_anchor delete();
        }
        level.zm_dm_kill_ai.no_powerups = 1;
        level.zm_dm_kill_ai.b_cleaned_up = 1;
        level.zm_dm_kill_ai kill();
        level.zm_dm_kill_n++;
        waitframe();
    }
    zm_dm_tell("killed " + level.zm_dm_kill_n + " zombies (" + level.zm_dm_kill_skip + " protected)");
}

// self = player. Gives every perk, then makes each one eternal (kept when downed): game
// loot_perks has-eternal function_b8960d650787a048 / make-eternal function_3c5c75cec72d90aa.
zm_dm_eternal_worker()
{
    self.zm_et_n = 0;
    for (self.zm_et_i = 0; self.zm_et_i < level.zm_dm_perks.size; self.zm_et_i++)
    {
        self.zm_et_k = level.zm_dm_perks[self.zm_et_i];
        if (!self namespace_377106c4017f7cda::function_e183e1e4f906ec3b(self.zm_et_k))
        {
            self namespace_377106c4017f7cda::function_a969ec70f9242aa4(self.zm_et_k, 0);
            waitframe();
        }
        if (!self namespace_377106c4017f7cda::function_b8960d650787a048(self.zm_et_k))
        {
            self namespace_377106c4017f7cda::function_3c5c75cec72d90aa(self.zm_et_k);
            waitframe();
        }
        if (self namespace_377106c4017f7cda::function_b8960d650787a048(self.zm_et_k))
        {
            self.zm_et_n++;
        }
    }
    zm_dm_tell("eternal perks: " + self.zm_et_n + " of " + level.zm_dm_perks.size);
}

// Freeze all zombies (FuzMenu's way): link each to a fixed script_origin; new spawns are
// caught every 0.25 s while it is on.
zm_dm_freeze_all_loop()
{
    while (zm_dm_flag(level.zm_dm_freeze_all))
    {
        level.zm_fz_list = zm_dm_zombies();
        for (level.zm_fz_i = 0; level.zm_fz_i < level.zm_fz_list.size; level.zm_fz_i++)
        {
            level.zm_fz_ai = level.zm_fz_list[level.zm_fz_i];
            if (isdefined(level.zm_fz_ai) && isalive(level.zm_fz_ai) && !isdefined(level.zm_fz_ai.zm_dm_anchor) && !zm_dm_protected(level.zm_fz_ai))
            {
                zm_dm_freeze_one(level.zm_fz_ai);
            }
        }
        wait 0.25;
    }
}

zm_dm_freeze_one(ai)
{
    ai.zm_dm_anchor = spawn("script_origin", ai.origin);
    ai linkto(ai.zm_dm_anchor);
}

zm_dm_unfreeze_one(ai)
{
    ai unlink();
    if (isdefined(ai.zm_dm_anchor))
    {
        ai.zm_dm_anchor delete();
    }
    ai.zm_dm_anchor = undefined;
}

zm_dm_unfreeze_all()
{
    level.zm_fz_list = getaiarray();
    for (level.zm_fz_i = 0; level.zm_fz_i < level.zm_fz_list.size; level.zm_fz_i++)
    {
        level.zm_fz_ai = level.zm_fz_list[level.zm_fz_i];
        if (isdefined(level.zm_fz_ai) && isdefined(level.zm_fz_ai.zm_dm_anchor))
        {
            zm_dm_unfreeze_one(level.zm_fz_ai);
        }
    }
}

// Every tick, for the menu owner: god mode, infinite ammo, and keeping jump / gravity /
// speed / ignore-me applied.
zm_dm_player_tick()
{
    p = level.zm_dm_player;
    if (!isdefined(p))
    {
        return;
    }
    // God mode is switched on by itself on every map load (setting no_auto_god 1 turns this off)
    if (!isdefined(p.zm_dm_autogod_done) && level.zm_dm_ticks > 40)
    {
        p.zm_dm_autogod_done = 1;
        if (zm_dm_num("no_auto_god", 0) != 1)
        {
            p.zm_dm_god = 1;
            p zm_dm_god_apply();
            zm_dm_dbg("auto_god", "on");
        }
    }
    if (zm_dm_flag(p.zm_dm_god) && level.zm_dm_ticks % 10 == 0)
    {
        p zm_dm_god_apply();
    }
    if (zm_dm_flag(level.zm_dm_player.zm_dm_ammo) && level.zm_dm_ticks % 20 == 3)
    {
        // game infinite ammo kept on, plus a top-up once a second as a backup
        level.zm_dm_player setinfiniteammo(1);
        level.zm_dm_player zm_dm_refill_self();
    }
    // Jump / gravity / ignore-me: re-applied every second in case the game resets them
    // (it sets them itself on some perks and on respawn).
    if (level.zm_dm_ticks % 20 == 0)
    {
        if (zm_dm_pval(p.zm_dm_jump) != 1)
        {
            p function_92305205d36aa2e1(p.zm_dm_jump);
        }
        if (zm_dm_pval(p.zm_dm_grav) != 1)
        {
            p function_b628f3a02e5332e6(p.zm_dm_grav);
        }
        if (zm_dm_flag(p.zm_dm_ignore))
        {
            p.ignoreme = 1;
        }
        if (zm_dm_pval(p.zm_dm_speed) != 1)
        {
            p setmovespeedscale(p.zm_dm_speed);
        }
    }
}

// Draws the current page. On-screen panel from zm_zz_devmenu_hud.gsc when it loaded and
// works; otherwise one centre-screen line (previous / current / next), because BO7's
// centre text shows one line at a time.
// Setting ui: "hud" (or "both") = panel with automatic fallback, "print" = centre line only.
zm_dm_draw()
{
    if (!level.zm_dm_open)
    {
        return;
    }
    p = level.zm_dm_player;
    if (!isdefined(p) || level.zm_dm_labels.size == 0)
    {
        return;
    }
    rows = int(zm_dm_num("lines", 12));
    if (rows < 3)
    {
        rows = 3;
    }
    if (rows > 16)
    {
        rows = 16;
    }
    // Scrolling list: the selected row stays near the middle (the panel animates the scroll);
    // at the start / end of a list it can't, so the window stops there.
    level.zm_dm_top = level.zm_dm_sel - int(rows / 2);
    if (level.zm_dm_top > level.zm_dm_labels.size - rows)
    {
        level.zm_dm_top = level.zm_dm_labels.size - rows;
    }
    if (level.zm_dm_top < 0)
    {
        level.zm_dm_top = 0;
    }
    pos = (level.zm_dm_sel + 1) + "/" + level.zm_dm_labels.size;
    ui = zm_dm_str("ui", "hud");
    shown = 0;
    if (ui != "print" && isdefined(level.zm_dm_hud_create))
    {
        theme = zm_dm_theme();
        x = int(zm_dm_num("panel_x", 20));
        if (zm_dm_num("panel_right", 1) == 1)
        {
            x = 640 - 270 - x;
        }
        // Level fields from here on: locals came back empty after the call into the
        // panel script (Kronos quirk), so the built panel was never seen.
        level.zm_dw_rows = rows;
        level.zm_dw_pos = pos;
        level.zm_dw_ui = ui;
        level.zm_dw_shown = 0;
        level.zm_dw_acc = level.zm_dm_theme_colors[theme];
        level.zm_dw_accs = zm_dm_str("accent_rgb", "");
        if (level.zm_dw_accs != "" && level.zm_dw_accs != "0")
        {
            level.zm_dw_acp = strtok(level.zm_dw_accs, " ");
            if (level.zm_dw_acp.size == 3)
            {
                level.zm_dw_acc = (float(level.zm_dw_acp[0]), float(level.zm_dw_acp[1]), float(level.zm_dw_acp[2]));
            }
        }
        level.zm_dw_key = rows + "|" + theme + "|" + x + "|" + zm_dm_str("hud_bg_image", "") + "|" + level.zm_dw_accs + "|" + zm_dm_num("hud_bg_tint", 0.45);
        if (!isdefined(level.zm_dm_player.zm_dmh) || level.zm_dm_player.zm_dmh.key != level.zm_dw_key)
        {
            level.zm_dw_ok = level.zm_dm_player [[ level.zm_dm_hud_create ]](level.zm_dw_rows, x, 70, level.zm_dw_acc, level.zm_dw_key);
            zm_dm_dbg("hud", level.zm_dw_ok);
        }
        if (isdefined(level.zm_dm_player.zm_dmh))
        {
            level.zm_dw_list = "";
            level.zm_dw_istr = [];
            for (level.zm_dw_r = 0; level.zm_dw_r < level.zm_dw_rows && level.zm_dm_top + level.zm_dw_r < level.zm_dm_labels.size; level.zm_dw_r++)
            {
                if (isdefined(level.zm_dm_label_istr[level.zm_dm_top + level.zm_dw_r]))
                {
                    level.zm_dw_istr[level.zm_dw_r] = level.zm_dm_label_istr[level.zm_dm_top + level.zm_dw_r];
                }
                if (level.zm_dw_r > 0)
                {
                    level.zm_dw_list = level.zm_dw_list + "\n";
                }
                level.zm_dw_list = level.zm_dw_list + "^7" + level.zm_dm_labels[level.zm_dm_top + level.zm_dw_r];
            }
            level.zm_dw_foot = "[{+speed_throw}] Up   [{+attack}] Down   [{+activate}] Select   [{+melee}] Back";
            level.zm_dm_player [[ level.zm_dm_hud_show ]]("PHANTOM MENU", level.zm_dm_title, level.zm_dw_list, level.zm_dm_sel - level.zm_dm_top, level.zm_dw_foot);
            level.zm_dw_shown = 1;
            zm_dm_dbg("hud_step", "shown " + level.zm_dw_pos);
            zm_dm_pic_update();
        }
        shown = level.zm_dw_shown;
        ui = level.zm_dw_ui;
        pos = level.zm_dw_pos;
        p = level.zm_dm_player;
    }
    if (!shown && ui != "print")
    {
        // Panel failed: no centre-screen text unless the player chose text mode.
        zm_dm_dbg("hud_step", "panel failed " + pos);
        return;
    }
    if (!shown)
    {
        line = "^3> " + level.zm_dm_labels[level.zm_dm_sel] + " ^3<";
        if (level.zm_dm_sel > 0)
        {
            line = "^7" + level.zm_dm_labels[level.zm_dm_sel - 1] + "   " + line;
        }
        if (level.zm_dm_sel + 1 < level.zm_dm_labels.size)
        {
            line = line + "   ^7" + level.zm_dm_labels[level.zm_dm_sel + 1];
        }
        p iprintlnbold(level.zm_dm_title + " ^7" + pos + "   " + line);
        zm_dm_dbg("hud_step", "text mode " + pos);
    }
}

zm_dm_hud_hide()
{
    level.zm_pu_last = "";
    setdvar(@"phantom_pic", "");
    // the add-on writes "1" (logo file is the original), "0" (changed) or "?" (could not check)
    setdvar(@"phantom_logo_ok", "");
    p = level.zm_dm_player;
    if (isdefined(p) && isdefined(level.zm_dm_hud_destroy))
    {
        p [[ level.zm_dm_hud_destroy ]]();
    }
}

zm_dm_say(text)
{
    level.zm_dm_last = text;
    zm_dm_dbg("last", text);
}

// ---------------------------------------------------------------- spawning

zm_dm_types_refresh()
{
    s = zm_dm_str("types", "");
    if (s != "")
    {
        level.zm_dm_types = strtok(s, "|");
    }
    else
    {
        level.zm_dm_types = level.zm_dm_types_all;
    }
}

zm_dm_short_type(t)
{
    w = strtok(t, "_");
    s = "";
    for (i = 0; i < w.size; i++)
    {
        if (w[i] == "sat" || w[i] == "spawner")
        {
            continue;
        }
        if (s == "")
        {
            s = w[i];
        }
        else
        {
            s = s + " " + w[i];
        }
    }
    return s;
}

zm_dm_spawn(type, count)
{
    // All values on level fields, like zm_zspawn (the spawner that works): in Kronos GSC a
    // local can come back empty after calling another script function.
    level.zm_dm_sp_type = type;
    level.zm_dm_sp_count = count;
    if (level.zm_dm_sp_count < 1)
    {
        level.zm_dm_sp_count = 1;
    }
    if (level.zm_dm_sp_count > 24)
    {
        level.zm_dm_sp_count = 24;
    }
    level.zm_dm_sp_dist = zm_dm_num("spawn_dist", 300);
    level.zm_dm_sp_scale = zm_dm_num("spawn_scale", 1);
    if (!isdefined(level.zm_dm_player))
    {
        return;
    }
    level.zm_dm_ok = 0;
    for (level.zm_dm_sp_i = 0; level.zm_dm_sp_i < level.zm_dm_sp_count; level.zm_dm_sp_i++)
    {
        zm_dm_spawn_one();
    }
    if (level.zm_dm_ok == 0)
    {
        zm_dm_tell("^1not loaded on this map:^7 " + level.zm_dm_sp_type);
    }
    else
    {
        zm_dm_tell("spawned " + level.zm_dm_ok + " x " + level.zm_dm_sp_type);
    }
}

// One AI, spread in an arc in front of the player (same maths as zm_zspawn).
zm_dm_spawn_one()
{
    p = level.zm_dm_player;
    yaw = 0;
    a = p.angles;
    if (isdefined(a))
    {
        yaw = a[1];
    }
    off = 0;
    if (level.zm_dm_sp_count > 1)
    {
        off = (level.zm_dm_sp_i - (level.zm_dm_sp_count - 1) / 2) * 12;
    }
    dir = anglestoforward((0, yaw + off, 0));
    pos = p.origin + dir * level.zm_dm_sp_dist;
    ai = namespace_85d424ad210ad4c9::function_35dc52fde01c4d08(level.zm_dm_sp_type, pos, (0, yaw + 180, 0), "axis");
    if (isdefined(ai))
    {
        level.zm_dm_ok++;
        level.zm_dm_spawned[level.zm_dm_spawned.size] = ai;
        if (level.zm_dm_sp_scale != 1)
        {
            ai setscale(level.zm_dm_sp_scale);
        }
    }
}

zm_dm_alive_spawned()
{
    n = 0;
    for (i = 0; i < level.zm_dm_spawned.size; i++)
    {
        if (isdefined(level.zm_dm_spawned[i]))
        {
            n++;
        }
    }
    return n;
}

// Deletes the AI you spawned (fields only).
zm_dm_clear()
{
    level.zm_dm_del_list = level.zm_dm_spawned;
    level.zm_dm_spawned = [];
    zm_dm_delete_list();
}

// Deletes the current target(s) (look / nearest / spawned / all zombies).
zm_dm_delete_targets()
{
    level.zm_dm_del_list = zm_dm_targets();
    zm_dm_delete_list();
}

zm_dm_delete_list()
{
    level.zm_dm_del_n = 0;
    for (level.zm_dm_del_i = 0; level.zm_dm_del_i < level.zm_dm_del_list.size; level.zm_dm_del_i++)
    {
        level.zm_dm_del_ai = level.zm_dm_del_list[level.zm_dm_del_i];
        if (isdefined(level.zm_dm_del_ai))
        {
            if (isdefined(level.zm_dm_del_ai.zm_dm_anchor))
            {
                level.zm_dm_del_ai unlink();
                level.zm_dm_del_ai.zm_dm_anchor delete();
            }
            level.zm_dm_del_ai delete();
            level.zm_dm_del_n++;
        }
    }
    zm_dm_tell("deleted " + level.zm_dm_del_n + " AI");
}

// ---------------------------------------------------------------- targets

zm_dm_target_name(t)
{
    if (t == "nearest")
    {
        return "nearest AI";
    }
    if (t == "spawned")
    {
        return "all I spawned";
    }
    if (t == "all")
    {
        return "all AI";
    }
    return "AI I look at";
}

zm_dm_next_target()
{
    t = level.zm_dm_target;
    if (t == "look")
    {
        t = "nearest";
    }
    else if (t == "nearest")
    {
        t = "spawned";
    }
    else if (t == "spawned")
    {
        t = "all";
    }
    else
    {
        t = "look";
    }
    level.zm_dm_target = t;
    nengine_store_set("devmenu", "target", t);
    nengine_store_save("devmenu", "settings");
}

// Returns the AI list for the current target mode. Everything on level fields: the old
// version kept its result in a local that Kronos lost after the zombie-list call (kill /
// freeze on "look" and "nearest" did nothing).
zm_dm_targets()
{
    level.zm_tg_t = level.zm_dm_target;
    level.zm_tg_out = [];
    if (level.zm_tg_t == "spawned")
    {
        for (level.zm_tg_i = 0; level.zm_tg_i < level.zm_dm_spawned.size; level.zm_tg_i++)
        {
            if (isdefined(level.zm_dm_spawned[level.zm_tg_i]))
            {
                level.zm_tg_out[level.zm_tg_out.size] = level.zm_dm_spawned[level.zm_tg_i];
            }
        }
        return level.zm_tg_out;
    }
    // zombie team + what you spawned (getaiarray() alone held AI that can't be affected)
    level.zm_tg_ais = zm_dm_zombies();
    if (!isdefined(level.zm_tg_ais))
    {
        level.zm_tg_ais = [];
    }
    for (level.zm_tg_i = 0; level.zm_tg_i < level.zm_dm_spawned.size; level.zm_tg_i++)
    {
        level.zm_tg_ai = level.zm_dm_spawned[level.zm_tg_i];
        if (isdefined(level.zm_tg_ai) && (!isdefined(level.zombie_team) || !isdefined(level.zm_tg_ai.team) || level.zm_tg_ai.team != level.zombie_team))
        {
            level.zm_tg_ais[level.zm_tg_ais.size] = level.zm_tg_ai;
        }
    }
    if (level.zm_tg_t == "all")
    {
        return level.zm_tg_ais;
    }
    level.zm_tg_p = level.zm_dm_player;
    if (!isdefined(level.zm_tg_p))
    {
        return level.zm_tg_out;
    }
    level.zm_tg_eye = level.zm_tg_p.origin + (0, 0, 60);
    level.zm_tg_f = anglestoforward(level.zm_tg_p getplayerangles());
    level.zm_tg_best = undefined;
    level.zm_tg_bs = -1;
    for (level.zm_tg_i = 0; level.zm_tg_i < level.zm_tg_ais.size; level.zm_tg_i++)
    {
        level.zm_tg_ai = level.zm_tg_ais[level.zm_tg_i];
        if (!isdefined(level.zm_tg_ai) || !isalive(level.zm_tg_ai))
        {
            continue;
        }
        level.zm_tg_d = (level.zm_tg_ai.origin + (0, 0, 40)) - level.zm_tg_eye;
        level.zm_tg_dd = level.zm_tg_d[0] * level.zm_tg_d[0] + level.zm_tg_d[1] * level.zm_tg_d[1] + level.zm_tg_d[2] * level.zm_tg_d[2];
        if (level.zm_tg_dd < 1)
        {
            continue;
        }
        if (level.zm_tg_t == "nearest")
        {
            level.zm_tg_sc = 100000000 - level.zm_tg_dd;
        }
        else
        {
            level.zm_tg_dot = level.zm_tg_d[0] * level.zm_tg_f[0] + level.zm_tg_d[1] * level.zm_tg_f[1] + level.zm_tg_d[2] * level.zm_tg_f[2];
            if (level.zm_tg_dot <= 0)
            {
                continue;
            }
            level.zm_tg_c2 = level.zm_tg_dot * level.zm_tg_dot / level.zm_tg_dd;
            if (level.zm_tg_c2 < 0.9)
            {
                continue;
            }
            level.zm_tg_sc = level.zm_tg_c2 * 100000000 - level.zm_tg_dd * 0.01;
        }
        if (level.zm_tg_sc > level.zm_tg_bs)
        {
            level.zm_tg_bs = level.zm_tg_sc;
            level.zm_tg_best = level.zm_tg_ai;
        }
    }
    if (isdefined(level.zm_tg_best))
    {
        level.zm_tg_out[0] = level.zm_tg_best;
    }
    return level.zm_tg_out;
}

// Freeze / unfreeze the current target(s): fixed script_origin anchor + linkto (FuzMenu's
// way); unlink + delete the anchor to let go. Fields only.
zm_dm_freeze_targets()
{
    level.zm_fz_list = zm_dm_targets();
    level.zm_fz_on = 0;
    level.zm_fz_off = 0;
    for (level.zm_fz_i = 0; level.zm_fz_i < level.zm_fz_list.size; level.zm_fz_i++)
    {
        level.zm_fz_ai = level.zm_fz_list[level.zm_fz_i];
        if (!isdefined(level.zm_fz_ai) || !isalive(level.zm_fz_ai))
        {
            continue;
        }
        if (isdefined(level.zm_fz_ai.zm_dm_anchor))
        {
            zm_dm_unfreeze_one(level.zm_fz_ai);
            level.zm_fz_off++;
        }
        else
        {
            zm_dm_freeze_one(level.zm_fz_ai);
            level.zm_fz_on++;
        }
    }
    zm_dm_tell("froze " + level.zm_fz_on + ", unfroze " + level.zm_fz_off);
}

// ---------------------------------------------------------------- animations

zm_dm_cats_build()
{
    if (level.zm_dm_cats_built && level.zm_dm_cats_filter == zm_dm_str("anim_filter", ""))
    {
        return;
    }
    level.zm_dm_cats_built = 1;
    level.zm_dm_cats_filter = zm_dm_str("anim_filter", "");
    level.zm_dm_cats = [];
    level.zm_dm_cat_list = [];
    if (!isdefined(level.zm_dm_anim_names))
    {
        return;
    }
    for (k = 0; k < level.zm_dm_anim_names.size; k++)
    {
        n = level.zm_dm_anim_names[k];
        if (level.zm_dm_cats_filter != "" && !issubstr(n, level.zm_dm_cats_filter))
        {
            continue;
        }
        w = strtok(n, "_");
        c = n;
        if (w.size >= 4)
        {
            c = w[1] + "_" + w[2] + "_" + w[3];
        }
        if (!isdefined(level.zm_dm_cat_list[c]))
        {
            level.zm_dm_cat_list[c] = [];
            level.zm_dm_cats[level.zm_dm_cats.size] = c;
        }
        list = level.zm_dm_cat_list[c];
        list[list.size] = k;
        level.zm_dm_cat_list[c] = list;
    }
}

zm_dm_short_anim(n)
{
    w = strtok(n, "_");
    if (w.size < 5)
    {
        return n;
    }
    s = w[4];
    for (i = 5; i < w.size; i++)
    {
        s = s + "_" + w[i];
    }
    return s;
}

zm_dm_anim_by_text(t)
{
    if (!isdefined(level.zm_dm_anim_names))
    {
        zm_dm_tell("no animations loaded");
        return;
    }
    for (k = 0; k < level.zm_dm_anim_names.size; k++)
    {
        if (level.zm_dm_anim_names[k] == t)
        {
            zm_dm_play_index(k);
            return;
        }
    }
    k = int(t);
    if (("" + k) == t && k >= 0 && k < level.zm_dm_anims.size)
    {
        zm_dm_play_index(k);
        return;
    }
    zm_dm_tell("^1no animation called^7 " + t);
}

zm_dm_play_index(k)
{
    // fields only (a local list came back empty after script calls in other menu actions)
    level.zm_pa_k = k;
    if (!isdefined(level.zm_dm_anims) || level.zm_pa_k < 0 || level.zm_pa_k >= level.zm_dm_anims.size)
    {
        zm_dm_tell("^1no animation " + level.zm_pa_k);
        return;
    }
    level.zm_pa_list = zm_dm_targets();
    if (!isdefined(level.zm_pa_list) || level.zm_pa_list.size == 0)
    {
        zm_dm_tell("^1no AI found^7 (target: " + zm_dm_target_name(level.zm_dm_target) + ")");
        return;
    }
    level.zm_pa_hold = zm_dm_num("anim_time", 4);
    if (level.zm_pa_hold < 0)
    {
        level.zm_pa_hold = 0;
    }
    if (level.zm_pa_hold > 30)
    {
        level.zm_pa_hold = 30;
    }
    level.zm_pa_n = 0;
    level.zm_pa_skip = 0;
    for (level.zm_pa_i = 0; level.zm_pa_i < level.zm_pa_list.size; level.zm_pa_i++)
    {
        level.zm_pa_ai = level.zm_pa_list[level.zm_pa_i];
        if (!isdefined(level.zm_pa_ai) || !isalive(level.zm_pa_ai))
        {
            continue;
        }
        // an animation only plays on its own creature (a karkinos animation does nothing on a viper)
        if (!zm_dm_anim_fits(level.zm_pa_ai, level.zm_dm_anim_names[level.zm_pa_k]))
        {
            level.zm_pa_skip++;
            continue;
        }
        level.zm_pa_ai.zm_dm_anim = level.zm_pa_k;
        level.zm_pa_ai.zm_dm_hold = level.zm_pa_hold;
        level.zm_pa_ai zm_dm_play_on();
        level.zm_dm_playing[level.zm_dm_playing.size] = level.zm_pa_ai;
        level.zm_pa_n++;
    }
    if (level.zm_pa_n == 0)
    {
        zm_dm_tell("^1this animation is for a " + zm_dm_anim_creature(level.zm_dm_anim_names[level.zm_pa_k]) + "^7 - target one (or spawn one) to play it");
    }
    else
    {
        zm_dm_tell("playing on " + level.zm_pa_n + " " + zm_dm_anim_creature(level.zm_dm_anim_names[level.zm_pa_k]) + " (" + level.zm_pa_skip + " other zombies skipped)");
    }
    zm_dm_dbg("anim_fit", level.zm_pa_n + " played, " + level.zm_pa_skip + " skipped");
    zm_dm_dbg("anim", level.zm_dm_anim_names[level.zm_pa_k]);
}

// self = AI. BO7's animscripted is function_f6b4d1849d98c555(notify, origin, angles, anim).
zm_dm_play_on()
{
    self.zm_dm_aref = level.zm_dm_anims[self.zm_dm_anim];
    self function_f6b4d1849d98c555("zm_dm_anim", self.origin, self.angles, self.zm_dm_aref);
    self.zm_dm_arate = zm_dm_num("anim_rate", 1);
    if (self.zm_dm_arate != 1)
    {
        self function_d4813fa37c19d595(self.zm_dm_aref, self.zm_dm_arate);
    }
    self.zm_dm_until = level.zm_dm_time + self.zm_dm_hold;
}

// Releases (or replays) AI whose hold time is over. Runs every tick.
zm_dm_anim_upkeep()
{
    if (level.zm_dm_playing.size == 0 || level.zm_dm_ticks % 4 != 0)
    {
        return;
    }
    loop = zm_dm_num("anim_loop", 0);
    keep = [];
    for (i = 0; i < level.zm_dm_playing.size; i++)
    {
        ai = level.zm_dm_playing[i];
        if (!isdefined(ai) || !isdefined(ai.zm_dm_anim))
        {
            continue;
        }
        if (ai.zm_dm_hold <= 0 || level.zm_dm_time < ai.zm_dm_until)
        {
            keep[keep.size] = ai;
            continue;
        }
        if (loop == 1)
        {
            ai zm_dm_play_on();
            keep[keep.size] = ai;
            continue;
        }
        ai function_1492235b4eb6e229();
        ai.zm_dm_anim = undefined;
    }
    level.zm_dm_playing = keep;
}

zm_dm_stop_all()
{
    n = 0;
    for (i = 0; i < level.zm_dm_playing.size; i++)
    {
        ai = level.zm_dm_playing[i];
        if (isdefined(ai))
        {
            ai function_1492235b4eb6e229();
            ai.zm_dm_anim = undefined;
            n++;
        }
    }
    level.zm_dm_playing = [];
    zm_dm_tell("stopped " + n + " AI");
}

// Menu messages (done / failed / what to do): big centre text, so they are noticed.
// Setting tell_center 0 = the old small line at the left.
zm_dm_tell(text)
{
    zm_dm_say(text);
    // every different message shown uses one of the game's limited text slots for the whole game
    // session; messages with changing numbers (points, counts) used them up, so numbers are left
    // out unless setting tell_numbers is 1 (the full text still goes to devmenu_dbg "last")
    // the add-on shows messages without using text slots: full text, numbers included
    if (getdvar(@"phantom_menu_lua") == "1" && zm_dm_num("no_lua_text", 0) != 1)
    {
        if (!isdefined(level.zm_dm_tell_n))
        {
            level.zm_dm_tell_n = 0;
        }
        level.zm_dm_tell_n++;
        setdvar(@"phantom_tell", level.zm_dm_tell_n + "|" + text);
        return;
    }
    if (zm_dm_num("tell_numbers", 0) != 1 && !issubstr(text, "round"))
    {
        text = zm_dm_no_numbers(text);
    }
    level.zm_dm_tell_p = level.zm_dm_player;
    if (isdefined(level.zm_dm_tell_p))
    {
        if (zm_dm_num("tell_center", 1) == 1)
        {
            level.zm_dm_tell_p iprintlnbold("^5PHANTOM^7  " + text);
        }
        else
        {
            level.zm_dm_tell_p iprintln("^5Phantom menu^7 " + text);
        }
    }
}

// ---------------------------------------------------------------- default spawn list

zm_dm_types_default()
{
    level.zm_dm_types_all = [];
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_boss_pops_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_hvt_zm_echo";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_mega_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_mega_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_mega_ob_ztron";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_toxic_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_abom_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_aeon_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_ob_boss";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_ob_falkner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_ob_nm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_zm_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_amalgam_zm_hvt_echo";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_abom_crawler_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_abom_crawler_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_agni_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_sm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_sm_blind";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_sm_friend";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_zm_hornet";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_zm_locust";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_zm_mantis";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_heavy_zm_scarab";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_sm_blind";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_sm_friend";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_zm_hornet";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_zm_locust";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_zm_mantis";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_armored_light_zm_scarab";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_firefly_mechanic";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_firefly_trucker";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_firefly_waitress";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_firefly_weaver";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_luna_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_luna_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_luna_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_mantis_fem_husk";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_mantis_husk";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_aries";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_aries_unknown";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_falkner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_friend";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_harrow";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_mannequin";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_ob_scorpio";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_sm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_sm_blind";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_sm_blind_hh";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_sm_friend";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_sm_gemini";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_toxic_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_toxic_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_cabin";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_cook";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_dempsey";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_diner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_facility";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_farm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_janus";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_firefly_sunken";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_lava_garden";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_acc_g";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_acc_m";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_acc_n";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_simon";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_simon_h";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_simon_k";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_simon_o";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_simon_s";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_simon_t";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_mq_sus_m";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_hornet_sq_samurai";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_locust";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_locust_olaf";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_lw";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_lw_hung";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_mantis";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_mantis_cin";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_mantis_lw";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_mantis_past";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_mantis_piano_teacher";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_ruby";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_ruby_mars";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_scarab";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_base_zm_ztron";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_boss_virgil_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_boss_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_hvt_nm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_hvt_zm_melee";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_hvt_zm_relic";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_callisto_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_deathworm_boss_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_deathworm_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_diana_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_diana_zm_assault_rounds";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_hvt_storm_caller";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_ob_elite";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_skoll_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_skoll_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_skoll_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_skoll_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_skoll_ob_falkner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_skoll_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_disciple_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_galileo_boss_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_galileo_drone_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_galileo_drone_ob_nm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_galileo_drone_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_galileo_hvt_ob_nm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_galileo_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_hvt_zm_echo";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_hvt_zm_relic";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_ob_boss";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_ob_elite";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_ob_falkner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_ob_nm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_quarantine_zone";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_ghoul_ztron";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_hellhound_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_hellhound_zm_hornet_mq";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_hermes_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_karkinos_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_karkinos_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_karkinos_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_loom_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_loom_minion_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_loom_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_hvt_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_ob_boss";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_ob_elite";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_ob_falkner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_ob_worldbossguard";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mangler_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_fire_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_fire_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_fire_zm_hellping_hound";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_mp_infect";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_methone_zm_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_emp_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_emp_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_hvt_emp_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_hvt_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_ob_champion";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_ob_elite";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_ob_elite_portal_guard";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_ob_falkner";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_ob_worldbossguard";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_mimic_zm_ztron";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_neptune_boss_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_neptune_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_hvt_zm_hornet_mq";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_hvt_zm_hornet_sq";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_hvt_zm_hornet_sq_static";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_orion_zm_static";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_parasite_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_parasite_ob_sm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_parasite_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_phobos_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_phobos_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_shade_mp";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_shade_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_shade_zm_locust_irradiated";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_shade_zm_ruby_ee_bongo";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_uranus_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_vermin_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_vermin_ob_sm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_vermin_ob_sm_aries";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_vermin_ob_sm_melee";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_vermin_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_boss_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_hvt";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_mini_boss_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_mini_hvt_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_mini_hvt_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_mini_ob";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_mini_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_viper_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_weyward_stinger_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_weyward_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm_bomb";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm_boss_fight";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm_downed";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm_scpq";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm_shadow";
    level.zm_dm_types_all[level.zm_dm_types_all.size] = "sat_spawner_zombie_wither_zm_shadow_mq";
}

// ---------------------------------------------------------------- round entry

// entry type          start keyboard typing (Enter: N = go to round N, -N = back N rounds,
//                     +N = forward N rounds; Esc cancels)
// entry add <n>       change the number (controller rows: +1 / +10 / -100 ...)
// entry clear         empty the number
// entry go            go to round <number>
// entry minus         take <number> rounds away
// entry plus          add <number> rounds
zm_dm_entry_cmd(w)
{
    level.zm_dm_ec = w[1];
    level.zm_dm_ec_n = 0;
    if (w.size > 2)
    {
        level.zm_dm_ec_n = int(w[2]);
    }
    c = level.zm_dm_ec;
    if (c == "type")
    {
        level.zm_dm_entry = "";
        level.zm_dm_typing = 1;
        level.zm_dm_typed_last = getdvar(@"phantom_typed");
        setdvar(@"phantom_typing", "1");
        if (getdvar(@"phantom_bg_lua") != "1")
        {
            zm_dm_tell("^1keyboard typing needs the phantom_bg add-on (game restart); use the +/- rows");
        }
        else
        {
            zm_dm_tell("type a round, Enter = go (-N = back N rounds), Esc = cancel");
        }
    }
    else if (c == "add" && w.size > 2)
    {
        level.zm_dm_entry_n = zm_dm_entry_num() + level.zm_dm_ec_n;
        if (level.zm_dm_entry_n < 0)
        {
            level.zm_dm_entry_n = 0;
        }
        if (level.zm_dm_entry_n > 9999)
        {
            level.zm_dm_entry_n = 9999;
        }
        level.zm_dm_entry = "" + level.zm_dm_entry_n;
    }
    else if (c == "clear")
    {
        level.zm_dm_entry = "";
    }
    else if (c == "go")
    {
        zm_dm_entry_apply("go");
    }
    else if (c == "minus")
    {
        zm_dm_entry_apply("minus");
    }
    else if (c == "plus")
    {
        zm_dm_entry_apply("plus");
    }
    zm_dm_build();
    zm_dm_draw();
}

// The number part of the entry (a leading - or + is ignored here).
zm_dm_entry_num()
{
    level.zm_dm_en_s = level.zm_dm_entry;
    if (level.zm_dm_en_s == "")
    {
        return 0;
    }
    if (getsubstr(level.zm_dm_en_s, 0, 1) == "-" || getsubstr(level.zm_dm_en_s, 0, 1) == "+")
    {
        level.zm_dm_en_s = getsubstr(level.zm_dm_en_s, 1, level.zm_dm_en_s.size);
    }
    if (level.zm_dm_en_s == "")
    {
        return 0;
    }
    return int(level.zm_dm_en_s);
}

zm_dm_entry_apply(how)
{
    // kept on level fields: locals can come back empty after calls in Kronos GSC
    level.zm_dm_ea_how = how;
    level.zm_dm_entry_n = zm_dm_entry_num();
    if (level.zm_dm_ea_how == "go" && level.zm_dm_entry != "")
    {
        if (getsubstr(level.zm_dm_entry, 0, 1) == "-")
        {
            level.zm_dm_ea_how = "minus";
        }
        else if (getsubstr(level.zm_dm_entry, 0, 1) == "+")
        {
            level.zm_dm_ea_how = "plus";
        }
    }
    if (level.zm_dm_entry == "1337")
    {
        zm_dm_unlock_secret();
        return;
    }
    if (level.zm_dm_entry == "666" && isdefined(level.zm_dmz_run))
    {
        level.zm_hell_msg = level.zm_dm_player [[ level.zm_dmz_run ]]("hell", "");
        zm_dm_tell(level.zm_hell_msg);
        return;
    }
    if (level.zm_dm_entry_n <= 0)
    {
        zm_dm_tell("^1type a number first");
        return;
    }
    if (level.zm_dm_ea_how == "minus")
    {
        zm_dm_round_jump(zm_dm_round_now() - level.zm_dm_entry_n);
    }
    else if (level.zm_dm_ea_how == "plus")
    {
        zm_dm_round_jump(zm_dm_round_now() + level.zm_dm_entry_n);
    }
    else
    {
        zm_dm_round_jump(level.zm_dm_entry_n);
    }
}

// Keyboard typing: reads what the add-on wrote (seq|#text|state) and redraws on change.
zm_dm_typing_tick()
{
    if (!level.zm_dm_open)
    {
        zm_dm_typing_stop();
        return;
    }
    level.zm_dm_ty_v = getdvar(@"phantom_typed");
    if (level.zm_dm_ty_v == level.zm_dm_typed_last || level.zm_dm_ty_v == "")
    {
        return;
    }
    level.zm_dm_typed_last = level.zm_dm_ty_v;
    level.zm_dm_ty_p = strtok(level.zm_dm_ty_v, "|");
    if (level.zm_dm_ty_p.size < 3)
    {
        return;
    }
    level.zm_dm_entry = getsubstr(level.zm_dm_ty_p[1], 1, level.zm_dm_ty_p[1].size);
    if (level.zm_dm_ty_p[2] == "1")
    {
        zm_dm_typing_stop();
        zm_dm_entry_apply("go");
    }
    else if (level.zm_dm_ty_p[2] == "2")
    {
        zm_dm_typing_stop();
        zm_dm_tell("typing cancelled");
    }
    else if (level.zm_dm_entry != "")
    {
        zm_dm_tell("round: " + level.zm_dm_entry);
    }
    zm_dm_build();
    zm_dm_draw();
}

zm_dm_typing_stop()
{
    level.zm_dm_typing = 0;
    setdvar(@"phantom_typing", "0");
}

// Instruction box beside the panel while Rounds > Type a round is open (fully opaque).
zm_dm_hint_tick()
{
    // shown while keyboard typing is on (Rounds page "Typed number") or on the old typing page
    level.zm_dm_hint_want = level.zm_dm_open && (level.zm_dm_page == "roundtype" || getdvar(@"phantom_typing") == "1") && isdefined(level.zm_dm_player);
    if (!isdefined(level.zm_dm_hint_on))
    {
        level.zm_dm_hint_on = 0;
    }
    if (level.zm_dm_hint_want == level.zm_dm_hint_on)
    {
        return;
    }
    level.zm_dm_hint_on = level.zm_dm_hint_want;
    if (!isdefined(level.zm_dm_hud_hint_show))
    {
        return;
    }
    if (level.zm_dm_hint_want)
    {
        level.zm_dm_player [[ level.zm_dm_hud_hint_show ]]("HOW TO TYPE A ROUND\n272  = go to round 272\n-5  = take away 5 rounds\n+5  = add 5 rounds\nEnter = go     Esc = cancel", 5);
        // the box needs 3 HUD elements; if the game had none left, say it in the middle instead
        if (!isdefined(level.zm_dm_player.zm_dmh_hint_e) || !isdefined(level.zm_dm_player.zm_dmh_hint_e[0]))
        {
            zm_dm_dbg("hint", "no hud elements - centre text");
            level.zm_dm_player iprintlnbold("^5TYPE A ROUND^7  272 = go to 272   -5 = back 5   +5 = add 5   Enter = go   Esc = cancel");
        }
        else
        {
            zm_dm_dbg("hint", "box shown");
        }
    }
    else if (isdefined(level.zm_dm_player))
    {
        level.zm_dm_player [[ level.zm_dm_hud_hint_hide ]]();
    }
}

// After a round jump: checks every 0.5 s (up to 40 s) that the round number reached the
// target. If the round changed to something else (the jump was asked while a round was
// already ending, so the game skipped the override), asks again, at most twice. Reports
// "now on round N" or that it failed. One watcher at a time (a new jump replaces it).
zm_dm_round_watch()
{
    level endon("zm_dm_rj_new");
    level.zm_dm_rj_t = 0;
    level.zm_dm_rj_seen = zm_dm_round_now();
    while (level.zm_dm_rj_t < 80)
    {
        if (zm_dm_round_watch_step())
        {
            return;
        }
        wait 0.5;
        level.zm_dm_rj_t++;
    }
    zm_dm_tell("^1round change failed: still round " + zm_dm_round_now() + " (wanted " + level.zm_dm_rj_target + ")");
    zm_dm_dbg("round_jump", "timeout at " + zm_dm_round_now());
}

// one check; returns 1 when finished
zm_dm_round_watch_step()
{
    level.zm_dm_rj_now = zm_dm_round_now();
    if (level.zm_dm_rj_now == level.zm_dm_rj_target)
    {
        zm_dm_tell("^2done: now on round " + level.zm_dm_rj_now);
        zm_dm_dbg("round_jump", "ok " + level.zm_dm_rj_now);
        return 1;
    }
    if (level.zm_dm_rj_now != level.zm_dm_rj_seen)
    {
        level.zm_dm_rj_seen = level.zm_dm_rj_now;
        if (level.zm_dm_rj_tries >= 2)
        {
            zm_dm_tell("^1round change failed: on round " + level.zm_dm_rj_now + " (wanted " + level.zm_dm_rj_target + ")");
            zm_dm_dbg("round_jump", "failed at " + level.zm_dm_rj_now);
            return 1;
        }
        level.zm_dm_rj_tries++;
        level thread namespace_7942a9cf653f89::function_68bdb49c82c0f892(level.zm_dm_rj_target);
        zm_dm_dbg("round_jump", "retry " + level.zm_dm_rj_tries + " at " + level.zm_dm_rj_now);
        level.zm_dm_rj_t = 0;
    }
    return 0;
}

// Cheat code inside the menu: Up Up Down Down Up Down Up Down (within 6 s) unlocks the secret
// row at the bottom of the main page (kept in settings: secret_unlocked 1).
zm_dm_cheat_key(d)
{
    level.zm_dm_cheat_ms = zm_dm_num("cheat_ms", 0);
    if (level.zm_dm_cheat_ms <= 0)
    {
        level.zm_dm_cheat_ms = 6000;
    }
    if (!isdefined(level.zm_dm_cheat) || gettime() - level.zm_dm_cheat_t > level.zm_dm_cheat_ms)
    {
        level.zm_dm_cheat = "";
        level.zm_dm_cheat_t = gettime();
    }
    if (d < 0)
    {
        level.zm_dm_cheat = level.zm_dm_cheat + "U";
    }
    else
    {
        level.zm_dm_cheat = level.zm_dm_cheat + "D";
    }
    if (level.zm_dm_cheat.size > 8)
    {
        level.zm_dm_cheat = getsubstr(level.zm_dm_cheat, level.zm_dm_cheat.size - 8, level.zm_dm_cheat.size);
    }
    if (level.zm_dm_cheat == "UUDDUDUD")
    {
        level.zm_dm_cheat = "";
        zm_dm_unlock_secret();
    }
}

zm_dm_unlock_secret()
{
    if (zm_dm_num("secret_unlocked", 0) == 1)
    {
        zm_dm_tell("^5secret menu^7 already unlocked - bottom of the main page");
        return;
    }
    zm_dm_store("secret_unlocked", 1);
    zm_dm_dbg("secret", "unlocked");
    zm_dm_tell("^5SECRET UNLOCKED^7 - look at the bottom of the main page");
    if (level.zm_dm_page == "main")
    {
        // rebuild with the new row; the code's last key (Down) then lands on it
        zm_dm_build();
        level.zm_dm_sel = level.zm_dm_labels.size - 2;
    }
}

// Zombie rain: rain_n zombies of loaded normal types drop from the sky around the player.
zm_dm_zombie_rain()
{
    zm_dm_spawn_types();
    level.zm_rn_types = [];
    for (level.zm_rn_i = 0; level.zm_rn_i < level.zm_dm_spawn_list.size; level.zm_rn_i++)
    {
        level.zm_rn_t = level.zm_dm_spawn_list[level.zm_rn_i];
        if (zm_dm_can_spawn(level.zm_rn_t) && (zm_dm_spawn_cat(level.zm_rn_t) == "normal" || zm_dm_spawn_cat(level.zm_rn_t) == "armored"))
        {
            level.zm_rn_types[level.zm_rn_types.size] = level.zm_rn_t;
        }
    }
    if (level.zm_rn_types.size == 0)
    {
        // no normal zombies loaded here: any non-boss type
        for (level.zm_rn_i = 0; level.zm_rn_i < level.zm_dm_spawn_list.size; level.zm_rn_i++)
        {
            level.zm_rn_t = level.zm_dm_spawn_list[level.zm_rn_i];
            if (zm_dm_can_spawn(level.zm_rn_t) && zm_dm_spawn_cat(level.zm_rn_t) != "boss")
            {
                level.zm_rn_types[level.zm_rn_types.size] = level.zm_rn_t;
            }
        }
    }
    if (level.zm_rn_types.size == 0)
    {
        zm_dm_tell("^1no zombies can spawn here right now");
        return;
    }
    level.zm_rn_yaw = 0;
    if (isdefined(level.zm_dm_player.angles))
    {
        level.zm_rn_yaw = level.zm_dm_player.angles[1];
    }
    level.zm_dm_sp_scale = 1;
    level.zm_dm_ok = 0;
    level.zm_rn_n = int(zm_dm_num("rain_n", 8));
    if (level.zm_rn_n <= 0)
    {
        level.zm_rn_n = 8;
    }
    for (level.zm_rn_k = 0; level.zm_rn_k < level.zm_rn_n; level.zm_rn_k++)
    {
        level.zm_dm_sp_type = level.zm_rn_types[randomint(level.zm_rn_types.size)];
        level.zm_dm_sp_dist = randomfloatrange(200, 500);
        level.zm_rn_before = level.zm_dm_ok;
        zm_dm_spawn_one_at(level.zm_rn_yaw + randomfloatrange(-80, 80));
        if (level.zm_dm_ok > level.zm_rn_before && isdefined(level.zm_dmz_drop))
        {
            level.zm_so_ai thread [[ level.zm_dmz_drop ]]();
        }
    }
    zm_dm_tell("^5zombie rain:^7 " + level.zm_dm_ok + " zombies");
}

// Newer actions, kept out of zm_dm_select_more's else-if chain (acts' compiler overflows its stack
// on very long chains). Returns 1 when the action was handled.
zm_dm_select_new(w)
{
    c = w[0];
    if (c == "salvage" && w.size > 1)
    {
        // salvage = the player's currency table (self.currency[#"salvage"]) + the HUD number (omnvar zm_salvage)
        level.zm_sv_p = level.zm_dm_player;
        if (w[1] == "inf")
        {
            level.zm_sv_p.zm_dm_infsalv = 1 - zm_dm_flag(level.zm_sv_p.zm_dm_infsalv);
            if (level.zm_sv_p.zm_dm_infsalv)
            {
                level.zm_sv_p thread zm_dm_salvage_loop();
            }
            zm_dm_tell("infinite salvage" + zm_dm_onoff(level.zm_sv_p.zm_dm_infsalv));
            return 1;
        }
        if (w[1] == "max")
        {
            level.zm_sv_p zm_dm_salvage_set(999999);
        }
        else
        {
            level.zm_sv_p zm_dm_salvage_set(level.zm_sv_p zm_dm_salvage_get() + int(w[1]));
        }
        zm_dm_tell("salvage: " + level.zm_sv_p zm_dm_salvage_get());
        return 1;
    }
    if (c == "zz" && w.size > 1)
    {
        // Chaos + secret options (zm_zz_devmenu_fun.gsc)
        if (!isdefined(level.zm_dmz_run))
        {
            zm_dm_tell("^1not available (fun script not loaded)");
        }
        else
        {
            level.zm_zz_v = "";
            if (w.size > 2)
            {
                level.zm_zz_v = w[2];
            }
            level.zm_zz_msg = level.zm_dm_player [[ level.zm_dmz_run ]](w[1], level.zm_zz_v);
            if (isdefined(level.zm_zz_msg))
            {
                zm_dm_tell(level.zm_zz_msg);
            }
        }
        return 1;
    }
    if (c == "wdoa" && w.size > 1)
    {
        // Dead Ops Arcade guns: their weapon files only exist in the Dead Ops Arcade map (zm_sat_ztron4)
        level.zm_wd_n = zm_dm_wscan_real(w[1]);
        if (!isdefined(level.zm_wd_n))
        {
            zm_dm_tell("^1only on the Dead Ops Arcade map^7 - the game keeps this gun inside that map");
            return 1;
        }
        level.zm_wd_p = level.zm_dm_player;
        if (isdefined(level.zm_wd_p.zm_dm_busy))
        {
            zm_dm_tell("still busy with the last weapon change");
            return 1;
        }
        level.zm_wd_p.zm_dm_wname = level.zm_wd_n;
        zm_dm_tell("loading " + level.zm_wd_n + " ...");
        level.zm_wd_p thread zm_dm_give_worker();
        return 1;
    }
    if (c == "wfull" && w.size > 1)
    {
        level.zm_wf_p = level.zm_dm_player;
        if (isdefined(level.zm_wf_p.zm_dm_busy))
        {
            zm_dm_tell("still busy with the last weapon change");
            return 1;
        }
        level.zm_wf_p.zm_dm_wname = w[1];
        zm_dm_tell("loading " + zm_dm_wnew_label(w[1]) + " ...");
        level.zm_wf_p thread zm_dm_give_worker();
        return 1;
    }
    if ((c == "opgo" || c == "camogo") && w.size > 1)
    {
        level.zm_dm_lkg = int(w[1]);
        if (c == "opgo")
        {
            zm_dm_go("opskin");
        }
        else
        {
            zm_dm_go("camogrp");
        }
        return 1;
    }
    if (c == "fxgroup" && w.size > 1)
    {
        level.zm_dm_fxg = int(w[1]);
        zm_dm_go("fxgrp");
        return 1;
    }
    if (c == "wnames")
    {
        // debug: every known gun display name into devmenu_dbg (wname_<cat>_<name>)
        level.zm_wn_k = getarraykeys(level.zm_dm_wdisp);
        for (level.zm_wn_i = 0; level.zm_wn_i < level.zm_wn_k.size; level.zm_wn_i++)
        {
            nengine_store_set("devmenu_dbg", "wname_" + level.zm_wn_k[level.zm_wn_i], level.zm_dm_wdisp[level.zm_wn_k[level.zm_wn_i]]);
        }
        zm_dm_tell("names: " + level.zm_wn_k.size);
        return 1;
    }
    if (c == "ntprobe")
    {
        // debug: what Kronos nengine_text gives back (to keep text slots across map restarts)
        level.zm_np = nengine_text("Phantom probe text");
        level.zm_np_t = "other";
        if (isstring(level.zm_np))
        {
            level.zm_np_t = "string";
        }
        else if (isint(level.zm_np))
        {
            level.zm_np_t = "int";
        }
        else if (isfloat(level.zm_np))
        {
            level.zm_np_t = "float";
        }
        zm_dm_dbg("np_type", level.zm_np_t);
        if (level.zm_np_t != "other")
        {
            zm_dm_dbg("np_val", level.zm_np);
        }
        level.zm_np2 = nengine_text("Phantom probe text");
        zm_dm_dbg("np_same", level.zm_np == level.zm_np2);
        return 1;
    }
    if (c == "boss" && w.size > 1)
    {
        if (!isdefined(level.zm_dmb_run))
        {
            zm_dm_tell("^1not available (boss script not loaded)");
            return 1;
        }
        level.zm_bs_v = "";
        if (w.size > 2)
        {
            level.zm_bs_v = w[2];
        }
        level.zm_bs_msg = level.zm_dm_player [[ level.zm_dmb_run ]](w[1], level.zm_bs_v);
        if (isdefined(level.zm_bs_msg))
        {
            zm_dm_tell(level.zm_bs_msg);
        }
        if (level.zm_dm_open)
        {
            zm_dm_build();
            zm_dm_draw();
        }
        return 1;
    }
    if (c == "rule" && w.size > 1)
    {
        level.zm_ru_v = "";
        if (w.size > 2)
        {
            level.zm_ru_v = w[2];
        }
        if (isdefined(level.zm_dmo_run))
        {
            zm_dm_tell(level.zm_dm_player [[ level.zm_dmo_run ]]("rule_" + w[1], level.zm_ru_v));
        }
        return 1;
    }
    if ((c == "bfxgo" || c == "bfxslot") && w.size > 1)
    {
        if (c == "bfxslot")
        {
            level.zm_dm_bfxslot = w[1];
            zm_dm_go("bfx");
        }
        else
        {
            level.zm_dm_bfxg = int(w[1]);
            zm_dm_go("bfxgrp");
        }
        return 1;
    }
    if (c == "mode" && w.size > 1)
    {
        level.zm_md_v = "";
        if (w.size > 2)
        {
            level.zm_md_v = w[2];
        }
        if (isdefined(level.zm_dmo_run))
        {
            level.zm_md_msg = level.zm_dm_player [[ level.zm_dmo_run ]]("mode_" + w[1], level.zm_md_v);
            if (isdefined(level.zm_md_msg))
            {
                zm_dm_tell(level.zm_md_msg);
            }
        }
        return 1;
    }
    if (c == "exec" && w.size > 1)
    {
        // any console command through the add-on (it runs phantom_exec when it changes)
        level.zm_ex_c = w[1];
        for (level.zm_ex_i = 2; level.zm_ex_i < w.size; level.zm_ex_i++)
        {
            level.zm_ex_c = level.zm_ex_c + " " + w[level.zm_ex_i];
        }
        setdvar(@"phantom_exec", level.zm_ex_c + " " + gettime());
        zm_dm_dbg("exec", level.zm_ex_c);
        zm_dm_tell("console: " + level.zm_ex_c);
        return 1;
    }
    if (c == "veh" && w.size > 1)
    {
        if (!isdefined(level.zm_dmv_run))
        {
            zm_dm_tell("^1not available (vehicles script not loaded)");
            return 1;
        }
        level.zm_vh_v = "";
        if (w.size > 2)
        {
            level.zm_vh_v = w[2];
        }
        level.zm_vh_msg = level.zm_dm_player [[ level.zm_dmv_run ]](w[1], level.zm_vh_v);
        if (isdefined(level.zm_vh_msg))
        {
            zm_dm_tell(level.zm_vh_msg);
        }
        return 1;
    }
    if (c == "look" && w.size > 1)
    {
        if (!isdefined(level.zm_dml_run))
        {
            zm_dm_tell("^1not available (looks script not loaded)");
            return 1;
        }
        level.zm_lk_v = "";
        if (w.size > 2)
        {
            level.zm_lk_v = w[2];
        }
        level.zm_lk_msg = level.zm_dm_player [[ level.zm_dml_run ]](w[1], level.zm_lk_v);
        if (isdefined(level.zm_lk_msg))
        {
            zm_dm_tell(level.zm_lk_msg);
        }
        return 1;
    }
    if (c == "op" && w.size > 1)
    {
        if (!isdefined(level.zm_dmo_run))
        {
            zm_dm_tell("^1not available (overpowered script not loaded)");
            return 1;
        }
        level.zm_op_v = "";
        if (w.size > 2)
        {
            level.zm_op_v = w[2];
        }
        level.zm_op_msg = level.zm_dm_player [[ level.zm_dmo_run ]](w[1], level.zm_op_v);
        if (isdefined(level.zm_op_msg))
        {
            zm_dm_tell(level.zm_op_msg);
        }
        return 1;
    }
    if (c == "fastreload")
    {
        level.zm_fr_p = level.zm_dm_player;
        level.zm_fr_p.zm_dm_freload = 1 - zm_dm_flag(level.zm_fr_p.zm_dm_freload);
        if (isdefined(level.zm_dmx_fastreload))
        {
            level.zm_fr_p [[ level.zm_dmx_fastreload ]](level.zm_fr_p.zm_dm_freload);
        }
        zm_dm_tell("fast reload" + zm_dm_onoff(level.zm_fr_p.zm_dm_freload));
        return 1;
    }
    if (c == "speedrun")
    {
        // a new round every speedrun_gap seconds (10)
        level.zm_dm_speedrun = 1 - zm_dm_flag(level.zm_dm_speedrun);
        level.zm_dm_speedrun_t = gettime();
        zm_dm_tell("speedrun rounds" + zm_dm_onoff(level.zm_dm_speedrun));
        return 1;
    }
    if (c == "godloadout")
    {
        zm_dm_god_loadout();
        return 1;
    }
    if (c == "chaosspawn")
    {
        zm_dm_chaos_spawn();
        return 1;
    }
    if (c == "fontnext")
    {
        level.zm_fn_l = strtok(getdvar(@"phantom_fonts"), "|");
        if (level.zm_fn_l.size == 0)
        {
            zm_dm_tell("^1no font list yet (the picture add-on sends it)");
            return 1;
        }
        level.zm_fn_cur = zm_dm_str("menu_font", "");
        level.zm_fn_next = level.zm_fn_l[0];
        for (level.zm_fn_i = 0; level.zm_fn_i < level.zm_fn_l.size; level.zm_fn_i++)
        {
            if (level.zm_fn_l[level.zm_fn_i] == level.zm_fn_cur)
            {
                level.zm_fn_next = level.zm_fn_l[(level.zm_fn_i + 1) % level.zm_fn_l.size];
            }
        }
        zm_dm_set_font(level.zm_fn_next);
        zm_dm_tell("font: " + level.zm_fn_next);
        return 1;
    }
    if (c == "fontreset")
    {
        zm_dm_set_font("");
        zm_dm_tell("font: default");
        return 1;
    }
    if (c == "preset" && w.size > 1)
    {
        zm_dm_preset(w[1]);
        return 1;
    }
    if (c == "presetsave" && w.size > 1)
    {
        // your own preset: colour, background, darkness, side, rows, loading colours, name
        // empty values saved as "-" (an empty field would shift the others)
        nengine_store_set("devmenu", "mypreset_" + w[1], zm_dm_dash(zm_dm_str("accent_rgb", "")) + "|" + zm_dm_dash(zm_dm_str("hud_bg_image", "")) + "|" + zm_dm_num("hud_bg_tint", 0.45) + "|" + zm_dm_num("panel_right", 1) + "|" + zm_dm_num("lines", 14) + "|" + zm_dm_dash(zm_dm_join(strtok(zm_dm_str("load_colors", ""), "|"), ",")) + "|" + zm_dm_theme());
        nengine_store_save("devmenu", "settings");
        zm_dm_tell("your setup is saved in slot " + w[1]);
        return 1;
    }
    if (c == "presetload" && w.size > 1)
    {
        level.zm_ps_v = zm_dm_str("mypreset_" + w[1], "");
        level.zm_ps_p = strtok(level.zm_ps_v, "|");
        if (level.zm_ps_v == "" || level.zm_ps_v == "0" || level.zm_ps_p.size < 7)
        {
            zm_dm_tell("^1slot " + w[1] + " is empty - save your setup there first");
            return 1;
        }
        nengine_store_set("devmenu", "accent_rgb", zm_dm_undash(level.zm_ps_p[0]));
        nengine_store_set("devmenu", "preset_name", "My slot " + w[1]);
        zm_dm_preset_rest(level.zm_ps_v);
        nengine_store_save("devmenu", "settings");
        zm_dm_tell("loaded your slot " + w[1]);
        return 1;
    }
    if (c == "tampertest")
    {
        level.zm_dm_player thread zm_dm_tamper_popup();
        return 1;
    }
    if (c == "zrain")
    {
        zm_dm_zombie_rain();
        return 1;
    }
    if (c == "zf" && w.size > 1)
    {
        // Forge + Map Builder link (zm_zz_devmenu_forge.gsc)
        if (!isdefined(level.zm_dmf_run))
        {
            zm_dm_tell("^1not available (forge script not loaded)");
        }
        else
        {
            level.zm_zf_v = "";
            if (w.size > 2)
            {
                level.zm_zf_v = w[2];
            }
            level.zm_zf_msg = level.zm_dm_player [[ level.zm_dmf_run ]](w[1], level.zm_zf_v);
            if (isdefined(level.zm_zf_msg))
            {
                zm_dm_tell(level.zm_zf_msg);
            }
        }
        return 1;
    }
    if (c == "setv" && w.size > 2)
    {
        // setv <setting> <number> [message]
        zm_dm_store(w[1], float(w[2]));
        if (w.size > 3)
        {
            zm_dm_tell(w[3] + " " + w[2]);
        }
        return 1;
    }
    if (c == "wave" && w.size > 1)
    {
        // custom waves: every new round spawns extra enemies of one kind (boss / hvt / elite /
        // armored / normal / hound / mix), "wave off" stops
        if (w[1] == "off")
        {
            level.zm_dm_wave = undefined;
            zm_dm_tell("custom waves OFF");
        }
        else
        {
            level.zm_dm_wave = w[1];
            level.zm_dm_wave_last = zm_dm_round_now();
            if (w.size > 2 && w[2] == "now")
            {
                level.zm_dm_wave_last = -1;
                zm_dm_tell("custom waves: " + w[1] + " (first wave now)");
            }
            else
            {
                zm_dm_tell("custom waves: " + w[1] + " (starts next round)");
            }
        }
        return 1;
    }
    return 0;
}

zm_dm_salvage_get()
{
    if (!isdefined(self.currency) || !isdefined(self.currency[#"salvage"]))
    {
        return 0;
    }
    return self.currency[#"salvage"];
}

zm_dm_salvage_set(n)
{
    self.zm_dm_sv_n = n;
    if (self.zm_dm_sv_n < 0)
    {
        self.zm_dm_sv_n = 0;
    }
    if (self.zm_dm_sv_n > 999999)
    {
        self.zm_dm_sv_n = 999999;
    }
    if (!isdefined(self.currency))
    {
        self.currency = [];
    }
    self.currency[#"salvage"] = self.zm_dm_sv_n;
    self setclientomnvar("zm_salvage", self.zm_dm_sv_n);
}

// Infinite salvage: back to the max once a second while on.
zm_dm_salvage_loop()
{
    self endon("disconnect");
    while (zm_dm_flag(self.zm_dm_infsalv))
    {
        if (self zm_dm_salvage_get() < 999999)
        {
            self zm_dm_salvage_set(999999);
        }
        wait 1;
    }
}

// Background: build each gun of a weapon category once and keep its display name (a game text
// label) in level.zm_dm_wdisp["<cat> <name>"]; redraws the page when done.
zm_dm_wdisp_fill(cat, list)
{
    if (!isdefined(level.zm_dm_wdisp))
    {
        level.zm_dm_wdisp = [];
        level.zm_dm_wdisp_done = [];
    }
    if (isdefined(level.zm_dm_wdisp_busy))
    {
        return;
    }
    level.zm_dm_wdisp_busy = 1;
    level.zm_wd_cat = cat;
    level.zm_wd_list = list;
    level.zm_wd_n = 0;
    for (level.zm_wd_i = 0; level.zm_wd_i < level.zm_wd_list.size; level.zm_wd_i++)
    {
        level.zm_wd_name = zm_dm_weapon_name(level.zm_wd_cat, level.zm_wd_list[level.zm_wd_i]);
        if (!isdefined(level.zm_wd_name))
        {
            continue;
        }
        level.zm_wd_built = undefined;
        level thread zm_dm_wdisp_build();
        waitframe();
        waitframe();
        if (isdefined(level.zm_wd_built) && !isnullweapon(level.zm_wd_built) && isdefined(level.zm_wd_built.displayname))
        {
            level.zm_dm_wdisp[level.zm_wd_cat + " " + level.zm_wd_list[level.zm_wd_i]] = level.zm_wd_built.displayname;
            level.zm_wd_n++;
        }
    }
    level.zm_dm_wdisp_done[level.zm_wd_cat] = 1;
    level.zm_dm_wdisp_busy = undefined;
    zm_dm_dbg("wdisp", level.zm_wd_cat + " " + level.zm_wd_n + " of " + level.zm_wd_list.size);
    if (level.zm_dm_open && level.zm_dm_page == "wlist" && level.zm_dm_wcat == level.zm_wd_cat)
    {
        zm_dm_build();
        zm_dm_draw();
    }
}

zm_dm_wdisp_build()
{
    level.zm_wd_built = weapon::buildweapon(level.zm_wd_name, getweapondefaultattachments(level.zm_wd_name));
}

// Aim + Knife counts as the open / close combo when pressed within this many ticks (0.05 s each).
// While the menu is open it has to be (almost) at the same time, so a quick Aim (up) followed by
// Knife (back) is just up + back and never closes the menu. Settings combo_ticks / combo_ticks_open.
zm_dm_combo_window()
{
    if (level.zm_dm_open)
    {
        level.zm_dm_cw = int(zm_dm_num("combo_ticks_open", 0));
        if (level.zm_dm_cw <= 0)
        {
            level.zm_dm_cw = 3;
        }
        return level.zm_dm_cw;
    }
    level.zm_dm_cw = int(zm_dm_num("combo_ticks", 0));
    if (level.zm_dm_cw <= 0)
    {
        level.zm_dm_cw = 10;
    }
    return level.zm_dm_cw;
}

// Knife = back one page. On the main page the first press only warns; a second press within
// 1.5 s closes (so tapping back too often never closes the menu by accident).
zm_dm_knife_back()
{
    if (level.zm_dm_stack.size > 0)
    {
        zm_dm_back();
        return;
    }
    if (isdefined(level.zm_dm_close_arm) && gettime() - level.zm_dm_close_arm < 1500)
    {
        level.zm_dm_close_arm = undefined;
        zm_dm_set_open(0);
        return;
    }
    level.zm_dm_close_arm = gettime();
    zm_dm_tell("Knife again to close the menu");
}

// ---------------------------------------------------------------- changed-files warning
// Shown when someone tries to open the menu after the credit was changed or removed: a big box
// in the middle of the screen for 15 s explaining why the menu does not open. Drawn here (not by
// the panel script) so it still shows when the panel file was edited.
zm_dm_tamper_popup()
{
    self endon("disconnect");
    if (isdefined(self.zm_dm_tp_up))
    {
        return;
    }
    self.zm_dm_tp_up = 1;
    self.zm_dm_tp = [];
    self zm_dm_tp_box(-170, -70, 340, 140, (0, 0, 0), 0.92, 50);
    self zm_dm_tp_box(-170, -70, 340, 3, (0.9, 0.05, 0.05), 1, 51);
    self zm_dm_tp_box(-170, 67, 340, 3, (0.9, 0.05, 0.05), 1, 51);
    self zm_dm_tp_box(-170, -70, 3, 140, (0.9, 0.05, 0.05), 1, 51);
    self zm_dm_tp_box(167, -70, 3, 140, (0.9, 0.05, 0.05), 1, 51);
    self zm_dm_tp_line(-58, 1.6, (1, 0.15, 0.15), "PHANTOM MENU IS DISABLED");
    self zm_dm_tp_line(-28, 0.95, (1, 1, 1), "The menu files were changed: the \"Made by Ares\"");
    self zm_dm_tp_line(-12, 0.95, (1, 1, 1), "credit or the PHANTOM logo was removed or edited.");
    self zm_dm_tp_line(8, 0.95, (1, 1, 1), "That is why the menu is not working.");
    self zm_dm_tp_line(30, 1.0, (1, 0.8, 0.2), "Please don't change anything in the menu.");
    self zm_dm_tp_line(46, 0.85, (0.75, 0.75, 0.75), "Put the original menu files back to use it again.");
    for (self.zm_dm_tp_i = 0; self.zm_dm_tp_i < self.zm_dm_tp.size; self.zm_dm_tp_i++)
    {
        self.zm_dm_tp[self.zm_dm_tp_i].alpha = 0;
        self.zm_dm_tp[self.zm_dm_tp_i] fadeovertime(0.3);
        self.zm_dm_tp[self.zm_dm_tp_i].alpha = 1;
    }
    wait 15;
    for (self.zm_dm_tp_i = 0; self.zm_dm_tp_i < self.zm_dm_tp.size; self.zm_dm_tp_i++)
    {
        if (isdefined(self.zm_dm_tp[self.zm_dm_tp_i]))
        {
            self.zm_dm_tp[self.zm_dm_tp_i] destroy();
        }
    }
    self.zm_dm_tp = [];
    self.zm_dm_tp_up = undefined;
}

zm_dm_tp_elem(x, y, color, sort)
{
    self.zm_dm_tp_e = newclienthudelem(self);
    if (!isdefined(self.zm_dm_tp_e))
    {
        return;
    }
    self.zm_dm_tp_e.horzalign = "center";
    self.zm_dm_tp_e.vertalign = "middle";
    self.zm_dm_tp_e.alignx = "left";
    self.zm_dm_tp_e.aligny = "top";
    self.zm_dm_tp_e.x = x;
    self.zm_dm_tp_e.y = y;
    self.zm_dm_tp_e.color = color;
    self.zm_dm_tp_e.alpha = 1;
    self.zm_dm_tp_e.sort = sort;
    self.zm_dm_tp_e.foreground = 1;
    self.zm_dm_tp_e.hidewheninmenu = 1;
    self.zm_dm_tp_e.archived = 0;
    self.zm_dm_tp[self.zm_dm_tp.size] = self.zm_dm_tp_e;
}

zm_dm_tp_box(x, y, w, h, color, alpha, sort)
{
    self zm_dm_tp_elem(x, y, color, sort);
    if (isdefined(self.zm_dm_tp_e))
    {
        self.zm_dm_tp_e setshader("white", w, h);
    }
}

zm_dm_tp_line(y, scale, color, text)
{
    self zm_dm_tp_elem(0, y, color, 52);
    if (isdefined(self.zm_dm_tp_e))
    {
        self.zm_dm_tp_e.alignx = "center";
        self.zm_dm_tp_e.font = "default";
        self.zm_dm_tp_e.fontscale = scale;
        self.zm_dm_tp_e settext(nengine_text(text));
    }
}

// Gun picture box: when the selected row gives a gun ("wgive <cat> <name>") and the add-on has a
// picture for it (pages key gunpics = "|gp_<cat>_<name>|..."), tell the add-on which picture and
// at which row height; otherwise clear it.
zm_dm_pic_update()
{
    level.zm_pu_v = "";
    if (isdefined(level.zm_dm_values[level.zm_dm_sel]))
    {
        level.zm_pu_v = level.zm_dm_values[level.zm_dm_sel];
    }
    level.zm_pu_out = "";
    if (getsubstr(level.zm_pu_v, 0, 6) == "wgive ")
    {
        level.zm_pu_w = strtok(level.zm_pu_v, " ");
        if (level.zm_pu_w.size >= 3)
        {
            level.zm_pu_img = "gp_" + level.zm_pu_w[1] + "_" + level.zm_pu_w[2];
            if (issubstr(zm_dm_pg("gunpics"), "|" + level.zm_pu_img + "|"))
            {
                level.zm_pu_y = zm_dm_num("hud_top", 78) + (level.zm_dm_sel - level.zm_dm_top) * zm_dm_num("hud_row_h", 14) + zm_dm_num("hud_row_h", 14) / 2;
                // size / gap in GSC units and slide time in ms (settings pic_w 110, pic_gap 6, pic_ms 110)
                level.zm_pu_out = level.zm_pu_img + "|" + int(level.zm_pu_y) + "|" + zm_dm_pic_num("pic_w", 110) + "|" + zm_dm_pic_num("pic_gap", 6) + "|" + zm_dm_pic_num("pic_ms", 110);
            }
        }
    }
    // New weapons page rows ("wfull sat_<cat>_<name>[_zm|_mp]"): same gp_<cat>_<name> picture
    if (getsubstr(level.zm_pu_v, 0, 6) == "wfull ")
    {
        level.zm_pu_b = zm_dm_wbase(getsubstr(level.zm_pu_v, 6, level.zm_pu_v.size));
        if (getsubstr(level.zm_pu_b, 0, 4) == "sat_")
        {
            level.zm_pu_img = "gp_" + getsubstr(level.zm_pu_b, 4, level.zm_pu_b.size);
            if (!issubstr(zm_dm_pg("gunpics"), "|" + level.zm_pu_img + "|") && issubstr(level.zm_pu_img, "exotic"))
            {
                // exotic variant: the base gun's picture
                level.zm_pu_img = getsubstr(level.zm_pu_img, 0, level.zm_pu_img.size - 6);
            }
            if (issubstr(zm_dm_pg("gunpics"), "|" + level.zm_pu_img + "|"))
            {
                level.zm_pu_y = zm_dm_num("hud_top", 78) + (level.zm_dm_sel - level.zm_dm_top) * zm_dm_num("hud_row_h", 14) + zm_dm_num("hud_row_h", 14) / 2;
                level.zm_pu_out = level.zm_pu_img + "|" + int(level.zm_pu_y) + "|" + zm_dm_pic_num("pic_w", 110) + "|" + zm_dm_pic_num("pic_gap", 6) + "|" + zm_dm_pic_num("pic_ms", 110);
            }
        }
    }
    // enemies on the Spawn pages: picture zp_<type> (pages key zpics)
    if (getsubstr(level.zm_pu_v, 0, 6) == "spawn ")
    {
        level.zm_pu_w = strtok(level.zm_pu_v, " ");
        if (level.zm_pu_w.size >= 2 && issubstr(zm_dm_pg("zpics"), "|zp_" + level.zm_pu_w[1] + "|"))
        {
            level.zm_pu_y = zm_dm_num("hud_top", 78) + (level.zm_dm_sel - level.zm_dm_top) * zm_dm_num("hud_row_h", 14) + zm_dm_num("hud_row_h", 14) / 2;
            level.zm_pu_out = "zp_" + level.zm_pu_w[1] + "|" + int(level.zm_pu_y) + "|" + zm_dm_pic_num("pic_w", 110) + "|" + zm_dm_pic_num("pic_gap", 6) + "|" + zm_dm_pic_num("pic_ms", 110);
        }
    }
    if (!isdefined(level.zm_pu_last) || level.zm_pu_last != level.zm_pu_out)
    {
        level.zm_pu_last = level.zm_pu_out;
        setdvar(@"phantom_pic", level.zm_pu_out);
        zm_dm_dbg("pic", level.zm_pu_out);
    }
}

// setting value, or def when missing / 0
zm_dm_pic_num(key, def)
{
    level.zm_pn_v = zm_dm_num(key, def);
    if (!isdefined(level.zm_pn_v) || level.zm_pn_v <= 0)
    {
        return def;
    }
    return level.zm_pn_v;
}

// The creature an animation name belongs to: 4th part of ai_<game>_<mode>_<creature>_...
zm_dm_anim_creature(name)
{
    level.zm_ac_w = strtok(name, "_");
    if (level.zm_ac_w.size >= 4)
    {
        return level.zm_ac_w[3];
    }
    return "?";
}

// Does the animation name fit this AI (its classname, e.g. actor_sat_spawner_zombie_viper_zm)?
zm_dm_anim_fits(ai, name)
{
    if (!isdefined(ai) || !isdefined(ai.classname))
    {
        return 1;
    }
    level.zm_af_cls = ai.classname;
    level.zm_af_t = zm_dm_anim_creature(name);
    if (level.zm_af_t == "zombie")
    {
        return issubstr(level.zm_af_cls, "zombie_base") || issubstr(level.zm_af_cls, "_zombie_zm");
    }
    if (level.zm_af_t == "dog" || level.zm_af_t == "dawg")
    {
        return issubstr(level.zm_af_cls, "hound") || issubstr(level.zm_af_cls, "dog") || issubstr(level.zm_af_cls, "hellping");
    }
    return issubstr(level.zm_af_cls, level.zm_af_t);
}

// text without digit runs (and without what is left dangling around them: " x", ": ", "()")
zm_dm_no_numbers(text)
{
    level.zm_nn_out = "";
    level.zm_nn_dig = 0;
    for (level.zm_nn_i = 0; level.zm_nn_i < text.size; level.zm_nn_i++)
    {
        level.zm_nn_c = getsubstr(text, level.zm_nn_i, level.zm_nn_i + 1);
        if (issubstr("0123456789", level.zm_nn_c) && !(level.zm_nn_i > 0 && getsubstr(text, level.zm_nn_i - 1, level.zm_nn_i) == "^"))
        {
            level.zm_nn_dig = 1;
            continue;
        }
        if (level.zm_nn_dig && (level.zm_nn_c == "," || level.zm_nn_c == "."))
        {
            continue;
        }
        level.zm_nn_dig = 0;
        level.zm_nn_out = level.zm_nn_out + level.zm_nn_c;
    }
    return level.zm_nn_out;
}


// D-pad up (controller); own function per direction: locals don't survive a wait in Kronos GSC
zm_dm_wait_dpad_up()
{
    self endon("disconnect");
    while (isdefined(self))
    {
        self waittill("zm_dm_dpad_up");
        self zm_dm_cmd_event("dup");
    }
}

// D-pad down (controller); own function per direction: locals don't survive a wait in Kronos GSC
zm_dm_wait_dpad_down()
{
    self endon("disconnect");
    while (isdefined(self))
    {
        self waittill("zm_dm_dpad_down");
        self zm_dm_cmd_event("ddown");
    }
}

// D-pad left (controller); own function per direction: locals don't survive a wait in Kronos GSC
zm_dm_wait_dpad_left()
{
    self endon("disconnect");
    while (isdefined(self))
    {
        self waittill("zm_dm_dpad_left");
        self zm_dm_cmd_event("dleft");
    }
}

// D-pad right (controller); own function per direction: locals don't survive a wait in Kronos GSC
zm_dm_wait_dpad_right()
{
    self endon("disconnect");
    while (isdefined(self))
    {
        self waittill("zm_dm_dpad_right");
        self zm_dm_cmd_event("dright");
    }
}

// ---------------------------------------------------------------- presets
// Built-in looks per Zombies era: accent colour, background darkness, background picture (only
// when it is installed: backgrounds list in the pages file), loading screen colours. Takes effect
// at once (panel rebuilds); the loading screen colours show from the next match.
zm_dm_preset(id)
{
    level.zm_pr_id = id;
    level.zm_pr_bg = "";
    if (id == "phantom")
    {
        nengine_store_set("devmenu", "logo_img", "phantom_logo");
        nengine_store_set("devmenu", "accent_rgb", "");
        nengine_store_set("devmenu", "preset_name", "");
        nengine_store_set("devmenu", "load_colors", "6a1bff|38b6ff|e6d8ff|a04dff");
        nengine_store_set("devmenu", "theme", 2);
        nengine_store_save("devmenu", "settings");
        zm_dm_tell("preset: Phantom (default)");
        return;
    }
    else if (id == "aether")
    {
        zm_dm_preset_set("Dark Aether", "0.55 0.25 1", 0.5, "phantom_bg", "6a1bff|38b6ff|e6d8ff|a04dff");
    }
    else if (id == "waw")
    {
        zm_dm_preset_set("World at War", "0.75 0.1 0.08", 0.6, "", "7a0d0d|c8a46a|efe3c8|b01818");
    }
    else if (id == "bo1")
    {
        zm_dm_preset_set("Black Ops 1", "0.95 0.55 0.1", 0.55, "", "ff8a1a|ffd36a|fff0d8|ff9a2a");
    }
    else if (id == "bo2")
    {
        zm_dm_preset_set("Black Ops 2", "0.1 0.75 0.85", 0.5, "", "1aa7c8|7ff0ff|e0fbff|3fd6ff");
    }
    else if (id == "bo3")
    {
        zm_dm_preset_set("Black Ops 3", "1 0.75 0.15", 0.55, "", "ff9c1a|ffe27a|fff3d6|ffc23a");
    }
    else if (id == "bo4")
    {
        zm_dm_preset_set("Black Ops 4", "1 0.42 0.08", 0.55, "", "ff5a0a|ffb36a|ffe6d6|ff7a1a");
    }
    else if (id == "cw")
    {
        zm_dm_preset_set("Cold War", "0.25 0.9 0.75", 0.5, "", "1fb89a|8cffe8|e0fff8|3fe0c0");
    }
    else if (id == "bo6")
    {
        zm_dm_preset_set("Black Ops 6", "0.9 0.12 0.2", 0.55, "", "c8102e|ff6a6a|ffe0e0|ff2a3a");
    }
    else
    {
        zm_dm_tell("^1unknown preset " + id);
        return;
    }
    zm_dm_tell("preset: " + zm_dm_str("preset_name", id));
}

zm_dm_preset_set(name, rgb, tint, bg, loadc)
{
    // era header picture logo_<id>.png (tools\makelogos.js) and font (setting preset_font_<id>)
    level.zm_pr_logo = "logo_" + level.zm_pr_id;
    if (level.zm_pr_id == "aether")
    {
        level.zm_pr_logo = "phantom_logo";
    }
    nengine_store_set("devmenu", "logo_img", level.zm_pr_logo);
    level.zm_pr_font = zm_dm_str("preset_font_" + level.zm_pr_id, "");
    if (level.zm_pr_font == "" || level.zm_pr_font == "0")
    {
        // built-in era fonts (a fresh install has no preset_font_<id> settings)
        level.zm_pr_font = zm_dm_preset_font_def(level.zm_pr_id);
    }
    if (level.zm_pr_font != "" && level.zm_pr_font != "0")
    {
        zm_dm_set_font(level.zm_pr_font);
    }
    nengine_store_set("devmenu", "preset_name", name);
    nengine_store_set("devmenu", "accent_rgb", rgb);
    nengine_store_set("devmenu", "hud_bg_tint", tint);
    nengine_store_set("devmenu", "load_colors", loadc);
    // the preset's own background picture: setting preset_bg_<id> (put any installed background
    // there to give a preset its picture), else the built-in one when installed
    level.zm_pr_bg = zm_dm_str("preset_bg_" + level.zm_pr_id, "");
    if ((level.zm_pr_bg == "" || level.zm_pr_bg == "0") && issubstr("|" + zm_dm_pg("bg_list") + "|", "|bg_" + level.zm_pr_id + "|"))
    {
        // era background bg_<id> when it is installed
        level.zm_pr_bg = "bg_" + level.zm_pr_id;
    }
    if (level.zm_pr_bg == "" || level.zm_pr_bg == "0")
    {
        level.zm_pr_bg = bg;
    }
    if (level.zm_pr_bg != "" && issubstr("|" + zm_dm_pg("bg_list") + "|", "|" + level.zm_pr_bg))
    {
        nengine_store_set("devmenu", "hud_bg_image", level.zm_pr_bg);
    }
    nengine_store_save("devmenu", "settings");
}

// applies the saved fields after the colour: bg|tint|side|rows|load colours|theme
zm_dm_preset_rest(v)
{
    level.zm_pr_f = strtok(v, "|");
    // field 0 = colour (handled), then bg, tint, side, rows, load colours, theme
    if (level.zm_pr_f.size >= 7)
    {
        nengine_store_set("devmenu", "hud_bg_image", zm_dm_undash(level.zm_pr_f[1]));
        nengine_store_set("devmenu", "hud_bg_tint", float(level.zm_pr_f[2]));
        nengine_store_set("devmenu", "panel_right", int(level.zm_pr_f[3]));
        nengine_store_set("devmenu", "lines", int(level.zm_pr_f[4]));
        nengine_store_set("devmenu", "load_colors", zm_dm_join(strtok(zm_dm_undash(level.zm_pr_f[5]), ","), "|"));
        nengine_store_set("devmenu", "theme", int(level.zm_pr_f[6]));
    }
}

zm_dm_dash(v)
{
    if (!isdefined(v) || v == "" || v == "0")
    {
        return "-";
    }
    return v;
}

zm_dm_undash(v)
{
    if (!isdefined(v) || v == "-")
    {
        return "";
    }
    return v;
}

// parts joined with sep
zm_dm_join(parts, sep)
{
    level.zm_jn_out = "";
    for (level.zm_jn_i = 0; level.zm_jn_i < parts.size; level.zm_jn_i++)
    {
        if (level.zm_jn_i > 0)
        {
            level.zm_jn_out = level.zm_jn_out + sep;
        }
        level.zm_jn_out = level.zm_jn_out + parts[level.zm_jn_i];
    }
    return level.zm_jn_out;
}

// menu font: saved in settings, told to the add-on (it rebuilds the menu text)
zm_dm_set_font(name)
{
    nengine_store_set("devmenu", "menu_font", name);
    nengine_store_save("devmenu", "settings");
    setdvar(@"phantom_font", name);
}

// ready at the latest 3.5 s after the player spawned (no waiting for walking)
zm_dm_load_timeout()
{
    wait 3.5;
    zm_dm_load_step(100);
}

// One button: god mode, infinite ammo, max points + salvage, every perk (eternal), golden armor,
// rapid fire + fast reload, held gun Pack-a-Punch IV + Ultra rarity.
zm_dm_god_loadout()
{
    level.zm_gl_p = level.zm_dm_player;
    if (!isdefined(level.zm_gl_p))
    {
        return;
    }
    if (!zm_dm_flag(level.zm_gl_p.zm_dm_god))
    {
        zm_dm_select_more(strtok("toggle god", " "));
    }
    if (!zm_dm_flag(level.zm_gl_p.zm_dm_ammo))
    {
        zm_dm_select_more(strtok("toggle ammo", " "));
    }
    zm_dm_select_more(strtok("points set 2147483647", " "));
    zm_dm_select_new(strtok("salvage max", " "));
    zm_dm_select_more(strtok("perketernal", " "));
    if (!zm_dm_flag(level.zm_gl_p.zm_dm_golden))
    {
        zm_dm_select_more(strtok("toggle golden", " "));
    }
    if (!zm_dm_flag(level.zm_gl_p.zm_dm_rapid))
    {
        zm_dm_select_more(strtok("toggle rapid", " "));
    }
    if (!zm_dm_flag(level.zm_gl_p.zm_dm_freload))
    {
        zm_dm_select_new(strtok("fastreload", " "));
    }
    zm_dm_select_more(strtok("pap 4", " "));
    level thread zm_dm_god_loadout_rarity();
    zm_dm_tell("^3GOD LOADOUT^7 - everything maxed");
}

zm_dm_god_loadout_rarity()
{
    wait 1.5;
    zm_dm_select_more(strtok("rarity 5", " "));
}

// Chaos spawn: chaos_n (30) random enemies of every loaded kind around the player.
zm_dm_chaos_spawn()
{
    zm_dm_spawn_types();
    level.zm_cs_types = [];
    for (level.zm_cs_i = 0; level.zm_cs_i < level.zm_dm_spawn_list.size; level.zm_cs_i++)
    {
        if (zm_dm_can_spawn(level.zm_dm_spawn_list[level.zm_cs_i]))
        {
            level.zm_cs_types[level.zm_cs_types.size] = level.zm_dm_spawn_list[level.zm_cs_i];
        }
    }
    if (level.zm_cs_types.size == 0)
    {
        zm_dm_tell("^1nothing can spawn here right now");
        return;
    }
    level.zm_dm_sp_scale = 1;
    level.zm_dm_ok = 0;
    level.zm_cs_n = int(zm_dm_pic_num("chaos_n", 30));
    level.zm_cs_yaw = 0;
    if (isdefined(level.zm_dm_player.angles))
    {
        level.zm_cs_yaw = level.zm_dm_player.angles[1];
    }
    for (level.zm_cs_k = 0; level.zm_cs_k < level.zm_cs_n; level.zm_cs_k++)
    {
        level.zm_dm_sp_type = level.zm_cs_types[randomint(level.zm_cs_types.size)];
        level.zm_dm_sp_dist = randomfloatrange(250, 500);
        zm_dm_spawn_one_at(level.zm_cs_yaw + randomfloatrange(-90, 90));
    }
    zm_dm_tell("^1CHAOS:^7 " + level.zm_dm_ok + " enemies");
}

// AUTO-DETECT: enemy types the game itself has spawned this match (its own per-type table
// level.var_83048cc59a40c0af, filled for every AI it spawns) + the type of every living AI
// (.var_ef88add57e25f858). Types not in the built-in list (new maps / updates) join the Spawn page.
zm_dm_autodetect()
{
    if (!isdefined(level.zm_dm_auto_types))
    {
        level.zm_dm_auto_types = [];
        level.zm_dm_auto_new = 0;
    }
    level.zm_ad_n0 = level.zm_dm_auto_types.size;
    if (isdefined(level.var_83048cc59a40c0af))
    {
        level.zm_ad_k = getarraykeys(level.var_83048cc59a40c0af);
        for (level.zm_ad_i = 0; level.zm_ad_i < level.zm_ad_k.size; level.zm_ad_i++)
        {
            zm_dm_auto_add(level.zm_ad_k[level.zm_ad_i]);
        }
    }
    level.zm_ad_ai = getaiarray();
    for (level.zm_ad_i = 0; level.zm_ad_i < level.zm_ad_ai.size; level.zm_ad_i++)
    {
        if (isdefined(level.zm_ad_ai[level.zm_ad_i]) && isdefined(level.zm_ad_ai[level.zm_ad_i].var_ef88add57e25f858))
        {
            zm_dm_auto_add(level.zm_ad_ai[level.zm_ad_i].var_ef88add57e25f858);
        }
    }
    if (level.zm_dm_auto_types.size != level.zm_ad_n0)
    {
        zm_dm_auto_merge();
    }
    return level.zm_dm_auto_types.size - level.zm_ad_n0;
}

zm_dm_auto_add(t)
{
    if (!isdefined(t) || !isstring(t) || t == "")
    {
        if (isdefined(t) && !isstring(t))
        {
            level.zm_dm_auto_hash = 1;
        }
        return;
    }
    for (level.zm_aa_i = 0; level.zm_aa_i < level.zm_dm_auto_types.size; level.zm_aa_i++)
    {
        if (level.zm_dm_auto_types[level.zm_aa_i] == t)
        {
            return;
        }
    }
    level.zm_dm_auto_types[level.zm_dm_auto_types.size] = t;
}

// add auto-detected types that the Spawn page doesn't have yet (only if the game can spawn them now)
zm_dm_auto_merge()
{
    if (!isdefined(level.zm_dm_auto_types) || !isdefined(level.zm_dm_spawn_list))
    {
        return;
    }
    for (level.zm_am_i = 0; level.zm_am_i < level.zm_dm_auto_types.size; level.zm_am_i++)
    {
        level.zm_am_t = level.zm_dm_auto_types[level.zm_am_i];
        level.zm_am_have = 0;
        for (level.zm_am_j = 0; level.zm_am_j < level.zm_dm_spawn_list.size; level.zm_am_j++)
        {
            if (level.zm_dm_spawn_list[level.zm_am_j] == level.zm_am_t || issubstr(level.zm_am_t, level.zm_dm_spawn_list[level.zm_am_j]))
            {
                level.zm_am_have = 1;
                break;
            }
        }
        if (!level.zm_am_have && zm_dm_can_spawn(level.zm_am_t))
        {
            level.zm_dm_spawn_list[level.zm_dm_spawn_list.size] = level.zm_am_t;
            level.zm_dm_auto_new++;
            zm_dm_dbg("auto_new_" + level.zm_dm_auto_new, level.zm_am_t);
        }
    }
    zm_dm_dbg("auto_types", level.zm_dm_auto_types.size + " seen, " + level.zm_dm_auto_new + " added");
    if (isdefined(level.zm_dm_auto_hash))
    {
        zm_dm_dbg("auto_hash", 1);
    }
}

// every model the map uses (script models + other entities with a model), for the Map props page
zm_dm_props_scan()
{
    level.zm_dm_mprops = [];
    level.zm_ps_e = getentarray();
    for (level.zm_ps_i = 0; level.zm_ps_i < level.zm_ps_e.size; level.zm_ps_i++)
    {
        level.zm_ps_x = level.zm_ps_e[level.zm_ps_i];
        if (!isdefined(level.zm_ps_x) || !isdefined(level.zm_ps_x.model) || !isstring(level.zm_ps_x.model))
        {
            continue;
        }
        level.zm_ps_m = level.zm_ps_x.model;
        if (level.zm_ps_m == "" || level.zm_ps_m == "tag_origin" || issubstr(level.zm_ps_m, "*") || isplayer(level.zm_ps_x) || isalive(level.zm_ps_x))
        {
            continue;
        }
        level.zm_ps_have = 0;
        for (level.zm_ps_j = 0; level.zm_ps_j < level.zm_dm_mprops.size; level.zm_ps_j++)
        {
            if (level.zm_dm_mprops[level.zm_ps_j] == level.zm_ps_m)
            {
                level.zm_ps_have = 1;
                break;
            }
        }
        if (!level.zm_ps_have && level.zm_dm_mprops.size < 300)
        {
            level.zm_dm_mprops[level.zm_dm_mprops.size] = level.zm_ps_m;
        }
    }
}


// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dm_init_is_zombies()
{
    level.zm_dm_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dm_init_gt) || level.zm_dm_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dm_init_gt, 0, 2) == "zm";
}

// WEAPON SCAN: every weapon the game has on this map (its own table level.weaponmapdata, read
// fresh each match) plus crossover / exotic names checked with weaponexists. Guns that are not
// already on a Weapons page go on Weapons > New weapons, so new guns from game updates show up
// by themselves. dbg wscan / wscan_new.
zm_dm_wscan()
{
    level.zm_dm_wnew = [];
    level.zm_ws_seen = [];
    level.zm_ws_keys = 0;
    level.zm_ws_hash = 0;
    if (isdefined(level.weaponmapdata))
    {
        level.zm_ws_k = getarraykeys(level.weaponmapdata);
        level.zm_ws_keys = level.zm_ws_k.size;
        for (level.zm_ws_i = 0; level.zm_ws_i < level.zm_ws_k.size; level.zm_ws_i++)
        {
            if (isstring(level.zm_ws_k[level.zm_ws_i]))
            {
                zm_dm_wscan_add(level.zm_ws_k[level.zm_ws_i]);
            }
            else
            {
                level.zm_ws_hash++;
            }
        }
    }
    level.zm_ws_cs = "sat_ar_ztrondg2 sat_dm_scotia sat_dm_scotiaexotic sat_dm_tasman sat_la_fang sat_la_zm_dinj sat_la_ztroncrossbow sat_la_ztronpable3 ";
    level.zm_ws_cs = level.zm_ws_cs + "sat_la_ztronwarmachine sat_lm_deathmachine sat_lm_hades sat_lm_zeus sat_lm_zeusexotic sat_lm_ztrondeathmachine sat_lm_ztronjetgun sat_lm_ztronlmg ";
    level.zm_ws_cs = level.zm_ws_cs + "sat_me_elnath sat_me_zombiefists sat_pi_alcor sat_pi_ztronraygun sat_sh_terrier sat_sh_ztronshotgun sat_sm_hyena sat_sm_mammoth sat_sm_stoat ";
    level.zm_ws_cs = level.zm_ws_cs + "sat_sm_zebra sat_sm_zebraexotic";
    level.zm_ws_c = strtok(level.zm_ws_cs, " ");
    for (level.zm_ws_i = 0; level.zm_ws_i < level.zm_ws_c.size; level.zm_ws_i++)
    {
        level.zm_ws_n = zm_dm_wscan_real(level.zm_ws_c[level.zm_ws_i]);
        if (isdefined(level.zm_ws_n))
        {
            zm_dm_wscan_add(level.zm_ws_n);
        }
    }
    zm_dm_dbg("wscan", level.script + " table " + level.zm_ws_keys + " (hashed " + level.zm_ws_hash + ") new " + level.zm_dm_wnew.size);
    level.zm_ws_txt = "";
    for (level.zm_ws_i = 0; level.zm_ws_i < level.zm_dm_wnew.size && level.zm_ws_i < 60; level.zm_ws_i++)
    {
        level.zm_ws_txt = level.zm_ws_txt + level.zm_dm_wnew[level.zm_ws_i] + " ";
    }
    zm_dm_dbg("wscan_new", level.zm_ws_txt);
    return level.zm_dm_wnew.size;
}

// the real name the game knows (plain, _zm or _mp), or undefined
zm_dm_wscan_real(n)
{
    if (zm_dm_weapon_known(n))
    {
        return n;
    }
    if (zm_dm_weapon_known(n + "_zm"))
    {
        return n + "_zm";
    }
    if (zm_dm_weapon_known(n + "_mp"))
    {
        return n + "_mp";
    }
    return undefined;
}

zm_dm_wscan_add(n)
{
    if (!issubstr(n, "_") || issubstr(n, "_ui_") || issubstr(n, "dummy") || issubstr(n, "none") || issubstr(n, "fists") || issubstr(n, "ztron") || issubstr(n, "diveknife") || issubstr(n, "zombie_melee") || issubstr(n, "zombie_mimic"))
    {
        return;
    }
    level.zm_wa_b = zm_dm_wbase(n);
    // a gun class we know (sat_<class>_...): ar sm lm sh dm sn pi la me ww
    level.zm_wa_t = strtok(level.zm_wa_b, "_");
    if (level.zm_wa_t.size < 3 || !issubstr(" ar sm lm sh dm sn pi la me ww ", " " + level.zm_wa_t[1] + " "))
    {
        return;
    }
    for (level.zm_wa_i = 0; level.zm_wa_i < level.zm_ws_seen.size; level.zm_wa_i++)
    {
        if (level.zm_ws_seen[level.zm_wa_i] == level.zm_wa_b)
        {
            return;
        }
    }
    level.zm_ws_seen[level.zm_ws_seen.size] = level.zm_wa_b;
    if (zm_dm_wmenu_has(level.zm_wa_t[1], getsubstr(level.zm_wa_b, level.zm_wa_t[0].size + level.zm_wa_t[1].size + 2, level.zm_wa_b.size)))
    {
        return;
    }
    level.zm_dm_wnew[level.zm_dm_wnew.size] = n;
}

// name without _zm / _mp at the end
zm_dm_wbase(n)
{
    if (n.size > 3 && (getsubstr(n, n.size - 3, n.size) == "_zm" || getsubstr(n, n.size - 3, n.size) == "_mp"))
    {
        return getsubstr(n, 0, n.size - 3);
    }
    return n;
}

// is this gun already on a Weapons page? (pages weapons_<cat>, wonder + scorestreak pages)
zm_dm_wmenu_has(cat, n)
{
    level.zm_wh_l = strtok(zm_dm_pg("weapons_" + cat), " ");
    for (level.zm_wh_i = 0; level.zm_wh_i < level.zm_wh_l.size; level.zm_wh_i++)
    {
        if (level.zm_wh_l[level.zm_wh_i] == n)
        {
            return 1;
        }
    }
    if (issubstr(zm_dm_pg("page_wonder") + zm_dm_pg("page_streaks"), "wgive " + cat + " " + n + "|") || issubstr(zm_dm_pg("page_wonder") + zm_dm_pg("page_streaks") + "~", "wgive " + cat + " " + n + "~"))
    {
        return 1;
    }
    return 0;
}

// "ztronraygun (pistol, crossover)" style label from a weapon name
zm_dm_wnew_label(n)
{
    level.zm_wl_b = zm_dm_wbase(n);
    level.zm_wl_t = strtok(level.zm_wl_b, "_");
    if (level.zm_wl_t.size < 3)
    {
        return n;
    }
    level.zm_wl_n = getsubstr(level.zm_wl_b, level.zm_wl_t[0].size + level.zm_wl_t[1].size + 2, level.zm_wl_b.size);
    level.zm_wl_k = level.zm_wl_t[1];
    level.zm_wl_c = level.zm_wl_k;
    if (level.zm_wl_k == "ar")
    {
        level.zm_wl_c = "assault rifle";
    }
    else if (level.zm_wl_k == "sm")
    {
        level.zm_wl_c = "SMG";
    }
    else if (level.zm_wl_k == "lm")
    {
        level.zm_wl_c = "LMG";
    }
    else if (level.zm_wl_k == "sh")
    {
        level.zm_wl_c = "shotgun";
    }
    else if (level.zm_wl_k == "dm")
    {
        level.zm_wl_c = "marksman";
    }
    else if (level.zm_wl_k == "sn")
    {
        level.zm_wl_c = "sniper";
    }
    else if (level.zm_wl_k == "pi")
    {
        level.zm_wl_c = "pistol";
    }
    else if (level.zm_wl_k == "la")
    {
        level.zm_wl_c = "launcher";
    }
    else if (level.zm_wl_k == "me")
    {
        level.zm_wl_c = "melee";
    }
    else if (level.zm_wl_k == "ww")
    {
        level.zm_wl_c = "wonder weapon";
    }
    // friendly names: exotic = the base gun's real name + Exotic, a few special ones by hand
    if (issubstr(level.zm_wl_n, "exotic"))
    {
        level.zm_wl_r = zm_dm_wreal(level.zm_wl_k, getsubstr(level.zm_wl_n, 0, level.zm_wl_n.size - 6));
        if (level.zm_wl_r != "")
        {
            return level.zm_wl_r + " Exotic (" + level.zm_wl_c + ")";
        }
    }
    if (level.zm_wl_n == "zm_dinj")
    {
        return "Mutant Injection (launcher)";
    }
    if (level.zm_wl_n == "mangler_cannon")
    {
        return "Mangler Cannon (launcher)";
    }
    level.zm_wl_x = "";
    if (issubstr(level.zm_wl_n, "ztron"))
    {
        level.zm_wl_x = ", crossover";
    }
    else if (issubstr(level.zm_wl_n, "exotic"))
    {
        level.zm_wl_x = ", exotic";
    }
    return level.zm_wl_n + " (" + level.zm_wl_c + level.zm_wl_x + ")";
}

// menu font of each era preset
zm_dm_preset_font_def(id)
{
    if (id == "waw") return "SecondaryBold";
    if (id == "bo1") return "PrimaryBlack";
    if (id == "bo2") return "SecondaryMedium";
    if (id == "bo3") return "PrimaryLight";
    if (id == "bo4") return "PrimaryBold";
    if (id == "bo6") return "SecondaryRegular";
    return "TertiaryMedium";
}

// real in-game name of a menu gun (pages weapons_<cat> + wnames_<cat>), or ""
zm_dm_wreal(cat, n)
{
    level.zm_wr_l = strtok(zm_dm_pg("weapons_" + cat), " ");
    level.zm_wr_m = strtok(zm_dm_pg("wnames_" + cat), "|");
    for (level.zm_wr_i = 0; level.zm_wr_i < level.zm_wr_l.size; level.zm_wr_i++)
    {
        if (level.zm_wr_l[level.zm_wr_i] == n && level.zm_wr_i < level.zm_wr_m.size)
        {
            return level.zm_wr_m[level.zm_wr_i];
        }
    }
    return "";
}

// Looks pages (lists from the looks script loot scan): operators -> their skins, camos in groups of 25
zm_dm_looks_page(page)
{
    if (!isdefined(level.zm_dml_ready))
    {
        level.zm_dm_title = "LOOKS";
        zm_dm_item("Still scanning the game - open again in a few seconds", "none");
        return;
    }
    if (page == "ops")
    {
        level.zm_dm_title = "OPERATORS (" + level.zm_dml_ops.size + ")";
        for (level.zm_lp_i = 0; level.zm_lp_i < level.zm_dml_ops.size; level.zm_lp_i++)
        {
            zm_dm_item([[ level.zm_dml_op_label_fn ]](level.zm_dml_ops[level.zm_lp_i]) + " (" + level.zm_dml_op_skins[level.zm_lp_i].size + ")" + zm_dm_arrow(), "opgo " + level.zm_lp_i);
        }
    }
    else if (page == "opskin")
    {
        level.zm_dm_title = "SKINS";
        level.zm_lp_l = level.zm_dml_op_skins[level.zm_dm_lkg];
        for (level.zm_lp_i = 0; level.zm_lp_i < level.zm_lp_l.size; level.zm_lp_i++)
        {
            zm_dm_item([[ level.zm_dml_skin_label_fn ]](namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_lp_l[level.zm_lp_i])), "look skin " + level.zm_lp_l[level.zm_lp_i]);
        }
    }
    else if (page == "camos")
    {
        level.zm_dm_title = "CAMOS (" + level.zm_dml_camo_ids.size + ")";
        for (level.zm_lp_i = 0; level.zm_lp_i < level.zm_dml_camo_ids.size; level.zm_lp_i = level.zm_lp_i + 25)
        {
            level.zm_lp_e = level.zm_lp_i + 25;
            if (level.zm_lp_e > level.zm_dml_camo_ids.size)
            {
                level.zm_lp_e = level.zm_dml_camo_ids.size;
            }
            zm_dm_item("Camos " + (level.zm_lp_i + 1) + " - " + level.zm_lp_e + zm_dm_arrow(), "camogo " + level.zm_lp_i);
        }
    }
    else
    {
        level.zm_dm_title = "CAMOS";
        for (level.zm_lp_i = level.zm_dm_lkg; level.zm_lp_i < level.zm_dm_lkg + 25 && level.zm_lp_i < level.zm_dml_camo_ids.size; level.zm_lp_i++)
        {
            zm_dm_item(namespace_952965bfef60cff8::function_f54ecb89dfab8e8c(level.zm_dml_camo_ids[level.zm_lp_i]), "look camo " + level.zm_dml_camo_ids[level.zm_lp_i]);
        }
    }
}

// for the game modes (overpowered script): self = player, give a gun by its base name (sat_<cat>_<n>)
zm_dm_give_named(n)
{
    level.zm_gn_n = zm_dm_wscan_real(n);
    if (!isdefined(level.zm_gn_n) || isdefined(self.zm_dm_busy))
    {
        return 0;
    }
    self.zm_dm_wname = level.zm_gn_n;
    self thread zm_dm_give_worker();
    return 1;
}

// every menu gun (pages weapons_<cat>) as sat_<cat>_<name>
zm_dm_all_guns()
{
    level.zm_ag = [];
    level.zm_ag_c = strtok("ar sm lm sh dm sn pi", " ");
    for (level.zm_ag_i = 0; level.zm_ag_i < level.zm_ag_c.size; level.zm_ag_i++)
    {
        level.zm_ag_l = strtok(zm_dm_pg("weapons_" + level.zm_ag_c[level.zm_ag_i]), " ");
        for (level.zm_ag_j = 0; level.zm_ag_j < level.zm_ag_l.size; level.zm_ag_j++)
        {
            level.zm_ag[level.zm_ag.size] = "sat_" + level.zm_ag_c[level.zm_ag_i] + "_" + level.zm_ag_l[level.zm_ag_j];
        }
    }
    return level.zm_ag;
}
