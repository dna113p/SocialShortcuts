local _, ns = ...

local categoryID
local dropdowns = {}
local askToJoinCheckbox

local askToJoin = {
  label = "Invite Asks to Join",
  help = "While you are alone, Invite asks to join a player who is already in a group.",
}

-- The page is its own canvas, not Blizzard's settings list. Picking in a list dropdown runs the addon's
-- option code inside Blizzard's pooled controls, and on build 70532 that taints Blizzard's own settings
-- until /reload (nameplate errors, 2026-10-21). A dropdown on the addon's own frame stays clean.
-- Header, row and spacing metrics copy Blizzard_SettingsList.xml, Blizzard_SettingsList.lua and
-- Blizzard_SettingControls.xml.
local ROW_HEIGHT = 26
local ROW_SPACING = 9
local FIRST_ROW_Y = -64

-- A swap can change another row, and its menu is closed, so a refresh of its selection text is enough.
local function RefreshDropdowns()
  for _, dropdown in pairs(dropdowns) do dropdown:Update() end
end

local function ShowHelp(owner, entry)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip_SetTitle(GameTooltip, entry.label)
  GameTooltip_AddNormalLine(GameTooltip, entry.help)
  GameTooltip:Show()
end

-- One settings row with its label, and the entry's help on hover.
local function AddRow(panel, index, entry)
  local y = FIRST_ROW_Y - (index - 1) * (ROW_HEIGHT + ROW_SPACING)
  local row = CreateFrame("Frame", nil, panel)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, y)
  row:SetPoint("TOPRIGHT", 0, y)
  row:EnableMouse(true)
  row:SetScript("OnEnter", function() ShowHelp(row, entry) end)
  row:SetScript("OnLeave", GameTooltip_Hide)

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetJustifyH("LEFT")
  label:SetPoint("LEFT", 37, 0)
  label:SetPoint("RIGHT", row, "CENTER", -85, 0)
  label:SetText(entry.label)
  return row
end

local function AddActionRow(panel, action, index)
  local row = AddRow(panel, index, action)

  local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
  dropdown:SetWidth(220)
  dropdown:SetPoint("LEFT", row, "CENTER", -40, 0)
  dropdown:HookScript("OnEnter", function() ShowHelp(dropdown, action) end)
  dropdown:HookScript("OnLeave", GameTooltip_Hide)
  dropdown:SetupMenu(function(_, rootDescription)
    for _, token in ipairs(ns.modifierOrder) do
      local radio = rootDescription:CreateRadio(ns.modifierLabel[token],
        function() return ns.db[action.key] == token end,
        function()
          ns.AssignModifier(action.key, token)
          RefreshDropdowns()
        end)

      -- The menu is rebuilt on every open, so the game option is read fresh. Disabled with an error line, the
      -- way Blizzard's dungeon finder greys out a choice (LFDFrame.lua).
      if token == "META" and not ns.IsCommandFree() then
        radio:SetEnabled(false)
        radio:SetTooltip(function(tooltip)
          GameTooltip_SetTitle(tooltip, ns.modifierLabel.META)
          GameTooltip_AddErrorLine(tooltip, "Turn off " .. MAC_USE_COMMAND_LEFT_CLICK_AS_RIGHT_CLICK .. " in "
            .. MAC_SETTINGS_LABEL .. " to use Command.")
        end)
      end
    end
  end)

  -- Generated once here, because the frame is hidden until the panel shows it.
  dropdown:GenerateMenu()
  dropdowns[action.key] = dropdown
end

-- The checkbox and its offsets are the ones Blizzard's settings list builds for a checkbox row
-- (SettingsCheckboxControlMixin), placed on the addon's own canvas for the same taint reason as the
-- dropdowns. Init wires the click to its own callback registry, the way the list control listens to it.
local function AddAskToJoinRow(panel, index)
  local row = AddRow(panel, index, askToJoin)

  local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckboxTemplate")
  checkbox:SetPoint("LEFT", row, "CENTER", -80, 0)
  checkbox:Init(ns.db.askToJoin, function()
    GameTooltip_SetTitle(SettingsTooltip, askToJoin.label)
    GameTooltip_AddNormalLine(SettingsTooltip, askToJoin.help)
  end)
  checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, checked)
    ns.db.askToJoin = checked
  end, row)
  askToJoinCheckbox = checkbox
end

local function RestoreDefaults()
  for key, value in pairs(ns.defaults) do ns.db[key] = value end
  askToJoinCheckbox:SetValue(ns.db.askToJoin)
  local note = ns.FreeCommandKey()
  if note then ns.Print(note) end
  RefreshDropdowns()
end

local function BuildPanel()
  local panel = CreateFrame("Frame")

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetJustifyH("LEFT")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(ns.title)

  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetAtlas("Options_HorizontalDivider", true)
  divider:SetPoint("TOP", 0, -50)

  local defaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defaults:SetSize(96, 22)
  defaults:SetPoint("TOPRIGHT", -36, -16)
  defaults:SetText(SETTINGS_DEFAULTS)
  defaults:SetScript("OnClick", RestoreDefaults)

  for index, action in ipairs(ns.actions) do AddActionRow(panel, action, index) end
  AddAskToJoinRow(panel, #ns.actions + 1)
  return panel
end

local function RegisterPanel()
  local category = Settings.RegisterCanvasLayoutCategory(BuildPanel(), ns.title)
  Settings.RegisterAddOnCategory(category)
  categoryID = category:GetID()
end

EventUtil.ContinueOnPlayerLogin(RegisterPanel)

local waitingForCombat = false

local function OpenSettings()
  if not categoryID then return end

  -- C_SettingsUtil.OpenSettingsPanel has restrictions the source does not spell out, so an open in
  -- combat waits for combat to end instead of failing silently.
  if InCombatLockdown() then
    ns.Print("Opens after combat.")
    if not waitingForCombat then
      waitingForCombat = true
      EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
        waitingForCombat = false
        OpenSettings()
      end)
    end
    return
  end

  Settings.OpenToCategory(categoryID)
end

SLASH_SOCIALSHORTCUTS1, SLASH_SOCIALSHORTCUTS2 = "/socialshortcuts", "/ssc"
SlashCmdList.SOCIALSHORTCUTS = OpenSettings

-- Addon Compartment entry points named in the toc. Blizzard calls them with the addon name first, then the
-- menu row.
SocialShortcuts_CompartmentClick = OpenSettings

function SocialShortcuts_CompartmentEnter(_, menuButton)
  GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
  GameTooltip_SetTitle(GameTooltip, ns.title)
  for _, action in ipairs(ns.actions) do
    local token = ns.db[action.key]
    if token ~= "NONE" then
      GameTooltip_AddColoredDoubleLine(GameTooltip, ns.modifierLabel[token] .. "-click", action.label,
        HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    end
  end
  GameTooltip_AddInstructionLine(GameTooltip, "Click to open the settings.")
  GameTooltip:Show()
end

function SocialShortcuts_CompartmentLeave()
  GameTooltip:Hide()
end
