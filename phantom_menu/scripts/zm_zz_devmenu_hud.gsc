// Phantom menu (c) Ares. All rights reserved. Do not remove or change the "Made by Ares" credit.
// zm_zz_devmenu_hud - on-screen panel for Phantom menu (zm_zz_devmenu, Kronos).
// Kept in its own script: if BO7 lacks one of these HUD commands, only this file fails
// to link and the menu falls back to its centre-screen text mode.
//
// Style: tall dark panel at the screen edge with thin accent border lines, a path line at the
// top ("Phantom / MAIN"), one text element per row, an outline box drawn exactly around the
// selected row and sized to its text, and the PHANTOM logo at the bottom.
// Opening: the panel slides in and fades in, then the logo and every row are typed out
// letter by letter, one row after another.
// Text must go through Kronos' nengine_text() before settext, or it doesn't show.
// State lives on the player (self.zm_dmh): Kronos GSC loses locals across a wait.
//
// Live settings (kronos\devmenu\settings.json, read on every redraw):
//   hud_w 200 (panel width)   hud_row_h 14 (row height)   hud_text 1 (row text size)
//   hud_char_w 5.6 (width of one letter at size 1, for the outline box)   hud_top 34
//   hud_text_dy 0 (move row text up/down inside its box)   hud_bg_a 0.85
//   hud_open 0.25 (slide-in seconds)   hud_typing 1 (type text on open)   hud_type_step 1
//   (letters per 0.05 s)   hud_type_pages 0 (also type when you change page)   panel_right 1

autoexec zm_dmh_init()
{
    // Zombies only: Kronos loads custom scripts in every mode
    if (!zm_dmh_init_is_zombies())
    {
        return;
    }
    level.zm_dmh_str = [];
    level.zm_dmh_nstr = 0;
    // the credit the panel draws (checked by the main menu script)
    level.zm_dmh_credit = "Made by Ares";
    level.zm_dm_hud_create = &zm_dmh_create;
    level.zm_dm_hud_destroy = &zm_dmh_close;
    level.zm_dm_hud_show = &zm_dmh_show;
    level.zm_dm_hud_hint_show = &zm_dmh_hint_show;
    level.zm_dm_hud_hint_hide = &zm_dmh_hint_hide;
    // the dvar outlives the match: clear a picture left from the last one
    setdvar(@"phantom_bg", "");
    // The Lua add-on can only change a dvar that exists: create phantom_bg_lua once per game
    // session ("0"); the add-on sets it to "1" every 2 s while it runs.
    if (getdvar(@"phantom_bg_lua") != "1")
    {
        setdvar(@"phantom_bg_lua", "0");
    }
}

// Menu closed: remove the panel; the next build is a fresh open (typing plays again).
zm_dmh_close()
{
    self zm_dmh_hint_hide();
    self.zm_dmh_fresh = 1;
    t = zm_dmh_num("hud_close", 0.2);
    if (!isdefined(self.zm_dmh) || t <= 0)
    {
        self zm_dmh_destroy();
        return;
    }
    // Slide back out to the screen edge and fade (hud_close seconds), then remove. The picture
    // add-on is told a moment later (hud_bg_close_delay): it reacts at once, while the panel
    // movement reaches the screen a little after the server starts it.
    h = self.zm_dmh;
    h.typing = 0;
    h.type_id = -1;
    h.closing = 1;
    h.rf_id = -1;
    self.zm_dmh_cid = -1;
    h.off = h.w;
    if (!h.right)
    {
        h.off = 0 - h.w;
    }
    for (h.ci = 0; h.ci < h.all.size; h.ci++)
    {
        if (isdefined(h.all[h.ci]))
        {
            h.all[h.ci] moveovertime(t);
            h.all[h.ci] fadeovertime(t);
            h.all[h.ci].x = h.all[h.ci].x + h.off;
            h.all[h.ci].alpha = 0;
        }
    }
    h.cl_id = randomint(1000000);
    self.zm_dmh_cl_id = h.cl_id;
    self.zm_dmh_cl_t = t;
    self thread zm_dmh_close_later();
    self thread zm_dmh_bg_leave_later();
}

// Tells the picture add-on to slide out, hud_bg_close_delay seconds after the panel starts to.
// Skipped when the menu was reopened meanwhile (new panel record without cl_id).
zm_dmh_bg_leave_later()
{
    self endon("disconnect");
    self.zm_dmh_bg_delay = zm_dmh_num("hud_bg_close_delay", 0.05);
    if (self.zm_dmh_bg_delay > 0)
    {
        wait self.zm_dmh_bg_delay;
    }
    if (isdefined(self.zm_dmh) && isdefined(self.zm_dmh.cl_id) && self.zm_dmh.cl_id == self.zm_dmh_cl_id)
    {
        setdvar(@"phantom_bg", "");
    }
}

// Removes the closed panel once its slide-out is done, unless it was reopened meanwhile
// (a reopen builds a new panel record without cl_id). Fields only: locals die at the wait.
zm_dmh_close_later()
{
    self endon("disconnect");
    wait self.zm_dmh_cl_t + 0.05;
    if (isdefined(self.zm_dmh) && isdefined(self.zm_dmh.cl_id) && self.zm_dmh.cl_id == self.zm_dmh_cl_id)
    {
        self zm_dmh_destroy();
    }
}

zm_dmh_num(key, def)
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

zm_dmh_str(key, def)
{
    v = nengine_store_get("devmenu", key);
    if (!isdefined(v))
    {
        return def;
    }
    if (isstring(v))
    {
        return v;
    }
    return "" + v;
}

zm_dmh_elem(x, y, color, alpha, sort)
{
    e = newclienthudelem(self);
    if (!isdefined(e))
    {
        return undefined;
    }
    // Every element ever made for this player, so destroy can remove all of them (even ones
    // from a panel build that failed halfway).
    if (!isdefined(self.zm_dmh_every))
    {
        self.zm_dmh_every = [];
    }
    self.zm_dmh_every[self.zm_dmh_every.size] = e;
    e.alignx = "left";
    e.aligny = "top";
    // Right side: anchored to the screen's right edge (x counts back from it, as FuzMenu
    // does); the 640-wide left anchoring only covers the 4:3 middle of a wide screen.
    e.horzalign = "left";
    if (isdefined(self.zm_dmh) && isdefined(self.zm_dmh.halign))
    {
        e.horzalign = self.zm_dmh.halign;
    }
    e.vertalign = "top";
    e.x = x;
    e.y = y;
    e.color = color;
    e.alpha = alpha;
    e.sort = sort;
    e.foreground = 1;
    e.hidewheninmenu = 1;
    e.archived = 0;
    return e;
}

