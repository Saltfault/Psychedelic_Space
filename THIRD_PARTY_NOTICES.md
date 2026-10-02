# Third-party notices and rights audit

The root [LICENSE](LICENSE) applies to original project code only. It does not relicense bundled
art, fonts, or addons. Preserve upstream license text with redistributed components where
required. This inventory records evidence available in this checkout; unknown terms are marked
unknown rather than inferred.

The Godot Engine license and bundled third-party copyright inventory are included as
[GODOT_LICENSE.txt](GODOT_LICENSE.txt) and [GODOT_COPYRIGHT.txt](GODOT_COPYRIGHT.txt), copied
from the installed Godot 4.7.2 distribution. Keep both with desktop distributions built using
the engine.

## Project assets

| Component | Author/source | License or terms | Required notice / status |
|---|---|---|---|
| Engine flame strip | Dolkyns; `assets/licenses/engine_flames_license.txt` | Custom terms permit commercial game use and in-game distribution; standalone redistribution/resale is prohibited | Credit optional. Local license retained. |
| Warped Shooting FX projectile art | Luis Zuno (ansimuz); [creator asset page](https://ansimuz.itch.io/warped-shooting-fx) | CC0 1.0 Universal, stated on the creator's asset page | Attribution optional; local license PDF retained. |
| Super Pixel Effects explosion | Will Tice / unTied Games; local terms refer to `http://untiedgames.com/files/license.txt` | Custom terms allow commercial/noncommercial game use; standalone pack redistribution is prohibited | Attribution required: `Pixel Art Assets - Will Tice / unTied Games` (or the pack-title form listed in the local terms). |
| Pixelosopher font | Filip Uzunov / Helianthus Games; [creator page](https://helianthus-games.itch.io/pixelosopher) | SIL Open Font License 1.1; local OFL text retained | Include copyright and OFL notice with font redistribution; reserved font name applies to modified versions. |
| Planet Icons Pack [16x16px] | Helianthus Games / Filip Uzunov; [creator page](https://helianthus-games.itch.io/pixelart-planets-16x16) | Included custom license permits personal and commercial derivative projects and modifications; standalone redistribution prohibited | Attribution is not required. `Tech.png` and `Tech2.png` are used for station and outpost markers. Preserve the source license with the asset pack. |
| Shoot'em Up player, enemy, and boss sheets | Archive `Shoot'em Up.rar`; creator/source is not present in the archive | **Unverified** | Do not publish or commercially distribute until the original source and grant are confirmed. Local warning retained. |
| Warp portal sheet | Creator/source details are not present in the project records | **Unverified** | Do not redistribute until rights and attribution are confirmed. The portal sheet is not currently referenced by project scenes. |
| Animated world-object sheet | SteelSoldier, [Top Down Sci-fi Tileset](https://steelsoldier.itch.io/top-down-sci-fi-tileset) | Creator permits commercial and non-commercial projects with credit and a link to the asset page | Credit SteelSoldier and link the asset page if this sheet is used or redistributed. No scene/resource use found by the project reference scan. |
| Planetary Megapack | Croatz, [creator's asset page](https://croatz.itch.io/planetary-megapack) | Creator permits commercial and non-commercial project use; resale or redistribution of the asset pack itself is prohibited | Project use is permitted. Do not resell or redistribute the source pack. Not currently included in this project's assets. |
| Sci-Fi Turret Sprite Pack | Felmir Productions, [creator's asset page](https://felmir-productions.itch.io/sci-fi-turret-sprite-pack) | Creator permits use in any project, including commercial projects; attribution is optional but appreciated | Credit is optional. The pack is mentioned as optional guide content and is not currently included in this project's assets. |
| Pixel Spaceship Megapack | Guardian, [creator's asset page](https://guardian5.itch.io/spaceship-megapack) | Personal and commercial use/editing allowed; redistribution as an asset or asset pack prohibited | Credit appreciated, not required. Selected atlases are copied under `assets/sprites/ships/guardian5/`. |
| PIPOYA FREE VFX HEX Shield | Pipoya, [creator's asset page](https://pipoya.itch.io/pipoya-free-vfx-hex-shield) | Personal/commercial production use and editing allowed; resale/redistribution of the assets prohibited | Attribution not required. Selected shield sheets are under `assets/effects/ram_shield/`. |
| 3D Planet Generator | Naejimer, [creator's page](https://naejimer.itch.io/godot-3d-planet-generator) and [Godot Asset Library listing](https://godotengine.org/asset-library/asset/1615) | MIT | Attribution appreciated, not required. Sample resources are in `addons/naejimer_3d_planet_generator/`; this folder is not enabled as an editor plugin. Preserve upstream MIT text with the sample. |
| Kosmik Kode, Vol. 2 and Vol. 3 | Psychic Rink / Shoffur, [Vol. 2](https://psychicrink.itch.io/kosmik-kode-vol-2), [Vol. 3](https://psychicrink.itch.io/kosmik-kode-vol-3) | CC BY 4.0, as stated on each creator product page | Attribution required. Include “Kosmik Kode sound effects by Shoffur / Psychic Rink, CC BY 4.0.” Selected clips are copied under `assets/audio/sfx/`. |
| Sci-Fi UI SFX Pack | JDSherbert, [creator's asset page](https://jdsherbert.itch.io/sci-fi-ui-sfx-pack) | See the pack's included `LICENSE.pdf`; creator's page confirms the credit requirement | Credit “JDSherbert” in the credits roll or a text file included with the game. Selected menu clips are under `assets/audio/sfx/`. |
| COSMOS Free Dark Loop Kit | OliOxen, [GameDev Market listing](https://www.gamedevmarket.net/asset/cosmos-free-dark-loop-kit-25-loops) | GameDev Market Pro Licence: use in media products is permitted; standalone asset/derivative redistribution is prohibited | Creator requests credit: “COSMOS music by OliOxen.” Selected loops are under `assets/audio/music/`. |
| Neon Skirmish sampler | Original author and source URL could not be verified; the downloaded archive contains its own license file | Internal terms allow game use and prohibit standalone asset-pack redistribution; no external source was verified | Retain the archive's license file with the source pack. Do not publish or commercially distribute these selected sounds until the creator/source record is confirmed. Selected sounds are under `assets/audio/sfx/`. |

## Bundled addons and fonts

| Addon/component | Author or organization | Source | License/status |
|---|---|---|---|
| GDQuest GDScript formatter | GDQuest | `addons/GDQuest_GDScript_formatter` | MIT; upstream notice is present locally. |
| Godit | Michal Rychtar | `addons/godit` | MIT; upstream notice is present locally. |
| Godoban | Jael Gonzalez | `addons/godoban` | MIT; upstream notice is present locally. Bundled Geist font is SIL OFL 1.1; `addons/godoban/fonts/OFL.txt` is present. |
| Godot AI | Godot AI contributors | `addons/godot_ai` | MIT; upstream notice is present locally. |
| Lit | Shawn Deprey / Fading Lantern Games | `addons/lit` | MIT; upstream notice is present locally. |
| Log.gd | Russell Matney | [upstream repository](https://github.com/russmatney/log.gd) | MIT; upstream notice is present locally. |
| Project Time Tracker | Yuri Sizov / Fifut | `addons/project-time-tracker` | MIT; upstream notice is present locally. |
| Quill IDE | Silver Demon Studios | `addons/quill-ide` | MIT; upstream notice is present locally. |
| Terminal | Poing Studios | `addons/terminal` | MIT; upstream notice is present locally. |
| YARD | Elliot Fontaine | [upstream repository](https://github.com/elliotfontaine/yard-godot) | MIT; upstream notice is present locally. |
| Developer Console | Nathan “jitspoe” Wulf and contributors | [upstream repository](https://github.com/jitspoe/godot-console) | Upstream `LICENSE.md` is titled “MIT No Attribution” and identifies copyright © 2025 Nathan “jitspoe” Wulf and contributors. The bundled folder has no local license copy; retain this source/terms record with distributions. |
| Inspector Tabs | PiCode | [upstream repository](https://github.com/PiCode9560/Godot-Inspector-Tabs) | Upstream identifies MIT; license text is not present in this checkout. Include the applicable upstream notice before redistribution. |

MIT-licensed items above have their upstream license files in their addon folders except where
explicitly called out. The project's MIT license is not a substitute for missing upstream
notices. Godot itself is MIT-licensed; follow the engine's official [license compliance guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html) when preparing a distributed build.
