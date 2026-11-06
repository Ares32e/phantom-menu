# Phantom Menu

A Black Ops 7 **Zombies** mod menu for the Kronos launcher. Made by **Ares**.

Spawn any enemy, get any gun, Pack-a-Punch it, skip or go back rounds, move map objects, build your own bosses, play special modes and a lot more. Works in Zombies only, and it switches itself off in Multiplayer. **Solo / private matches only.** Please don't use it to ruin other people's games.

## Install

Install **Phantom Menu** from the Workshop page in the Kronos launcher. It goes to `cod25\kronos\mods\phantom_menu`.
Start the game, load a Zombies match and wait for the PHANTOM loading bar to say **READY**.

If you used an older hand-copied version, delete its `zm_zz_devmenu*.gsc`, `zm_sandbox.gsc`, `zm_zmap.gsc` and `zm_zspawn.gsc` from `cod25\kronos\custom_scripts`, so the menu doesn't run twice.

## Controls

| | Mouse / keyboard | Controller |
|---|---|---|
| Open / close | Aim + Knife together | LT + R3 (L2 + R3) |
| Up | Aim | LT / D-pad up |
| Down | Shoot | RT / D-pad down |
| Select | Use (F) | X / Square, D-pad right |
| Back | Knife | R3, D-pad left |

On the main page, pressing Knife once shows "Knife again to close the menu".

## What's in it

- **Player:**
  - god mode, infinite ammo, speed / jump / gravity, noclip, cinematic mode, infinite points, free purchases
  - armor, teleports and saved spots, points and salvage
  - perks (incl. eternal), operator skins, camos, bundles
- **Weapons:**
  - every gun by category with its in-game name, wonder weapons
  - Pack-a-Punch I-IV, rarity, rapid fire, infinite equipment
  - an auto scan for new / crossover / exotic guns
- **Zombies:** spawn any loaded enemy (bosses, HVTs, elites, armored, hounds), custom waves, animations, freeze / kill / friendly zombies
- **Game:**
  - game modes: gun game, one in the chamber, sharpshooter, One Gun Roulette
  - match rules incl. Map Rotation
  - map scan, rounds (forward and back), power-ups, world options
- **Fun:** chaos options, effects, vehicles, gamble, **Boss Creator** (your own boss with a prop body, effects, abilities and a health bar)
- **Overpowered:** god loadout, damage multipliers, aimbot, ESP, explosive / Zeus / freeze-ray shots, break-the-game options
- **Build:** Forge (pick up and move map objects, save copies), Map Builder support
- **Settings:** colours, side, rows, font, backgrounds, presets (Phantom, Dark Aether, World at War, Black Ops 1 / 2 / 3 / 4, Cold War, Black Ops 6), 3 save slots
- **Debug Options:** in the game's Settings > Debug Options there is a **PHANTOM OPTIONS** tab with match rules, zombie settings, match start options, Map Rotation, One Gun Roulette and "Turn Off Phantom Menu"
- **Secret:** a hidden page. Hint: a famous cheat code with Aim (up) and Shoot (down).

## Your own pictures

The menu ships with its logo, era headers, prestige rings, the preset backgrounds, 66 gun pictures and 24 enemy pictures. You can add your own icons, backgrounds, gun pictures and enemy pictures with the **Phantom Pictures** helper:

1. Download `Phantom-Pictures-Helper.zip` from this repo and unzip the `Phantom Pictures` folder into `cod25\kronos\mods\phantom_menu`.
2. Drop PNGs into its folders:

| Folder | What | Size (pixels) |
|---|---|---|
| `Icons\Level 1` ... `Icons\Level 55` | level badge for that level (one picture per folder) | 256 x 256 |
| `Icons\Prestige 1` ... `Icons\Prestige 10` | prestige icon | 256 x 256 |
| `Icons\Prestige Master 1 (levels 1-25)` ... `41 (levels 977-1000)` | Prestige Master icon for those levels | 256 x 256 |
| `Backgrounds` | picture behind the menu: any name, or a preset name (`aether`, `waw`, `bo1`, `bo2`, `bo3`, `bo4`, `cw`, `bo6`) to replace that preset's background | 720 x 1080 (tall) |
| `Gun Pictures` | picture when you hover a gun, named after the gun ID (e.g. `sat_ar_kiwi.png`) | 512 x 256 (wide) |
| `Enemy Pictures` | picture when you hover an enemy, named after the enemy ID (e.g. `sat_spawner_zombie_karkinos_ob.png`) | 512 x 256 (wide) |

3. Double-click `Install Phantom Pictures.bat`.
4. Restart the game.

- **PNG only:** it must be a real PNG. In Paint, use *File > Save as > PNG picture*.
- **Sizes:** other sizes are fitted automatically. Icons, gun pictures and enemy pictures look best with a see-through background.
- **Empty icon folders** keep the game's own icon.
- **Picking a prestige icon in the game** shows that icon; pick the X to go back to your pictures.
- **Always add pictures with the helper:** it also tells the menu which pictures exist.
- **IDs:** every gun and enemy ID is in `Picture names.txt`.

## Tips

- **Menu doesn't open:** wait for READY, then press Aim and Knife at the same time.
- **"not loaded here" when spawning:** that enemy isn't loaded on this map or in this area yet. Map scan shows what can spawn.
- **Alt-tab:** solo matches pause when you alt-tab, so the menu pauses too.
- **Reload:** Game > World > Restart map reloads the menu without leaving the match.
- **Reset:** settings live in `cod25\kronos\devmenu\settings.json`. Delete that file to reset them.
- **Credit and logo:** don't edit the credit or the PHANTOM logo. The menu then refuses to open.

## Credits

Made by Ares. Header fonts: Stardos Stencil, Black Ops One, Saira Stencil One, Orbitron, Teko, Oxanium, Bebas Neue (SIL Open Font License).