// Adds a built element to the panel and remembers where it rests (HUD elements can't hold
// extra fields of our own, so base x / alpha live in the panel record).
zm_dmh_add(e)
{
    h = self.zm_dmh;
    if (!isdefined(e))
    {
        return e;
    }
    h.bx[h.all.size] = e.x;
    h.ba[h.all.size] = e.alpha;
    h.all[h.all.size] = e;
    nengine_store_set("devmenu_dbg", "hud_build", "elements " + h.all.size);
    return e;
}

zm_dmh_box(x, y, w, h, color, alpha, sort)
{
    e = zm_dmh_elem(x, y, color, alpha, sort);
    if (isdefined(e))
    {
        e setshader("white", int(w), int(h));
    }
    return e;
}

zm_dmh_text(x, y, scale, color, sort, alignx)
{
    e = zm_dmh_elem(x, y, color, 1, sort);
    if (isdefined(e))
    {
        e.font = "default";
        e.fontscale = scale;
        if (isdefined(alignx))
        {
            e.alignx = alignx;
        }
    }
    return e;
}

// self = player. rows = rows in the list, accent = theme colour, key = what the panel was
// made for (rows / theme / side): it is rebuilt when that changes. Building = opening.
zm_dmh_create(rows, x, y, accent, key)
{
    zm_dmh_destroy();
    h = spawnstruct();
    h.w = zm_dmh_num("hud_w", 200);
    h.right = zm_dmh_num("panel_right", 1) == 1;
    h.x0 = 0;
    h.halign = "left";
    if (h.right)
    {
        h.x0 = 0 - h.w;
        h.halign = "right";
    }
    h.row_h = zm_dmh_num("hud_row_h", 14);
    h.text_s = zm_dmh_num("hud_text", 1);
    h.top = zm_dmh_num("hud_top", 34);
    h.text_dy = zm_dmh_num("hud_text_dy", 0);
    h.rows = rows;
    h.key = key;
    h.accent = accent;
    h.labels = [];
    h.cache = [];
    h.all = [];
    h.bx = [];
    h.ba = [];
    // Registered first, so a build that fails halfway is still cleaned up by destroy.
    self.zm_dmh = h;
    // Opening animation (slide-in, picture slide + fade, row cascade) only when the menu was just
    // opened; page changes that rebuild the panel (other row count) show it at once.
    h.isfresh = (!isdefined(self.zm_dmh_fresh) || self.zm_dmh_fresh);
    h.open_ms = 0;
    h.fade_ms = 0;
    if (h.isfresh)
    {
        h.open_ms = int(zm_dmh_num("hud_open", 0.3) * 1000);
        h.fade_ms = int(zm_dmh_num("hud_bg_fade_in", 0.6) * 1000);
    }
    // background + border lines + path line + separators
    // Panel height: down to just below the controls line (BO7's weapon / ammo display covers
    // the bottom corners), or the full screen height with hud_full 1.
    h.foot_y = h.top + h.rows * h.row_h + 10;
    h.height = h.foot_y + 32;
    if (zm_dmh_num("hud_full", 0) == 1)
    {
        h.height = 480;
    }
    // Background: plain black, or a picture (hud_bg_image = a PNG name in
    // kronos\Assets\Images, without .png; Kronos loads those at game start) with a dark
    // tint layer over it so the text stays readable (hud_bg_tint 0-1, hud_bg_img_a 0-1).
    h.bg_img = zm_dmh_str("hud_bg_image", "");
    // Picture drawn by the phantom_bg Lua add-on (kronos\mods\phantom_bg; loads at game start).
    // It sets the dvar phantom_bg_lua to "1" when running; then the panel only draws a see-through
    // tint (hud_bg_tint) over the picture. Without the add-on the panel stays plain dark.
    h.lua_bg = 0;
    h.frame_lua = 0;
    h.logo_pic = 0;
    h.lua_text = 0;
    if (h.bg_img != "" && h.bg_img != "0" && h.bg_img != "none" && getdvar(@"phantom_bg_lua") == "1")
    {
        h.lua_bg = 1;
        // build number: every build (also a rebuild) makes the picture slide in again with the panel
        if (!isdefined(level.zm_dmh_bid))
        {
            level.zm_dmh_bid = 0;
        }
        level.zm_dmh_bid++;
        // hud_bg_frame_lua 1: the add-on also draws the dark tint and the border line together with
        // the picture, as one piece, so the frame and picture can never come apart while sliding
        // (the panel's start time on screen jitters by up to one server frame).
        h.frame_lua = zm_dmh_num("hud_bg_frame_lua", 1) == 1;
        if (h.frame_lua)
        {
            h.logo_pic = 1;
            // the add-on also draws the row texts and the path line: its text uses none of the
            // game's limited text slots, so menu text can never run out
            if (zm_dmh_num("no_lua_text", 0) != 1 && getdvar(@"phantom_menu_lua") == "1")
            {
                h.lua_text = 1;
            }
        }
        h.tint_a = zm_dmh_num("hud_bg_tint", 0.45);
        if (h.frame_lua)
        {
            h.tint_a = 0;
        }
        h.bg = self zm_dmh_add(zm_dmh_box(h.x0, 0, h.w, h.height, (0, 0, 0), h.tint_a, 1));
        setdvar(@"phantom_bg", "PBG|" + h.bg_img + "|" + zm_dmh_num("panel_right", 1) + "|" + h.w + "|" + h.height + "|" + zm_dmh_num("hud_lua_scale", 2.25) + "|" + zm_dmh_num("hud_lua_dx", 0) + "|" + zm_dmh_num("hud_lua_dy", 0) + "|" + zm_dmh_num("hud_bg_img_a", 1) + "|" + zm_dmh_num("hud_lua_prio", -1000) + "|" + h.open_ms + "|" + int(zm_dmh_num("hud_close", 0.2) * 1000) + "|" + level.zm_dmh_bid + "|" + h.fade_ms + "|" + int(zm_dmh_num("hud_close", 0.2) * 1000) + "|" + zm_dmh_num("hud_bg_fade_pow", 2) + "|" + int(zm_dmh_num("hud_bg_lag", 0.04) * 1000) + "|" + zm_dmh_num("hud_bg_motion", 0) + "|" + accent[0] + " " + accent[1] + " " + accent[2] + "|" + zm_dmh_num("hud_bg_tint", 0.45) + "|2|" + zm_dmh_num("hud_bg_frame_lua", 1) + "|" + zm_dmh_logo_img() + "|" + zm_dmh_num("hud_logo_y", 8));
        nengine_store_set("devmenu_dbg", "hud_bg", "lua picture " + h.bg_img);
    }
    else if (h.bg_img != "" && h.bg_img != "0" && h.bg_img != "none" && zm_dmh_num("hud_bg_gsc", 0) == 1)
    {
        h.bg = self zm_dmh_add(zm_dmh_elem(h.x0, 0, (1, 1, 1), zm_dmh_num("hud_bg_img_a", 1), 1));
        if (isdefined(h.bg))
        {
            h.bg setshader(h.bg_img, int(h.w), int(h.height));
            self zm_dmh_add(zm_dmh_box(h.x0, 0, h.w, h.height, (0, 0, 0), zm_dmh_num("hud_bg_tint", 0.45), 2));
        }
        nengine_store_set("devmenu_dbg", "hud_bg", "image " + h.bg_img);
    }
    else
    {
        h.bg = self zm_dmh_add(zm_dmh_box(h.x0, 0, h.w, h.height, (0, 0, 0), zm_dmh_num("hud_bg_a", 0.85), 1));
        nengine_store_set("devmenu_dbg", "hud_bg", "plain");
    }
    if (!isdefined(h.bg))
    {
        // HUD element pool full or newclienthudelem missing
        self zm_dmh_destroy();
        return 0;
    }
    // One border line, on the side facing the middle of the screen (drawn by the add-on instead
    // when it draws the frame).
    if (h.lua_bg && h.frame_lua)
    {
    }
    else if (h.right)
    {
        self zm_dmh_add(zm_dmh_box(h.x0, 0, 2, h.height, accent, 1, 3));
    }
    else
    {
        self zm_dmh_add(zm_dmh_box(h.x0 + h.w - 2, 0, 2, h.height, accent, 1, 3));
    }
    // clean look (setting hud_old_lines 1 = old): dividers thin, see-through, inset
    h.clean = zm_dmh_num("hud_old_lines", 0) != 1;
    h.div_a = 0.9;
    h.div_in = 6;
    if (h.clean)
    {
        h.div_a = 0.35;
        h.div_in = 14;
    }
    self zm_dmh_add(zm_dmh_box(h.x0 + h.div_in, h.top - 8, h.w - h.div_in * 2, 1, accent, h.div_a, 3));
    h.path = self zm_dmh_add(zm_dmh_text(h.x0 + 10, h.top - 22, 0.9, (0.85, 0.85, 0.85), 6));
    // rows: one text element each, so the outline box can sit exactly on a row
    h.row = [];
    for (h.bi = 0; h.bi < rows; h.bi++)
    {
        h.row[h.bi] = self zm_dmh_add(zm_dmh_text(h.x0 + 12, h.top + h.bi * h.row_h + h.text_dy, h.text_s, (0.92, 0.92, 0.92), 6));
        // row font: live setting hud_font_rows (e.g. "default", "smallfixed" for a retro look)
        h.row[h.bi].font = zm_dmh_str("hud_font_rows", "default");
    }
    // selection outline: four thin lines (top, bottom, left, right) + a faint fill
    h.sel_t = self zm_dmh_add(zm_dmh_box(h.x0 + 8, h.top, 50, 1, (1, 1, 1), 1, 5));
    h.sel_b = self zm_dmh_add(zm_dmh_box(h.x0 + 8, h.top, 50, 1, (1, 1, 1), 1, 5));
    h.sel_l = self zm_dmh_add(zm_dmh_box(h.x0 + 8, h.top, 1, h.row_h, (1, 1, 1), 1, 5));
    h.sel_r = self zm_dmh_add(zm_dmh_box(h.x0 + 8, h.top, 1, h.row_h, (1, 1, 1), 1, 5));
    h.sel_f = self zm_dmh_add(zm_dmh_box(h.x0 + 8, h.top, 50, h.row_h, accent, 0.25, 4));
    if (h.clean && isdefined(h.sel_l))
    {
        h.sel_l.color = accent;
    }
    h.arrow = self zm_dmh_add(zm_dmh_text(h.x0 + 4, h.top, h.text_s, accent, 6));
    // bottom: separator, PHANTOM logo, controls
    // PHANTOM logo at the top (the top-right corner is free in BO7's HUD), controls line
    // under the last row, closing line under that.
    h.logo = self zm_dmh_add(zm_dmh_text(h.x0 + h.w / 2, zm_dmh_num("hud_logo_y", 8), 1.7, accent, 6, "center"));
    // credit line: built in its own thread, so a problem there can never stop the panel
    self.zm_dmh_credit_h = h;
    self thread zm_dmh_credit_make();
    self zm_dmh_add(zm_dmh_box(h.x0 + h.div_in, h.foot_y - 4, h.w - h.div_in * 2, 1, accent, h.div_a, 3));
    h.foot = self zm_dmh_add(zm_dmh_text(h.x0 + h.w / 2, h.foot_y, 0.75, (0.6, 0.6, 0.6), 6, "center"));
    if (h.clean)
    {
        self zm_dmh_add(zm_dmh_box(h.x0, h.height - 1, h.w, 1, accent, 0.6, 3));
    }
    else
    {
        self zm_dmh_add(zm_dmh_box(h.x0, h.height - 2, h.w, 2, accent, 1, 3));
    }
    // Typing effect without new texts: a black cover over the row slides off to the right
    // with a thin cursor at its edge (letter-by-letter texts used up Kronos' text slots).
    // (cover boxes of the old cover typing removed: they only used up HUD elements)
    h.caret = self zm_dmh_add(zm_dmh_box(h.x0 + 10, h.top, 2, h.row_h, accent, 0, 8));
    // the logo has its own cover: it is revealed slowly while the rows type, ending with them
    nengine_store_set("devmenu_dbg", "hud_build", "built " + h.all.size);
    self zm_dmh_open_anim();
    nengine_store_set("devmenu_dbg", "hud_build", "built + anim " + h.all.size);
    return 1;
}

