# Changelog

## [1.1.0](https://github.com/dna113p/SocialShortcuts/compare/v1.0.0...v1.1.0) (2026-11-08)


### Features

* add configurable world and chat mouseover controls ([bdeac2a](https://github.com/dna113p/SocialShortcuts/commit/bdeac2a0f2acfcdb10a5f858993cf898a3b11779))
* configure modifier and mouse button for each shortcut ([15cfef4](https://github.com/dna113p/SocialShortcuts/commit/15cfef4b8d8d236473b3aff43e6242a46323c30e))

## 1.1.0-dj.1 — mouseover fork


- Add configurable world/nameplate modifier-clicks for Invite, Whisper, and Add Friend.
- Add native WoW hover keybindings for chat names, player frames, supported lists, and world players.
- Allow each action to choose its modifier and Left, Right, Middle, Mouse 4, or Mouse 5 button.
- Preserve existing saved controls while adding a World Mouseover toggle and complete-shortcut conflict swaps.
- Reject world actions through unrelated UI or after a detected camera drag, and coordinate native/click dispatch.
- Add behavioral regression tests and Lua 5.1/5.4 CI. Live-client verification remains necessary.


## 1.0.0 (2026-11-06)


### Features

* Invite asks to join a grouped player while you are alone, and suggests the player to your leader when you can't invite ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))
* Invite Asks to Join setting to turn off asking to join ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))
* On the Mac the first load turns off Command left click as right click, so Command works as a key ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))
* Shortcut clicks on chat names run only the shortcut and no longer open a whisper ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))
* Starting keys follow reach from WASD: Option whispers, Command invites and Shift adds a friend on the Mac ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))


### Bug Fixes

* Settings rows have the same spacing as the game's own settings ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))
* Windows no longer offers the Windows key, which opens the Start menu ([889fb68](https://github.com/miyankooo/SocialShortcuts/commit/889fb681cc0a33b66d100b9bdbd315d2a70b70d8))
