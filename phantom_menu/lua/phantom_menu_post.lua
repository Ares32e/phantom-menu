-- Phantom menu background: draws a picture behind the Phantom menu panel.
-- The GSC menu (zm_zz_devmenu_hud.gsc) writes the dvar phantom_bg while the panel is open:
--   PBG|<image>|<right 0/1>|<width>|<height>|<scale>|<dx>|<dy>|<alpha>|<priority>|<open ms>|<close ms>|<build>|<fade in ms>|<fade out ms>|<fade ease power>|<lag ms>
-- (width / height in GSC HUD units, 640x480; scale turns them into UI units, 2.25 = 1080 / 480).
-- Empty dvar = menu closed. Every value comes from the menu's live settings, so alignment can be
-- tuned in the match without restarting the game. This file itself only loads at game start.
do
  local function log(s) pcall(KRONOS.log, "phantom bg: " .. tostring(s)) end

  local old = rawget(_G, "PhantomBg")
  if old then old.on = false; if old.drop then pcall(old.drop) end end
  local P = { on = true, ticks = 0 }
  rawset(_G, "PhantomBg", P)

  local CL = rawget(_G, "CLUA")
  local hashDvar = rawget(_G, "xhashdvar") or rawget(_G, "PushXHashDvar") or (type(CL) == "table" and CL.PushXHashDvar)
  local hashName = rawget(_G, "xhash") or rawget(_G, "PushXHash") or (type(CL) == "table" and CL.PushXHash)

  -- field lookup that also tries the hashed key (BO7 Lua tables are often keyed by hash)
  local function field(t, k)
    if t == nil then return nil end
    local ok, v = pcall(function() return t[k] end)
    if ok and v ~= nil then return v end
    if type(hashName) == "function" then
      ok, v = pcall(function() return t[hashName(k)] end)
      if ok then return v end
    end
    return nil
  end

  local function dvar(name, value)
    local D = rawget(_G, "Dvar")
    local key = name
    if type(hashDvar) == "function" then
      local ok, h = pcall(hashDvar, name)
      if ok and h ~= nil then key = h end
    end
    if value == nil then
      local f = field(D, "GetDvarString")
      if type(f) ~= "function" then return nil end
      local ok, v = pcall(f, key)
      if ok and v ~= nil then return tostring(v) end
      return nil
    end
    local f = field(D, "SetDvarString")
    if type(f) == "function" then pcall(f, key, value) end
  end

  local mats = {}
  local function material(name)
    if mats[name] == nil then
      local ok, m = pcall(function()
        local asset = (type(CL) == "table" and CL.PushXHashAsset) or rawget(_G, "xhashasset")
        return RegisterMaterial(asset and asset(name) or name)
      end)
      mats[name] = (ok and m) or false
      log("material " .. name .. " " .. tostring(ok and m ~= nil))
    end
    return mats[name] or nil
  end

  -- top-most element of the player's UI (same place the game HUD lives)
  local function screen()
    local roots = field(LUI, "UIRoot")
    local get = field(roots, "GetRootForControllerIndex")
    if type(get) ~= "function" then return nil end
    local ok, e = pcall(get, 0)
    if not ok or e == nil then return nil end
    for _ = 1, 16 do
      local okp, up = pcall(function() return e:getParent() end)
      if not okp or up == nil or up == e then break end
      e = up
    end
    return e
  end

  local function inMatch()
    local f = field(rawget(_G, "Engine"), "InFrontend")
    if type(f) ~= "function" then return true end
    local ok, v = pcall(f)
    return ok and v == false
  end

  local function paused()
    local fm = field(LUI, "FlowManager")
    local f = field(fm, "IsInStack")
    if type(f) ~= "function" or type(hashName) ~= "function" then return false end
    local ok, v = pcall(f, hashName("MPPauseMenu"))
    return ok and v == true
  end

  local function split(s)
    local out = {}
    for part in (s .. "|"):gmatch("(.-)|") do out[#out + 1] = part end
    return out
  end

  -- Real-time milliseconds clock WITHOUT os.clock (in BO7 it is processor time: it ran x1 in
  -- a quiet moment and ~3-4x during play, so the picture outran the panel). Real time comes
  -- from the UI's own Wait(200) timer (R.base += 200 per completion); between those steps
  -- the clock moves by an even share per frame (200 ms / frames counted in the last step).
  local R = { base = 0, frames = 0, frameMs = 16, last = 0, steps = 0 }
  local function now()
    local t = R.base + math.min(200, R.frames * R.frameMs)
    if t < R.last then t = R.last end
    R.last = t
    return t
  end
  local function clockStep()
    if R.frames > 0 then R.frameMs = 200 / R.frames end
    R.base = R.base + 200
    R.frames = 0
    R.steps = R.steps + 1
    if R.steps == 25 then log("clock: " .. string.format("%.1f", R.frameMs) .. " ms per frame") end
  end

  -- Places the picture, pushed off past the screen edge by off (UI units), instantly.
  -- All motion is done here frame by frame (no engine animations), so it can't get out of step.
  local function put(e, g, off)
    local l, r
    if g.right then l, r = -g.w + g.dx + off, g.dx + off else l, r = g.dx - off, g.w + g.dx - off end
    if g.right then
      e:SetAnchorsAndPosition(1, 0, 0, 1, l, r, g.dy, g.h + g.dy)
    else
      e:SetAnchorsAndPosition(0, 1, 0, 1, l, r, g.dy, g.h + g.dy)
    end
  end

  local function parse(text)
    local f = split(text)
    if f[1] ~= "PBG" or #f < 11 then return nil end
    local sc = tonumber(f[6]) or 2.25
    local g = {
      img = f[2], right = tonumber(f[3]) == 1,
      w = (tonumber(f[4]) or 200) * sc, h = (tonumber(f[5]) or 300) * sc,
      dx = tonumber(f[7]) or 0, dy = tonumber(f[8]) or 0, a = tonumber(f[9]) or 1,
      prio = tonumber(f[10]) or 0, open = tonumber(f[11]) or 250, close = tonumber(f[12]) or 200,
      fadeIn = tonumber(f[14]), fadeOut = tonumber(f[15]), pow = tonumber(f[16]) or 2,
      -- the GSC panel motion reaches the screen this long after the dvar changes: the picture
      -- waits the same time before it starts moving (measured with timestamped screen captures)
      lag = tonumber(f[17]) or 0,
      -- motion 0 = moved here every frame by the clock above, 1 = the game UI's own timed
      -- animation (SetLeft / SetRight / SetAlpha with a duration), started after the lag
      motion = tonumber(f[18]) or 0,
      -- frame: the add-on also draws the panel's dark tint and border line over the picture
      -- (one piece that slides as a whole); accent = border colour "r g b" (0-1)
      tint = tonumber(f[20]) or 0.45, border = (tonumber(f[21]) or 2) * sc,
      frame = tonumber(f[22]) == 1,
      -- logo picture drawn centred at the top of the frame (GSC y), 90% of the panel width
      logo = f[23], logoY = (tonumber(f[24]) or 8) * sc,
    }
    local r, gr, b = (f[19] or ""):match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
    local function c255(v) return math.max(0, math.min(255, math.floor((tonumber(v) or 0) * 255 + 0.5))) end
    g.accent = r and (c255(r) * 65536 + c255(gr) * 256 + c255(b)) or 0x33ff59
    g.fadeIn = g.fadeIn or g.open
    g.fadeOut = g.fadeOut or g.close
    return g
  end

  -- Motion record: offset from -> to over ms (straight line, like the panel's moveovertime),
  -- alpha from -> to over its own time with an ease (pow > 1 = stays faint, then shows late).
  local function animate(e, g, offFrom, offTo, ms, aFrom, aTo, ams, pow)
    P.anim = { e = e, g = g, t0 = now() + (g.lag or 0), offFrom = offFrom, offTo = offTo, ms = ms,
      aFrom = aFrom, aTo = aTo, ams = ams, pow = pow or 1, engine = false }
  end

  local function progress(an)
    local t = now() - an.t0
    if t < 0 then return 0, 0 end
    local p = an.ms > 0 and math.min(1, t / an.ms) or 1
    local q = an.ams > 0 and math.min(1, t / an.ams) or 1
    return p, q
  end

  -- engine motion: one timed call per property once the lag has passed
  local function places(e, g, off)
    if g.right then return -g.w + g.dx + off, g.dx + off end
    return g.dx - off, g.w + g.dx - off
  end
  local function stepEngine(an)
    local t = now() - an.t0
    if t < 0 then return false end
    if not an.fired then
      an.fired = true
      local l, r = places(an.e, an.g, an.offTo)
      local ok = an.ms > 0 and pcall(function() an.e:SetLeft(l, an.ms); an.e:SetRight(r, an.ms) end)
      if not ok then pcall(put, an.e, an.g, an.offTo) end
      if not P.hidden then pcall(function() an.e:SetAlpha(an.aTo, an.ams) end) end
    end
    return t >= math.max(an.ms, an.ams) + 20
  end

  local function step(an)
    if an.engine then return stepEngine(an) end
    local p, q = progress(an)
    pcall(put, an.e, an.g, an.offFrom + (an.offTo - an.offFrom) * p)
    if not P.hidden then
      pcall(function() an.e:SetAlpha(an.aFrom + (an.aTo - an.aFrom) * (q ^ an.pow), 0) end)
    end
    -- the picture inside the frame has its own, later fade-in (eased)
    local done = p >= 1 and q >= 1
    if an.img then
      local t = math.max(0, now() - an.t0)
      local r = an.imgMs > 0 and math.min(1, t / an.imgMs) or 1
      pcall(function() an.img:SetAlpha(an.imgA * (r ^ an.imgPow), 0) end)
      done = done and r >= 1
    end
    return done
  end

  function P.drop()
    if P.pic then pcall(function() P.pic:closeTree() end) end
    if P.anim and P.anim.e == P.pic then P.anim = nil end
    P.pic = nil; P.shown = nil; P.parent = nil
  end

  local function child(parent, rgb, alpha, l, r, anchorLeft, anchorRight)
    local e = LUI.UIImage.new()
    pcall(function() e:SetHandleMouse(false) end)
    pcall(function() e:setFocusable(false) end)
    -- fill the frame (both anchors) or a strip at one edge
    if anchorLeft and anchorRight then e:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
    elseif anchorLeft then e:SetAnchorsAndPosition(0, 1, 0, 0, l, r, 0, 0)
    else e:SetAnchorsAndPosition(1, 0, 0, 0, l, r, 0, 0) end
    if rgb then e:SetRGB(rgb) end
    e:SetAlpha(alpha, 0)
    parent:addElement(e)
    return e
  end

  -- Panel built (or rebuilt): one frame element (picture, then dark tint and border line on top)
  -- starts off-screen at the edge and slides + fades in with the panel; the picture inside fades
  -- in later on its own (hud_bg_fade_in, eased by hud_bg_fade_pow).
  local function show(text, parent)
    local g = parse(text)
    if not g then return end
    P.drop()
    if P.leaving then pcall(function() P.leaving:closeTree() end); P.leaving = nil; P.anim = nil end
    local c = LUI.UIElement.new()
    pcall(function() c:SetHandleMouse(false) end)
    pcall(function() c:setPriority(g.prio) end)
    local start = g.open > 0 and g.w or 0
    put(c, g, start)
    c:SetAlpha(0, 0)
    parent:addElement(c)
    local img = child(c, nil, 0, 0, 0, true, true)
    -- picture "name", or an animated one "name:frames:ms" (PNG frames name_f000, name_f001 ...
    -- made from a GIF / video by toolsaddbg.js), cycled in tick()
    local base, nf, fms = g.img:match("^([^:]+):(%d+):(%d+)$")
    P.frames = nil
    local m
    if base and tonumber(nf) > 1 then
      P.frames = { name = base, n = tonumber(nf), ms = math.max(20, tonumber(fms)), t0 = now(), idx = 0 }
      m = material(string.format("%s_f%03d", base, 0))
    else
      m = material(base or g.img)
    end
    if m then img:setImage(m, 0) else img:SetRGB(0x202020) end
    if g.frame then
      child(c, 0x000000, g.tint, 0, 0, true, true)
      -- border on the side facing the middle of the screen, like the panel's own line
      if g.right then child(c, g.accent, 1, 0, g.border, true, false)
      else child(c, g.accent, 1, -g.border, 0, false, true) end
    end
    if g.logo and g.logo ~= "" then
      local lm = material(g.logo) or material("phantom_logo")
      if lm then
        local lw = g.w * 0.9
        local lh = lw * 225 / 1024
        local lx = (g.w - lw) / 2
        local lg = child(c, nil, 1, 0, 0, true, true)
        pcall(function() lg:SetAnchorsAndPosition(0, 1, 0, 1, lx, lx + lw, g.logoY, g.logoY + lh) end)
        lg:setImage(lm, 0)
      end
    end
    P.pic = c; P.img = img; P.geo = g; P.shown = text; P.parent = parent; P.hidden = false
    animate(c, g, start, 0, g.open, 0, 1, g.open, 1)
    P.anim.img = img; P.anim.imgA = g.a; P.anim.imgMs = g.fadeIn; P.anim.imgPow = g.pow
    log("shown " .. text)
  end

  -- Panel closed: slide + fade out with it (same distance and time), then remove the element.
  local function leave()
    local e, g = P.pic, P.geo
    P.pic = nil; P.shown = nil; P.parent = nil
    if not e then return end
    if not g or g.close <= 0 or P.hidden then
      pcall(function() e:closeTree() end); P.anim = nil; return
    end
    -- start from where it is now (it may still be sliding / fading in)
    local off, a = 0, 1
    if P.anim and P.anim.e == e then
      local p, q = progress(P.anim)
      off = P.anim.offFrom + (P.anim.offTo - P.anim.offFrom) * p
      a = P.anim.aFrom + (P.anim.aTo - P.anim.aFrom) * (q ^ P.anim.pow)
    end
    P.leaving = e
    animate(e, g, off, off + g.w, g.close, a, 0, math.min(g.fadeOut, g.close), 1)
  end

  -- Phantom menu extras drawn / run here (GSC writes the dvars):
  --   phantom_hud  = a short line shown at the top centre (zombie counter); "" = hidden
  --   phantom_exec = "<console command> <time>" run once when it changes (e.g. map_restart)
  local X = {}
  local function hudLine(parent)
    local text = dvar("phantom_hud") or ""
    if text == (X.text or "") and (text == "" or X.parent == parent) then return end
    if X.box and (text == "" or X.parent ~= parent) then pcall(function() X.box:closeTree() end); X.box = nil; X.label = nil end
    X.text = text
    if text == "" or parent == nil then return end
    if not X.box then
      local ok = pcall(function()
        local b = LUI.UIElement.new()
        pcall(function() b:SetHandleMouse(false) end)
        pcall(function() b:setPriority(1000) end)
        b:SetAnchorsAndPosition(0.5, 0.5, 0, 1, -250, 250, 115, 145)
        local t = LUI.UIStyledText.new()
        t:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
        local fonts = rawget(_G, "FONT_HANDLE")
        local font = field(fonts, "TertiaryMedium") or field(fonts, "SecondaryRegular") or field(fonts, "PrimaryBold")
        if font then pcall(function() t:SetFont(font) end) end
        pcall(function() t:SetFontSize(22 * (tonumber(rawget(_G, "_PT")) or 1)) end)
        pcall(function() t:SetAlignment(0) end)
        t:SetRGB(0xffffff)
        b:addElement(t)
        parent:addElement(b)
        X.box = b; X.label = t; X.parent = parent
      end)
      if not ok then log("hud line: could not build"); return end
    end
    pcall(function() X.label:setText(text) end)
  end
  -- BOSS BAR (Boss Creator bosses): dvar phantom_boss = "<name>|<health %>", "" = hidden.
  -- Top centre like the game's own boss bar: name in capitals, long dark bar, red health fill,
  -- a lighter strip that drains after each hit.
  local BB = {}
  local function bossDrop()
    if BB.box then pcall(function() BB.box:closeTree() end) end
    BB.box = nil; BB.parent = nil; BB.name = nil
  end
  local function bossBuild(parent)
    local b = LUI.UIElement.new()
    pcall(function() b:SetHandleMouse(false) end)
    pcall(function() b:setPriority(900) end)
    b:SetAnchorsAndPosition(0.5, 0.5, 0, 1, -380, 380, 52, 120)
    local fonts = rawget(_G, "FONT_HANDLE")
    local font = field(fonts, "PrimaryBold") or field(fonts, "TertiaryMedium")
    BB.label = LUI.UIStyledText.new()
    if font then pcall(function() BB.label:SetFont(font) end) end
    pcall(function() BB.label:SetFontSize(30) end)
    pcall(function() BB.label:SetAlignment(1) end)
    BB.label:SetRGB(0xffffff)
    BB.label:SetAnchorsAndPosition(0, 1, 0, 1, 0, 760, 0, 32)
    b:addElement(BB.label)
    local function img(rgb, a, x0, x1, y0, y1)
      local e = LUI.UIImage.new(); e:SetRGB(rgb); e:SetAlpha(a, 0)
      e:SetAnchorsAndPosition(0, 1, 0, 1, x0, x1, y0, y1)
      b:addElement(e)
      return e
    end
    BB.w = 760
    BB.frame = img(0x000000, 0.7, -2, BB.w + 2, 38, 54)
    BB.track = img(0x2a0808, 0.9, 0, BB.w, 40, 52)
    BB.trail = img(0xffd27a, 0.9, 0, BB.w, 40, 52)
    BB.fill = img(0xc8141e, 1, 0, BB.w, 40, 52)
    BB.shine = img(0xff5a5a, 0.55, 0, BB.w, 40, 43)
    BB.edge1 = img(0xffffff, 0.35, -2, BB.w + 2, 37, 38)
    BB.edge2 = img(0xffffff, 0.35, -2, BB.w + 2, 54, 55)
    parent:addElement(b)
    BB.box = b; BB.parent = parent; BB.shown = 100; BB.trailp = 100
  end
  local function bossTick(parent)
    local raw = dvar("phantom_boss") or ""
    local name, pct = raw:match("^(.-)|(%d+)$")
    if not name or name == "" or parent == nil then if BB.box then bossDrop() end return end
    if not BB.box or BB.parent ~= parent then bossDrop(); pcall(bossBuild, parent) end
    if not BB.box then return end
    pct = math.max(0, math.min(100, tonumber(pct) or 100))
    if name ~= BB.name then BB.name = name; pcall(function() BB.label:setText(string.upper(name)) end); BB.shown = pct; BB.trailp = pct end
    -- fill eases fast, the light strip follows slowly (shows the damage just taken)
    BB.shown = BB.shown + (pct - BB.shown) * 0.35
    if BB.trailp < BB.shown then BB.trailp = BB.shown else BB.trailp = BB.trailp + (BB.shown - BB.trailp) * 0.06 end
    local fw = BB.w * BB.shown / 100
    local tw = BB.w * BB.trailp / 100
    pcall(function() BB.fill:SetAnchorsAndPosition(0, 1, 0, 1, 0, fw, 40, 52) end)
    pcall(function() BB.shine:SetAnchorsAndPosition(0, 1, 0, 1, 0, fw, 40, 43) end)
    pcall(function() BB.trail:SetAnchorsAndPosition(0, 1, 0, 1, 0, tw, 40, 52) end)
  end
  -- PHANTOM SECTION IN SETTINGS > DEBUG OPTIONS. Kronos builds that page by wrapping the game's
  -- OPTIONS functions (it shares its hash helper as KRONOS.H). Phantom wraps the same functions on
  -- top and adds its own section; each option sets a dvar the Phantom scripts read every second.
  local PO = {
    { id = "70a5e000000000a0", kind = "toggle", grp = 3, dv = "phantom_o_off", name = "Turn Off Phantom Menu",
      desc = "On: the Phantom menu, its loading screen and its hints stay off in your matches (switch back Off to use it again)." },
    { id = "70a5e000000000a1", kind = "toggle", grp = 3, dv = "phantom_o_autogod", name = "God Mode On Map Load",
      desc = "Turns Phantom god mode on every time a Zombies map loads." },
    { id = "70a5e000000000a2", kind = "toggle", grp = 3, dv = "phantom_o_timer", name = "Match Timer",
      desc = "Shows the match time and round at the top of the screen." },
    { id = "70a5e000000000a3", kind = "toggle", grp = 1, dv = "phantom_o_roul", name = "Weapon Roulette",
      desc = "A random gun every new round." },
    { id = "70a5e000000000a4", kind = "toggle", grp = 1, dv = "phantom_o_heal", name = "Round-End Heal",
      desc = "Full health at every new round; downed players get a self revive." },
    { id = "70a5e000000000a5", kind = "list", grp = 1, dv = "phantom_o_rest", name = "Rest Break",
      desc = "Seconds with no zombie spawns at the start of every round.", values = { "0", "10", "30", "60" },
      labels = { "Off", "10 s", "30 s", "60 s" } },
    { id = "70a5e000000000a6", kind = "list", grp = 2, dv = "phantom_o_sprint", name = "Super Sprinters",
      desc = "Every zombie sprints from this round on.", values = { "0", "20", "30", "40", "50" },
      labels = { "Off", "Round 20", "Round 30", "Round 40", "Round 50" } },
    { id = "70a5e000000000a7", kind = "list", grp = 2, dv = "phantom_o_tough", name = "Zombie Toughness",
      desc = "How much more damage zombies can take.", values = { "1", "2", "5", "10" },
      labels = { "Normal", "2x", "5x", "10x" } },
    { id = "70a5e000000000a8", kind = "toggle", grp = 1, dv = "phantom_o_hs", name = "Headshots Only",
      desc = "Only headshots hurt zombies." },
    { id = "70a5e000000000a9", kind = "toggle", grp = 1, dv = "phantom_o_melee", name = "Melee Only",
      desc = "Only melee hurts zombies." },
    { id = "70a5e000000000c1", kind = "list", grp = 5, dv = "phantom_o_sround", name = "Starting Round",
      desc = "Jumps to this round when the match starts.", values = { "1", "5", "10", "15", "20", "30", "50", "100" } },
    { id = "70a5e000000000c2", kind = "list", grp = 5, dv = "phantom_o_spoints", name = "Starting Points",
      desc = "Your points when the match starts.", values = { "0", "5000", "10000", "50000", "100000", "1000000" },
      labels = { "Normal", "5,000", "10,000", "50,000", "100,000", "1,000,000" } },
    { id = "70a5e000000000c3", kind = "toggle", grp = 5, dv = "phantom_o_sperks", name = "Spawn With All Perks",
      desc = "Every perk the map has, given when the match starts." },
    { id = "70a5e000000000c4", kind = "list", grp = 5, dv = "phantom_o_kpts", name = "Extra Points Per Kill",
      desc = "Bonus points for every zombie killed.", values = { "0", "50", "100", "250", "500" },
      labels = { "Off", "50", "100", "250", "500" } },
    { id = "70a5e000000000c8", kind = "toggle", grp = 5, dv = "phantom_o_onegun", name = "One Gun Roulette",
      desc = "A crate spawns behind you: press Use at it for a random gun (sometimes a wonder weapon). That gun is your only gun for the match; you can still Pack-a-Punch it." },
    { id = "70a5e000000000c9", kind = "toggle", grp = 5, dv = "phantom_o_rot", name = "Map Rotation",
      desc = "Every few rounds everyone is teleported to another part of the map (boss areas and hidden spots outside the play area too). You can't leave that area until the next rotation." },
    { id = "70a5e000000000ca", kind = "list", grp = 5, dv = "phantom_o_rotn", name = "Map Rotation: Every",
      desc = "How many rounds between moves.", values = { "1", "2", "3", "5" }, labels = { "1 round", "2 rounds", "3 rounds", "5 rounds" } },
    { id = "70a5e000000000cb", kind = "list", grp = 5, dv = "phantom_o_rotspots", name = "Map Rotation: Places",
      desc = "Where you can be sent.", values = { "0", "1", "2" }, labels = { "Everywhere", "Map areas only", "Hidden spots only" } },
    { id = "70a5e000000000cc", kind = "list", grp = 5, dv = "phantom_o_rotr", name = "Map Rotation: Area Size",
      desc = "How big the area is that you can't leave.", values = { "0", "600", "1500", "2500" }, labels = { "Normal", "Small", "Big", "Huge" } },
    { id = "70a5e000000000cd", kind = "toggle", grp = 5, dv = "phantom_o_rotstay", name = "Map Rotation: Zombies Stay",
      desc = "On = zombies are not brought into your area (rounds can get stuck in hidden spots)." },
    { id = "70a5e000000000c5", kind = "toggle", grp = 5, dv = "phantom_o_gg", name = "Gun Game",
      desc = "A new gun every 3 kills." },
    { id = "70a5e000000000c6", kind = "list", grp = 2, dv = "phantom_o_cap", name = "Max Zombies Per Round",
      desc = "How many zombies a round has.", values = { "0", "6", "12", "24", "50" },
      labels = { "Normal", "6", "12", "24", "50" } },
    { id = "70a5e000000000c7", kind = "list", grp = 2, dv = "phantom_o_zspeed", name = "Zombie Speed",
      desc = "How every zombie moves.", values = { "off", "walk", "run", "sprint" },
      labels = { "Normal", "Walk", "Run", "Sprint" } },
    { id = "70a5e000000000b2", kind = "toggle", grp = 4, dv = "phantom_o_picon", name = "Phantom Prestige Icons",
      desc = "Prestige Master shows a Phantom icon for every 1000 levels (1-10) instead of the game's icon." },
    { id = "70a5e000000000b3", kind = "toggle", grp = 4, dv = "phantom_o_brand", name = "Phantom On The Main Menu",
      desc = "Shows PHANTOM MENU in the corner of the main menu." },
  }
  local PH = { hooks = {}, byId = nil }
  local function runCmd(cmd)
    local eng = rawget(_G, "Engine")
    -- Kronos' own way: Engine[hash eb81a5136c5503e4](cmd, controller)
    local K = rawget(_G, "KRONOS")
    if K and K.H and type(eng) == "table" then
      local f = eng[K.H("eb81a5136c5503e4")]
      if type(f) == "function" and pcall(f, cmd, 0) then return true end
    end
    for _, name in ipairs({ "Exec", "ExecNow" }) do
      local run = field(eng, name)
      if type(run) == "function" then
        if pcall(run, cmd) then return true end
        if pcall(run, 0, cmd) then return true end
      end
    end
    return false
  end
  local function poSet(dv, val)
    dvar(dv, val)
    if dvar(dv) ~= val then runCmd("set " .. dv .. " " .. val) end
  end
  local function poData(o, H, OK, ax)
    local t, id = {}, H(o.id, 3)
    t[H(OK.id)] = id; t[H(OK.sb)] = id; t[H(OK.name)] = o.name; t[H(OK.desc)] = o.desc; t[H(OK.def)] = 1
    if o.kind == "level" then
      t[H(OK.type)] = "Dropdown"; t[H(OK.labels)] = o.labels
      t[H(OK.value)] = function(c) return 1 end
      t[H(OK.action)] = function(c, v)
        local lv = tonumber(o.values[v] or "")
        if not lv then return end
        local D = rawget(_G, "Dvar")
        local set = field(D, "SetDvarString")
        if type(set) ~= "function" then return end
        -- Kronos' level: rank dvar a9e6b907229d534e = level - 1, xp dvar f4bb97895b995476
        pcall(set, H("a9e6b907229d534e", 1), tostring(lv - 1))
        pcall(set, H("f4bb97895b995476", 1), tostring(1200000 + (lv - 57) * 48000))
        poSet("phantom_o_lvl", tostring(lv))
        log("level set to " .. lv)
      end
    elseif o.kind == "toggle" then
      t[H(OK.type)] = "ToggleButton"; t[H(OK.labels)] = { "Off", "On" }
      t[H(OK.value)] = function(c) return dvar(o.dv) == "1" and 2 or 1 end
      t[H(OK.action)] = function(c, v) poSet(o.dv, v == 2 and "1" or "0") end
    else
      t[H(OK.type)] = "Dropdown"; t[H(OK.labels)] = o.labels or o.values
      t[H(OK.value)] = function(c)
        local cur = dvar(o.dv)
        if cur == nil or cur == "" then cur = "0" end
        for i, v in ipairs(o.values) do if v == cur then return i end end
        return 1
      end
      t[H(OK.action)] = function(c, v) poSet(o.dv, o.values[v] or o.values[1]) end
    end
    return ax(t)
  end
  local function hookPhantomOptions()
    local K = rawget(_G, "KRONOS")
    local H = K and K.H
    local O = rawget(_G, "OPTIONS")
    if type(H) ~= "function" or type(O) ~= "table" or type(O.TabIds) ~= "table" or O.TabIds.DEBUG == nil then return end
    local OK = { id = "08b72e07b55c3ac0", sb = "7228576e3216368b", type = "a79439ef7bfa9c2d", name = "c4bcadba8e631b86",
      desc = "0cc44970c8397929", labels = "4bc513f856980a8a", value = "7ce4fd9430e80cea", action = "6568640b035a56df",
      def = "1230e315819fab00", list = "de7843f98867b161", autoId = "488ca93aa60dc466" }
    local function ax(t)
      local X = rawget(_G, "XHash")
      if type(X) == "table" and X.SetAutoXHashMetatable then return X.SetAutoXHashMetatable(t, 0) or t end
      return t
    end
    if not PH.byId then
      PH.byId = {}
      for _, o in ipairs(PO) do PH.byId[H(o.id, 3)] = o end
    end
    -- outermost wrap: a new closure whenever someone else wrapped on top (no recursion)
    local function wrap(hex, make)
      local k = H(hex); local cur = O[k]
      if cur == PH.hooks[hex] or type(cur) ~= "function" then return end
      local fn = make(cur)
      -- a callable table: Kronos only re-wraps a slot that holds a function, so ours stays on top
      local tbl = setmetatable({}, { __call = function(_, ...) return fn(...) end })
      PH.hooks[hex] = tbl; O[k] = tbl
      log("debug options: wrapped " .. hex)
    end
    wrap("e7686f7a9907efd8", function(orig) return function(sb, ...)
      local o = sb ~= nil and PH.byId[sb]
      if o then return poData(o, H, OK, ax) end
      return orig(sb, ...)
    end end)
    wrap("9f6c4b08602983fb", function(orig) return function(sb, c, ...)
      local o = sb ~= nil and PH.byId[sb]
      if o then return poData(o, H, OK, ax) end
      return orig(sb, c, ...)
    end end)
    wrap("7bf7f57679e8d050", function(orig) return function(tab, c, idx, ...)
      if not (type(tab) == "table" and tab[H(OK.id)] == O.TabIds.DEBUG) then return orig(tab, c, idx, ...) end
      local okS, secs = pcall(function()
        local list = orig(tab, c)
        if type(list) ~= "table" then return list end
        for _, sec in ipairs(list) do
          if sec[H(OK.autoId)] == "phantom" then return list end
        end
        -- the options already there become "Default Debug Options"
        for _, sec in ipairs(list) do
          pcall(function() sec[H(OK.name)] = "DEFAULT DEBUG OPTIONS" end)
        end
        local gnames = { "MATCH RULES", "ZOMBIES", "PLAYER & SCREEN", "PRESTIGE & MAIN MENU", "MATCH START & MINI GAMES" }
        local groups = {}
        for gi, gname in ipairs(gnames) do
          local items = {}
          for _, o in ipairs(PO) do
            if o.grp == gi then items[#items + 1] = ax({ [H(OK.sb)] = H(o.id, 3) }) end
          end
          groups[#groups + 1] = ax({ [H(OK.name)] = gname, [H(OK.list)] = items })
        end
        list[#list + 1] = ax({ [H(OK.name)] = "PHANTOM OPTIONS", [H(OK.autoId)] = "phantom", [H(OK.list)] = groups })
        return list
      end)
      if not okS or type(secs) ~= "table" then return orig(tab, c, idx, ...) end
      if idx then return secs[idx] and secs[idx][H(OK.list)] end
      return secs
    end end)
  end
  -- PRESTIGE ICONS: wrap the game's level icon lookup (PROGRESSION, the same one Kronos wraps) on top;
  -- with phantom_o_picon on, Prestige Master shows phantom_pi_<1..10> (one per 1000 levels).
  -- Which own icon pictures are installed: "*" = all, else "|pi_lvl_3|pi_prestige_1|...|".
  -- "Install My Pictures.bat" rewrites the next line. Icons not listed show the game icon.
  local MY_ICONS = "" -- MY_ICONS
  local function haveIcon(n) return n ~= nil and (MY_ICONS == "*" or MY_ICONS:find("|" .. n .. "|", 1, true) ~= nil) end
  local IE = { wrapped = {}, seen = {}, map = {}, slots = {} }
  local PI = { hook = nil }
  local function hookPrestigeIcons()
    local K = rawget(_G, "KRONOS")
    local H = K and K.H
    local P = rawget(_G, "PROGRESSION")
    if type(H) ~= "function" or type(P) ~= "table" then return end
    local k = H("d9c6922557618920")
    local cur = P[k]
    if type(cur) ~= "function" or cur == PI.hook then return end
    local orig = cur
    PI.hook = function(rank, prestige, ...)
      -- ICON PACK: images pi_lvl_1..55 (one per level), pi_prestige_1..10, pi_mtier_1..41 (Prestige Master, ~24 levels each);
      -- dvar phantom_o_rankicons "0" = off (missing = on). Old Phantom master rings stay as fallback.
      local r = tonumber(rank) or 0
      local p = tonumber(prestige) or 0
      local name
      -- an icon the player picked in the game (prestige icon screen; Kronos check: PLAYERPROFILE icon id
      -- for (a3, a4) not 0) shows that game icon; nothing picked (the X) -> our pictures
      local a3, a4 = ...
      if a3 ~= nil and a4 ~= nil and dvar("phantom_o_rankicons") ~= "0" then
        local okc, id = pcall(function() return PLAYERPROFILE[H("2e251e8212678573")](a3, a4) end)
        if PI.lastId ~= tostring(id) then PI.lastId = tostring(id); log("rank icons: picked icon id " .. tostring(okc) .. " " .. tostring(id)) end
        local nid = okc and tonumber(id)
        PI.picked = nil
        local tilePic = nid and IE.idPic and dvar("phantom_o_tileicons") ~= "0" and IE.idPic[nid]
        if tilePic and nid ~= 115656 and haveIcon(tilePic) and material(tilePic) then
          PI.picked = tilePic
          return tilePic
        end
        if nid and nid ~= 0 then
          -- a picked icon shows that GAME icon (same lookup Kronos uses); the X (id 0) brings our PNG back
          local oki, img = pcall(function() return LEVEL_ICON[H("f7e7a7a4e7e58c7d")](nid) end)
          local CoDt = rawget(_G, "CoD")
          -- the X on the icon screen equips the game default icon for this prestige: treat that as no pick
          local okd, def = pcall(orig, rank, prestige, ...)
          -- id 115656 = what the game saves when the X is picked (seen 2026-11-06)
          local isDefault = nid == 115656 or (okd and def ~= nil and (def == img or tostring(def) == tostring(img)))
          if PI.lastDef ~= tostring(def) .. tostring(img) then
            PI.lastDef = tostring(def) .. tostring(img)
            log("rank icons: picked " .. tostring(img) .. " game default " .. tostring(def) .. " -> " .. (isDefault and "PNG" or "game icon"))
          end
          if oki and img and img ~= "" and not isDefault and not (CoDt and (img == CoDt.ERROR_TEXTURE or img == CoDt.PLACEHOLDER_TEXTURE_STR)) then
            if PI.lastImg ~= tostring(img) then PI.lastImg = tostring(img); log("rank icons: picked icon image " .. tostring(img)) end
            PI.picked = img
            return img
          end
          if not isDefault then return orig(rank, prestige, ...) end
        end
      end
      if dvar("phantom_o_rankicons") ~= "0" then
        if p <= 0 then
          name = "pi_lvl_" .. math.max(1, math.min(55, r + 1))
        elseif p <= 10 then
          name = "pi_prestige_" .. p
        else
          name = "pi_mtier_" .. math.max(1, math.min(41, math.floor(r * 41 / 1000) + 1))
        end
        if name and haveIcon(name) and material(name) then return name end
      end
      if dvar("phantom_o_picon") == "1" and p >= 11 then
        local tier = math.max(1, math.min(10, math.floor(r / 1000) + 1))
        name = "phantom_pi_" .. tier
        if material(name) then return name end
      end
      return orig(rank, prestige, ...)
    end
    -- full self test once: every level 1-55 (prestige 0), every prestige 1-10 (all 55 levels each),
    -- Prestige Master levels 1-1000; checks each answer is the expected picture and that it loads
    if not PI.tested then
      PI.tested = true
      local runs, bad, used = 0, {}, {}
      local function check(r, p, want)
        runs = runs + 1
        local ok, v = pcall(PI.hook, r, p)
        if not ok or v ~= want or not material(want) then
          if #bad < 20 then bad[#bad + 1] = "L" .. (r + 1) .. "/P" .. p .. " got " .. tostring(ok and v) .. " want " .. want end
        else
          used[want] = (used[want] or 0) + 1
        end
      end
      for r = 0, 54 do check(r, 0, "pi_lvl_" .. (r + 1)) end
      for p = 1, 10 do for r = 0, 54 do check(r, p, "pi_prestige_" .. p) end end
      for r = 0, 999 do check(r, 11, "pi_mtier_" .. (math.floor(r * 41 / 1000) + 1)) end
      local n = 0
      for _ in pairs(used) do n = n + 1 end
      log("rank icons full test: " .. runs .. " checks, " .. (runs - #bad) .. " ok, " .. n .. " different pictures used")
      for _, b in ipairs(bad) do log("rank icons FAIL: " .. b) end
      for _, grp in ipairs({ "lvl", "prestige", "mtier" }) do
        local parts = {}
        for i = 1, (grp == "lvl" and 55 or (grp == "mtier" and 41 or 10)) do parts[#parts + 1] = i .. ":" .. tostring(used["pi_" .. grp .. "_" .. i] or 0) end
        log("rank icons " .. grp .. " counts " .. table.concat(parts, " "))
      end
    end
    P[k] = PI.hook
    log("prestige icon hook on")
  end
  -- ICONS EVERYWHERE: every function in the game tables that hand out level / prestige icon names
  -- (PROGRESSION, LEVEL_ICON, RANK_ICON...) is wrapped; a returned string that is a game rank icon name
  -- (sat_ui_icon_rank_mp_levelNN) becomes our picture for that level. Every other icon-like name seen
  -- is logged once ("icon name seen") so prestige / master names can be mapped too.
  -- material hashes of the game rank icons (asset hash and plain FNV) -> level
  local RANKHASH = { ["60674bcd8b5db03c"] = 1, ["8ce86db272faf7f5"] = 1, ["18c6c6b107372d7d"] = 2, ["706c66e13cca1e54"] = 2, ["6898ce13359d89d6"] = 3, ["5abbaa34c4e6fceb"] = 3, ["5de0d0d8ca39e0cf"] = 4, ["28342566b9e47faa"] = 4, ["21c880db6510a218"] = 5, ["399d877c221a9dc1"] = 5, ["68f3a5949834ede9"] = 6, ["8515b3f995af3d90"] = 6, ["28276b4bdf9c0df2"] = 7, ["9dd506ec65ccf6e7"] = 7, ["7ca21ece8d5dcb2b"] = 8, ["9f24511e4c86a396"] = 8, ["4d0b7e0fc4105094"] = 9, ["e5b77caa0fe8333d"] = 9, ["5712e2693f620caa"] = 10, ["1a7606282d62e617"] = 10, ["687c447ea7982ac1"] = 11, ["a6d1e430bf1a7d00"] = 11, ["33f470fc1b2cca90"] = 12, ["d9fa2b02938efab1"] = 12, ["4cb3c3eeeb4a83e7"] = 13, ["9eb6a6beaa13841a"] = 13, ["7cfd4ae4a468858e"] = 14, ["4c6a651606a7ed9b"] = 14, ["3bc72ab4f87884f5"] = 15, ["67d30429787fa904"] = 15, ["1f4b23e3c247ab54"] = 16, ["d8c23bb630f68ee5"] = 16, ["99a67374a6489eb"] = 17, ["441764b3af15987e"] = 17, ["4d85111af2efe1b2"] = 18, ["37ee23ffa428fe7f"] = 18, ["24ce187aa4a45ca9"] = 19, ["4dfd853e6b70cf88"] = 19, ["1f1432e49e79bdc5"] = 20, ["e4898a5ce20b2138"] = 20, ["4a5cc1a39385f45e"] = 21, ["ebd2f3d14015c96f"] = 21, ["3e3886c1c0b0a37b"] = 22, ["dfa8c117da9eea92"] = 22, ["796a479d7c0c8a64"] = 23, ["fa4bc88d10f3ff89"] = 23, ["603f87f277ff5691"] = 24, ["379d909332bc6f5c"] = 24, ["32d2a63e626fbcfa"] = 25, ["fa6e99319f2bdb33"] = 25, ["79c51f1edea3ee77"] = 26, ["f68af10bab797276"] = 26, ["67391f5374eb2b60"] = 27, ["f1ec032075f7e59d"] = 27, ["1a05ff5ec028a58d"] = 28, ["dc7c53e6f4a20c70"] = 28, ["2a2ef60668eff566"] = 29, ["aa088d62cbdaf647"] = 29, ["3f2a1ff07b8f8b4"] = 30, ["2b45d90f0ea07939"] = 30, ["15cdedadb072894b"] = 31, ["54c8d7e96a120682"] = 31, ["2580c054b3f0f16e"] = 32, ["e071996fb3b16a5f"] = 32, ["4fe897af7ac346d5"] = 33, ["efff23dd89d6568"] = 33, ["b5b10e97a1f9970"] = 34, ["6b27425c3aab188d"] = 34, ["58e74a6551588347"] = 35, ["fb503903e3726866"] = 35, ["634768dfa571bf0a"] = 36, ["4f029edf2a4e76e3"] = 36, ["1667e4671e8c4ea1"] = 37, ["5f87b8742724c18c"] = 37, ["667c4d95b839fc5c"] = 38, ["3160caeff281c991"] = 38, ["294d563424a96833"] = 39, ["3f3e93bdcf22ffa"] = 39, ["2cec22a673cac967"] = 40, ["3e7e480721933e9a"] = 40, ["142ccfb3a3ad1010"] = 41, ["79c1cc4b0b0eb531"] = 41, ["48b4a33630187041"] = 42, ["46998579369a3780"] = 42, ["374b4120c7e2522a"] = 43, ["ba3da770a4e2a097"] = 43, ["69d2c5eed2e4cf6b"] = 44, ["e3df05fc269552fe"] = 44, ["7f83829b4ac7f0d4"] = 45, ["7889dcfea8764965"] = 45, ["1bff896c80f8ca75"] = 46, ["79aa571efff6384"] = 46, ["5d35a99c2ce8cb0e"] = 47, ["ec32065e7e27a81b"] = 47, ["26e96f9df203f60f"] = 48, ["338e0c3274652b22"] = 48, ["676c1fa089f94158"] = 49, ["b984fc3755cd1259"] = 49, ["2a95205b1c0639de"] = 50, ["31635af570a58c3"] = 50, ["7f4c919c26fa0345"] = 51, ["c27e79c1a34b066c"] = 51, ["59a2a655048ccfe4"] = 52, ["d408bfb56e83dded"] = 52, ["1e70e5794930e8fb"] = 53, ["fc9813c36d99f5c6"] = 53, ["130b04f5eaf0027a"] = 54, ["48bc5266fa1b1e3f"] = 54, ["4077e6aa007f9c11"] = 55, ["bfac890e02746b48"] = 55, ["513a9a7127cb9dc0"] = 1, ["d8c9d04d66b6c231"] = 1, ["513a9d7127cba2d9"] = 2, ["d8c9cd4d66b6bd18"] = 2, ["513a9c7127cba126"] = 3, ["d8c9ce4d66b6becb"] = 3, ["513a9f7127cba63f"] = 4, ["d8c9d34d66b6c74a"] = 4, ["513a9e7127cba48c"] = 5, ["d8c9d44d66b6c8fd"] = 5, ["513aa17127cba9a5"] = 6, ["d8c9d14d66b6c3e4"] = 6, ["513aa07127cba7f2"] = 7, ["d8c9d24d66b6c597"] = 7, ["513aa37127cbad0b"] = 8, ["d8c9c74d66b6b2e6"] = 8, ["513aa27127cbab58"] = 9, ["d8c9c84d66b6b499"] = 9, ["5137357127c8bc4a"] = 10, ["d8cd554d66b9da07"] = 10, ["5137367127c8bdfd"] = 11, ["d8cd544d66b9d854"] = 11, ["5137337127c8b8e4"] = 12, ["d8cd574d66b9dd6d"] = 12, ["5137347127c8ba97"] = 13, ["d8cd564d66b9dbba"] = 13, ["5137317127c8b57e"] = 14, ["d8cd514d66b9d33b"] = 14, ["5137327127c8b731"] = 15, ["d8cd504d66b9d188"] = 15, ["51372f7127c8b218"] = 16, ["d8cd534d66b9d6a1"] = 16, ["5137307127c8b3cb"] = 17, ["d8cd524d66b9d4ee"] = 17, ["51372d7127c8aeb2"] = 18, ["d8cd4d4d66b9cc6f"] = 18, ["51372e7127c8b065"] = 19, ["d8cd4c4d66b9cabc"] = 19, ["51342f7127c67c41"] = 20, ["d8c3434d66b166ec"] = 20, ["51342e7127c67a8e"] = 21, ["d8c3444d66b1689f"] = 21, ["51342d7127c678db"] = 22, ["d8c3454d66b16a52"] = 22, ["51342c7127c67728"] = 23, ["d8c3464d66b16c05"] = 23, ["5134337127c6830d"] = 24, ["d8c33f4d66b16020"] = 24, ["5134327127c6815a"] = 25, ["d8c3404d66b161d3"] = 25, ["5134317127c67fa7"] = 26, ["d8c3414d66b16386"] = 26, ["5134307127c67df4"] = 27, ["d8c3424d66b16539"] = 27, ["5134277127c66ea9"] = 28, ["d8c34b4d66b17484"] = 28, ["5134267127c66cf6"] = 29, ["d8c34c4d66b17637"] = 29, ["5130a97127c362b8"] = 30, ["d8c6c94d66b48075"] = 30, ["5130aa7127c3646b"] = 31, ["d8c6c84d66b47ec2"] = 31, ["5130ab7127c3661e"] = 32, ["d8c6c74d66b47d0f"] = 32, ["5130ac7127c367d1"] = 33, ["d8c6c64d66b47b5c"] = 33, ["5130ad7127c36984"] = 34, ["d8c6c54d66b479a9"] = 34, ["5130ae7127c36b37"] = 35, ["d8c6c44d66b477f6"] = 35, ["5130af7127c36cea"] = 36, ["d8c6c34d66b47643"] = 36, ["5130b07127c36e9d"] = 37, ["d8c6c24d66b47490"] = 37, ["5130a17127c35520"] = 38, ["d8c6d14d66b48e0d"] = 38, ["5130a27127c356d3"] = 39, ["d8c6d04d66b48c5a"] = 39, ["5148337127d72c17"] = 40, ["d8bc574d66ab6a3a"] = 40, ["5148327127d72a64"] = 41, ["d8bc584d66ab6bed"] = 41, ["5148357127d72f7d"] = 42, ["d8bc554d66ab66d4"] = 42, ["5148347127d72dca"] = 43, ["d8bc564d66ab6887"] = 43, ["51482f7127d7254b"] = 44, ["d8bc534d66ab636e"] = 44, ["51482e7127d72398"] = 45, ["d8bc544d66ab6521"] = 45, ["5148317127d728b1"] = 46, ["d8bc514d66ab6008"] = 46, ["5148307127d726fe"] = 47, ["d8bc524d66ab61bb"] = 47, ["51482b7127d71e7f"] = 48, ["d8bc4f4d66ab5ca2"] = 48, ["51482a7127d71ccc"] = 49, ["d8bc504d66ab5e55"] = 49, ["51452d7127d4ec0e"] = 50, ["d8bfbd4d66ae4d63"] = 50, ["51452e7127d4edc1"] = 51, ["d8bfbc4d66ae4bb0"] = 51, ["51452b7127d4e8a8"] = 52, ["d8bfbf4d66ae50c9"] = 52, ["51452c7127d4ea5b"] = 53, ["d8bfbe4d66ae4f16"] = 53, ["5145317127d4f2da"] = 54, ["d8bfc14d66ae542f"] = 54, ["5145327127d4f48d"] = 55, ["d8bfc04d66ae527c"] = 55 }
  local function levelFromHash(x)
    local s = tostring(x)
    for h in s:gmatch("%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x+") do
      h = h:lower():gsub("^0+", "")
      if RANKHASH[h] then return RANKHASH[h] end
      if #h == 17 and RANKHASH[h:sub(2)] then return RANKHASH[h:sub(2)] end
    end
    return nil
  end
  local function iconFor(str)
    if type(str) ~= "string" or dvar("phantom_o_rankicons") == "0" then return nil end
    local lv = str:match("^sat_ui_icon_rank_mp_level(%d+)")
    if lv then return "pi_lvl_" .. math.max(1, math.min(55, tonumber(lv))) end
    return IE.map[str]
  end
  local function noteName(str, where)
    if type(str) ~= "string" or IE.seen[str] then return end
    local l = str:lower()
    if l:find("rank", 1, true) or l:find("prestige", 1, true) or l:find("level", 1, true) then
      IE.seen[str] = true
      log("icon name seen: " .. str .. " from " .. where)
    end
  end
  local function wrapIconTable(tname)
    local T = rawget(_G, tname)
    if type(T) ~= "table" then return 0 end
    local n = 0
    for k, f in pairs(T) do
      local slot = tname .. "." .. tostring(k)
      if type(f) == "function" and not IE.wrapped[f] and f ~= PI.hook and not IE.slots[slot] then
        IE.slots[slot] = true
        local orig = f
        local where = tname .. "." .. tostring(k)
        local w = function(...)
          local r = { n = 0 }
          local function pack(...) r.n = select("#", ...); for i = 1, r.n do r[i] = (select(i, ...)) end end
          pack(orig(...))
          for i = 1, r.n do
            if type(r[i]) == "string" then
              noteName(r[i], where)
              if tname == "LEVEL_ICON" and not IE.seen["any" .. r[i]] and (IE.anyn or 0) < 30 then IE.anyn = (IE.anyn or 0) + 1; IE.seen["any" .. r[i]] = true; log("level icon value: " .. r[i] .. " from " .. where) end
              local mine = iconFor(r[i])
              if mine and not haveIcon(mine) then mine = nil end
              if mine and PI.picked ~= nil then
                r[i] = PI.picked
              elseif mine and material(mine) then r[i] = mine end
            end
          end
          return (table.unpack or unpack)(r, 1, r.n)
        end
        IE.wrapped[w] = true
        T[k] = w
        n = n + 1
      end
    end
    return n
  end
  -- PRESTIGE ICON TILES: every icon the prestige icon screens can show (LEVEL_ICON lookup by id, the
  -- same Kronos uses) gets one of our 106 pictures; wherever the game loads that icon picture
  -- (RegisterMaterial) ours is loaded instead. dvar phantom_o_tileicons "0" = off.
  local function picPool()
    if IE.pool then return IE.pool end
    local p = {}
    for i = 1, 55 do p[#p + 1] = "pi_lvl_" .. i end
    for i = 1, 10 do p[#p + 1] = "pi_prestige_" .. i end
    for i = 1, 41 do p[#p + 1] = "pi_mtier_" .. i end
    IE.pool = p
    return p
  end
  local function buildTileMap()
    if IE.tileMap then return end
    local K = rawget(_G, "KRONOS"); local H = K and K.H
    local LI = rawget(_G, "LEVEL_ICON")
    if type(H) ~= "function" or type(LI) ~= "table" or type(LI[H("f7e7a7a4e7e58c7d")]) ~= "function" then return end
    local get = LI[H("f7e7a7a4e7e58c7d")]
    local CoDt = rawget(_G, "CoD")
    local pool = picPool()
    IE.tileMap, IE.idPic = {}, {}
    local n, lo, hi = 0, nil, nil
    for id = 114000, 118999 do
      local ok, img = pcall(get, id)
      if ok and img ~= nil and img ~= "" and not (CoDt and (img == CoDt.ERROR_TEXTURE or img == CoDt.PLACEHOLDER_TEXTURE_STR)) then
        local key = tostring(img)
        if not IE.tileMap[key] then
          n = n + 1
          IE.tileMap[key] = pool[(n - 1) % #pool + 1]
        end
        IE.idPic[id] = IE.tileMap[key]
        lo = lo or id; hi = id
      end
    end
    log("icon tiles: " .. n .. " icons found (ids " .. tostring(lo) .. "-" .. tostring(hi) .. "), each mapped to a picture")
  end
  local function hookRegisterMaterial()
    local cur = rawget(_G, "RegisterMaterial")
    if type(cur) ~= "function" or cur == IE.rm then return end
    local orig = cur
    IE.rm = function(x, ...)
      if dvar("phantom_o_rankicons") ~= "0" then
        local lv
        if type(x) == "string" then
          lv = x:match("^sat_ui_icon_rank_mp_level(%d+)")
          noteName(x, "RegisterMaterial")
        else
          lv = levelFromHash(x)
          local tile = IE.tileMap and dvar("phantom_o_tileicons") ~= "0" and IE.tileMap[tostring(x)]
          if tile and not haveIcon(tile) then tile = nil end
          if tile then
            IE.tileHits = (IE.tileHits or 0) + 1
            if IE.tileHits <= 5 or IE.tileHits % 100 == 0 then log("icon tiles: swapped " .. IE.tileHits .. " (" .. tile .. ")") end
            local asset = (type(CL) == "table" and CL.PushXHashAsset) or rawget(_G, "xhashasset")
            local okt, mt = pcall(orig, asset and asset(tile) or tile)
            if okt and mt ~= nil then return mt end
          end
        end
        if lv and PI.picked ~= nil then
          local pk = PI.picked
          if type(pk) == "string" then
            local asset = (type(CL) == "table" and CL.PushXHashAsset) or rawget(_G, "xhashasset")
            pk = asset and asset(pk) or pk
          end
          local okp, mp = pcall(orig, pk)
          if okp and mp ~= nil then return mp end
        end
        if lv and not haveIcon("pi_lvl_" .. math.max(1, math.min(55, tonumber(lv)))) then lv = nil end
        if lv then
          local mine = "pi_lvl_" .. math.max(1, math.min(55, tonumber(lv)))
          if not IE.seen["rm" .. mine] then IE.seen["rm" .. mine] = true; log("icons everywhere: material for level " .. lv .. " -> " .. mine) end
          local asset = (type(CL) == "table" and CL.PushXHashAsset) or rawget(_G, "xhashasset")
          local ok, m = pcall(orig, asset and asset(mine) or mine)
          if ok and m ~= nil then return m end
        end
      end
      return orig(x, ...)
    end
    _G.RegisterMaterial = IE.rm
    log("icons everywhere: RegisterMaterial hook on")
  end
  local function hookIconsEverywhere()
    pcall(buildTileMap)
    pcall(hookRegisterMaterial)
    local total = 0
    for _, t in ipairs({ "PROGRESSION", "LEVEL_ICON", "RANK_ICON", "PRESTIGE", "Prestige", "PrestigeUtils", "RankUtils" }) do
      local ok, n = pcall(wrapIconTable, t)
      if ok then total = total + n end
    end
    if total > 0 then log("icons everywhere: wrapped " .. total .. " functions") end
    if not IE.tablesLogged then
      IE.tablesLogged = true
      local have = {}
      for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" then
          local l = k:lower()
          if l:find("icon", 1, true) or l:find("prestige", 1, true) or l:find("rank", 1, true) or l:find("level", 1, true) then have[#have + 1] = k end
        end
      end
      table.sort(have)
      log("icons everywhere: icon-like tables " .. table.concat(have, ", "))
      -- read only: what LEVEL_ICON holds (keys, value kinds, first table entries)
      local LI = rawget(_G, "LEVEL_ICON")
      if type(LI) == "table" then
        local parts, n, shown = {}, 0, 0
        for k, v in pairs(LI) do
          n = n + 1
          if n <= 30 then parts[#parts + 1] = tostring(k) .. ":" .. type(v) end
          if type(v) == "table" and shown < 3 then
            shown = shown + 1
            local f, m = {}, 0
            for k2, v2 in pairs(v) do
              m = m + 1
              if m <= 25 then f[#f + 1] = tostring(k2) .. "=" .. (type(v2) == "table" and "table" or tostring(v2)) end
            end
            log("icons everywhere: LEVEL_ICON." .. tostring(k) .. " (" .. m .. "): " .. table.concat(f, ", "))
          end
        end
        log("icons everywhere: LEVEL_ICON has " .. n .. ": " .. table.concat(parts, ", "))
      end
    end
  end
  -- MAIN MENU BRAND: "PHANTOM MENU" + your level in the bottom-left corner of the main menu
  local MB = {}
  local function brandTick(parent)
    local want = dvar("phantom_o_brand") == "1" and not inMatch() and parent ~= nil
    if not want then
      if MB.box then pcall(function() MB.box:closeTree() end); MB.box = nil end
      return
    end
    local rk = tonumber(dvar("phantom_rank_view") or "")
    local D = rawget(_G, "Dvar"); local K = rawget(_G, "KRONOS")
    local getd = field(D, "GetDvarString")
    if K and K.H and type(getd) == "function" then
      local ok, v = pcall(getd, K.H("a9e6b907229d534e", 1))
      if ok then rk = (tonumber(v) or 0) + 1 end
    end
    local text = "PHANTOM MENU   |   MADE BY ARES"
    if not MB.box or MB.parent ~= parent then
      if MB.box then pcall(function() MB.box:closeTree() end) end
      local ok = pcall(function()
        local b = LUI.UIElement.new()
        pcall(function() b:SetHandleMouse(false) end)
        pcall(function() b:setPriority(2000) end)
        b:SetAnchorsAndPosition(0, 1, 1, 0, 40, 900, -70, -30)
        local t = LUI.UIStyledText.new()
        local fonts = rawget(_G, "FONT_HANDLE")
        local font = field(fonts, "PrimaryBold") or field(fonts, "TertiaryMedium")
        if font then pcall(function() t:SetFont(font) end) end
        pcall(function() t:SetFontSize(28) end)
        t:SetRGB(0xb07aff)
        t:SetAnchorsAndPosition(0, 1, 0, 1, 0, 860, 0, 40)
        b:addElement(t)
        parent:addElement(b)
        MB.box = b; MB.label = t; MB.parent = parent; MB.text = nil
      end)
      if not ok then return end
    end
    if MB.text ~= text then MB.text = text; pcall(function() MB.label:setText(text) end) end
  end
  -- Kronos re-attaches its Debug Options code from inside MenuBuilder.BuildRegisteredType (its
  -- upvalue hookDebugOptions) right before the settings screen is built, which would put it on top
  -- of ours and drop the Phantom tab. Chain our hook right after it, once, through the debug library.
  local function chainAfterKronos()
    if PH.chained then return end
    local dbg = rawget(_G, "debug")
    if type(dbg) ~= "table" then PH.chained = "nodebug"; log("debug options: no debug library"); return end
    local MB = rawget(_G, "MenuBuilder")
    if type(dbg) ~= "table" or type(dbg.getupvalue) ~= "function" or type(dbg.setupvalue) ~= "function" or type(MB) ~= "table" then return end
    local f = MB.BuildRegisteredType
    if type(f) ~= "function" then return end
    for i = 1, 200 do
      local name, val = dbg.getupvalue(f, i)
      if name == nil then break end
      if name == "hookDebugOptions" and type(val) == "function" then
        local kronosHook = val
        dbg.setupvalue(f, i, function(...)
          local r = { pcall(kronosHook, ...) }
          pcall(hookPhantomOptions)
          if r[1] then return unpack(r, 2) end
        end)
        PH.chained = true
        log("debug options: chained after Kronos")
        return
      end
    end
    PH.chained = "none"
    log("debug options: Kronos hook not found")
  end
  -- Phantom level past the game's 1000 cap: keep writing it into the menus' own rank data value
  local function levelKeep()
    -- target = the saved rank (Kronos rank dvar a9e6b907229d534e holds level - 1)
    local want
    do
      local K0 = rawget(_G, "KRONOS"); local D0 = rawget(_G, "Dvar"); local g0 = field(D0, "GetDvarString")
      if K0 and K0.H and type(g0) == "function" then
        local ok0, v0 = pcall(g0, K0.H("a9e6b907229d534e", 1))
        if ok0 and tonumber(v0) then want = tonumber(v0) + 1 end
      end
    end
    if not want or want <= 1000 then
      if not PH.lvlNo then PH.lvlNo = true; log("level keep: no target (" .. tostring(dvar("phantom_o_lvl")) .. ")") end
      return
    end
    local K = rawget(_G, "KRONOS"); local H = K and K.H
    local DS = rawget(_G, "_DataSources")
    if type(H) ~= "function" or type(DS) ~= "table" then return end
    local prog = DS[H("dffc2cf2d66f1248")]; prog = prog and prog[H("c7091fb2a7344c70")]
    local rankDS = prog and prog[H("6db3201fd1eb3847")]
    if not rankDS then
      if not PH.lvlNoDS then PH.lvlNoDS = true; log("level keep: rank data not found") end
      return
    end
    local okv, cur = pcall(function() return rankDS:GetValue(0) end)
    if okv and tonumber(cur) == want - 1 then return end
    local ok = pcall(function() rankDS:SetValue(0, want - 1) end)
    if not PH.lvlLogged then PH.lvlLogged = true; log("level keep: was " .. tostring(cur) .. ", set " .. tostring(want - 1) .. " ok " .. tostring(ok)) end
  end
  -- LEVEL PAST 1000: the menus turn the saved rank into the shown level with a PROGRESSION function
  -- that stops at 1000. Find every PROGRESSION function that answers 1000 for rank 9999 and let it
  -- answer rank + 1 instead whenever it would have stopped at the cap.
  local function uncapLevel()
    if PH.uncapped then return end
    local P = rawget(_G, "PROGRESSION")
    if type(P) ~= "table" then return end
    PH.uncapped = true
    local n, found = 0, 0
    for k, f in pairs(P) do
      if type(f) == "function" then
        n = n + 1
        local ok, r = pcall(f, 9999, 11)
        if ok and (r == 1000 or r == 999) then
          found = found + 1
          local orig, capv = f, r
          P[k] = function(rank, ...)
            local v = orig(rank, ...)
            local rk = tonumber(rank)
            if v == capv and rk and rk >= 1000 then return rk + (capv == 1000 and 1 or 0) end
            return v
          end
          log("level uncap: function " .. tostring(k) .. " gave " .. tostring(r))
        end
      end
    end
    log("level uncap: checked " .. n .. " functions, uncapped " .. found)
  end
  -- REAL LEVEL OVER THE MENU CORNER: the game's level number stops at 1000; with the option on,
  -- a dark plate with your saved level is drawn over it in the menus (not in matches)
  local RL = {}
  local function savedLevel()
    local K0 = rawget(_G, "KRONOS"); local D0 = rawget(_G, "Dvar"); local g0 = field(D0, "GetDvarString")
    if not (K0 and K0.H and type(g0) == "function") then return nil end
    local okr, vr = pcall(g0, K0.H("a9e6b907229d534e", 1))
    local okx, vx = pcall(g0, K0.H("f4bb97895b995476", 1))
    local lv = okr and tonumber(vr) and (tonumber(vr) + 1) or nil
    local xp = okx and tonumber(vx) or nil
    if xp and xp >= 1200000 then
      local fromXp = 57 + math.floor((xp - 1200000) / 48000)
      if not lv or fromXp > lv then lv = fromXp end
    end
    return lv
  end
  -- LEVEL UP banner past 1000 (the game's own splash stops at its table)
  local LU = {}
  local function levelUpBanner(parent, lv)
    if LU.box then pcall(function() LU.box:closeTree() end); LU.box = nil end
    pcall(function()
      local b = LUI.UIElement.new()
      pcall(function() b:SetHandleMouse(false) end)
      pcall(function() b:setPriority(5100) end)
      b:SetAnchorsAndPosition(0.5, 0.5, 0, 1, -300, 300, 160, 240)
      -- dark plate with gold edges so it reads on bright skies
      local bg = LUI.UIImage.new(); bg:SetRGB(0x0b0e14); bg:SetAlpha(0.82, 0)
      bg:SetAnchorsAndPosition(0, 1, 0, 1, 40, 560, -6, 66)
      b:addElement(bg)
      local e1 = LUI.UIImage.new(); e1:SetRGB(0xffd27a); e1:SetAlpha(0.9, 0)
      e1:SetAnchorsAndPosition(0, 1, 0, 1, 40, 560, -8, -6)
      b:addElement(e1)
      local e2 = LUI.UIImage.new(); e2:SetRGB(0xffd27a); e2:SetAlpha(0.9, 0)
      e2:SetAnchorsAndPosition(0, 1, 0, 1, 40, 560, 66, 68)
      b:addElement(e2)
      local t = LUI.UIStyledText.new()
      local fonts = rawget(_G, "FONT_HANDLE")
      local font = field(fonts, "PrimaryBold") or field(fonts, "TertiaryMedium")
      if font then pcall(function() t:SetFont(font) end) end
      pcall(function() t:SetFontSize(44) end)
      pcall(function() t:SetAlignment(1) end)
      t:SetRGB(0xffd27a)
      t:SetAnchorsAndPosition(0, 1, 0, 1, 0, 600, 0, 60)
      pcall(function() t:setText("LEVEL UP!  " .. tostring(lv)) end)
      b:addElement(t)
      parent:addElement(b)
      LU.box = b; LU.t0 = now()
    end)
  end
  local function levelUpTick(parent)
    local lv = savedLevel()
    if not lv or parent == nil then return end
    -- test switch: dvar phantom_lvltest "1" (set by the Phantom menu action "dvar phantom_lvltest 1")
    -- pretends one level was gained, then clears itself
    -- test switch: phantom_lvltest "1" = one level up; a number above 1000 (e.g. "1015") = a level-up
    -- banner for every level from 1001 up to it, one every 1.5 s
    local tv = tonumber(dvar("phantom_lvltest") or "") or 0
    if tv == 1 then
      dvar("phantom_lvltest", "0")
      LU.last = lv - 1
      log("level up test from " .. LU.last)
    elseif tv > 1000 then
      dvar("phantom_lvltest", "0")
      LU.seq = 1001; LU.seqEnd = tv; LU.seqT = 0
      log("level up test run 1001 - " .. tv)
    end
    if LU.seq and now() - (LU.seqT or 0) >= 1500 then
      levelUpBanner(parent, LU.seq)
      log("level up " .. LU.seq .. " (test)")
      LU.seqT = now()
      LU.seq = LU.seq + 1
      if LU.seq > LU.seqEnd then LU.seq = nil end
    end
    if LU.last and lv > LU.last and lv > 1000 then
      -- only the Phantom banner: firing the game's own level-up event made the UI reload (freezes)
      log("level up " .. lv)
      levelUpBanner(parent, lv)
    end
    LU.last = lv
    if LU.box and now() - (LU.t0 or 0) > 3500 then pcall(function() LU.box:closeTree() end); LU.box = nil end
  end
  local function realLevelTick(parent)
    local rk = savedLevel()
    local want = dvar("phantom_o_lvltxt") == "1" and not inMatch() and parent ~= nil and rk and rk > 1000
    if not want then
      if RL.box then pcall(function() RL.box:closeTree() end); RL.box = nil end
      return
    end
    local dx = tonumber(dvar("phantom_o_lvlx") or "") or 0
    local dy = tonumber(dvar("phantom_o_lvly") or "") or 0
    local key = rk .. "|" .. dx .. "|" .. dy
    if RL.box and RL.parent == parent and RL.key == key then return end
    if RL.box then pcall(function() RL.box:closeTree() end); RL.box = nil end
    pcall(function()
      local b = LUI.UIElement.new()
      pcall(function() b:SetHandleMouse(false) end)
      pcall(function() b:setPriority(5000) end)
      -- top-right corner, where the game shows the level next to the rank icon
      b:SetAnchorsAndPosition(1, 0, 0, 1, -455 + dx, -345 + dx, 22 + dy, 62 + dy)
      local bg = LUI.UIImage.new(); bg:SetRGB(0x0b0e14); bg:SetAlpha(0.97, 0)
      bg:SetAnchorsAndPosition(0, 1, 0, 1, 0, 110, 0, 40)
      b:addElement(bg)
      local t = LUI.UIStyledText.new()
      local fonts = rawget(_G, "FONT_HANDLE")
      local font = field(fonts, "PrimaryMedium") or field(fonts, "TertiaryMedium")
      if font then pcall(function() t:SetFont(font) end) end
      pcall(function() t:SetFontSize(30) end)
      t:SetRGB(0xffffff)
      t:SetAnchorsAndPosition(0, 1, 0, 1, 4, 110, 4, 36)
      pcall(function() t:setText(tostring(rk)) end)
      b:addElement(t)
      parent:addElement(b)
      RL.box = b; RL.parent = parent; RL.key = key
    end)
  end
  -- PARTY SCAN (calling cards, step 1): logs the menu elements around the party row that shows
  -- the player name, and any global tables with calling-card names. Read-only, a few times.
  local function execCheck()
    local e = dvar("phantom_exec") or ""
    if X.exec == nil then X.exec = e; return end
    if e == X.exec then return end
    X.exec = e
    if e == "" then return end
    local cmd = e:match("^(.-) %d+$") or e
    local eng = rawget(_G, "Engine")
    for _, name in ipairs({ "Exec", "ExecNow" }) do
      local run = field(eng, name)
      if type(run) == "function" then
        local ok = pcall(run, cmd)
        if not ok then ok = pcall(run, 0, cmd) end
        if ok then log("exec " .. cmd); return end
      end
    end
    log("exec failed " .. cmd)
  end


  -- Gun picture box: the GSC menu writes the dvar phantom_pic = "<image>|<row y>" (row y in GSC
  -- units from the top) while a gun row is selected, "" otherwise. The box sits beside the panel
  -- (on its inner side) and slides out from behind it very fast (PIC.ms); a new gun slides again.
  local PIC = { text = nil, box = nil, ms = 110 }
  local function picDrop()
    if PIC.box then pcall(function() PIC.box:closeTree() end) end
    PIC.box = nil; PIC.anim = nil
  end
  local function picPlace(off)
    local g, b = P.geo, PIC.box
    if not g or not b then return end
    local bw, bh = PIC.w, PIC.h
    -- off 0 = fully out, off bw = hidden behind the panel
    if g.right then
      local r = -g.w - PIC.gap + off
      b:SetAnchorsAndPosition(1, 0, 0, 1, r - bw, r, PIC.y, PIC.y + bh)
    else
      local l = g.w + PIC.gap - off
      b:SetAnchorsAndPosition(0, 1, 0, 1, l, l + bw, PIC.y, PIC.y + bh)
    end
  end
  local function picShow(img, rowY, parent, bwG, gapG, ms)
    picDrop()
    local g = P.geo
    if not g then return end
    local m = material(img)
    if not m then return end
    local sc = g.w / 200
    PIC.w = (bwG or 110) * sc; PIC.h = PIC.w / 2
    PIC.gap = (gapG or 6) * sc; PIC.ms = ms or 110
    PIC.y = math.max(10, rowY * sc - PIC.h / 2)
    local b = LUI.UIElement.new()
    pcall(function() b:SetHandleMouse(false) end)
    -- behind the panel frame, so it comes out from under it
    pcall(function() b:setPriority(g.prio - 1) end)
    parent:addElement(b)
    child(b, 0x000000, 0.88, 0, 0, true, true)
    local pic = child(b, nil, 1, 0, 0, true, true)
    pcall(function() pic:SetAnchorsAndPosition(0, 0, 0, 0, 4, -4, 4, -4) end)
    pic:setImage(m, 0)
    -- accent lines top and bottom
    local t1 = child(b, g.accent, 1, 0, 0, true, true); pcall(function() t1:SetAnchorsAndPosition(0, 0, 0, 1, 0, 0, 0, 2) end)
    local t2 = child(b, g.accent, 1, 0, 0, true, true); pcall(function() t2:SetAnchorsAndPosition(0, 0, 1, 0, 0, 0, -2, 0) end)
    PIC.box = b
    PIC.anim = { t0 = now() }
    picPlace(PIC.w)
  end
  local function picTick(parent)
    local t = dvar("phantom_pic") or ""
    if t ~= PIC.text then
      PIC.text = t
      if t == "" or not P.pic then picDrop()
      else
        local f = split(t)
        pcall(picShow, f[1], tonumber(f[2]) or 100, parent, tonumber(f[3]), tonumber(f[4]), tonumber(f[5]))
      end
    end
    if PIC.box and PIC.anim then
      local p = math.min(1, (now() - PIC.anim.t0) / PIC.ms)
      -- ease out: fast start, soft stop
      local e = 1 - (1 - p) * (1 - p)
      pcall(picPlace, PIC.w * (1 - e))
      if p >= 1 then PIC.anim = nil end
    end
    if PIC.box and not P.pic then picDrop() end
  end


  -- Logo check: reads images/phantom_logo.png once and compares it with the original (size and a
  -- simple checksum). Result in the dvar phantom_logo_ok (re-sent every 2 s, the menu creates it):
  -- "1" original, "0" changed / missing, "?" could not read files here.
  local LOGO = { size = 349459, sum = 1555378818, result = nil }
  local function logoCheck()
    local io_ = rawget(_G, "io")
    if type(io_) ~= "table" or type(io_.open) ~= "function" then
      -- no file access in BO7 Lua: at least the logo picture must still be there under its name
      local okm, m = pcall(function() return RegisterMaterial((CL and CL.PushXHashAsset) and CL.PushXHashAsset("phantom_logo") or "phantom_logo") end)
      LOGO.result = (okm and m ~= nil) and "1" or "0"
      log("logo check (no file access, picture present): " .. LOGO.result)
      return
    end
    local data
    for _, p in ipairs({ "kronos/mods/phantom_bg/images/phantom_logo.png", "kronos\\mods\\phantom_bg\\images\\phantom_logo.png" }) do
      local ok, fh = pcall(io_.open, p, "rb")
      if ok and fh then
        local okr, d = pcall(function() return fh:read("*a") end)
        pcall(function() fh:close() end)
        if okr and d then data = d; break end
      end
    end
    if not data then LOGO.result = "?"; log("logo check: logo file not found"); return end
    local s = 0
    for i = 1, #data do s = (s * 31 + string.byte(data, i)) % 2147483647 end
    if #data == LOGO.size and s == LOGO.sum then LOGO.result = "1" else LOGO.result = "0" end
    log("logo check: " .. LOGO.result .. " (" .. #data .. " bytes)")
  end
  pcall(logoCheck)


  -- Menu text: the GSC panel writes the visible page into the dvar phantom_menu
  --   PM|build|sel|top|row_h|text size|text_dy|bulge|bulge step|scroll ms|row delay ms|fresh|path|row0|row1|...
  -- (positions in GSC units). The rows and the path line are drawn here, inside the sliding picture
  -- frame, so they move with the panel. Text drawn by the UI uses none of the game's limited text
  -- slots (texts shown by game scripts do), so menu text can never run out.
  local M = { text = nil, rows = {}, path = nil, frame = nil }
  -- BO7's UI fonts (FONT_HANDLE keys), sent to the menu in phantom_fonts
  local FONTS = {}
  pcall(function()
    local fh = rawget(_G, "FONT_HANDLE")
    if type(fh) == "table" then
      local n = 0
      for k, _ in pairs(fh) do n = n + 1; if type(k) == "string" then FONTS[#FONTS + 1] = k end end
      -- BO7 keys the table by hashed names: test the usual LUI font names instead
      if #FONTS == 0 then
        local cands = {}
        for _, fam in ipairs({ "Primary", "Secondary", "Tertiary", "Mono", "Title", "Hud", "Objective", "Condensed", "Header", "Body", "Small", "Big", "Default", "Stencil", "Digital", "Military" }) do
          for _, wt in ipairs({ "", "Bold", "Medium", "Regular", "Light", "Black", "Italic", "BoldItalic", "SemiBold", "Condensed" }) do
            cands[#cands + 1] = fam .. wt
          end
        end
        -- unknown names give a fallback font: keep only names that give a different font, once each
        local fallback = field(fh, "PhantomNoSuchFont")
        local seen = {}
        for _, nm in ipairs(cands) do
          local v = field(fh, nm)
          if v ~= nil and v ~= fallback and not seen[tostring(v)] then
            seen[tostring(v)] = true
            FONTS[#FONTS + 1] = nm
          end
        end
      end
      log("font table entries: " .. n)
      table.sort(FONTS)
    end
  end)
  log("fonts: " .. #FONTS .. " " .. table.concat(FONTS, " "))
  local function menuFont()
    local fonts = rawget(_G, "FONT_HANDLE")
    local name = dvar("phantom_font") or ""
    local f = (name ~= "" and field(fonts, name)) or nil
    return f or field(fonts, "TertiaryMedium") or field(fonts, "SecondaryRegular") or field(fonts, "PrimaryBold")
  end
  local function mText(parent, size)
    local t = LUI.UIStyledText.new()
    local font = menuFont()
    if font then pcall(function() t:SetFont(font) end) end
    pcall(function() t:SetFontSize(size) end)
    pcall(function() t:SetAlignment(0) end)
    pcall(function() t:SetHandleMouse(false) end)
    t:SetRGB(0xffffff)
    parent:addElement(t)
    return t
  end
  local function mClear()
    for _, r in ipairs(M.rows) do pcall(function() r.e:closeTree() end) end
    if M.path then pcall(function() M.path:closeTree() end) end
    M.rows = {}; M.path = nil; M.frame = nil; M.text = nil
  end
  local function mTick()
    local c, g = P.pic, P.geo
    if not c or not g then if M.frame then mClear() end return end
    if M.frame ~= c then mClear(); M.frame = c end
    local fname = dvar("phantom_font") or ""
    if fname ~= M.font then M.font = fname; mClear(); M.frame = c end
    local t = dvar("phantom_menu") or ""
    if t ~= M.text then
      M.text = t
      local f = split(t)
      if f[1] ~= "PM" then return end
      local build = f[2]
      M.sel = tonumber(f[3]) or 0; M.top = tonumber(f[4]) or 92; M.rowH = tonumber(f[5]) or 14
      M.size = tonumber(f[6]) or 1; M.dy = tonumber(f[7]) or 0; M.bulge = tonumber(f[8]) or 14
      M.bstep = tonumber(f[9]) or 4; M.ms = tonumber(f[10]) or 120; M.delay = tonumber(f[11]) or 200
      local fresh = f[12] == "1"
      local fs_ = M.rowH * 0.78 * M.size * 2.25
      if not M.path then M.path = mText(c, fs_ * 0.9) end
      pcall(function() M.path:setText(f[13] or "") end)
      local n = #f - 13
      -- new build after a fresh open: rows fade in one after another
      if build ~= M.build then
        M.build = build
        if fresh then M.t0 = now() else M.t0 = nil end
        for _, r in ipairs(M.rows) do r.y = nil end
      end
      for i = 1, n do
        local r = M.rows[i]
        if not r then r = { e = mText(c, fs_) }; M.rows[i] = r end
        pcall(function() r.e:setText(f[13 + i] or "") end)
        r.on = true
      end
      for i = n + 1, #M.rows do M.rows[i].on = false; pcall(function() M.rows[i].e:setText("") end) end
    end
    -- every frame: glide each row to its place (bulge indent around the selection)
    if not M.rowH then return end
    local k = 1 - math.exp(-(R.frameMs or 16) / math.max(20, M.ms * 0.45))
    local s2 = 2.25
    for i, r in ipairs(M.rows) do
      if r.on then
        local li = i - 1
        local off = math.max(0, M.bulge - math.abs(li - M.sel) * M.bstep)
        local tx = (12 + off) * s2
        local ty = (M.top + li * M.rowH + M.dy) * s2
        if r.y == nil then r.x = tx; r.y = ty end
        r.x = r.x + (tx - r.x) * k; r.y = r.y + (ty - r.y) * k
        local a = 1
        if M.t0 then a = math.max(0, math.min(1, (now() - M.t0 - li * M.delay) / 250)) end
        pcall(function()
          r.e:SetAnchorsAndPosition(0, 1, 0, 1, r.x, r.x + 600, r.y, r.y + M.rowH * s2)
          r.e:SetAlpha(a, 0)
        end)
      end
    end
    if M.path then
      pcall(function() M.path:SetAnchorsAndPosition(0, 1, 0, 1, 10 * s2, 10 * s2 + 600, (M.top - 22) * s2, (M.top - 22 + M.rowH) * s2) end)
    end
  end


  -- Centre messages (dvar phantom_tell "<n>|<text>"): big text under the middle of the screen
  -- for 2.5 s, fading out. Drawn by the UI, so no text slots are used.
  local T = { last = nil, box = nil, label = nil, t0 = 0 }
  local function tellTick(parent)
    local v = dvar("phantom_tell") or ""
    if v ~= T.last then
      T.last = v
      local n, msg = v:match("^(%d+)|(.*)$")
      if n and parent then
        if not T.box or T.parent ~= parent then
          if T.box then pcall(function() T.box:closeTree() end) end
          local b = LUI.UIElement.new()
          pcall(function() b:SetHandleMouse(false) end)
          pcall(function() b:setPriority(1100) end)
          b:SetAnchorsAndPosition(0.5, 0.5, 0.5, 0.5, -700, 700, 140, 190)
          local t = LUI.UIStyledText.new()
          t:SetAnchorsAndPosition(0, 0, 0, 0, 0, 0, 0, 0)
          local fonts = rawget(_G, "FONT_HANDLE")
          local font = field(fonts, "TertiaryMedium") or field(fonts, "SecondaryRegular") or field(fonts, "PrimaryBold")
          if font then pcall(function() t:SetFont(font) end) end
          pcall(function() t:SetFontSize(30) end)
          pcall(function() t:SetAlignment(1) end)
          t:SetRGB(0xffffff)
          b:addElement(t)
          parent:addElement(b)
          T.box = b; T.label = t; T.parent = parent
        end
        pcall(function() T.label:setText("^5PHANTOM^7  " .. msg) end)
        T.t0 = now()
      end
    end
    if T.box then
      local age = now() - T.t0
      local a = 1
      if age > 2500 then a = math.max(0, 1 - (age - 2500) / 400) end
      pcall(function() T.box:SetAlpha(a, 0) end)
    end
  end


  -- Loading screen (match start): PHANTOM letters, a brightness wave runs through the dimmed letters
  -- while each one hops, and a violet -> aether blue bar fills underneath following the menu's real loading
  -- steps (dvar phantom_load 0-100, set by the GSC menu). At 100 the bar hits the end, it says the
  -- menu is ready and how to open it, then fades out. Drawn by the UI: no text slots used.
  local L = { word = "PHANTOM", box = nil, shown = 0, target = 0, doneAt = nil, finished = false, minMs = 2500 }
  local function loadDrop()
    if L.box then pcall(function() L.box:closeTree() end) end
    L.box = nil; L.letters = nil
  end
  local function lerpRGB(a, b, f)
    local ar, ag, ab = math.floor(a / 65536), math.floor(a / 256) % 256, a % 256
    local br, bg, bb = math.floor(b / 65536), math.floor(b / 256) % 256, b % 256
    return math.floor(ar + (br - ar) * f) * 65536 + math.floor(ag + (bg - ag) * f) * 256 + math.floor(ab + (bb - ab) * f)
  end
  local function loadBuild(parent)
    -- colours from the preset in use: "bar start|bar end|letters|glow" (hex)
    local cs = split(dvar("phantom_load_colors") or "")
    L.c1 = tonumber(cs[1] or "", 16) or 0x6a1bff; L.c2 = tonumber(cs[2] or "", 16) or 0x38b6ff
    L.ct = tonumber(cs[3] or "", 16) or 0xe6d8ff; L.cg = tonumber(cs[4] or "", 16) or 0xa04dff
    local b = LUI.UIElement.new()
    pcall(function() b:SetHandleMouse(false) end)
    pcall(function() b:setPriority(1200) end)
    b:SetAnchorsAndPosition(0.5, 0.5, 0, 1, -330, 330, 250, 400)
    local fonts = rawget(_G, "FONT_HANDLE")
    local font = field(fonts, "PrimaryBold") or field(fonts, "TertiaryMedium") or field(fonts, "SecondaryRegular")
    L.letters = {}
    L.glows = {}
    local n = #L.word
    local step = 84
    local x0 = (660 - step * n) / 2
    for i = 1, n do
      local t = LUI.UIStyledText.new()
      if font then pcall(function() t:SetFont(font) end) end
      pcall(function() t:SetFontSize(70) end)
      pcall(function() t:SetAlignment(1) end)
      t:SetRGB(L.ct)
      t:SetAnchorsAndPosition(0, 1, 0, 1, x0 + (i - 1) * step, x0 + i * step, 20, 96)
      pcall(function() t:setText(L.word:sub(i, i)) end)
      -- cyan glow behind the letter (the CSS text-shadow), bright only at the hop
      local gl = LUI.UIStyledText.new()
      if font then pcall(function() gl:SetFont(font) end) end
      pcall(function() gl:SetFontSize(76) end)
      pcall(function() gl:SetAlignment(1) end)
      gl:SetRGB(L.cg); gl:SetAlpha(0, 0)
      pcall(function() gl:setText(L.word:sub(i, i)) end)
      b:addElement(gl)
      L.glows[i] = gl
      b:addElement(t)
      L.letters[i] = t
    end
    -- bar track + fill
    L.track = LUI.UIImage.new(); L.track:SetRGB(0x2a1446); L.track:SetAlpha(0.85, 0)
    L.track:SetAnchorsAndPosition(0, 1, 0, 1, x0, x0 + step * n, 108, 114)
    b:addElement(L.track)
    -- fill = linear gradient pink -> cyan across the whole bar (16 slices), shown up to the progress
    L.slices = {}
    for j = 1, 16 do
      local sl = LUI.UIImage.new()
      sl:SetRGB(lerpRGB(L.c1, L.c2, (j - 0.5) / 16)); sl:SetAlpha(0, 0)
      sl:SetAnchorsAndPosition(0, 1, 0, 1, x0, x0, 108, 114)
      b:addElement(sl)
      L.slices[j] = sl
    end
    L.x0 = x0; L.bw = step * n
    -- caption
    L.cap = LUI.UIStyledText.new()
    if font then pcall(function() L.cap:SetFont(field(fonts, "SecondaryRegular") or font) end) end
    pcall(function() L.cap:SetFontSize(26) end)
    pcall(function() L.cap:SetAlignment(1) end)
    L.cap:SetRGB(0xb9a6ff)
    L.cap:SetAnchorsAndPosition(0, 0, 0, 1, 0, 0, 126, 156)
    pcall(function() L.cap:setText("loading menu") end)
    b:addElement(L.cap)
    parent:addElement(b)
    L.box = b; L.t0 = now(); L.shown = 0
  end
  local function loadTick(parent)
    local raw = dvar("phantom_load") or ""
    local mid, pv = raw:match("^(%d+)|(%d+)$")
    local v = tonumber(pv or raw) or 0
    -- once per match: a new match id starts it again; the same match never shows it twice
    if mid and mid ~= L.mid then
      L.mid = mid; L.finished = false; L.doneAt = nil
      if L.box then loadDrop() end
      dvar("phantom_load_done", "")
    end
    if L.finished or v <= 0 or parent == nil then if L.box and (L.finished or v <= 0) then loadDrop() end return end
    if not L.box or L.parent ~= parent then loadDrop(); L.parent = parent; pcall(loadBuild, parent) end
    if not L.box then return end
    local tnow = now()
    -- bar eases toward the real progress
    -- the bar follows the real loading steps, but never fills faster than L.minMs (3 s), so it
    -- covers the time it takes to get into the map
    L.target = math.min(v / 100, (tnow - L.t0) / L.minMs)
    L.shown = L.shown + (L.target - L.shown) * math.min(1, (R.frameMs or 16) / 180)
    if L.target >= 1 and L.shown > 0.995 then L.shown = 1 end
    -- tell the menu the bar really reached the end (it opens only after that)
    if L.shown >= 1 then dvar("phantom_load_done", "1") end
    for j, sl in ipairs(L.slices) do
      local a0, a1 = (j - 1) / 16, j / 16
      local vis = math.max(0, math.min(a1, L.shown) - a0)
      pcall(function()
        sl:SetAnchorsAndPosition(0, 1, 0, 1, L.x0 + L.bw * a0, L.x0 + L.bw * (a0 + vis), 108, 114)
        sl:SetAlpha(vis > 0 and 1 or 0, 0)
      end)
    end
    -- letter wave: 1.6 s cycle, 0.1 s between letters, hop + brighten in the first 40 %
    for i, t in ipairs(L.letters) do
      local p = ((tnow - L.t0 - (i - 1) * 100) % 1600) / 1600
      local up, a = 0, 0.28
      if p < 0.4 then
        local q = p / 0.4
        local w = q < 0.5 and (1 - math.cos(q * 2 * math.pi)) / 2 or (1 - math.cos((1 - q) * 2 * math.pi)) / 2
        up = w * 14; a = 0.28 + 0.72 * w
      end
      if L.shown >= 1 then a = 1; up = 0 end
      pcall(function()
        local idx = i - 1
        local step = L.bw / #L.letters
        t:SetAnchorsAndPosition(0, 1, 0, 1, L.x0 + idx * step, L.x0 + (idx + 1) * step, 20 - up, 96 - up)
        t:SetAlpha(a, 0)
        local gl = L.glows and L.glows[i]
        if gl then
          gl:SetAnchorsAndPosition(0, 1, 0, 1, L.x0 + idx * step - 2, L.x0 + (idx + 1) * step + 2, 17 - up, 99 - up)
          gl:SetAlpha((a - 0.28) / 0.72 * 0.6, 0)
        end
        if L.shown >= 1 then t:SetRGB(lerpRGB(L.c1, L.c2, idx / (#L.letters - 1))) end
      end)
    end
    -- done: say so, hold, fade out
    if L.shown >= 1 then
      if not L.doneAt then
        L.doneAt = tnow
        pcall(function() L.cap:setText("^2READY^7  -  Aim + Knife to open  (LT + R3 / L2 + R3)") end)
      end
      local age = tnow - L.doneAt
      if age > 1200 then
        pcall(function() L.box:SetAlpha(math.max(0, 1 - (age - 1200) / 400), 0) end)
      end
      if age > 1700 then loadDrop(); L.finished = true end
    end
  end


  -- Credit at the bottom of the panel (text from the menu: dvar phantom_credit), "scanning highlight":
  -- letters at 25 % brightness, a thin glowing bar sweeps left -> right -> left (2.6 s each way,
  -- ease in-out) and each letter lights up fully as the bar passes it (band +-30 % of the word).
  local CR = { frame = nil, letters = nil, text = nil }
  local function crClear()
    if CR.box then pcall(function() CR.box:closeTree() end) end
    CR.box = nil; CR.letters = nil; CR.frame = nil
  end
  local function crTick()
    local c, g = P.pic, P.geo
    local text = dvar("phantom_credit") or ""
    if not c or not g or text == "" then if CR.box then crClear() end return end
    if CR.frame ~= c or CR.text ~= text then
      crClear(); CR.frame = c; CR.text = text
      local b = LUI.UIElement.new()
      pcall(function() b:SetHandleMouse(false) end)
      local size, adv = 26, 15
      local n = #text
      local w = n * adv
      -- centred, 20 UI units above the bottom edge of the frame
      b:SetAnchorsAndPosition(0, 1, 1, 0, (g.w - w) / 2, (g.w + w) / 2, -46, -16)
      c:addElement(b)
      local font = menuFont()
      CR.letters = {}
      for i = 1, n do
        local t = LUI.UIStyledText.new()
        if font then pcall(function() t:SetFont(font) end) end
        pcall(function() t:SetFontSize(size) end)
        pcall(function() t:SetAlignment(1) end)
        t:SetRGB(0xffffff)
        t:SetAnchorsAndPosition(0, 1, 0, 1, (i - 1) * adv, i * adv, 0, 30)
        pcall(function() t:setText(text:sub(i, i)) end)
        b:addElement(t)
        CR.letters[i] = t
      end
      CR.bar = LUI.UIImage.new(); CR.bar:SetRGB(g.accent or 0xff4fd8)
      b:addElement(CR.bar)
      CR.glow = LUI.UIImage.new(); CR.glow:SetRGB(g.accent or 0xff4fd8); CR.glow:SetAlpha(0.25, 0)
      b:addElement(CR.glow)
      CR.box = b; CR.w = w; CR.t0 = now()
    end
    -- ping-pong 2.6 s, ease in-out
    local t = ((now() - CR.t0) % 5200) / 2600
    if t > 1 then t = 2 - t end
    local e = (1 - math.cos(t * math.pi)) / 2
    local x = e * CR.w
    pcall(function()
      CR.bar:SetAnchorsAndPosition(0, 1, 0, 1, x - 1.5, x + 1.5, -6, 36)
      CR.glow:SetAnchorsAndPosition(0, 1, 0, 1, x - 9, x + 9, -6, 36)
    end)
    for i, l in ipairs(CR.letters) do
      local cx = (i - 0.5) / #CR.letters
      local d = math.abs(cx - e)
      local k = math.max(0, 1 - d / 0.3)
      pcall(function() l:SetAlpha(0.25 + 0.75 * k, 0) end)
    end
  end


  -- Controls line under the menu rows (dvar phantom_foot "<y in GSC units>|<text>"), centred, grey.
  local FT = { frame = nil, text = nil }
  local function ftTick()
    local c, g = P.pic, P.geo
    local v = dvar("phantom_foot") or ""
    if not c or not g or v == "" then
      if FT.e then pcall(function() FT.e:closeTree() end); FT.e = nil end
      FT.frame = nil; FT.text = nil
      return
    end
    if FT.frame ~= c or FT.text ~= v or FT.font ~= (dvar("phantom_font") or "") then
      if FT.e then pcall(function() FT.e:closeTree() end) end
      FT.frame = c; FT.text = v; FT.font = dvar("phantom_font") or ""
      local y, txt = v:match("^(%d+)|(.*)$")
      y = (tonumber(y) or 300) * 2.25
      local t = LUI.UIStyledText.new()
      local font = menuFont()
      if font then pcall(function() t:SetFont(font) end) end
      pcall(function() t:SetFontSize(20) end)
      pcall(function() t:SetAlignment(1) end)
      t:SetRGB(0xa0a0a0)
      t:SetAnchorsAndPosition(0, 0, 0, 1, 0, 0, y, y + 26)
      pcall(function() t:setText(txt or "") end)
      c:addElement(t)
      FT.e = t
    end
  end

  local function tick()
    P.ticks = P.ticks + 1
    if P.ticks % 15 == 0 then
      pcall(execCheck)
      pcall(hookPhantomOptions)
      pcall(chainAfterKronos)

      pcall(hookPrestigeIcons)
      pcall(hookIconsEverywhere)
      pcall(brandTick, screen())
      if inMatch() then pcall(hudLine, screen()) end
    end
    if P.ticks % 2 == 0 and inMatch() then pcall(bossTick, screen()) end
    R.frames = R.frames + 1
    if P.anim then
      if step(P.anim) then
        if P.leaving and P.anim.e == P.leaving then
          pcall(function() P.leaving:closeTree() end); P.leaving = nil
        end
        P.anim = nil
      end
    end
    if P.ticks % 120 == 1 then dvar("phantom_bg_lua", "1"); dvar("phantom_menu_lua", "1"); if #FONTS > 0 then dvar("phantom_fonts", table.concat(FONTS, "|")) end if LOGO.result then dvar("phantom_logo_ok", LOGO.result) end end
    if not inMatch() then P.drop(); picDrop(); return end
    if P.pic then pcall(picTick, P.parent) elseif PIC.box then picDrop(); PIC.text = nil end
    pcall(mTick)
    pcall(crTick)
    pcall(ftTick)
    if inMatch() then pcall(tellTick, screen()) end
    if inMatch() then pcall(loadTick, screen()) end
    local text = dvar("phantom_bg") or ""
    if text == "" then
      if P.pic then leave() end
      return
    end
    -- pause menu: hide in place (the GSC panel hides itself too), show again when it closes
    if paused() then
      if P.pic and not P.hidden then P.pic:SetAlpha(0, 0); P.hidden = true end
      return
    end
    if P.pic and P.hidden then
      P.hidden = false
      if not P.anim then P.pic:SetAlpha(1, 0) end
    end
    local parent = screen()
    if parent == nil then return end
    if text ~= P.shown or parent ~= P.parent then show(text, parent) end
    -- animated background: next frame when its time has come
    local fr = P.frames
    if fr and P.img then
      local idx = math.floor((now() - fr.t0) / fr.ms) % fr.n
      if idx ~= fr.idx then
        fr.idx = idx
        local m = material(string.format("%s_f%03d", fr.name, idx))
        if m then pcall(function() P.img:setImage(m, 0) end) end
      end
    end
  end

  -- UI timer: a hidden element's Wait() re-armed after every tick (every frame, so the picture moves as smoothly as the panel).
  local function root()
    local ok, r = pcall(function() return LUI.primaryRoot end)
    if ok and r then return r end
    local g = field(LUI, "GetRoot")
    if type(g) == "function" then
      local ok2, r2 = pcall(g)
      if ok2 then return r2 end
    end
    return nil
  end
  local function startTimer()
    if not P.on then return end
    local r = root()
    if r == nil then return end
    if P.timer then
      local ok, up = pcall(function() return P.timer:getParent() end)
      if ok and up == r then return end
      pcall(function() P.timer:closeTree() end)
    end
    local host = LUI.UIElement.new()
    pcall(function() host:SetHandleMouse(false) end)
    r:addElement(host)
    P.timer = host
    local function again()
      if not P.on or P.timer ~= host then return end
      local anim = host:Wait(1)
      if not anim then P.timer = nil; return end
      anim.onComplete = function()
        if not P.on or P.timer ~= host then return end
        local ok, err = pcall(tick)
        if not ok then
          P.errors = (P.errors or 0) + 1
          if P.errors <= 5 then log("tick error " .. tostring(err)) end
          pcall(P.drop)
        end
        pcall(again)
      end
    end
    again()
    -- real-time clock chain on its own element (see now())
    if P.clock then pcall(function() P.clock:closeTree() end) end
    local ck = LUI.UIElement.new()
    pcall(function() ck:SetHandleMouse(false) end)
    r:addElement(ck)
    P.clock = ck
    local function beat()
      if not P.on or P.clock ~= ck then return end
      local anim = ck:Wait(200)
      if not anim then P.clock = nil; return end
      anim.onComplete = function()
        if not P.on or P.clock ~= ck then return end
        pcall(clockStep)
        pcall(beat)
      end
    end
    beat()
  end

  -- The UI root is rebuilt on map load, which kills the timer: any input restarts it.
  -- Round typing for the Phantom menu: while the menu sets dvar phantom_typing to "1", number
  -- keys, - and +, Backspace, Enter and Esc are caught here (not passed to the game, so 1-3
  -- don't switch weapons) and written to dvar phantom_typed = "seq|#text|state"
  -- (state 0 typing, 1 Enter, 2 Esc). Unknown keys are logged (first 40) so names can be added.
  local KEYS = {}
  local function addKey(names, v)
    for _, n in ipairs(names) do
      KEYS[n] = v
      if type(hashName) == "function" then
        local ok, h = pcall(hashName, n)
        if ok and h ~= nil then KEYS[tostring(h):lower()] = v end
      end
    end
  end
  for d = 0, 9 do
    local s = tostring(d)
    addKey({ s, "kp_" .. s, "num" .. s, "numpad" .. s, "numpad_" .. s, "keypad_" .. s, "k_" .. s, "key_" .. s, "kp" .. s }, s)
  end
  addKey({ "-", "minus", "kp_minus", "numpadminus", "numpad_minus", "subtract", "kp_subtract" }, "-")
  addKey({ "+", "=", "plus", "equals", "kp_plus", "numpadplus", "numpad_plus", "add", "kp_add" }, "+")
  addKey({ "backspace", "back", "bksp", "kp_del", "del", "delete" }, "bs")
  addKey({ "enter", "return", "kp_enter", "numpadenter", "numpad_enter" }, "enter")
  addKey({ "escape", "esc" }, "esc")
  local T = { on = false, text = "", seq = 0, logged = 0 }
  local function typedWrite(state)
    T.seq = T.seq + 1
    dvar("phantom_typed", T.seq .. "|#" .. T.text .. "|" .. state)
  end
  -- returns true when the key was used (then the game doesn't get it)
  local function typingKey(...)
    if (dvar("phantom_typing") or "") ~= "1" then T.on = false; return false end
    if not T.on then T.on = true; T.text = "" end
    local args = { ... }
    local down = args[4]
    local found
    for i = 2, math.min(#args, 14) do
      local v = args[i]
      if type(v) == "string" or (type(v) == "number" and i >= 5) then
        local k = KEYS[tostring(v):lower()]
        if k then found = k; break end
      end
    end
    if not found then
      if down == true and T.logged < 40 then
        T.logged = T.logged + 1
        local parts = {}
        for i = 1, math.min(#args, 14) do parts[#parts + 1] = tostring(args[i]) end
        log("typing: unknown key " .. table.concat(parts, " "))
      end
      return false
    end
    if down ~= true then return true end
    if found == "enter" then typedWrite(1); T.on = false
    elseif found == "esc" then typedWrite(2); T.on = false
    elseif found == "bs" then T.text = T.text:sub(1, -2); typedWrite(0)
    elseif found == "-" or found == "+" then
      if T.text == "" then T.text = found; typedWrite(0) end
    elseif #T.text < 5 then T.text = T.text .. found; typedWrite(0) end
    return true
  end

  local function hookInput()
    local ui = field(LUI, "UIRoot")
    local orig = field(ui, "QueueInput")
    if type(orig) ~= "function" or P.hooked == ui then return end
    local wrapped = function(...)
      if P.on then pcall(startTimer) end
      if P.on then
        local ok, used = pcall(typingKey, ...)
        if ok and used then return true end
      end
      return orig(...)
    end
    ui.QueueInput = wrapped
    if type(hashName) == "function" then pcall(function() ui[hashName("QueueInput")] = wrapped end) end
    P.hooked = ui
  end

  pcall(startTimer)
  pcall(hookInput)
  log("loaded")
end
