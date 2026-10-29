# Branding

The project's mark: Godot's robot and Shandalar's magic as one disc, with
the five colours of Magic set around the rim.

| File | Use |
|---|---|
| `logo.png` | 1254×1254 master. Start here for anything new. |
| `logo-360.png` | The README's badge, so the page does not fetch 1.5 MB to draw one image. |
| `screenshots/duel-spell-chain.png`, `screenshots/main-menu.png`, `screenshots/deck-builder.png`, `screenshots/adventure-world.png`, `screenshots/adventure-dungeon.png` | The README's screenshots: 1280×800, with the optional original-game skin and card pictures, 256-colour PNGs. The first two keep their names because the 0.20.0 release notes link them. |
| `../game/icon.png` | 256×256, the program icon — `application/config/icon` in `project.godot`, which Godot draws in the editor, on the window and in the taskbar. It lives under `game/` because it ships inside the `.pck`: it is ours, not 1997 art, and it has to be there for a player who has imported nothing. |

GitHub's **social preview** (the card shown when a link to the repo is
shared) cannot be set from the API or the CLI — it is web-only. Upload
`logo.png` at **Settings → General → Social preview**.