// Slide in from the screen edge and fade in (game's own moveovertime / fadeovertime).
zm_dmh_open_anim()
{
    h = self.zm_dmh;
    t = zm_dmh_num("hud_open", 0.25);
    off = h.w;
    if (!h.right)
    {
        off = 0 - h.w;
    }
    // Type only when the menu was just opened (not when it rebuilds for a new colour / side /
    // row count): every typed letter step is a new text, and Kronos has a limited number of
    // text slots per match (when they run out, new texts stay blank).
    h.typing = zm_dmh_num("hud_typing", 1) == 1 && h.isfresh;
    self.zm_dmh_fresh = 0;
    h.type_row = -1;
    h.type_n = 0;
    for (h.ai = 0; h.ai < h.all.size; h.ai++)
    {
        e = h.all[h.ai];
        if (!isdefined(e))
        {
            continue;
        }
        if (t > 0 && h.isfresh)
        {
            e.x = h.bx[h.ai] + off;
            e.alpha = 0;
            e moveovertime(t);
            e fadeovertime(t);
        }
        e.x = h.bx[h.ai];
        e.alpha = h.ba[h.ai];
    }
    if (h.typing)
    {
        // Cascade instead of letter typing: letter typing makes a new text per letter step,
        // Kronos never reuses those slots between matches, and after a few matches every new
        // text in the session stays blank. The cascade uses no new texts: each row slides in
        // from the side and fades in, one after another; the logo fades in and grows over
        // the whole time, finishing with the last row.
        h.typing = 0;
        for (h.ai = 0; h.ai < h.rows; h.ai++)
        {
            h.row[h.ai].alpha = 0;
        }
        h.logo.alpha = 0;
        h.casc_wait = t;
        self thread zm_dmh_cascade();
    }
    // New text set on an element in the same frame it was made can stay blank in BO7
    // (seen after rebuilds: only the label with brand-new text was missing), so every text
    // is set once more a moment later.
    self thread zm_dmh_redraw_later();
    self thread zm_dmh_refresh_loop();
}

