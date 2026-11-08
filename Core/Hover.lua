local _, ns = ...

-- Native bindings use the same actions as modifier-clicks. Leaving them unassigned preserves the
-- player's existing keys; WoW saves assignments in the selected account/character binding profile.
BINDING_HEADER_SOCIALSHORTCUTS = ns.title
BINDING_NAME_SOCIALSHORTCUTS_WHISPER = "Whisper hovered player"
BINDING_NAME_SOCIALSHORTCUTS_INVITE = "Invite hovered player"
BINDING_NAME_SOCIALSHORTCUTS_FRIEND = "Add hovered player as a friend"

local bindingActions = {
  SOCIALSHORTCUTS_WHISPER = "whisper",
  SOCIALSHORTCUTS_INVITE = "invite",
  SOCIALSHORTCUTS_FRIEND = "friend",
}
local buttonKeys = {
  LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3",
  Button4 = "BUTTON4", Button5 = "BUTTON5",
}
local hoverFrames = setmetatable({}, { __mode = "k" })
local mousePresses = {}

function ns.GetHoverBindingAction(button)
  local key = buttonKeys[button]
  if not key then return nil end
  return bindingActions[GetBindingAction(CreateKeyChordStringUsingMetaKeyState(key), true)]
end

function ns.IsHoverBinding(button)
  return ns.GetHoverBindingAction(button) ~= nil
end

-- Resolvers read the current pooled row at invocation, rather than retaining an old player's name.
function ns.RegisterHoverFrame(frame, handler)
  if frame then hoverFrames[frame] = handler end
end

local function TopFocus()
  local foci = GetMouseFoci()
  return foci and foci[1]
end

local function IsForbidden(frame)
  return frame and frame.IsForbidden and frame:IsForbidden()
end

local function HoverHandler(focus)
  for _ = 1, 20 do
    if not focus or focus == WorldFrame or IsForbidden(focus) then return nil end
    if hoverFrames[focus] then return hoverFrames[focus] end
    focus = focus.GetParent and focus:GetParent()
  end
end

-- Only clear world focus or the current player's actual nameplate is accepted. An unrelated UI frame
-- can leave a stale mouseover token behind; it must never allow a click through to that player.
local function IsWorldFocus(focus)
  if focus == WorldFrame then return true end
  if not focus then return WorldFrame:IsMouseOver() end
  if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return false end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "mouseover")
  if not ok or not plate then return false end
  for _ = 1, 20 do
    if focus == plate then return true end
    if not focus or focus == WorldFrame or IsForbidden(focus) then return false end
    focus = focus.GetParent and focus:GetParent()
  end
  return false
end

local function PlayerName(unit)
  if C_Secrets.ShouldUnitIdentityBeSecret(unit) then return nil end
  local player = UnitIsPlayer(unit)
  if not ns.CanAccess(player) or not player then return nil end
  if not C_Secrets.CanCompareUnitTokens(unit, "player") then return nil end
  if C_Secrets.ShouldUnitComparisonBeSecret(unit, "player") then return nil end
  local same = UnitIsUnit(unit, "player")
  local friendly = UnitCanCooperate("player", unit)
  if not ns.CanAccess(same) or same or not ns.CanAccess(friendly) or not friendly then return nil end
  return ns.UnitFullName(unit)
end

function ns.RunUnitAction(action, unit)
  if not ns.CanRunAction(action) then return false end
  local name = PlayerName(unit)
  if not name then return false end
  local grouped = UnitInAnyGroup(unit, LE_PARTY_CATEGORY_HOME)
  if not ns.CanAccess(grouped) then grouped = nil end
  ns.RunAction(action, name, nil, grouped)
  return true
end

local function RunHovered(action)
  if ns.GetHoveredChatTarget then
    local name, chatFrame, active = ns.GetHoveredChatTarget()
    if active then
      if name then ns.RunAction(action, name, chatFrame) end
      return name ~= nil
    end
  end
  local focus = TopFocus()
  local handler = HoverHandler(focus)
  if handler then return handler(action) ~= false end
  if ns.db.worldMouseover and IsWorldFocus(focus) then return ns.RunUnitAction(action, "mouseover") end
  return false
end

local function NewPress(button)
  local press = { phase = "down", handled = false }
  mousePresses[button] = press
  return press
end

