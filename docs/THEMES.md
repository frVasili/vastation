# Make a theme

A **theme** changes how the launcher looks and sounds: colours, name, boot logo, sounds and tile pictures.
A theme is just a folder. Everything inside it is optional. Anything you leave out is taken
from the `default` theme, so you can start small.

## Folder layout

```
my-theme/
  theme.json          colours, names (all optional)
  wordmark.png        a picture instead of the text logo at boot (optional)
  sounds/             your own sounds (optional)
    nav.wav  tab.wav  select.wav  back.wav  error.wav  launch.wav  boot.wav  ambient.wav
  art/                logos and covers by name (optional)
    steam.png  kodi.svg  ...
```

Put the folder in one of these places. The first one that has the file wins:

1. `<wolf data folder>/vastation/user/themes/my-theme/` (your own, survives updates; this is the one to use)
2. `themes/my-theme/` next to the launcher program
3. `themes/my-theme/` inside the project (when running from source)

The folder name is the theme's id. A theme needs a `theme.json` to show up in the list.

## theme.json

Every field is optional.

| Field | What it does |
|---|---|
| `name` | The name shown in Settings. |
| `system_name` | The big word at boot and in About. Default `VAStation`. |
| `tagline` | The small line under it at boot. |
| `use_logos` | `false` shows big letters instead of app logos. Default `true`. |
| `palette` | Colours, see below. Written as `"#rrggbb"`. |

Palette colours:

| Key | Used for |
|---|---|
| `void` | The darkest background colour (top of the screen, boot sky). |
| `deep` | The other end of the background gradient, panels, fog in the boot scene. |
| `accent` | The main colour: panels, glow, boot light from below. Tile colours are blended with it. |
| `highlight` | The bright colour: glow frame around the selected tile, lit edges, boot light. |
| `text` | All text. |

### Full example: Ember (warm and orange)

Save as `.../themes/ember/theme.json`:

```json
{
  "name": "Ember",
  "palette": {
    "void": "#0c0403",
    "deep": "#3a1008",
    "accent": "#ff5a2b",
    "highlight": "#ffd08a",
    "text": "#fff6ee"
  }
}
```

That is the whole theme. It has no sounds or pictures of its own, so it uses the default ones.

## Sounds

Put files in `sounds/`. Use `.wav` or `.ogg`. Stereo, 44.1 kHz, 16 bit is a safe choice for WAV.

| File | When it plays | Good length |
|---|---|---|
| `nav.wav` | Moving between tiles | 0.1 to 0.3 s |
| `tab.wav` | Changing row (category) | 0.2 to 0.4 s |
| `select.wav` | Pressing a tile or setting | 0.2 to 0.4 s |
| `back.wav` | Going back, returning to the launcher | 0.2 to 0.4 s |
| `error.wav` | Something failed | 0.4 to 0.8 s |
| `launch.wav` | An app is starting | 1 to 2 s |
| `boot.wav` | Boot animation | about 6.5 to 7 s. The logo appears at **4.2 s**, put your big moment there. |
| `ambient.wav` | Quiet music behind the home screen | 30 s or more. It repeats, so make the end join the start smoothly. |

Keep them quiet and short. People hear them hundreds of times.

## Pictures (art)

Put pictures in `art/`. The file name is the name a tile uses. The built-in tiles use these names:
`steam`, `prism` (Minecraft), `lutris`, `retroarch`, `esde`, `kodi`, `firefox` (Internet), `xfce` (Desktop).
Add a file with the same name in your theme (`art/steam.png`) and your picture replaces the default one.
PNG, JPG, WebP and SVG work. Logos look best as a transparent PNG or an SVG, about 600 x 600 pixels.

Your own tiles can use theme art too (see `TILES.md`).

## The boot logo picture

Put `wordmark.png` in the theme folder. It is shown instead of the text name during boot.
It is shrunk to fit inside 70% of the screen width and 22% of the screen height, so a
transparent PNG about 1600 x 400 pixels works well. The tagline stays under it.

## Choosing a theme

- On the launcher: **System > Settings > Theme**. Press left or right. It changes at once.
- Or start the launcher with `VASTATION_THEME=ember` set. This wins over the Settings choice.

## Testing on a PC

You need Godot 4.7.2 and the project files.

1. Put your theme folder under `launcher/themes/`.
2. Run `tools/shots.sh /tmp/shots` (add `VASTATION_THEME=my-theme` in front to start with your theme).
3. Open the pictures in `/tmp/shots`. They show the boot, home and menus. Shots 14 and 15 show the Ember theme.

Check that text is readable on your colours, and that the glow frame stands out.

## Please note: other companies' material

Logos, music and pictures from games or brands belong to their owners. A theme that contains
such material should stay in a private place (your own user folder). Do **not** send it to the public repository.
Only share themes made of your own work or material you are allowed to share.

## Troubleshooting

- **My theme is not in the Settings list.** It needs a `theme.json` (even just `{}`) and the right folder.
  Restart the launcher after adding a new folder.
- **A colour does nothing.** Check the spelling: `void`, `deep`, `accent`, `highlight`, `text`. The value must look
  like `"#ff5a2b"`. A bad colour is skipped and a line `[theme] bad colour ...` goes to the log.
- **No sound from my file.** Use `.wav` or `.ogg`, with the exact names from the table above.
- **The old logos still show.** A name must match exactly, for example `steam.png`, and be in `art/`.
  If both `steam.png` and `steam.svg` exist in the same place, `.png` is used first.
- **The wordmark looks tiny.** The picture has a lot of empty space around it. Crop it.