// Row cascade (hud_row_delay seconds between rows, hud_row_slide seconds per row) and the
// slow logo fade + grow. Fields only (waits inside).
zm_dmh_cascade()
{
    self endon("disconnect");
    self.zm_dmh.casc_id = randomint(1000000);
    self.zm_dmh_cid = self.zm_dmh.casc_id;
    if (self.zm_dmh.casc_wait > 0)
    {
        wait self.zm_dmh.casc_wait;
    }
    if (!isdefined(self.zm_dmh) || self.zm_dmh.casc_id != self.zm_dmh_cid)
    {
        return;
    }
    self.zm_dmh.c_delay = zm_dmh_num("hud_row_delay", 0.12);
    self.zm_dmh.c_slide = zm_dmh_num("hud_row_slide", 0.25);
    self.zm_dmh.c_n = self.zm_dmh.labels.size;
    if (self.zm_dmh.c_n > self.zm_dmh.rows)
    {
        self.zm_dmh.c_n = self.zm_dmh.rows;
    }
    // logo: plain fade in over the whole cascade
    self.zm_dmh.c_total = self.zm_dmh.c_n * self.zm_dmh.c_delay + self.zm_dmh.c_slide;
    self.zm_dmh.logo fadeovertime(self.zm_dmh.c_total);
    self.zm_dmh.logo.alpha = 1;
    // rows: "vintage terminal" - a block cursor runs along the row while the row fades in,
    // one row after another (no new texts, nothing moves but the cursor)
    self.zm_dmh.c_cw = zm_dmh_num("hud_char_w", 5.6) * self.zm_dmh.text_s;
    for (self.zm_dmh_ci = 0; self.zm_dmh_ci < self.zm_dmh.c_n; self.zm_dmh_ci++)
    {
        if (!isdefined(self.zm_dmh) || self.zm_dmh.casc_id != self.zm_dmh_cid)
        {
            return;
        }
        self.zm_dmh_ce = self.zm_dmh.row[self.zm_dmh_ci];
        self.zm_dmh_ce fadeovertime(self.zm_dmh.c_slide);
        self.zm_dmh_ce.alpha = 1;
        self.zm_dmh.c_y = self.zm_dmh.top + self.zm_dmh_ci * self.zm_dmh.row_h + 2;
        self.zm_dmh.c_w = zm_dmh_plain_len(self.zm_dmh.labels[self.zm_dmh_ci]) * self.zm_dmh.c_cw;
        self.zm_dmh.c_x = self.zm_dmh_ce.x;
        zm_dmh_place(self.zm_dmh.caret, self.zm_dmh.c_x, self.zm_dmh.c_y, int(self.zm_dmh.c_cw), self.zm_dmh.row_h - 4);
        self.zm_dmh.caret.alpha = 1;
        self.zm_dmh.caret moveovertime(self.zm_dmh.c_slide);
        self.zm_dmh.caret.x = self.zm_dmh.c_x + self.zm_dmh.c_w;
        wait self.zm_dmh.c_delay;
    }
    if (!isdefined(self.zm_dmh) || self.zm_dmh.casc_id != self.zm_dmh_cid)
    {
        return;
    }
    // cursor blinks a few times at the end of the last row, then goes
    for (self.zm_dmh_ci = 0; self.zm_dmh_ci < 6; self.zm_dmh_ci++)
    {
        if (!isdefined(self.zm_dmh) || self.zm_dmh.casc_id != self.zm_dmh_cid)
        {
            return;
        }
        self.zm_dmh.caret.alpha = (self.zm_dmh_ci + 1) % 2;
        wait 0.25;
    }
    if (isdefined(self.zm_dmh) && self.zm_dmh.casc_id == self.zm_dmh_cid)
    {
        self.zm_dmh.caret.alpha = 0;
        for (self.zm_dmh_ci = 0; self.zm_dmh_ci < self.zm_dmh.rows; self.zm_dmh_ci++)
        {
            self.zm_dmh.row[self.zm_dmh_ci].alpha = 1;
        }
    }
}

// While the panel is open: every hud_refresh seconds set every text again (same texts, so no
// new text slots) - lines that didn't draw (BO7 sometimes drops a settext) come back.
zm_dmh_refresh_loop()
{
    self endon("disconnect");
    self.zm_dmh.rf_id = randomint(1000000);
    self.zm_dmh_rfid = self.zm_dmh.rf_id;
    while (1)
    {
        self.zm_dmh_rft = zm_dmh_num("hud_refresh", 1);
        if (self.zm_dmh_rft < 0.25)
        {
            self.zm_dmh_rft = 0.25;
        }
        wait self.zm_dmh_rft;
        if (!isdefined(self.zm_dmh) || !isdefined(self.zm_dmh.rf_id) || self.zm_dmh.rf_id != self.zm_dmh_rfid)
        {
            return;
        }
        if (isdefined(self.zm_dmh.closing) && self.zm_dmh.closing)
        {
            return;
        }
        if (isdefined(self.zm_dmh.last_list))
        {
            self.zm_dmh.cache = [];
            self zm_dmh_show(self.zm_dmh.last_title, self.zm_dmh.last_sub, self.zm_dmh.last_list, self.zm_dmh.last_sel, self.zm_dmh.last_foot);
        }
    }
}

