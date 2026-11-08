-- Checks configured keys and mouse clicks against simulated chat, UI and world hover state.
-- Run from the repo root: lua Tests/Hover.lua
local held, lockdown, notices, calls, frames = {}, false, {}, {}, {}
local foci, cursorX, cursorY, overWorld = {}, 100, 200, true
local cursorDX, cursorDY = 0, 0
local currentChatName, currentChatFrame, currentChatActive, nameplate, keyboardFocus
local units, bindings, mouseButtons = {}, {}, {}
local secret = {}

local function NewFrame(parent)
  local frame = { scripts = {}, events = {}, parent = parent }
  function frame:GetParent() return self.parent end
  function frame:IsShown() return true end
  function frame:IsForbidden() return false end
  function frame:GetName() return self.name end
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  function frame:GetScript(event) return self.scripts[event] end
  function frame:HookScript(event, callback) self.scripts[event] = callback end
  table.insert(frames, frame)
  return frame
end
CreateFrame = function() return NewFrame() end
WorldFrame = NewFrame()
WorldFrame.name = "WorldFrame"
GetMouseFoci = function() return foci end
GetMouseFocus = function() return foci[1] end
WorldFrame.IsMouseOver = function() return overWorld end
GetCursorPosition = function() return cursorX, cursorY end
GetCursorDelta = function() return cursorDX, cursorDY end
GetCurrentKeyBoardFocus = function() return keyboardFocus end
GetBindingAction = function(key) return bindings[key] or "" end
IsMouseButtonDown = function(button) return mouseButtons[button] or false end
CreateKeyChordStringUsingMetaKeyState = function(key)
  local chord = ""
  for _, modifier in ipairs({ "ALT", "CTRL", "SHIFT", "META" }) do
    if held[modifier] then chord = chord .. modifier .. "-" end
  end
  return chord .. key
end
IsShiftKeyDown = function() return held.SHIFT end
IsControlKeyDown = function() return held.CTRL end
IsAltKeyDown = function() return held.ALT end
IsMetaKeyDown = function() return held.META end
IsMacClient = function() return false end
issecretvalue = function(value) return value == secret end
C_AddOns = { GetAddOnMetadata = function() return "Social Shortcuts" end }
C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end }
C_CVar = { GetCVarBool = function() return false end }
EventUtil = { ContinueOnAddOnLoaded = function() end }
UIErrorsFrame = { AddExternalErrorMessage = function(_, message) table.insert(notices, message) end }
tInvert = function(values)
  local inverted = {}
  for key, value in pairs(values) do inverted[value] = key end
  return inverted
end
NONE, WHISPER, PARTY_INVITE, ADD_FRIEND = "None", "Whisper", "Invite", "Add Friend"
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
LE_REALM_RELATION_SAME, LE_PARTY_CATEGORY_HOME = 1, 1
RegionalUniqueNamesEnabled = function() return false end
UnitExists = function(unit) return units[unit] and units[unit].exists ~= false or false end
UnitIsPlayer = function(unit) return units[unit] and units[unit].isPlayer end
UnitIsUnit = function(unit, other)
  return units[unit] and units[other] and units[unit].id == units[other].id or false
end
UnitCanCooperate = function(_, unit) return units[unit] and units[unit].cooperate end
UnitIsFriend = UnitCanCooperate
UnitIsEnemy = function(_, unit) return units[unit] and units[unit].cooperate == false end
UnitInParty = function(unit) return units[unit] and units[unit].party end
UnitInRaid = function(unit) return units[unit] and units[unit].raid end
UnitInAnyGroup = function(unit) return units[unit] and units[unit].grouped end
UnitNameUnmodified = function(unit)
  local data = units[unit]
  if data then return data.name, data.realm end
end
UnitRealmRelationship = function(unit) return units[unit] and units[unit].relation or 1 end
C_Secrets = {
  ShouldUnitIdentityBeSecret = function(unit) return units[unit] and units[unit].secretIdentity or false end,
  CanCompareUnitTokens = function(unit) return not (units[unit] and units[unit].noCompare) end,
  ShouldUnitComparisonBeSecret = function(unit) return units[unit] and units[unit].secretComparison or false end,
}
C_NamePlate = { GetNamePlateForUnit = function(unit) if unit == "mouseover" then return nameplate end end }

