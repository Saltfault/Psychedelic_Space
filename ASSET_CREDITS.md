# Asset credits

## Sci-Fi UI Sprites pack — source/license unverified
The supplied `CREDIT.txt` does not identify an author, original source, or license. No attribution or usage permission is inferred. Its button, panel, slot, minimap-frame, icon, and portrait sheets are currently used by the menus and HUD. Confirm the original source and terms before public release or commercial distribution.

## Pixelosopher font
Pixelosopher by Jovanny Lemonad (2008–2010) and Filip Uzunov / Helianthus Games (2026), https://helianthus-games.itch.io/pixelosopher. Licensed under the SIL Open Font License 1.1. The font is embedded as the project's default UI font; its OFL text and credit are preserved in `assets/fonts/pixelosopher/License.txt` and `assets/fonts/pixelosopher/CREDIT.txt`. The OFL permits bundling with software; do not sell the font by itself or use the reserved name for a modified font.

## Super Pixel Sci-Fi UI
By Will Tice / unTied Games. https://untiedgames.itch.io/ (the exact product URL is not verified). The included license summary permits commercial and noncommercial game use, prohibits standalone asset redistribution, and requires credit. Attribution: “Pixel Art Assets - Will Tice / unTied Games.” Its blue panel and meter textures are used for HUD, map, and shop surfaces. Original license summary is preserved at `docs/asset_pack_materials/ui/SUPER_PIXEL_SCIFI_UI_LICENSE.txt`.

## Super Pixel Sci-fi FX Pack 1
By Will Tice / unTied Games. https://untiedgames.itch.io/ (exact product URL not verified). The included terms allow commercial and noncommercial game use, prohibit standalone redistribution, and require credit to Will Tice. Its large blue wormhole loop replaces the prior gate animation; its zap, spark, and explosion sheets provide projectile variants and randomized combat effects. License is preserved at `docs/asset_pack_materials/effects/scifi_fx/LICENSE.txt`.

## Engine Flames
By Dolkyns. https://dolkyns.itch.io/engine-flames. The player ship's engine flame uses this pack. Its custom license permits personal and commercial project use and modification, but prohibits standalone redistribution or resale. Credit is optional; suggested credit: “Engine flame assets by Dolkyns.” The original license and readme were reviewed during asset intake.

## Audio, shield, ship, and planet assets

- **Pixel Spaceship Megapack** — Guardian (`https://guardian5.itch.io/spaceship-megapack`). Personal and commercial use and editing are allowed; standalone or asset-pack redistribution is prohibited. Credit is appreciated but not required. The project's ship atlases are under `assets/sprites/ships/guardian5/`.
- **PIPOYA FREE VFX HEX Shield** — Pipoya (`https://pipoya.itch.io/pipoya-free-vfx-hex-shield`). Personal/commercial project use and edits are allowed; asset resale/redistribution is prohibited; attribution is not required. Ram's shield animation sheets are under `assets/effects/ram_shield/`.
- **3D Planet Generator** — Naejimer (`https://naejimer.itch.io/godot-3d-planet-generator`). MIT, with attribution appreciated but not required. The sample resources are copied under `addons/naejimer_3d_planet_generator/` to preserve their `res://` references; it is sample content, not an enabled editor plugin. The upstream source/license is recorded there and in `THIRD_PARTY_NOTICES.md`.
- **Planet Icons Pack [16x16px]** — Helianthus Games / Filip Uzunov (`https://helianthus-games.itch.io/pixelart-planets-16x16`). The included license permits commercial and personal derivative-project use and modification; attribution is not required, and standalone redistribution is prohibited. `Tech.png` marks stations and `Tech2.png` marks outposts in the maps.
- **Neon Skirmish sampler** — selected player-fire, hull-hit, and Dash sounds are under `assets/audio/sfx/`. The archive includes a license file allowing in-game use and disallowing standalone asset-pack redistribution; the author/original source URL could not be verified, so that limitation is explicitly retained in the notices.
- **Kosmik Kode, Vol. 2 and Vol. 3** — Psychic Rink / Shoffur (`https://psychicrink.itch.io/kosmik-kode-vol-2`, `https://psychicrink.itch.io/kosmik-kode-vol-3`). Both packs state CC BY 4.0 and require attribution. Selected enemy-fire/death, shield-block, and warp-arrival sounds are under `assets/audio/sfx/`. Attribution: “Kosmik Kode sound effects by Shoffur / Psychic Rink, CC BY 4.0.”
- **Sci-Fi UI SFX Pack** — JDSherbert (`https://jdsherbert.itch.io/sci-fi-ui-sfx-pack`). Its included terms require crediting JDSherbert in the credits roll or a text file in the game package. Selected menu sounds are under `assets/audio/sfx/`. Attribution: “Sci-Fi UI sound effects by JDSherbert.”
- **COSMOS Free Dark Loop Kit** — OliOxen (`https://www.gamedevmarket.net/asset/cosmos-free-dark-loop-kit-25-loops`). GameDev Market Pro Licence permits use in media products and prohibits standalone redistribution; the creator requests credit. Selected loops are under `assets/audio/music/`. Attribution: “COSMOS music by OliOxen.”
- **Shapeforms Audio Free Sounds** — Shapeforms (`https://shapeforms.itch.io/shapeforms-audio-free-sfx`). The creator's Free Sounds license permits commercial and non-commercial project use without required attribution; credit is included here as a courtesy. The two spacecraft engine-loop samples used for the ship profiles are under `assets/audio/sfx/engine/`.

Only selected runtime files are included in the project. Other acquired packs are not included until their exact source terms and any attribution requirements are recorded here.

Do not redistribute the standalone asset packs. Keep the included licenses and these attributions with the project.

## Asset organization

Runtime assets are organized by their project role:

- Player, enemy, and boss ship sheets: `assets/sprites/ships/`
- Projectile resources and their SCI-FI FX sheets: `assets/sprites/projectiles/`
- Active visual effects: `assets/effects/`
- Sound effects: `assets/audio/sfx/`
- Music: `assets/audio/music/`
- HUD and panel textures: `assets/ui/`
- Runtime shaders: `assets/shaders/`
- YARD ship, pilot, and module definitions: `assets/data/`
- Pixelosopher UI fonts: `assets/fonts/pixelosopher/`
- The project uses selected loops from this kit for sector roles, the main menu, pause menu, and run-finished screen.

The remaining project assets are referenced by scenes/resources or loaded through the YARD data registries. Godot `.import` and `.uid` sidecars remain beside active resources. Check each source pack's terms before using or redistributing its assets; some source/license details are unverified, and standalone pack redistribution may be prohibited.
