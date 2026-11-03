# SocialShortcuts

Whispers, invites or befriends a player on a modifier-click of their name. Features, defaults and restrictions are in `README.md`.

## Target

- No API probes.
- `main` holds the Forever version. `1.15.x-backup` keeps the only commit with Era code.

## Layout

- Toc order is the dependency order: `Core/Config.lua` (bindings, secret guard), `Core/Names.lua`, `Core/Actions.lua`, `Core/Hooks.lua` (click surfaces), `UI/Options.lua`. No embedded libraries.

## Rules

- `ns.PickAction` returns nothing while `C_ChatInfo.InChatMessagingLockdown()` is true. Every click surface asks it before reading a name. A bound click there shows `<Title> are off here.` through `UIErrorsFrame:AddExternalErrorMessage`. The chat whisper check asks `ns.HeldAction` before the gate, so Blizzard's own whisper never gets that notice.
- Notices go through `UIErrorsFrame:AddExternalErrorMessage`, never chat. There are two: the lockdown notice and the Group Finder one.
- Group Finder Invite runs the function `LFGBrowseUtil_GetInviteActionForResult` returns, Blizzard's own eligibility check. Without one it shows `Invite isn't available for this listing.`
- Group Finder browse entry rows keep their XML `OnClick`. Only divider rows call `SetScript`. A switch to a ScrollBox click hook on `LFGBrowseFrame.ScrollBox` must skip frames without `resultID`.
- Unit frames check `C_Secrets.CanCompareUnitTokens` and `C_Secrets.ShouldUnitComparisonBeSecret` before `UnitIsUnit`. They check `C_Secrets.ShouldUnitIdentityBeSecret` before `UnitNameUnmodified`.
- Secret checks go through `ns.CanAccess`, which wraps `issecretvalue` in `pcall`.
- Build unit names with `ns.UnitFullName`, never `GetUnitName`, which ignores its second argument on Forever.
- Whispers go only through `ChatFrameUtil.SendTell` and `ChatFrameUtil.SendBNetTell`, the calls Blizzard's own buttons make. On a chat name, whisper acts only on the CHATLINK modifier, because Blizzard whispers on every other left click.
- The addon writes no chat state: no whisper tabs, backlog copies, edit box fields or `ACTIVE_CHAT_EDIT_BOX`. So it never closes Blizzard's whisper box.
- Hook Blizzard code only with `HookScript`, `hooksecurefunc` and ScrollBox callbacks owned by `ns`. No protected calls. Hooks install at file load, through `EventUtil.ContinueOnAddOnLoaded` for Blizzard addons, never at login.
- Chat names go through one `SetItemRef` post-hook that reads `player:` and `playerCommunity:` links.
- Compact unit frames are hooked only when set up with `DefaultCompactUnitFrameSetup`, so nameplates and pet frames are never touched. The raid container stores that function at load, so its frames are also taken from `frameUpdateList.normal` after each `GetUnitFrame`. That keeps them hooked when another addon hooks the global.
- Battle.net friend rows take Whisper and Invite only.
- Settings are an own canvas page through `Settings.RegisterCanvasLayoutCategory`: three `WowStyle1DropdownTemplate` dropdowns over `ns.db` and a Defaults button, placed with the header and row metrics of Blizzard's settings list.
- Own-frame dropdowns stay clean, unlike Blizzard's list dropdowns. The trade-off: the settings search does not find the rows.
- Taking a modifier another action uses swaps the two, in `ns.AssignModifier`.
- Action labels are Blizzard's unit menu strings (`WHISPER`, `PARTY_INVITE`, `ADD_FRIEND`) and the opt-out is `NONE`.
- Windows defaults are Ctrl, Alt and Shift. Never default to the Windows key.
- The only chat line outside errors is the first-run hint, printed once per account when `SocialShortcutsDB` is new.
- `ns.title` reads the toc Title. It names the settings category, the compartment tooltip and the chat prefix, so the name is never a literal.
- Chat lines go through `ns.Print`.
- Left out on purpose: a notice about the Chat Shortcuts WeakAura, shortcuts on raid-container target frames (`DefaultCompactMiniFrameSetup`), Ignore and Guild Invite actions, a notice on blocked unit frames and a Shift tooltip.

## Checks

- Run `lua Tests/Assign.lua`, `lua Tests/PickAction.lua` and `lua Tests/Hooks.lua` after a change. They cover the modifier swap, the lockdown gate and its notice, the raid container hook, the Group Finder invite and the chat whisper order only.
- Turn on `/console taintLog 1` as well before testing in game.

## Release

- `.pkgmeta` leaves out `CLAUDE.md` and `Tests`. The repo has no `Tools` folder.