local ns = {}
assert(loadfile("Core/Config.lua"))("SocialShortcuts", ns)
assert(loadfile("Core/Names.lua"))("SocialShortcuts", ns)
ns.RunAction = function(action, name, chatFrame, grouped)
  calls[#calls + 1] = { action = action, name = name, chatFrame = chatFrame, grouped = grouped }
end
ns.GetHoveredChatTarget = function() return currentChatName, currentChatFrame, currentChatName ~= nil or currentChatActive end
assert(loadfile("Core/Hover.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end
local function Reset()
  held, lockdown, calls, notices, bindings, mouseButtons = {}, false, {}, {}, {}, {}
  currentChatName, currentChatFrame, currentChatActive, keyboardFocus, nameplate = nil, nil, false, nil, nil
  foci, cursorX, cursorY, overWorld = { WorldFrame }, 100, 200, true
  cursorDX, cursorDY = 0, 0
  units = {
    player = { id = "self", name = "Me", isPlayer = true, cooperate = true },
    mouseover = { id = "hover", name = "Hovered", realm = "OtherRealm", relation = 2, isPlayer = true, cooperate = true },
    target = { id = "target", name = "Selected", isPlayer = true, cooperate = true },
  }
  ns.db = {
    whisper = "CTRL", invite = "ALT", friend = "SHIFT",
    whisperButton = "LeftButton", inviteButton = "LeftButton", friendButton = "LeftButton",
    worldMouseover = true,
  }
end
local function Fire(event, button)
  if event == "GLOBAL_MOUSE_DOWN" then mouseButtons[button] = true end
  if event == "GLOBAL_MOUSE_UP" then mouseButtons[button] = nil end
  for _, frame in ipairs(frames) do
    if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, button) end
  end
end
local function Click(button)
  Fire("GLOBAL_MOUSE_DOWN", button)
  Fire("GLOBAL_MOUSE_UP", button)
end
local function Update()
  for _, frame in ipairs(frames) do
    if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 1 / 60) end
  end
end
local function OneAction(action, name)
  return #calls == 1 and calls[1].action == action and calls[1].name == name
end

Reset()
for _, action in ipairs({ "whisper", "invite", "friend" }) do
  calls = {}
  SocialShortcuts_RunHoveredAction(action)
  Check("the " .. action .. " key uses the world hover without changing target", OneAction(action, "Hovered-OtherRealm"))
end
Reset()
currentChatName, currentChatFrame = "ChatPlayer-Realm", NewFrame()
ns.RunHoveredAction("invite")
Check("chat name hover takes priority over world hover", OneAction("invite", "ChatPlayer-Realm"))
Check("chat hover retains its chat frame", #calls == 1 and calls[1].chatFrame == currentChatFrame)
currentChatName = "NextChatPlayer"
calls = {}
ns.RunHoveredAction("whisper")
Check("a key resolves the current chat name each time", OneAction("whisper", "NextChatPlayer"))
currentChatName, currentChatActive, calls = nil, true, {}
ns.RunHoveredAction("invite")
Check("an invalidated chat hover cannot fall through to a world player", #calls == 0)

Reset()
local row, rowChild = NewFrame(), nil
rowChild = NewFrame(row)
ns.RegisterHoverFrame(row, function(action) ns.RunAction(action, "UIPlayer"); return true end)
foci = { rowChild }
ns.RunHoveredAction("friend")
Check("registered UI rows work through a hovered child", OneAction("friend", "UIPlayer"))
foci, calls = { row }, {}
ns.RunHoveredAction("invite")
Check("registered UI rows work when directly hovered", OneAction("invite", "UIPlayer"))
currentChatName, calls = "ChatPriority", {}
ns.RunHoveredAction("invite")
Check("chat hover takes priority over a registered UI row", OneAction("invite", "ChatPriority"))

Reset()
ns.RunHoveredAction("missing")
ns.RunHoveredAction(nil)
Check("unknown action bindings do nothing", #calls == 0)
lockdown = true
ns.RunHoveredAction("invite")
Check("explicit keybindings respect chat lockdown", #calls == 0)
Reset()
keyboardFocus = NewFrame()
ns.RunHoveredAction("invite")
Check("typing in an edit box does not trigger a hovered-player keybinding", #calls == 0)
Reset()
ns.db.invite = "NONE"
ns.RunHoveredAction("invite")
Check("a native key remains usable when its modifier-click shortcut is disabled", OneAction("invite", "Hovered-OtherRealm"))
Reset()
units.mouseover.grouped = true
ns.RunHoveredAction("invite")
Check("known group membership reaches the invite-or-join action", #calls == 1 and calls[1].grouped == true)
Reset()
units.mouseover.grouped = secret
ns.RunHoveredAction("invite")
Check("secret group membership is omitted from action dispatch", #calls == 1 and calls[1].grouped == nil)
Reset()
ns.db.worldMouseover = false
ns.RunHoveredAction("invite")
held.ALT = true
Click("LeftButton")
Check("the world option disables world key and click actions", #calls == 0)
currentChatName = "ChatStillEnabled"
ns.RunHoveredAction("invite")
Check("the world option leaves chat hover available", OneAction("invite", "ChatStillEnabled"))

local invalidUnits = {
  { "a missing hover", function() units.mouseover = nil end },
  { "an NPC", function() units.mouseover.isPlayer = false end },
  { "the player themselves", function() units.mouseover.id = "self" end },
  { "an enemy", function() units.mouseover.cooperate = false end },
  { "a secret identity", function() units.mouseover.secretIdentity = true end },
  { "an unavailable comparison", function() units.mouseover.noCompare = true end },
  { "a secret comparison", function() units.mouseover.secretComparison = true end },
  { "a secret name", function() units.mouseover.name = secret end },
  { "a secret realm", function() units.mouseover.realm = secret end },
  { "a secret player flag", function() units.mouseover.isPlayer = secret end },
  { "a secret cooperation flag", function() units.mouseover.cooperate = secret end },
  { "an empty name", function() units.mouseover.name = "" end },
}
for _, case in ipairs(invalidUnits) do
  Reset()
  case[2]()
  ns.RunHoveredAction("invite")
  held.ALT = true
  Click("LeftButton")
  Check(case[1] .. " cannot receive world actions", #calls == 0)
end

Reset()
foci = {}
ns.RunHoveredAction("invite")
Check("empty mouse foci can resolve an actual world hover", OneAction("invite", "Hovered-OtherRealm"))
calls, overWorld = {}, false
ns.RunHoveredAction("invite")
Check("empty mouse foci do not imply a world hover", #calls == 0)
Reset()
local overlay = NewFrame()
foci = { overlay, WorldFrame }
ns.RunHoveredAction("invite")
held.ALT = true
Click("LeftButton")
Check("an unknown UI overlay blocks a stale world mouseover", #calls == 0)
Reset()
nameplate = NewFrame(WorldFrame)
nameplate.UnitFrame = NewFrame(nameplate)
nameplate.UnitFrame.unit = "mouseover"
foci = { nameplate.UnitFrame }
ns.RunHoveredAction("invite")
Check("a recognized mouseover nameplate resolves the world player", OneAction("invite", "Hovered-OtherRealm"))

Reset()
held.ALT = true
Click("LeftButton")
Check("a configured modifier click invites the world hover once", OneAction("invite", "Hovered-OtherRealm"))
Reset()
Click("LeftButton")
held.ALT = true
Click("RightButton")
held.CTRL = true
Click("LeftButton")
Check("plain clicks, wrong buttons and extra modifiers do nothing", #calls == 0)
Reset()
ns.db.inviteButton = "Button4"
held.ALT = true
Click("Button4")
Check("the configured extra mouse button works in the world", OneAction("invite", "Hovered-OtherRealm"))
Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
Check("native mouse bindings are identified by the full key combination", ns.IsHoverBinding("LeftButton"))
Check("a different mouse button is not claimed", not ns.IsHoverBinding("Button4"))
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
SocialShortcuts_RunHoveredAction("invite")
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("one native mouse binding does not also run the modifier click", OneAction("invite", "Hovered-OtherRealm"))

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
mouseButtons.LeftButton = true
SocialShortcuts_RunHoveredAction("invite")
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("native dispatch before the global down event is still a single action", OneAction("invite", "Hovered-OtherRealm"))

for _, order in ipairs({ { "Button4", "Button5" }, { "Button5", "Button4" } }) do
  Reset()
  bindings.BUTTON4, bindings.BUTTON5 = "SOCIALSHORTCUTS_INVITE", "SOCIALSHORTCUTS_INVITE"
  Fire("GLOBAL_MOUSE_DOWN", order[1])
  SocialShortcuts_RunHoveredAction("invite")
  Fire("GLOBAL_MOUSE_DOWN", order[2])
  SocialShortcuts_RunHoveredAction("invite")
  Fire("GLOBAL_MOUSE_UP", order[2])
  Fire("GLOBAL_MOUSE_UP", order[1])
  Check("two held native mouse bindings dispatch once each in " .. order[1] .. "-first order", #calls == 2)
end

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
-- A UI OnMouseUp may precede the global up event, but the physical button is already released.
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("UI mouse-up before the global event supplies a consumed native binding", OneAction("invite", "UIPlayer"))
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("two deliberate presses still dispatch two actions", #calls == 2 and calls[2].name == "UIPlayer")

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
SocialShortcuts_RunHoveredAction("invite")
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("native down dispatch and a UI mouse-up fallback share one press", OneAction("invite", "UIPlayer"))

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
SocialShortcuts_RunHoveredAction("invite")
-- The same command can also be bound to a keyboard key pressed while the mouse remains held.
SocialShortcuts_RunHoveredAction("invite")
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("a separate keyboard shortcut still works while its mouse binding is held",
  #calls == 2 and calls[1].name == "UIPlayer" and calls[2].name == "UIPlayer")

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_FRIEND"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Fire("GLOBAL_MOUSE_UP", "LeftButton")
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Check("UI fallback after global mouse-up runs the assigned native action once", OneAction("friend", "UIPlayer"))


Reset()
held.ALT = true
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
held.ALT, held.SHIFT = nil, true
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("changing the modifier during a UI press cannot run a different action", #calls == 0)

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_FRIEND"
Fire("GLOBAL_MOUSE_UP", "LeftButton")
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Check("changing a native mouse assignment during a press cancels its UI fallback", #calls == 0)

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
-- Model a missed global up event, followed by another real click.
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
mouseButtons.LeftButton = nil
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("a new down event recovers after a lost global mouse-up", #calls == 2 and calls[2].name == "UIPlayer")


Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
SocialShortcuts_RunHoveredAction("invite")
mouseButtons.LeftButton = nil
-- The first global up is lost; the next native binding fires before its global down event.
mouseButtons.LeftButton = true
SocialShortcuts_RunHoveredAction("invite")
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("native-before-down remains a single action after a lost global mouse-up", #calls == 2)

Reset()
held.ALT = true
bindings["ALT-BUTTON1"] = "SOCIALSHORTCUTS_INVITE"
foci = { rowChild }
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
SocialShortcuts_RunHoveredAction("invite")
mouseButtons.LeftButton = nil
Update()
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Fire("GLOBAL_MOUSE_UP", "LeftButton")
ns.RunClickAction("LeftButton", function(action) ns.RunAction(action, "UIPlayer") end)
Check("observing a released button clears stale native state before a later UI click", #calls == 2)

Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check("pressing alone does not invite before a possible camera drag", #calls == 0)
cursorX = cursorX + 7
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("a camera drag does not invite", #calls == 0)
Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
cursorX = cursorX + 9
Update()
cursorX = cursorX - 9
Update()
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("dragging away and back before release still cancels the world click", #calls == 0)
Reset()
held.ALT = true
ns.db.inviteButton = "RightButton"
Fire("GLOBAL_MOUSE_DOWN", "RightButton")
Update()
cursorDX = 8
Update()
cursorDX = 0
Fire("GLOBAL_MOUSE_UP", "RightButton")
Check("mouselook motion cancels the click even when the visible cursor is locked", #calls == 0)
Reset()
held.ALT = true
cursorDX = 100
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Update()
cursorDX = 0
Update()
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("mouse movement before the press does not cancel a stationary click", OneAction("invite", "Hovered-OtherRealm"))
Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
units.mouseover.id, units.mouseover.name = "different", "DifferentPlayer"
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("moving to another player before release cancels the click", #calls == 0)
Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
foci = { overlay }
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("moving onto UI before release cancels the world click", #calls == 0)
Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
held.ALT = nil
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("releasing the modifier before the mouse cancels the click", #calls == 0)
Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
held.ALT, held.SHIFT = nil, true
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("changing to another action before release cancels the world click", #calls == 0)
Reset()
held.ALT = true
Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
lockdown = true
Fire("GLOBAL_MOUSE_UP", "LeftButton")
Check("entering lockdown before release cancels the world click", #calls == 0)

print(failures == 0 and "Hover: all checks passed" or ("Hover: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
