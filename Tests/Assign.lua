-- Checks the platform labels, the first load, the Command key and the modifier swap in Core/Config.lua
-- against stubs of the client. Run from the repo root: lua Tests/Assign.lua
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown, IsMetaKeyDown = nil, nil, nil, nil
IsMacClient = function() return true end
tInvert = function(t) local inverted = {} for k, v in pairs(t) do inverted[v] = k end return inverted end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND = "None", "Whisper", "Invite", "Add Friend"
MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK = "Command left click as right click"
YELLOW_FONT_COLOR = { WrapTextInColorCode = function(_, text) return text end }
local onLoaded
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) onLoaded = callback end }
local commandRightClick = true
C_CVar = {
  GetCVarBool = function() return commandRightClick end,
  SetCVar = function(_, value) commandRightClick = value == "1" end,
}

local ns = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

local labels = ns.modifierLabel
Check("macOS names the keys Shift, Control, Option and Command",
  labels.SHIFT == "Shift" and labels.CTRL == "Control" and labels.ALT == "Option" and labels.META == "Command")

Check("Mac defaults: Option whispers, Command invites, Shift adds a friend",
  ns.defaults.whisper == "ALT" and ns.defaults.invite == "META" and ns.defaults.friend == "SHIFT")

Check("Command is taken while the game treats Command-click as a right click", not ns.IsCommandFree())
local lines, realPrint = {}, print
print = function(line) table.insert(lines, line) end
onLoaded()
print = realPrint
Check("the first load on a Mac turns the right-click option off", ns.IsCommandFree() and ns.db.invite == "META")
Check("the first-run line says so, in one line",
  #lines == 1 and lines[1]:find("Turned off Command left click as right click, so Command works as a key.", 1, true))
Check("a second free changes nothing and says nothing", ns.FreeCommandKey() == nil)

IsMacClient = function() return false end
local pc = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", pc)
labels = pc.modifierLabel
Check("Windows names the keys Shift, Ctrl and Alt and offers no Windows key",
  labels.SHIFT == "Shift" and labels.CTRL == "Ctrl" and labels.ALT == "Alt" and labels.META == nil
  and #pc.modifierOrder == 4 and pc.modifierOrder[4] == "ALT")
SocialShortcutsDB = { whisper = "CTRL", invite = "ALT", friend = "META", join = "NONE" }
onLoaded()
Check("a saved Windows key binding falls back to the default", pc.db.friend == "SHIFT")
Check("a setting the addon no longer has is dropped", pc.db.join == nil)
Check("a missing toggle starts on", pc.db.askToJoin == true)
SocialShortcutsDB = { whisper = "CTRL", invite = "ALT", friend = "SHIFT", askToJoin = false }
onLoaded()
Check("a saved toggle off stays off", pc.db.askToJoin == false)
commandRightClick = true
Check("Windows never reads or changes the Mac option", pc.IsCommandFree() and pc.FreeCommandKey() == nil and commandRightClick)
Check("Windows defaults: Ctrl whispers, Alt invites, Shift adds a friend",
  pc.defaults.whisper == "CTRL" and pc.defaults.invite == "ALT" and pc.defaults.friend == "SHIFT")

ns.db = { whisper = "CTRL", invite = "META", friend = "ALT" }
ns.AssignModifier("whisper", "ALT")
Check("taking a used key swaps the two", ns.db.whisper == "ALT" and ns.db.friend == "CTRL" and ns.db.invite == "META")
ns.AssignModifier("invite", "NONE")
Check("None frees a key without touching the others", ns.db.invite == "NONE" and ns.db.whisper == "ALT" and ns.db.friend == "CTRL")
ns.AssignModifier("friend", "NONE")
Check("two actions can both be off", ns.db.invite == "NONE" and ns.db.friend == "NONE")
ns.AssignModifier("whisper", "SHIFT")
Check("a free key moves without a swap",
  ns.db.whisper == "SHIFT" and ns.db.invite == "NONE" and ns.db.friend == "NONE")
ns.AssignModifier("whisper", "SHIFT")
Check("the same key again changes nothing", ns.db.whisper == "SHIFT")

print(failures == 0 and "Assign: all checks passed" or ("Assign: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
