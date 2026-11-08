-- Checks exact click combinations, native bindings and the lockdown gate against stubs of the client. Run from the repo
-- root: lua Tests/PickAction.lua
local held, lockdown, notices = {}, false, {}
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
IsShiftKeyDown = function() return held.SHIFT end
IsControlKeyDown = function() return held.CTRL end
IsAltKeyDown = function() return held.ALT end
IsMetaKeyDown = function() return held.META end
IsMacClient = function() return true end
tInvert = function(t) local inverted = {} for k, v in pairs(t) do inverted[v] = k end return inverted end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND = "None", "Whisper", "Invite", "Add Friend"
EventUtil = { ContinueOnAddOnLoaded = function() end }
C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end }
UIErrorsFrame = { AddExternalErrorMessage = function(_, message) table.insert(notices, message) end }

local ns = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)
ns.db = { whisper = "CTRL", invite = "META", friend = "ALT",
  whisperButton = "LeftButton", inviteButton = "Button4", friendButton = "RightButton" }

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

Check("no modifier picks nothing", ns.PickAction() == nil)
held.CTRL = true
Check("a bound modifier picks its action", ns.PickAction() == "whisper")
Check("an exact modifier and button picks its action", ns.PickAction("LeftButton") == "whisper")
Check("a different or unsupported button picks nothing", ns.PickAction("RightButton") == nil and ns.PickAction("Button6") == nil)
held.CTRL, held.META = nil, true
Check("extra mouse buttons dispatch their configured action", ns.PickAction("Button4") == "invite")
held.META, held.CTRL = nil, true
ns.db.invite = "CTRL"
Check("one modifier supports separate actions on different buttons",
  ns.PickAction("LeftButton") == "whisper" and ns.PickAction("Button4") == "invite")
Check("the buttonless hover lookup returns the first matching modifier", ns.HeldAction() == "whisper")
ns.db.invite = "META"
ns.IsHoverBinding = function(button) return button == "LeftButton" end
Check("a native hover mouse binding suppresses the duplicate click action", ns.PickAction("LeftButton") == nil)
Check("native binding suppression leaves the hover lookup intact", ns.HeldAction("LeftButton") == "whisper" and ns.PickAction() == "whisper")
ns.IsHoverBinding = nil
lockdown = true
Check("lockdown picks nothing", ns.PickAction() == nil)
Check("lockdown shows the notice", #notices == 1 and notices[1] == "Social Shortcuts are off here.")
Check("the held action ignores lockdown", ns.HeldAction() == "whisper")
held.CTRL = nil
ns.PickAction()
held.SHIFT = true
ns.PickAction()
held.SHIFT, held.CTRL = nil, nil
held.ALT, held.META = true, true
ns.PickAction()
Check("a plain, unbound or two-key click in lockdown shows no notice", #notices == 1)
held.ALT, held.META = nil, nil
Check("unknown explicit actions are rejected without a notice", not ns.CanRunAction("missing") and not ns.CanRunAction(nil) and #notices == 1)
Check("explicit keybinding actions respect the same lockdown gate", not ns.CanRunAction("invite") and #notices == 2)
held.CTRL = true
ns.PickAction("RightButton")
Check("an unmatched button in lockdown shows no notice", #notices == 2)
ns.IsHoverBinding = function() return true end
ns.PickAction("LeftButton")
Check("native binding dispatch remains responsible for its own lockdown notice", #notices == 2)
ns.IsHoverBinding = nil
lockdown = false
held.CTRL = nil
ns.db.invite = "NONE"
Check("native keybindings can run without a modifier and with a disabled click shortcut", ns.CanRunAction("invite") == true)
Check("None never creates an unmodified mouse shortcut", ns.PickAction("Button4") == nil)
held.SHIFT, held.META = true, true
ns.db.friend = "SHIFT"
Check("extra modifiers never match a single-modifier shortcut", ns.PickAction("RightButton") == nil)

print(failures == 0 and "PickAction: all checks passed" or ("PickAction: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
