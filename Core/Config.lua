local addonName, ns = ...

ns.title = C_AddOns.GetAddOnMetadata(addonName, "Title")

-- The client offers exactly four modifier predicates, so a binding stores the physical modifier and the
-- platform only decides what it is called: META is Command on macOS, ALT is Option. Detecting the platform
-- here keeps every other file free of Mac branches. META stays tested on Windows too, so a click with the
-- Windows key held never counts as a plain Ctrl, Alt or Shift click.
local modifierTests = {
  SHIFT = IsShiftKeyDown,
  CTRL = IsControlKeyDown,
  ALT = IsAltKeyDown,
  META = IsMetaKeyDown,
}

local isMac = IsMacClient()

local macLabels = { NONE = NONE, SHIFT = "Shift", CTRL = "Control", ALT = "Option", META = "Command" }
local pcLabels = { NONE = NONE, SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt" }

-- Fixed order so the dropdowns read the same every session, with the opt-out first. Windows leaves out its
-- fourth key, because the Windows key opens the Start menu over the game and no game option blocks it. A
-- saved Windows key binding is then unknown and falls back to the default in LoadSettings.
ns.modifierOrder = { "NONE", "SHIFT", "CTRL", "ALT" }
if isMac then table.insert(ns.modifierOrder, "META") end
ns.modifierLabel = isMac and macLabels or pcLabels

local knownTokens = tInvert(ns.modifierOrder)

ns.mouseButtonOrder = { "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5" }
ns.mouseButtonLabel = {
  LeftButton = "Left click",
  RightButton = "Right click",
  MiddleButton = "Middle click",
  Button4 = "Mouse button 4",
  Button5 = "Mouse button 5",
}
local knownButtons = tInvert(ns.mouseButtonOrder)

-- Labels are the strings Blizzard's own unit menu shows for the same actions (UnitPopupSharedButtonMixins.lua).
-- The verb completes the first-run hint.
ns.actions = {
  { key = "whisper", label = WHISPER, verb = "whisper", help = "Open a whisper to the clicked player." },
  { key = "invite", label = PARTY_INVITE, verb = "invite", help = "Invite the clicked player to your group." },
  { key = "friend", label = ADD_FRIEND, verb = "add as a friend", help = "Add the clicked player to your friends list." },
}
local knownActions = {}
for _, action in ipairs(ns.actions) do knownActions[action.key] = true end

-- Defaults follow reach from a hand on WASD: Invite, used most, gets the key next to the space bar, and
-- Whisper the next easiest. Shift goes to Add Friend, because a Shift-click on a chat name also runs the
-- game's own insert-name or /who, which does no harm there. The options panel reads these too, so its
-- Defaults button restores the same values.
ns.defaults = {
  whisper = isMac and "ALT" or "CTRL",
  invite = isMac and "META" or "ALT",
  friend = "SHIFT",
  whisperButton = "LeftButton",
  inviteButton = "LeftButton",
  friendButton = "LeftButton",
  askToJoin = true,
  worldMouseover = true,
}

-- The Mac client can turn Command-left-click into a right click
-- (Blizzard_SettingsDefinitions_Shared/Mac.lua). That translation changes the configured mouse button, so
-- Command works as a predictable shortcut modifier only while that option is off.
local COMMAND_RIGHT_CLICK = "MacUseCommandLeftClickAsRightClick"

function ns.IsCommandFree()
  return not isMac or not C_CVar.GetCVarBool(COMMAND_RIGHT_CLICK)
end

-- The Mac defaults bind Command, so the first load and the Defaults button turn the option off. After that
-- the game's own checkbox decides, and the settings grey Command out while it is on. Returns the note for
-- the chat line when it had to change the option, so the user learns why Command-click stopped
-- right-clicking. The write is a plain C_CVar call: Blizzard's settings panel picks up script CVar changes
-- through securecallfunction (Blizzard_SettingsPanel.lua), so its own state never runs under addon taint.
function ns.FreeCommandKey()
  if ns.IsCommandFree() then return nil end

  C_CVar.SetCVar(COMMAND_RIGHT_CLICK, "0")
  return "Turned off " .. MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK .. ", so Command works as a key."
end

-- A few secrets outlive the chat lockdown: chat lines kept from restricted content, and unit names under
-- identity restrictions. issecretvalue is declared SecretArguments = "AllowedWhenUntainted"; whether the
-- flag makes it raise for addon code is unsettled, since Blizzard's own chat filter wrapper calls
-- canaccessvalue under captured addon taint (ChatFrameFilters.lua). pcall answers right either way,
-- because a raise means secret, and nil never reaches the predicate.
function ns.CanAccess(value)
  if value == nil then return true end

  local ok, secret = pcall(issecretvalue, value)
  return ok and not secret
end

-- Modules read this lazily, so it is safe that it stays empty until ADDON_LOADED.
ns.db = {}

-- The chat prefix every addon of this set shares, in Blizzard's own colour object rather than a hex code.
function ns.Print(message)
  print(YELLOW_FONT_COLOR:WrapTextInColorCode("[" .. ns.title .. "]:") .. " " .. message)
end

-- Exactly one modifier has to be held. Requiring the rest to be up stops one chord from matching two
-- bindings, and makes an assignment mean the same thing no matter which modifier it is.
local function HeldModifier()
  local held
  for token, IsDown in pairs(modifierTests) do
    if IsDown() then
      if held then return nil end
      held = token
    end
  end
  return held
end

local function MouseButton(actionKey)
  return ns.db[actionKey .. "Button"] or ns.defaults[actionKey .. "Button"]
end

-- Only the complete modifier and mouse-button combination is exclusive. Taking another action's shortcut
-- swaps both parts, preserving the displaced action's shortcut rather than silently disabling it.
local function AssignShortcut(actionKey, token, button)
  if not knownActions[actionKey] or not knownTokens[token] or not knownButtons[button] then return false end

  local previousToken = ns.db[actionKey]
  local previousButton = MouseButton(actionKey)
  if previousToken == token and previousButton == button then return false end
  if token ~= "NONE" then
    for _, action in ipairs(ns.actions) do
      if action.key ~= actionKey and ns.db[action.key] == token and MouseButton(action.key) == button then
        ns.db[action.key] = previousToken
        ns.db[action.key .. "Button"] = previousButton
      end
    end
  end
  ns.db[actionKey] = token
  ns.db[actionKey .. "Button"] = button
  return true
end

function ns.AssignModifier(actionKey, token)
  if not knownActions[actionKey] then return false end
  return AssignShortcut(actionKey, token, MouseButton(actionKey))
end

function ns.AssignMouseButton(actionKey, button)
  if not knownActions[actionKey] then return false end
  return AssignShortcut(actionKey, ns.db[actionKey], button)
end

-- Without a button this is a non-consuming modifier lookup for hover detection. Actual clicks supply
-- their button so actions may share a modifier without matching the same click.
function ns.HeldAction(button)
  if button and not knownButtons[button] then return nil end
  local held = HeldModifier()
  if not held then return nil end

  for _, action in ipairs(ns.actions) do
    if ns.db[action.key] == held and (not button or MouseButton(action.key) == button) then return action.key end
  end
end

-- Inside restricted content the client hands player names, chat links and listing leaders out as secret
-- values. Addon code can neither inspect a secret name nor pass one on: InviteUnit, RequestInviteFromUnit
-- and AddFriend are declared SecretArguments = "AllowedWhenUntainted", so a tainted caller handing them a
-- secret raises. Every click surface asks this first, and the lockdown question takes no argument, so it
-- answers before any surface reads a name. A bound click there says so in Blizzard's red error text,
-- because the default click that runs instead would look like the shortcut misfired.
function ns.CanRunAction(action)
  if not knownActions[action] then return false end
  if C_ChatInfo.InChatMessagingLockdown() then
    UIErrorsFrame:AddExternalErrorMessage(ns.title .. " are off here.")
    return false
  end
  return true
end

function ns.PickAction(button)
  -- A mouse button assigned through WoW's native keybindings is dispatched by the hover binding handler.
  -- Letting a frame's modifier-click handler dispatch it too would send the same action twice.
  if button and ns.IsHoverBinding and ns.IsHoverBinding(button) then return nil end
  local action = ns.HeldAction(button)
  if ns.CanRunAction(action) then return action end
end

-- The addon has no visible surface of its own, so the first load on an account names the keys once. A
-- changed game option rides on the same line.
local function PrintFirstRunHint(note)
  local bindings = {}
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then
      table.insert(bindings, ns.modifierLabel[token] .. " + " .. ns.mouseButtonLabel[MouseButton(action.key)]
        .. " to " .. action.verb)
    end
  end
  local hint = "Player shortcuts: " .. table.concat(bindings, ", ")
    .. ". Type /ssc to change shortcuts and find mouseover keybindings."
  ns.Print(note and hint .. " " .. note or hint)
end

-- A token the dropdowns do not offer would bind nothing and leave its dropdown blank, so an unknown or
-- missing value falls back to the default. A toggle keeps any saved true or false. Keys of settings the
-- addon no longer has are dropped.
local function LoadSettings()
  local firstRun = type(SocialShortcutsDB) ~= "table"
  if firstRun then SocialShortcutsDB = {} end

  for key in pairs(SocialShortcutsDB) do
    if ns.defaults[key] == nil then SocialShortcutsDB[key] = nil end
  end
  for key, value in pairs(ns.defaults) do
    local saved = SocialShortcutsDB[key]
    local valid
    if type(value) == "boolean" then
      valid = type(saved) == "boolean"
    elseif knownActions[key] then
      valid = knownTokens[saved]
    else
      valid = knownButtons[saved]
    end
    if not valid then SocialShortcutsDB[key] = value end
  end
  ns.db = SocialShortcutsDB

  -- Old settings had no button fields. They migrate to left click above. If a manually edited or repaired
  -- profile contains duplicate combinations, preserve the first and disable the duplicate click shortcut.
  local used = {}
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then
      local combination = token .. ":" .. MouseButton(action.key)
      if used[combination] then ns.db[action.key] = "NONE" else used[combination] = true end
    end
  end

  if firstRun then PrintFirstRunHint(ns.FreeCommandKey()) end
end

EventUtil.ContinueOnAddOnLoaded(addonName, LoadSettings)