zm_dmh_redraw_later()
{
    self endon("disconnect");
    wait 0.1;
    if (!isdefined(self.zm_dmh) || !isdefined(self.zm_dmh.last_list))
    {
        return;
    }
    self.zm_dmh.cache = [];
    self zm_dmh_show(self.zm_dmh.last_title, self.zm_dmh.last_sub, self.zm_dmh.last_list, self.zm_dmh.last_sel, self.zm_dmh.last_foot);
}

// Types the logo, then each row, a few letters every 0.05 s. Fields only (waits inside).
zm_dmh_type_loop()
{
    self endon("disconnect");
    self.zm_dmh.type_id = randomint(1000000);
    self.zm_dmh_tid = self.zm_dmh.type_id;
    for (self.zm_dmh_tw = 0; self.zm_dmh_tw < self.zm_dmh.type_wait; self.zm_dmh_tw++)
    {
        wait 0.05;
    }
    // row -1 = the logo
    while (isdefined(self.zm_dmh) && self.zm_dmh.type_id == self.zm_dmh_tid && self.zm_dmh.typing)
    {
        self zm_dmh_type_step();
        wait 0.05;
    }
}

// One step of the typing effect (hud_type_step letters per 0.05 s). Rows type one after
// another with real partial texts; the PHANTOM logo types in step with all rows together and
// finishes with the last one. Every partial text costs one Kronos text slot ONCE per game
// session (cached and reused on every later open); when hud_type_budget slots are used,
// rows just appear whole one after another. (A cover box can't hide text: BO7 draws HUD
// text above every box.)
zm_dmh_type_step()
{
    h = self.zm_dmh;
    if (h.type_row >= h.rows || h.type_row >= h.labels.size)
    {
        self zm_dmh_type_done();
        return;
    }
    h.t_step = int(zm_dmh_num("hud_type_step", 2));
    if (h.t_step < 1)
    {
        h.t_step = 1;
    }
    h.t_over = level.zm_dmh_nstr > zm_dmh_num("hud_type_budget", 300);
    if (h.type_total_w < 0)
    {
        // first step: total letters of all rows (for the logo's pace)
        h.type_total_w = 0;
        for (h.ai = 0; h.ai < h.rows && h.ai < h.labels.size; h.ai++)
        {
            h.type_total_w = h.type_total_w + zm_dmh_plain_len(h.labels[h.ai]);
        }
        h.logo.alpha = 1;
        h.l_shown = -1;
    }
    if (h.type_n == 0)
    {
        h.t_full = self zm_dmh_type_text(h.type_row);
        h.t_len = zm_dmh_plain_len(h.t_full);
        h.row[h.type_row].alpha = 1;
    }
    h.type_n = h.type_n + h.t_step;
    h.type_done_w = h.type_done_w + h.t_step;
    if (h.t_over)
    {
        h.type_done_w = h.type_done_w - h.t_step + h.t_len;
        h.type_n = h.t_len;
    }
    // logo letters: same share of PHANTOM as the share of all rows typed so far
    h.l_n = 7;
    if (h.type_total_w > 0 && h.type_done_w < h.type_total_w)
    {
        h.l_n = int(7 * h.type_done_w / h.type_total_w);
    }
    if (h.l_n != h.l_shown)
    {
        h.l_shown = h.l_n;
        h.l_text = "";
        if (h.l_n > 0)
        {
            h.l_text = zm_dmh_prefix(zm_dmh_logo_text(h), h.l_n);
        }
        zm_dmh_set("logo", h.logo, h.l_text);
    }
    if (h.type_n >= h.t_len)
    {
        // row done: show it whole, go to the next one
        self zm_dmh_set_row(h.type_row, h.t_full);
        h.type_row++;
        h.type_n = 0;
        if (h.type_row >= h.rows || h.type_row >= h.labels.size)
        {
            self zm_dmh_type_done();
        }
        return;
    }
    h.t_pre = zm_dmh_prefix(h.t_full, h.type_n);
    self zm_dmh_set_row(h.type_row, h.t_pre);
}

zm_dmh_type_done()
{
    h = self.zm_dmh;
    h.typing = 0;
    // (no cover boxes any more)
    h.caret.alpha = 0;
    for (h.ai = 0; h.ai < h.rows; h.ai++)
    {
        h.row[h.ai].alpha = 1;
    }
    h.logo.alpha = 1;
    zm_dmh_set("logo", h.logo, zm_dmh_logo_text(h));
    self zm_dmh_draw_rows();
    self zm_dmh_sel_vis();
}

// Text of row r (-1 = logo).
zm_dmh_type_text(r)
{
    h = self.zm_dmh;
    if (r < 0)
    {
        return "PHANTOM";
    }
    if (r < h.labels.size)
    {
        return h.labels[r];
    }
    return "";
}

zm_dmh_set_row(r, text)
{
    h = self.zm_dmh;
    if (r < 0)
    {
        zm_dmh_set("logo", h.logo, text);
        return;
    }
    if (r < h.rows)
    {
        zm_dmh_set("row" + r, h.row[r], text);
    }
}

// First n visible letters of s, keeping ^N colour codes (they take no space on screen).
zm_dmh_prefix(s, n)
{
    out = "";
    seen = 0;
    i = 0;
    while (i < s.size && seen < n)
    {
        c = getsubstr(s, i, i + 1);
        if (c == "^" && i + 1 < s.size)
        {
            out = out + getsubstr(s, i, i + 2);
            i = i + 2;
            continue;
        }
        out = out + c;
        seen++;
        i++;
    }
    return out;
}

// Number of letters shown on screen (^N colour codes left out).
zm_dmh_plain_len(s)
{
    n = 0;
    i = 0;
    while (i < s.size)
    {
        if (getsubstr(s, i, i + 1) == "^" && i + 1 < s.size)
        {
            i = i + 2;
            continue;
        }
        n++;
        i++;
    }
    return n;
}

