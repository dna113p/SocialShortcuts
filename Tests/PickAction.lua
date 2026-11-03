-- Checks the lockdown gate and its notice in Core/Config.lua against stubs of the client. Run from the repo
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
ns.db = { whisper = "CTRL", invite = "META", friend = "ALT" }

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

Check("no modifier picks nothing", ns.PickAction() == nil)
held.CTRL = true
Check("a bound modifier picks its action", ns.PickAction() == "whisper")
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

print(failures == 0 and "PickAction: all checks passed" or ("PickAction: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
