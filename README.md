<img src="https://raw.githubusercontent.com/miyankooo/SocialShortcuts/main/.github/icon.png" width="64" height="64" alt="">

# Social Shortcuts — configurable mouseover fork

Invite, whisper, or add a friend directly from a character in the world, a nameplate, a chat name, or a player frame in WoW Forever. This fork of [miyankooo/SocialShortcuts](https://github.com/miyankooo/SocialShortcuts) adds world mouseover, configurable mouse buttons, and normal WoW hover keybindings.

## Quick start

1. Install the release ZIP's `SocialShortcuts` folder in the Forever client's `Interface/AddOns` directory, replacing the original addon. The folder must contain `SocialShortcuts.toc` directly. Use this fork instead of loading a second copy alongside the original.
2. Restart WoW, or `/reload` when replacing an already installed copy.
3. **Alt + left-click a friendly player in the world to invite them** on Windows. The same shortcut works on chat names, unit frames, and supported player lists. World mouseover starts enabled.
4. Type **`/ssc`** to choose each action's modifier and mouse button, or turn off world mouseover.
5. For **hover + press a key**, open **Options → Keybindings → AddOns → Social Shortcuts** and bind *Invite hovered player*, *Whisper hovered player*, or *Add hovered player as a friend*. These bindings start unassigned. For example, bind Invite to an unused keyboard key and press it while hovering a chat name or a character.

## Controls

| Action | Windows starting shortcut | macOS starting shortcut |
| --- | --- | --- |
| Invite | Alt + left-click | Command + left-click |
| Whisper | Ctrl + left-click | Option + left-click |
| Add Friend | Shift + left-click | Shift + left-click |

In `/ssc`, every action can use Left, Right, Middle, Mouse 4, or Mouse 5 with its selected modifier. **None** turns off that action's modifier-click shortcut; it does not remove a separately assigned native hover keybinding. Actions may share a modifier when they use different mouse buttons. Assigning a shortcut already used by another action swaps the two complete shortcuts.

The native WoW keybinding screen supports the game's keyboard and mouse-button bindings, including modifier combinations. A native mouse binding takes precedence over a matching addon modifier-click and is dispatched only once per click. WoW saves native bindings using its account or character binding profile; `/ssc` settings are saved account-wide. The `/ssc` Defaults button restores the click controls and toggles, leaving native WoW bindings alone.

Keyboard hover shortcuts prefer the current chat name, then the hovered player frame or list row, then a friendly character or nameplate in the world. They never fall back to your selected target. The World Mouseover toggle controls world/nameplate clicks and hover bindings together; chat and other UI shortcuts continue working when it is off.

## Features

- Whisper, Invite and Add Friend, each with configurable mouse controls and an optional hover keybinding.
- Works on friendly characters and nameplates, chat names, target/focus/party/raid frames, the friends list, Who list, guild roster, and Group Finder.
- Battle.net friends get a Battle.net whisper, and Invite reaches the character they play.
- Inviting into a full party offers to convert it to a raid.
- Invite works like the game's own menu entry: it invites when you can, suggests the player to your leader when you are in a group without lead, and asks to join when you are alone and they are in a group. Turn off asking to join with Invite Asks to Join in the settings.

## Behavior and limits

The shortcuts are off in dungeons, raids and PvP matches, where the game hides player names.

In chat, a configured shortcut click runs its action without opening an extra whisper. An unassigned click keeps its normal behavior. The default Shift + left-click still inserts the name or runs `/who`, as well as the configured Add Friend action. Outside chat, native targeting and context-menu behavior is retained; choosing Right click can also open the game's usual menu.

World modifier-clicks require pressing and releasing over the same friendly player, without a detected drag beyond six screen pixels. NPCs, yourself, hostile players, hidden identities, and unrelated UI overlays are ignored. Native hover bindings act immediately on the key press. Nameplates are resolved through the game's existing mouseover unit; the addon does not change protected nameplate frames.

The fork retains the original addon folder and saved-variable name so existing settings migrate. It omits the upstream CurseForge project ID to keep this fork from identifying itself as the original CurseForge release. Install updates from this fork's releases.

## Verification

Run the behavioral tests and Lua syntax checks from the repository root:

```sh
sh Tools/verify.sh
# Or select a Lua executable:
SOCIAL_SHORTCUTS_LUA=lua5.1 sh Tools/verify.sh
```

CI runs the same checks with Lua 5.1 and 5.4. The tests cover settings migration and conflicts, current chat/link identity, pooled UI rows, world click/drag handling, restricted identities, and native/click dispatch ordering. They use simulated game APIs; an in-game check is still needed for actual UI event delivery and protected-client behavior.

Build an installable archive with `python3 Tools/package.py 1.1.0-dj.1`. It includes the native bindings and every runtime file named by the TOC, substitutes the version, and excludes tests and development tools.