zm_dmh_destroy()
{
    if (isdefined(self.zm_dmh))
    {
        self.zm_dmh.typing = 0;
        self.zm_dmh.type_id = -1;
    }
    if (isdefined(self.zm_dmh_every))
    {
        for (self.zm_dmh_di = 0; self.zm_dmh_di < self.zm_dmh_every.size; self.zm_dmh_di++)
        {
            if (isdefined(self.zm_dmh_every[self.zm_dmh_di]))
            {
                self.zm_dmh_every[self.zm_dmh_di] destroy();
            }
        }
    }
    self.zm_dmh_every = [];
    self.zm_dmh = undefined;
    // tells the Lua add-on to remove the picture
    setdvar(@"phantom_bg", "");
}

// Sets a text only when it changed (every new string uses up a text slot).
zm_dmh_set(key, e, text)
{
    h = self.zm_dmh;
    if (!isdefined(e))
    {
        return;
    }
    if (text == "")
    {
        text = " ";
    }
    if (isdefined(h.cache[key]) && h.cache[key] == text)
    {
        return;
    }
    h.cache[key] = text;
    if (isdefined(h.lua_text) && h.lua_text && key == "foot")
    {
        // the add-on draws the controls line (plain words: the button-icon codes didn't show)
        e settext(nengine_text(" "));
        setdvar(@"phantom_foot", int(h.foot_y) + "|Aim  up      Shoot  down      Use  select      Knife  back");
        return;
    }
    if (isdefined(h.lua_text) && h.lua_text && (key == "path" || getsubstr(key, 0, 3) == "row"))
    {
        e settext(nengine_text(" "));
        return;
    }
    // a row with a game text label (e.g. a gun's in-game name): show that label instead
    if (getsubstr(key, 0, 3) == "row" && isdefined(level.zm_dw_istr))
    {
        level.zm_dmh_ri = int(getsubstr(key, 3, key.size));
        if (isdefined(level.zm_dw_istr[level.zm_dmh_ri]))
        {
            e settext(level.zm_dw_istr[level.zm_dmh_ri]);
            return;
        }
    }
    if (!isdefined(level.zm_dmh_str[text]))
    {
        level.zm_dmh_str[text] = nengine_text(text);
        level.zm_dmh_nstr++;
        nengine_store_set("devmenu_dbg", "hud_strings", level.zm_dmh_nstr);
    }
    loc = level.zm_dmh_str[text];
    if (isdefined(loc))
    {
        e settext(loc);
    }
    else
    {
        e settext(text);
    }
}

// Writes every row's full text (the typing effect only hides / covers, it never makes new
// texts), and the logo.
zm_dmh_draw_rows()
{
    h = self.zm_dmh;
    for (i = 0; i < h.rows; i++)
    {
        t = "";
        if (i < h.labels.size)
        {
            t = h.labels[i];
        }
        if (h.typing && i == h.type_row)
        {
            continue;
        }
        zm_dmh_set("row" + i, h.row[i], t);
    }
    if (!h.typing)
    {
        zm_dmh_set("logo", h.logo, zm_dmh_logo_text(h));
    }
}

// title = menu name (unused, the logo shows it), sub = page title, list = rows joined by
// line breaks, sel_row = highlighted row (0-based, on screen), foot = controls line.
zm_dmh_show(title, sub, list, sel_row, foot)
{
    h = self.zm_dmh;
    if (!isdefined(h))
    {
        return;
    }
    h.last_title = title;
    h.last_sub = sub;
    h.last_list = list;
    h.last_sel = sel_row;
    h.last_foot = foot;
    h.labels = strtok(list, "\n");
    // new page = no scroll glide (the list jumps to the new page)
    h.changed_page = !isdefined(h.prev_sub) || h.prev_sub != sub;
    h.prev_sub = sub;
    h.changed = !isdefined(h.list_text) || h.list_text != list;
    h.list_text = list;
    if (h.changed &&!h.typing && isdefined(h.shown_once) && zm_dmh_num("hud_type_pages", 0) == 1)
    {
        h.typing = 1;
        h.type_row = 0;
        h.type_n = 0;
        h.type_wait = 0;
        self thread zm_dmh_type_loop();
    }
    h.shown_once = 1;
    zm_dmh_set("path", h.path, "^7Phantom ^8/ ^7" + sub);
    zm_dmh_set("foot", h.foot, foot);
    self zm_dmh_draw_rows();
    // outline box around the selected row, as wide as its text
    h.sel = sel_row;
    if (h.sel < 0 || h.sel >= h.rows)
    {
        h.sel = 0;
    }
    h.sel_lab = "";
    if (h.sel < h.labels.size)
    {
        h.sel_lab = h.labels[h.sel];
    }
    h.cw = zm_dmh_num("hud_char_w", 5.6);
    // "Animated list" look (user's video): the selected row is pushed in the most, the
    // rows around it less the further away they are, and the list scrolls smoothly so the
    // selection stays near the middle. hud_bulge (indent of the selected row), hud_bulge_step
    // (less per row away), hud_scroll_t (seconds per move).
    h.bulge = zm_dmh_num("hud_bulge", 14);
    h.bstep = zm_dmh_num("hud_bulge_step", 4);
    h.mv_t = zm_dmh_num("hud_scroll_t", 0.12);
    h.cur_top = 0;
    if (isdefined(level.zm_dm_top))
    {
        h.cur_top = level.zm_dm_top;
    }
    h.dtop = 0;
    if (isdefined(h.prev_top) && !h.changed_page)
    {
        h.dtop = h.cur_top - h.prev_top;
    }
    h.prev_top = h.cur_top;
    for (h.li = 0; h.li < h.rows; h.li++)
    {
        h.l_off = h.bulge - abs(h.li - h.sel) * h.bstep;
        if (h.l_off < 0)
        {
            h.l_off = 0;
        }
        h.l_x = h.x0 + 12 + h.l_off;
        h.l_y = h.top + h.li * h.row_h + h.text_dy;
        if (h.mv_t > 0 && h.dtop != 0 && abs(h.dtop) <= 3)
        {
            // start one row lower / higher and glide into place = scrolling
            h.row[h.li].y = h.l_y + h.dtop * h.row_h;
        }
        if (h.mv_t > 0)
        {
            h.row[h.li] moveovertime(h.mv_t);
        }
        h.row[h.li].x = h.l_x;
        h.row[h.li].y = h.l_y;
    }
    // selection outline + arrow, glided to the selected row
    h.s_off = h.bulge;
    h.bw = zm_dmh_plain_len(h.sel_lab) * h.cw * h.text_s + 10;
    if (h.clean)
    {
        // the whole row width (one clean bar instead of a box around the text)
        h.bw = h.w - 16 - h.bulge;
    }
    if (h.bw > h.w - 14 - h.s_off)
    {
        h.bw = h.w - 14 - h.s_off;
    }
    h.bx = h.x0 + 8 + h.s_off;
    h.by = h.top + h.sel * h.row_h;
    zm_dmh_place(h.sel_t, h.bx, h.by, h.bw, 1);
    zm_dmh_place(h.sel_b, h.bx, h.by + h.row_h - 1, h.bw, 1);
    if (h.clean)
    {
        zm_dmh_place(h.sel_l, h.bx, h.by, 2, h.row_h);
    }
    else
    {
        zm_dmh_place(h.sel_l, h.bx, h.by, 1, h.row_h);
    }
    zm_dmh_place(h.sel_r, h.bx + h.bw - 1, h.by, 1, h.row_h);
    zm_dmh_place(h.sel_f, h.bx, h.by, h.bw, h.row_h);
    if (isdefined(h.arrow))
    {
        zm_dmh_set("arrow", h.arrow, ">");
        if (h.mv_t > 0)
        {
            h.arrow moveovertime(h.mv_t);
        }
        h.arrow.x = h.bx - 9;
        h.arrow.y = h.by + h.text_dy;
    }
    self zm_dmh_sel_vis();
    if (h.lua_text)
    {
        self zm_dmh_lua_publish();
    }
}

