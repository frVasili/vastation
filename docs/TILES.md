# Add your own tiles and images

A **tile** is one square (or tall, or wide) picture on the launcher's home screen.
Pressing it starts an app or a game. You can add tiles, hide the ones you do not want,
and change their order. You do this by writing one small text file. You do not need to rebuild anything.

## Where the files go

Everything lives in the **user folder** on the server:

```
<wolf data folder>/vastation/user/
```

The Wolf data folder is the one that holds `cfg/config.toml`. The installer creates the user folder for you.
Inside it you can have:

| Name | What it is |
|---|---|
| `tiles.json` | Your tiles and changes. This is the main file. |
| `art/` | Your pictures (logos and covers). |
| `themes/` | Your own themes. See `THEMES.md`. |

**Changes apply the next time the launcher starts.** Easiest way: in the launcher choose
System > End Session, then connect again from Moonlight.

## The smallest tiles.json

This adds one tile called "Chess" to the Games row. It starts the Wolf app named "Firefox".

```json
{
  "tiles": [
    {
      "id": "chess",
      "title": "Chess",
      "category": "games",
      "launch": { "type": "wolf_app", "profile": "user", "app": "Firefox" }
    }
  ]
}
```

1. Open (or create) `tiles.json` in the user folder.
2. Paste the text above.
3. Save. Restart the launcher (see above).
4. Look at the Games row. "Chess" is at the end. It shows a big letter "C" because it has no picture yet.

Careful with commas: every item in a list needs a comma **between** items, but not after the last one.
If you make a mistake, the launcher still starts. It skips the broken part and shows a short note
in the top right corner, like `tiles.json: tile chess: category 'gmes' does not exist`.

## Every field of a tile

| Field | Needed? | What it does |
|---|---|---|
| `id` | yes | A short name nobody else uses. Only small letters, digits, `-` and `_`. Example: `heroic`. |
| `title` | yes | The big name shown under the tile. |
| `subtitle` | no | The smaller line under the name. |
| `category` | yes | Which row it is in: `games`, `emulation`, `media`, `system`, or a category you added. |
| `art.logo` | no | A logo shown in the middle of the tile. A file name without the ending, for example `"heroic"`. |
| `art.cover` | no | A picture that fills the whole tile. Use this instead of a logo for game covers. |
| `art.accent` | no | Two colours for the tile glass, dark first: `["#16345c", "#2f7fd6"]`. The whole screen glows in these colours when the tile is selected. |
| `art.shape` | no | `"square"` (default), `"cover"` (tall) or `"banner"` (wide). |
| `launch` | yes | What happens when you press it. See the three types below. |

**Picture sizes** (bigger is fine, the launcher shrinks it; PNG, JPG, WebP and SVG all work):

| Shape | Size in pixels |
|---|---|
| square | 600 x 600 |
| cover | 600 x 900 |
| banner | 1280 x 720 |

**Where to put pictures.** Put the file in the `art/` folder inside the user folder, for example
`art/heroic.png`. Then write `"logo": "heroic"`. You can also write a path from the user folder,
for example `"cover": "art/covers/doom.jpg"`.
A tile without a picture shows a big letter. That is fine.

## The three launch types

### 1. wolf_app: an app that is already in Wolf

Use the app's **title exactly as written in Wolf's config** (`config.toml`, the `title = "..."` line).

```json
{
  "id": "browser2",
  "title": "Web",
  "subtitle": "Firefox",
  "category": "media",
  "art": { "logo": "firefox", "accent": ["#4a1a5c", "#ff7139"] },
  "launch": { "type": "wolf_app", "profile": "user", "app": "Firefox" }
}
```

### 2. wolf_runner: any Docker image, even if Wolf does not know it

"Docker image" means a ready-made app package. This example starts the Heroic Games Launcher.
It is set up the same way Games on Whales sets up its own apps.

