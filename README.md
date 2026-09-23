# BindPad (WoW Forever)

BindPad is a keybinding UI for spells, items and macros. Drag anything onto one of its slots, click the slot, and press a key to bind it. You don't need a free action bar slot for it.

This is a re-release of BindPad for **World of Warcraft: Forever** (client 1.60.x, Interface `16001`).

> [!NOTE]
> This is a fork of [BindPad](https://www.curseforge.com/wow/addons/bind-pad) by **Tageshi**, which is maintained by the BindPad team on CurseForge. All credit for the original addon goes to them. This fork only ports it to the WoW Forever client and packages it. Please report problems with this version on this repository's [issue tracker](https://github.com/leehmanQQ/bindpad-forever/issues), not to the original authors.

## Features

- Bind keys to spells, items, macros, mounts, battle pets and equipment sets without putting them on an action bar.
- **BindPad Macros**: create as many virtual macros as you want, without using the limited slots in Blizzard's macro panel.
- **General** slots are shared by all your characters. **Character Specific** slots (three tabs) belong to one character.
- Up to five profiles per character. BindPad remembers which profile goes with which talent group and switches automatically.
- Optionally saves and restores all of Blizzard's key bindings per profile ("Save All Keys").
- Optionally shows BindPad hotkeys on action bar buttons and in tooltips ("Show Hotkeys").

## Installation

1. Download the latest release from [GitHub Releases](https://github.com/leehmanQQ/bindpad-forever/releases). It will also be on CurseForge once that project is published.
2. Extract the `BindPad` folder into your WoW Forever `Interface/AddOns/` folder. During the beta that's `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart the game, or type `/reload`.

## Usage

- `/bindpad` or `/bp` opens or closes the BindPad window. You can also bind a key to **Toggle BindPad** in Blizzard's key bindings menu.
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

The addon source lives in [BindPad/](BindPad/). Lua is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua) using [stylua.toml](stylua.toml). Editor settings are in [.editorconfig](.editorconfig).

```sh
npx @johnnymorganz/stylua-bin BindPad/          # format
npx @johnnymorganz/stylua-bin --check BindPad/  # verify (runs in CI on release)
```

To test in game, symlink or copy `BindPad/` into your `Interface/AddOns/` folder. When the addon runs straight from source, the version shows as `@project-version@`. The packager replaces it at release time.

## Releasing

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) in [.github/workflows/release.yml](.github/workflows/release.yml). To release, push a tag:

```sh
git tag -a 1.0.0 -m "1.0.0"
git push origin 1.0.0
```

The workflow checks formatting, builds `BindPad-<version>-forever.zip`, creates a GitHub release and, once it's configured, uploads the zip to CurseForge. Tags that contain `alpha` or `beta` are uploaded as alpha or beta files.

### CurseForge setup (one-time)

1. Create the project at <https://authors.curseforge.com/#/projects/create/choose-game>. Choose World of Warcraft, then Addon, and mention that it's a fork of BindPad. The project goes through moderation before it's public.
2. Copy the **Project ID** from the "About Project" box on the project page.
3. Create an API token at <https://authors.curseforge.com/#/settings/api-tokens>.
4. In this GitHub repository, go to **Settings → Secrets and variables → Actions** and add:
   - **Variables** tab: `CURSEFORGE_PROJECT_ID` = the project ID
   - **Secrets** tab: `CF_API_KEY` = the API token

Until both are set, the workflow only creates the GitHub release.

## License

The original BindPad doesn't include a license. All rights to the original code belong to its author, Tageshi, and the BindPad team. This fork adds no license of its own.