// Visible page for the add-on (dvar phantom_menu):
// PM|build|sel|top|row_h|text size|text_dy|bulge|bulge step|scroll ms|row delay ms|fresh|path|row0|row1|...
zm_dmh_lua_publish()
{
    h = self.zm_dmh;
    h.lp = "PM|" + level.zm_dmh_bid + "|" + h.sel + "|" + h.top + "|" + h.row_h + "|" + h.text_s + "|" + h.text_dy + "|" + h.bulge + "|" + h.bstep + "|" + int(h.mv_t * 1000) + "|" + int(zm_dmh_num("hud_row_delay", 0.2) * 1000) + "|" + h.isfresh + "|^7Phantom ^8/ ^7" + h.last_sub;
    for (h.lpi = 0; h.lpi < h.rows && h.lpi < h.labels.size; h.lpi++)
    {
        h.lp = h.lp + "|" + h.labels[h.lpi];
    }
    setdvar(@"phantom_menu", h.lp);
}
zm_dmh_sel_vis()
{
    h = self.zm_dmh;
    if (!isdefined(h) || !isdefined(h.sel))
    {
        return;
    }
    // Always shown (it fades in with the panel, before the text types in), so you always see
    // which row you're on.
    h.sel_on = 1;
    h.sel_a = 0;
    if (h.sel_on)
    {
        h.sel_a = 1;
    }
    if (isdefined(h.sel_t))
    {
        h.sel_t.alpha = h.sel_a;
        h.sel_b.alpha = h.sel_a;
        h.sel_l.alpha = h.sel_a;
        h.sel_r.alpha = h.sel_a;
        h.sel_f.alpha = h.sel_a * 0.25;
        if (h.clean)
        {
            // no box edges: just the stripe and a soft tint
            h.sel_t.alpha = 0;
            h.sel_b.alpha = 0;
            h.sel_r.alpha = 0;
            h.sel_f.alpha = h.sel_a * 0.18;
        }
    }
}

zm_dmh_place(e, x, y, w, ht)
{
    if (!isdefined(e))
    {
        return;
    }
    e.x = x;
    e.y = y;
    e setshader("white", int(w), int(ht));
}

// ---------------------------------------------------------------- hint box

// Small fully opaque box beside the panel with instructions (used by Rounds > Type a round).
// self = player. lines = text with \n line breaks, n = number of lines. Its elements are kept
// apart from the panel's (self.zm_dmh_hint_e), so panel rebuilds don't touch it.
zm_dmh_hint_show(lines, n)
{
    // parameters kept on self: locals can come back empty after calls in Kronos GSC
    self.zm_dmh_hint_txt = lines;
    self.zm_dmh_hint_n = n;
    self zm_dmh_hint_hide();
    self.zm_dmh_hint_w = zm_dmh_num("hint_w", 150);
    self.zm_dmh_hint_lh = zm_dmh_num("hint_line_h", 11);
    self.zm_dmh_hint_h = self.zm_dmh_hint_n * self.zm_dmh_hint_lh + 10;
    self.zm_dmh_hint_pw = zm_dmh_num("hud_w", 200);
    self.zm_dmh_hint_y = zm_dmh_num("hud_top", 78) + zm_dmh_num("hint_dy", 0);
    self.zm_dmh_hint_al = "left";
    self.zm_dmh_hint_x = self.zm_dmh_hint_pw + 6;
    if (zm_dmh_num("panel_right", 1) == 1)
    {
        self.zm_dmh_hint_al = "right";
        self.zm_dmh_hint_x = 0 - self.zm_dmh_hint_pw - 6 - self.zm_dmh_hint_w;
    }
    self.zm_dmh_hint_c = (0.2, 0.8, 0.3);
    if (isdefined(self.zm_dmh) && isdefined(self.zm_dmh.accent))
    {
        self.zm_dmh_hint_c = self.zm_dmh.accent;
    }
    self.zm_dmh_hint_e = [];
    self.zm_dmh_hint_e[0] = self zm_dmh_hint_elem(self.zm_dmh_hint_x, self.zm_dmh_hint_y, (0, 0, 0), 10);
    if (isdefined(self.zm_dmh_hint_e[0]))
    {
        self.zm_dmh_hint_e[0] setshader("white", int(self.zm_dmh_hint_w), int(self.zm_dmh_hint_h));
    }
    self.zm_dmh_hint_e[1] = self zm_dmh_hint_elem(self.zm_dmh_hint_x, self.zm_dmh_hint_y, self.zm_dmh_hint_c, 11);
    if (isdefined(self.zm_dmh_hint_e[1]))
    {
        self.zm_dmh_hint_e[1] setshader("white", int(self.zm_dmh_hint_w), 2);
    }
    self.zm_dmh_hint_e[2] = self zm_dmh_hint_elem(self.zm_dmh_hint_x + 6, self.zm_dmh_hint_y + 6, (1, 1, 1), 12);
    if (isdefined(self.zm_dmh_hint_e[2]))
    {
        self.zm_dmh_hint_e[2].font = "default";
        self.zm_dmh_hint_e[2].fontscale = zm_dmh_num("hint_text", 0.85);
        self.zm_dmh_hint_loc = level.zm_dmh_str[self.zm_dmh_hint_txt];
        if (!isdefined(self.zm_dmh_hint_loc))
        {
            level.zm_dmh_str[self.zm_dmh_hint_txt] = nengine_text(self.zm_dmh_hint_txt);
            self.zm_dmh_hint_loc = level.zm_dmh_str[self.zm_dmh_hint_txt];
        }
        if (isdefined(self.zm_dmh_hint_loc))
        {
            self.zm_dmh_hint_e[2] settext(self.zm_dmh_hint_loc);
        }
        else
        {
            self.zm_dmh_hint_e[2] settext(self.zm_dmh_hint_txt);
        }
    }
}