```json
{
  "id": "heroic",
  "title": "Heroic",
  "subtitle": "Epic, GOG and Amazon games",
  "category": "games",
  "art": { "accent": ["#1a2a4a", "#4a8bff"] },
  "launch": {
    "type": "wolf_runner",
    "runner": {
      "name": "WolfHeroic",
      "image": "ghcr.io/games-on-whales/heroic-games-launcher:edge",
      "env": [
        "RUN_SWAY=true",
        "GOW_REQUIRED_DEVICES=/dev/input/* /dev/dri/* /dev/nvidia*"
      ],
      "mounts": [],
      "devices": [],
      "ports": [],
      "base_create_json": "{\"HostConfig\": {\"IpcMode\": \"host\", \"CapAdd\": [\"SYS_ADMIN\", \"SYS_NICE\", \"SYS_PTRACE\", \"NET_RAW\", \"MKNOD\", \"NET_ADMIN\"], \"SecurityOpt\": [\"seccomp=unconfined\", \"apparmor=unconfined\"], \"Ulimits\": [{\"Name\": \"nofile\", \"Hard\": 10240, \"Soft\": 10240}], \"Privileged\": false, \"DeviceCgroupRules\": [\"c 13:* rmw\", \"c 244:* rmw\"]}}"
    }
  }
}
```

What the parts mean:

- `image`: the package to download. The first start can take several minutes.
- `env`: settings given to the app, written as `"NAME=value"`.
- `name`: Wolf keeps the app's own files (logins, settings, games) in a folder with this name inside
  its data folder (`profile-data/user/<name>`), so they are still there next time. Do not change it later.
- `mounts`: extra folders shared with the app, `"folder on the server:folder in the app:rw"`, for example
  a games drive. Usually empty.
- `devices`, `ports`: usually empty.
- `base_create_json`: technical rights for the container, copied from how Games on Whales apps are defined.
  Copy it as it is. It must stay on one line, with `\"` for every quote.

### 3. A "game tile": an existing app with extra settings

Add `env` to a `wolf_app` tile to hand settings to the app. This opens Steam straight into
Team Fortress 2 (Steam game number 440):

```json
{
  "id": "tf2",
  "title": "Team Fortress 2",
  "category": "games",
  "art": { "cover": "art/tf2.jpg", "shape": "cover" },
  "launch": {
    "type": "wolf_app",
    "profile": "user",
    "app": "Steam",
    "env": ["STEAM_STARTUP_FLAGS=-bigpicture -applaunch 440"]
  }
}
```

The Steam game number is in the store address: `store.steampowered.com/app/440`.
This tile shares your Steam login with the normal Steam tile.

## Hide, reorder, new rows

All of these can sit in the same `tiles.json`, next to `"tiles"`.

**Hide built-in tiles** (use their `id`: steam, minecraft, lutris, retroarch, esde, kodi, internet, desktop, settings, power):

```json
{ "hide": ["kodi", "esde"] }
```

**Change the order.** Tiles you list come first, in your order. The rest follow in their usual order.

```json
{ "order": { "games": ["minecraft", "steam"] } }
```

**Add a row (category).** Then use its `id` in your tiles.

```json
{
  "categories": [ { "id": "extras", "title": "Extras" } ],
  "tiles": [
    { "id": "radio", "title": "Radio", "category": "extras",
      "launch": { "type": "wolf_app", "profile": "user", "app": "Firefox" } }
  ]
}
```

**Replace a built-in tile.** Give your tile the same `id` as the built-in one.
Your version is used instead. A new `id` is added at the end of its row.
A category with an existing `id` is just renamed.

## Troubleshooting

- **Nothing changed.** Restart the launcher (System > End Session, then reconnect). It reads the file only at start.
- **A note appears in the top right.** It tells you the first problem in `tiles.json`.
  The launcher skipped that tile. Fix it and restart.
- **No tiles from my file at all, and the note says "not valid JSON".** A comma, quote or bracket is wrong.
  Paste the file into any "JSON checker" web page to find the spot.
- **The tile shows a letter, not my picture.** The file name or place is wrong. The picture must be in
  `art/` and the name must match (capital letters count). Try the full path: `"logo": "art/heroic.png"`.
- **The tile starts but fails with an error.** For `wolf_app`, check the app title matches Wolf's config exactly.
  For `wolf_runner`, check the image name and that the server can download it.
- **I cannot find the user folder.** It is the `vastation/user` folder inside Wolf's data folder
  (the folder where `cfg/config.toml` lives).