-- Native mouse bindings may run before the global down event, or a clickable UI may consume them.
-- Both paths share a physical press record, not a timer: an actual second click is never throttled.
function ns.RunHoveredAction(action)
  if not ns.CanRunAction(action) then return false end
  if GetCurrentKeyBoardFocus() then return false end
  local heldPresses = {}
  for button in pairs(buttonKeys) do
    if IsMouseButtonDown(button) and ns.GetHoverBindingAction(button) == action then
      local press = mousePresses[button]
      if not press or press.phase ~= "down" then
        press = NewPress(button)
      end
      -- All held matching buttons are covered: a second mouse binding for the same action must not
      -- leave one pending fallback behind. Native keyboard presses themselves always remain usable.
      table.insert(heldPresses, press)
    end
  end
  local ran = RunHovered(action)
  if ran then
    for _, press in ipairs(heldPresses) do
      press.handled = true
      press.awaitingGlobalDown = true
    end
  end
  return ran
end

SocialShortcuts_RunHoveredAction = ns.RunHoveredAction

function ns.RunClickAction(button, handler)
  local press = mousePresses[button]
  if press and press.handled then return false end
  local action = ns.GetHoverBindingAction(button)
  if action then
    if not ns.CanRunAction(action) then return false end
  else
    action = ns.PickAction(button)
  end
  if not action then return false end
  if press and press.captured and action ~= press.action then return false end
  local ran = handler(action) ~= false
  if ran then
    if not press then
      press = NewPress(button)
      press.phase = "up"
    end
    press.handled = true
  end
  return ran
end

local input = CreateFrame("Frame")
input:RegisterEvent("GLOBAL_MOUSE_DOWN")
input:RegisterEvent("GLOBAL_MOUSE_UP")
input:SetScript("OnUpdate", function()
  local x, y = GetCursorPosition()
  local dx, dy = GetCursorDelta()
  for button, press in pairs(mousePresses) do
    -- Input events are synchronous. Preserve an early native callback through that dispatch, not across
    -- subsequent frames when a lost mouse-up or game focus change could otherwise retain stale state.
    press.awaitingGlobalDown = nil
    if press.phase == "down" then
      if not IsMouseButtonDown(button) then
        press.phase = "up"
      elseif press.name and not press.handled then
        local distance = math.sqrt((x - press.lastX) ^ 2 + (y - press.lastY) ^ 2)
        -- Skip the first raw delta, which can contain movement from before the button was pressed.
        -- Later deltas also catch mouselook while the visible cursor is locked/recentered.
        if press.sampled then distance = math.max(distance, math.sqrt(dx ^ 2 + dy ^ 2)) end
        press.travel = press.travel + distance
        press.dragged = press.dragged or press.travel > 6
        press.lastX, press.lastY, press.sampled = x, y, true
      end
    end
  end
end)
input:SetScript("OnEvent", function(_, event, button)
  if not buttonKeys[button] then return end
  if event == "GLOBAL_MOUSE_DOWN" then
    local press = mousePresses[button]
    -- Preserve a native action that ran earlier during this same mouse-down dispatch.
    if press and press.phase == "down" and press.awaitingGlobalDown then
      press.awaitingGlobalDown = nil
    else
      press = NewPress(button)
    end
    press.action = ns.GetHoverBindingAction(button) or ns.HeldAction(button)
    press.captured = true
    if not press.action or not ns.db.worldMouseover or C_ChatInfo.InChatMessagingLockdown()
      or not IsWorldFocus(TopFocus()) then return end
    press.name = PlayerName("mouseover")
    press.x, press.y = GetCursorPosition()
    press.lastX, press.lastY, press.travel = press.x, press.y, 0
    press.sampled, press.dragged = false, false
    return
  end

  local press = mousePresses[button]
  if not press then return end
  -- Retain the handled flag through the rest of mouse-up: UI scripts may run on either side of this event.
  press.phase = "up"
  press.awaitingGlobalDown = nil
  if press.handled or press.dragged or not press.name or not ns.db.worldMouseover
    or not IsWorldFocus(TopFocus()) then return end
  local x, y = GetCursorPosition()
  if (x - press.x) ^ 2 + (y - press.y) ^ 2 > 36 then return end
  local action = ns.GetHoverBindingAction(button) or ns.HeldAction(button)
  if action ~= press.action or not ns.CanRunAction(action) or PlayerName("mouseover") ~= press.name then return end
  ns.RunClickAction(button, function(selected) return ns.RunUnitAction(selected, "mouseover") end)
end)