zm_dmh_hint_elem(x, y, color, sort)
{
    e = newclienthudelem(self);
    if (!isdefined(e))
    {
        return undefined;
    }
    e.alignx = "left";
    e.aligny = "top";
    e.horzalign = self.zm_dmh_hint_al;
    e.vertalign = "top";
    e.x = x;
    e.y = y;
    e.color = color;
    e.alpha = 1;
    e.sort = sort;
    e.foreground = 1;
    e.hidewheninmenu = 1;
    e.archived = 0;
    return e;
}

zm_dmh_hint_hide()
{
    if (isdefined(self.zm_dmh_hint_e))
    {
        for (self.zm_dmh_hint_i = 0; self.zm_dmh_hint_i < self.zm_dmh_hint_e.size; self.zm_dmh_hint_i++)
        {
            if (isdefined(self.zm_dmh_hint_e[self.zm_dmh_hint_i]))
            {
                self.zm_dmh_hint_e[self.zm_dmh_hint_i] destroy();
            }
        }
    }
    self.zm_dmh_hint_e = undefined;
}

// "Made by Ares": fades red -> black -> red while this panel lives (fixed, not a setting).
zm_dmh_credit_pulse()
{
    self endon("disconnect");
    self.zm_dmh_pulse_on = self.zm_dmh_pulse_h;
    self.zm_dmh_pulse_k = 0;
    while (isdefined(self.zm_dmh_pulse_on.credit) && isdefined(self.zm_dmh) && self.zm_dmh == self.zm_dmh_pulse_on)
    {
        self zm_dmh_credit_step();
        wait 0.05;
    }
}

// one colour step: red -> near black -> red, 28 steps (1.4 s) per full pulse; no fadeovertime
zm_dmh_credit_step()
{
    self.zm_dmh_pulse_k = (self.zm_dmh_pulse_k + 1) % 28;
    self.zm_dmh_pulse_f = self.zm_dmh_pulse_k / 14.0;
    if (self.zm_dmh_pulse_k >= 14)
    {
        self.zm_dmh_pulse_f = (28 - self.zm_dmh_pulse_k) / 14.0;
    }
    // f 0 = red, 1 = near black
    self.zm_dmh_pulse_on.credit.color = (1 - 0.95 * self.zm_dmh_pulse_f, 0.1 - 0.1 * self.zm_dmh_pulse_f, 0.1 - 0.1 * self.zm_dmh_pulse_f);
}

// pulse time per fade; a missing setting reads as 0 here, and wait 0 in a loop freezes the game
zm_dmh_pulse_t()
{
    level.zm_dmh_pt = zm_dmh_num("hud_credit_pulse", 0.7);
    if (!isdefined(level.zm_dmh_pt) || level.zm_dmh_pt < 0.1)
    {
        level.zm_dmh_pt = 0.7;
    }
    return level.zm_dmh_pt;
}

// v, or def when v is missing / 0
zm_dmh_min(v, def)
{
    if (!isdefined(v) || v == 0)
    {
        return def;
    }
    return v;
}

zm_dmh_credit_make()
{
    nengine_store_set("devmenu_dbg", "credit", "start");
    self.zm_dmh_ch = self.zm_dmh_credit_h;
    // under the controls line at the bottom of the panel
    self.zm_dmh_cy = self.zm_dmh_ch.foot_y + 16;

    self.zm_dmh_ce = zm_dmh_text(self.zm_dmh_ch.x0 + self.zm_dmh_ch.w / 2, self.zm_dmh_cy, 0.85, (0.85, 0.85, 0.85), 6, "center");
    nengine_store_set("devmenu_dbg", "credit", "made elem");
    self.zm_dmh_ch.credit = self zm_dmh_add(self.zm_dmh_ce);
    nengine_store_set("devmenu_dbg", "credit", "added");
    // fixed credit: not a setting, nobody can change it
    self.zm_dmh_ch.credit_t = level.zm_dmh_credit;
    zm_dmh_set("credit", self.zm_dmh_ch.credit, self.zm_dmh_ch.credit_t);
    nengine_store_set("devmenu_dbg", "credit", "text set");
    self.zm_dmh_pulse_h = self.zm_dmh_ch;
    // the add-on draws the credit itself (scanning highlight); the GSC text stays blank then
    setdvar(@"phantom_credit", level.zm_dmh_credit);
    if (self.zm_dmh_ch.lua_text)
    {
        self.zm_dmh_ch.credit settext(nengine_text(" "));
        nengine_store_set("devmenu_dbg", "credit", "lua");
    }
}

// "PHANTOM" as text, or blank when the add-on draws the logo picture instead
zm_dmh_logo_text(h)
{
    if (isdefined(h) && isdefined(h.logo_pic) && h.logo_pic)
    {
        return " ";
    }
    return "PHANTOM";
}

// header picture: the preset's (setting logo_img), else the PHANTOM logo
zm_dmh_logo_img()
{
    level.zm_dmh_li = zm_dmh_str("logo_img", "phantom_logo");
    if (level.zm_dmh_li == "" || level.zm_dmh_li == "0")
    {
        level.zm_dmh_li = "phantom_logo";
    }
    return level.zm_dmh_li;
}

// true in Zombies (game type zm_...), false in Multiplayer / other modes; unknown = allow
zm_dmh_init_is_zombies()
{
    level.zm_dmh_init_gt = getdvar(@"ui_gametype");
    if (!isdefined(level.zm_dmh_init_gt) || level.zm_dmh_init_gt == "")
    {
        return 1;
    }
    return getsubstr(level.zm_dmh_init_gt, 0, 2) == "zm";
}
