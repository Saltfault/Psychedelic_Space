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
| Shoot'em Up player, enemy, and boss sheets | Archive `Shoot'em Up.rar`; creator/source is not present in the archive | **Unverified** | Do not publish or commercially distribute until the original source and grant are confirmed. Local warning retained. |
| Warp portal sheet | `Downloads/Portal.zip`; creator/source is not present in the archive | **Unverified** | Do not redistribute until rights and attribution are confirmed. Local warning retained. The sheet is not yet wired into the campaign. |
| Animated world-object sheet | SteelSoldier, [Top Down Sci-fi Tileset](https://steelsoldier.itch.io/top-down-sci-fi-tileset) | Creator permits commercial and non-commercial projects with credit and a link to the asset page | Credit SteelSoldier and link the asset page if this sheet is used or redistributed. No scene/resource use found by the project reference scan. |
| Planetary Megapack | Croatz, [creator's asset page](https://croatz.itch.io/planetary-megapack) | Creator permits commercial and non-commercial project use; resale or redistribution of the asset pack itself is prohibited | Project use is permitted. Do not resell or redistribute the source pack. Not currently included in this project's assets. |
| Sci-Fi Turret Sprite Pack | Felmir Productions, [creator's asset page](https://felmir-productions.itch.io/sci-fi-turret-sprite-pack) | Creator permits use in any project, including commercial projects; attribution is optional but appreciated | Credit is optional. The pack is mentioned as optional guide content and is not currently included in this project's assets. |

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
