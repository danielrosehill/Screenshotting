---
name: screenshot
description: "Take a screenshot on Linux from the CLI: full screen, monitor, select area, active window, delayed. Flameshot by default."
---

# Screenshot

## Just run the script

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/screenshot.sh" <mode> [output_path] [--clipboard]
```

| Mode | Captures | Needs the user? |
|---|---|---|
| `full` | Whole desktop, all monitors | No |
| `monitor` | Monitor under the cursor | No |
| `region` | Dragged selection, captured on release | Yes |
| `annotate` | Dragged selection, then Flameshot's drawing toolbar | Yes |
| `geom:WxH+X+Y` | Fixed rectangle | No |
| `window` | Active window | No |
| `delay:N` | Whole desktop after N seconds | No |

The default output is `~/Pictures/Screenshots/<ISO-timestamp>.png`. The script prints the path on success. `--clipboard` also copies the image.

`SCREENSHOT_DELAY=N` adds a delay to any mode, which gives the user time to focus a window. `SCREENSHOT_BACKEND` forces a backend.

Exit 1 means no backend or an unsupported mode. Exit 2 means nothing was captured, usually a cancelled selection: report that and do not retry.

## Backends

Flameshot is the default because it has the better CLI: it runs on GNOME, KDE and X11, writes raw PNG to stdout, and annotates during capture. It has no active-window mode, so `window` uses Spectacle or gnome-screenshot.

Selection order for everything else: Flameshot, Spectacle, grim (wlroots Wayland), gnome-screenshot.

## Direct commands

| Task | Flameshot | Spectacle | grim |
|---|---|---|---|
| Full | `flameshot full -r > out.png` | `spectacle -b -n -f -o out.png` | `grim out.png` |
| Monitor | `flameshot screen -r > out.png` | `spectacle -b -n -m -o out.png` | `grim -o <name> out.png` |
| Select area | `flameshot gui -s -r > out.png` | `spectacle -b -n -r -o out.png` | `grim -g "$(slurp)" out.png` |
| Active window | none | `spectacle -b -n -a -o out.png` | none |
| Window under cursor | none | `spectacle -b -n -u -o out.png` | none |
| Delay | `-d <milliseconds>` | `-d <milliseconds>` | `sleep` first |

## Notes

- In `window` mode the active window is often the terminal running this agent. Use `SCREENSHOT_DELAY=5` and tell the user to focus the target window.
- Spectacle window captures include the window shadow, so the image can be larger than the screen.
- `flameshot full --region` hung with no output on v13.3.0 under KDE Wayland (2026-11-07), so `geom:` captures the full screen and crops it with ImageMagick.
- Headless sessions cannot capture: report that and stop.
