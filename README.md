# BindPad (WoW Forever)

BindPad is a keybinding UI for spells, items and macros. Drag anything onto one of its slots, click the slot, and press a key to bind it. You don't need a free action bar slot for it.

This is a re-release of BindPad for **World of Warcraft: Forever** (client 1.60.x, Interface `16001`).

> [!NOTE]
> This is a fork of [BindPad](https://www.curseforge.com/wow/addons/bind-pad) by **Tageshi**, which is maintained by the BindPad team on CurseForge. All credit for the original addon goes to them. This fork only ports it to the WoW Forever client and packages it. Please report problems with this version on this repository's [issue tracker](https://github.com/leehmanQQ/bindpad-forever/issues), not to the original authors.

## Features

- Bind keys to spells, items, macros, mounts, battle pets and equipment sets without putting them on an action bar.
- **BindPad Macros**: create as many virtual macros as you want, without using the limited slots in Blizzard's macro panel. Names and icons are picked with the same icon selector as Blizzard's macro panel.
- **General** slots are shared by all your characters. **Character Specific** slots (three tabs) belong to one character. Tick **For all characters** on a General slot's key binding to carry that key over to your other characters.
- Up to five profiles per character. BindPad remembers which profile goes with which talent group (shown with the talent tree you spent the most points in) and switches automatically.
- Optionally saves and restores all of Blizzard's key bindings per profile ("Save All Keys").
- Optionally shows BindPad hotkeys on action bar buttons and in tooltips ("Show Hotkeys").
- Listed in the minimap's addon compartment menu.

## Installation

1. Install it from [CurseForge](https://www.curseforge.com/wow/addons/bindpad-forever), or download the latest release from [GitHub Releases](https://github.com/leehmanQQ/bindpad-forever/releases).
2. Extract the `BindPad` folder into your WoW Forever `Interface/AddOns/` folder. During the beta that's `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart the game, or type `/reload`.

## Usage

- `/bindpad` or `/bp` opens or closes the BindPad window. You can also use the minimap's addon compartment menu, or bind a key to **Toggle BindPad** in Blizzard's key bindings menu.
- Drag a spell, item or macro onto an empty slot. Click the slot and press a key to bind it.
- Click the small red **+** to create a BindPad Macro. Right-click a spell, item or macro slot to convert it into a BindPad Macro.
- Drag a slot to move it, or Shift-click it to pick it up. Right-click to clear an icon from the cursor.

Slash commands:

| Command | Description |
| --- | --- |
| `/bp` | Toggle the BindPad window |
| `/bp list` | List saved character profiles |
| `/bp delete Realm_Character` | Delete another character's profiles |
| `/bp copyfrom Realm_Character` | Copy profiles from another character |

The complete original user guide is in [BindPad/readme.txt](BindPad/readme.txt).

## Development

The addon source lives in [BindPad/](BindPad/). Lua is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) using [stylua.toml](stylua.toml) and linted with [luacheck](https://github.com/lunarmodules/luacheck) using [.luacheckrc](.luacheckrc). Editor settings are in [.editorconfig](.editorconfig). Both checks run in CI on every push and pull request, and again before each release.

```sh
npx @johnnymorganz/stylua-bin BindPad/          # format
npx @johnnymorganz/stylua-bin --check BindPad/  # verify formatting
docker run --rm -v "$PWD":/data -w /data ghcr.io/lunarmodules/luacheck:v1.2.0 BindPad  # lint
```

User-facing strings live in [BindPad/Localization.lua](BindPad/Localization.lua) as one English table. Translations only list the keys they change; anything missing falls back to English. When a new global is needed (a Blizzard API, or a new function referenced from XML), add it to `.luacheckrc`.

To test in game, symlink or copy `BindPad/` into your `Interface/AddOns/` folder. When the addon runs straight from source, the version shows as `@project-version@`. The packager replaces it at release time.

## Releasing

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) in [.github/workflows/release.yml](.github/workflows/release.yml). To release, push a tag:

```sh
git tag -a 1.0.0 -m "1.0.0"
git push origin 1.0.0
```

The workflow checks formatting, builds `BindPad-<version>-forever.zip`, creates a GitHub release and uploads the zip to [CurseForge](https://www.curseforge.com/wow/addons/bindpad-forever). Tags that contain `alpha` or `beta` are uploaded as alpha or beta files.

The CurseForge project ID (1709144) is set in [BindPad/BindPad.toc](BindPad/BindPad.toc) as `X-Curse-Project-ID`. The upload needs a `CF_API_KEY` repository secret containing a token from <https://authors.curseforge.com/#/settings/api-tokens>.

## License

The original BindPad doesn't include a license. All rights to the original code belong to its author, Tageshi, and the BindPad team. This fork adds no license of its own.
