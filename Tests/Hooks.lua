-- Checks live UI rows and chat links against client stubs. Hover dispatch/deduplication is tested separately.
-- Run from the repo root: lua Tests/Hooks.lua
local hooks, hoverHandlers, registryCallbacks = {}, {}, {}
local notices, runs, unitRuns, bnetRuns, forwarded = {}, {}, {}, {}, {}
local invites, clickCalls, asksToJoin, lockdown, chatLink = 0, 0, true, false, false
local shortcuts, nativeActions = {}, {}
local secret = {}
hooksecurefunc = function(target, method, hook)
  if type(target) == "string" then target, method, hook = nil, target, method end
  hooks[method] = hook
end

local function NewFrame(fields)
  local frame = fields or {}
  frame.hooks, frame.scripts, frame.scriptHooks = 0, {}, {}
  function frame:HookScript(script, handler)
    self.hooks = self.hooks + 1
    self.scriptHooks[script] = self.scriptHooks[script] or {}
    table.insert(self.scriptHooks[script], handler)
  end
  function frame:HasScript(script) return script ~= "OnMouseUp" or self.hasMouseUp ~= false end
  function frame:SetScript(script, handler) self.scripts[script] = handler end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:IsShown() return self.shown end
  return frame
end
local function FireScript(frame, script, ...)
  if frame.scripts[script] then frame.scripts[script](frame, ...) end
  for _, handler in ipairs(frame.scriptHooks[script] or {}) do handler(frame, ...) end
end
local function NewScrollBox(frames)
  return { frames = frames, ForEachFrame = function(self, callback)
    for _, frame in ipairs(self.frames) do callback(frame) end
  end }
end
ScrollUtil = { AddInitializedFrameCallback = function(scrollBox, callback, owner)
  scrollBox.initialize = function(frame) callback(owner, frame) end
end }

DefaultCompactUnitFrameSetup = function() end
TargetFrame = NewFrame({ unit = "target", totFrame = NewFrame({ unit = "targettarget" }) })
FocusFrame = NewFrame({ unit = "focus", totFrame = NewFrame({ unit = "focustarget" }) })
local partyFrame = NewFrame({ unit = "vehicle1", GetUnit = function() return "party1" end })
local partyFrames = { [partyFrame] = true }
PartyFrame = { PartyMemberFramePool = { EnumerateActive = function() return next, partyFrames end } }
local raidFrame = NewFrame({ frameType = "raid", unit = "raid1", displayedUnit = "raid2" })
local groupFrame, flaggedFrame = NewFrame(), NewFrame({ frameType = "flagged", unit = "raid3" })
CompactRaidFrameContainer = { frameUpdateList = { normal = { raidFrame, groupFrame } } }

FRIENDS_BUTTON_TYPE_WOW, FRIENDS_BUTTON_TYPE_BNET = 1, 2
local friendRow = NewFrame({ buttonType = FRIENDS_BUTTON_TYPE_WOW, id = 1 })
local bnetRow = NewFrame({ buttonType = FRIENDS_BUTTON_TYPE_BNET, id = 42 })
local divider = NewFrame({ hasMouseUp = false })
FriendsListFrame = { ScrollBox = NewScrollBox({ friendRow, bnetRow, divider }) }
local whoRow = NewFrame({ index = 1 })
LFGWhoListFrame = { ScrollBox = NewScrollBox({ whoRow }) }
local browseRow = NewFrame({ resultID = 1 })
LFGBrowseFrame = { ScrollBox = NewScrollBox({ browseRow }) }
local friendInfo = { { name = "FriendOne" }, { name = "FriendTwo" } }
local whoInfo = { { fullName = "WhoOne-Realm" }, { fullName = "WhoTwo-Realm" } }
C_FriendList = {
  GetFriendInfoByIndex = function(index) return friendInfo[index] end,
  GetWhoInfo = function(index) return whoInfo[index] end,
}
-- Listing 1 is solo and invitable, 2 a group, 3 solo but not invitable by you.
local listings = {
  { leaderName = "Leader1", numMembers = 1 },
  { leaderName = "Leader2", numMembers = 3 },
  { leaderName = "Leader3", numMembers = 1 },
}
C_LFGList = { GetSearchResultInfo = function(id) return listings[id] end }
LFGBrowseUtil_GetInviteActionForResult = function(id)
  if id == 1 then return "Invite", function() invites = invites + 1 end end
  return "Invite", nil
end
UIErrorsFrame = { AddExternalErrorMessage = function(_, message) table.insert(notices, message) end }
Enum = { ClubType = { BattleNet = 1, Guild = 2 } }
local clubInfo = { clubType = Enum.ClubType.Guild }
local guildRow = NewFrame({ memberInfo = { name = "GuildOne" } })
function guildRow:GetMemberInfo() return self.memberInfo end
local messageFrame = NewFrame()
CommunitiesFrame = {
  MemberList = { ScrollBox = NewScrollBox({ guildRow }), GetSelectedClubInfo = function() return clubInfo end },
  Chat = { MessageFrame = messageFrame },
}
local loadedAddOns = {
  Blizzard_CompactRaidFrames = true, Blizzard_GroupFinder_VanillaStyle = true,
  Blizzard_FriendsFrame = true, Blizzard_Communities = true,
}
EventUtil = { ContinueOnAddOnLoaded = function(name, callback) if loadedAddOns[name] then callback() end end }

local cover
UIParent = {}
CreateFrame = function()
  cover = NewFrame()
  function cover:SetFrameStrata() end
  function cover:RegisterForClicks(...) self.clicks = { ... } end
  function cover:RegisterEvent() end
  function cover:ClearAllPoints() end
  function cover:SetPoint(_, region, _, x, y) self.anchor = { region = region, x = x, y = y } end
  function cover:SetSize(width, height) self.width, self.height = width, height end
  return cover
end
EventRegistry = { RegisterCallback = function(_, event, callback) registryCallbacks[event] = callback end }
C_ChatInfo = { InChatMessagingLockdown = function() return lockdown end }
IsModifiedClick = function() return chatLink end
SetItemRef = function(link, label, button, chatFrame)
  forwarded[#forwarded + 1] = { link = link, label = label, button = button, chatFrame = chatFrame }
  hooks.SetItemRef(link, label, button, chatFrame)
end

local ns = {
  mouseButtonOrder = { "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5" },
  HeldAction = function(button) return shortcuts[button] end,
  GetHoverBindingAction = function(button) return nativeActions[button] end,
  IsHoverBinding = function(button) return nativeActions[button] ~= nil end,
  -- Use simple configured-action stubs here; Config/Hover tests own modifier matching and press tracking.
  RunClickAction = function(button, handler)
    clickCalls = clickCalls + 1
    local action = nativeActions[button] or shortcuts[button]
    if action and not lockdown then return handler(action) end
    return false
  end,
  RegisterHoverFrame = function(frame, handler) hoverHandlers[frame] = handler end,
  RunUnitAction = function(action, unit)
    unitRuns[#unitRuns + 1] = { action = action, unit = unit }
    return true
  end,
  RunAction = function(action, name, chatFrame, grouped)
    runs[#runs + 1] = { action = action, name = name, chatFrame = chatFrame, grouped = grouped }
  end,
  RunBNetAction = function(action, id) bnetRuns[#bnetRuns + 1] = { action = action, id = id } end,
  CanAccess = function(value) return value ~= secret end,
  AsksToJoin = function() return asksToJoin end,
}
assert(loadfile("Core/Hooks.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end
local function Reset(action, button)
  runs, unitRuns, bnetRuns, notices, forwarded = {}, {}, {}, {}, {}
  clickCalls, invites, lockdown, chatLink, asksToJoin = 0, 0, false, false, true
  shortcuts, nativeActions = {}, {}
  if action then shortcuts[button or "LeftButton"] = action end
end
local function OneAction(action, name)
  return #runs == 1 and runs[1].action == action and runs[1].name == name
end
local function Click(frame, button, upInside) FireScript(frame, "OnMouseUp", button or "LeftButton", upInside) end

-- Unit-frame hooks survive pooling and resolve the unit at the moment of input.
Check("a frame the raid container already holds is hooked at install", raidFrame.hooks == 1)
Check("a group frame in the same list is left alone", groupFrame.hooks == 0 and not hoverHandlers[groupFrame])
table.insert(CompactRaidFrameContainer.frameUpdateList.normal, flaggedFrame)
hooks.GetUnitFrame(CompactRaidFrameContainer, "raid3", "flagged")
Check("a raid frame handed out later is hooked", flaggedFrame.hooks == 1 and hoverHandlers[flaggedFrame])
Check("a raid frame is never hooked twice", raidFrame.hooks == 1)
local compactFrame, petFrame = NewFrame({ unit = "party2" }), NewFrame({ unit = "pet" })
hooks.CompactUnitFrame_SetUpFrame(compactFrame, DefaultCompactUnitFrameSetup)
hooks.CompactUnitFrame_SetUpFrame(petFrame, function() end)
Check("compact player frames are hooked without hooking pet/nameplate setups", compactFrame.hooks == 1 and petFrame.hooks == 0)
local laterParty = NewFrame({ unit = "party3" })
partyFrames[laterParty] = true
hooks.InitializePartyMemberFrames()
Check("new party members are hooked without duplicating existing hooks", laterParty.hooks == 1 and partyFrame.hooks == 1)
Reset("invite")
Click(TargetFrame)
Click(partyFrame)
Click(raidFrame)
Check("unit-frame clicks prefer displayedUnit, then GetUnit, then unit",
  #unitRuns == 3 and unitRuns[1].unit == "target" and unitRuns[2].unit == "party1" and unitRuns[3].unit == "raid2")
raidFrame.displayedUnit = "raid4"
hoverHandlers[raidFrame]("friend")
Check("a native hover action reads the current unit", #unitRuns == 4 and unitRuns[4].unit == "raid4" and unitRuns[4].action == "friend")
Reset("invite")
Click(TargetFrame, "LeftButton", false)
Check("a unit-frame press released outside is ignored", clickCalls == 0 and #unitRuns == 0)
Click(TargetFrame, "RightButton", true)
Check("an unconfigured unit-frame button does not dispatch", #unitRuns == 0)

-- Pooled list rows resolve fresh identities for both clicks and native keys.
Check("noninteractive friend-list dividers are left alone", divider.hooks == 0 and not hoverHandlers[divider])
Reset("invite")
Click(friendRow)
Check("the current WoW friend receives the click action", OneAction("invite", "FriendOne"))
friendRow.id = 2
FriendsListFrame.ScrollBox.initialize(friendRow)
runs = {}
hoverHandlers[friendRow]("whisper")
Check("a reused friend row resolves its new identity for a native key", OneAction("whisper", "FriendTwo") and friendRow.hooks == 1)
Click(bnetRow)
Check("Battle.net friends use their account action", #bnetRuns == 1 and bnetRuns[1].id == 42 and bnetRuns[1].action == "invite")
friendRow.id = 99
runs = {}
Click(friendRow)
friendRow.buttonType = 99
Click(friendRow)
Check("missing friends and non-player row types are ignored", #runs == 0)
friendRow.buttonType, friendRow.id = FRIENDS_BUTTON_TYPE_WOW, 2

Reset("invite")
Click(whoRow, "LeftButton", true)
Check("Who left-click shortcuts use mouse-up even when the row registers only right-click", OneAction("invite", "WhoOne-Realm"))
whoRow.index = 2
whoRow:SetScript("OnClick", function() end)
LFGWhoListFrame.ScrollBox.initialize(whoRow)
runs = {}
hoverHandlers[whoRow]("friend")
Check("Who reuse and OnClick replacement preserve one hover handler", OneAction("friend", "WhoTwo-Realm") and whoRow.hooks == 1)
runs = {}
Click(whoRow, "LeftButton", false)
Check("releasing outside a scrolling row does not act", #runs == 0)
local laterWho = NewFrame({ index = 1 })
LFGWhoListFrame.ScrollBox.initialize(laterWho)
Click(laterWho)
Check("rows initialized after install receive click and native handlers", OneAction("invite", "WhoOne-Realm") and hoverHandlers[laterWho])
runs, whoRow.index = {}, nil
Click(whoRow)
whoRow.index = 99
Click(whoRow)
Check("an empty or missing Who result is ignored", #runs == 0)

-- Preserve Blizzard's own Browse invite path and the existing invite-or-join behavior.
local function ClickListing(id)
  browseRow.resultID = id
  LFGBrowseFrame.ScrollBox.initialize(browseRow)
  Click(browseRow)
end
Reset("invite")
ClickListing(1)
Check("an invitable listing gets Blizzard's invite", invites == 1 and #notices == 0 and #runs == 0)
ClickListing(2)
Check("while Invite asks to join, a group listing invites its leader as grouped", OneAction("invite", "Leader2") and runs[1].grouped == true)
asksToJoin = false
ClickListing(2)
Check("otherwise a group listing gets a notice", #runs == 1 and #notices == 1)
ClickListing(3)
Check("a solo listing Blizzard will not invite gets a suggestion", #runs == 2 and runs[2].name == "Leader3" and runs[2].grouped == false)
Reset("whisper")
ClickListing(2)
Check("whisper still goes to the listing leader", OneAction("whisper", "Leader2"))
browseRow.resultID, runs = 3, {}
hoverHandlers[browseRow]("friend")
Check("native Browse actions resolve the current pooled listing once", OneAction("friend", "Leader3") and browseRow.hooks == 1)
runs, browseRow.isDelisted = {}, true
Click(browseRow)
browseRow.isDelisted, browseRow.hasSelf = false, true
Click(browseRow)
browseRow.hasSelf, browseRow.resultID = false, 99
Click(browseRow)
Check("delisted, self-containing and missing listings are ignored", #runs == 0)

Reset("invite")
Click(guildRow)
Check("guild rows dispatch the selected member", OneAction("invite", "GuildOne"))
guildRow.memberInfo = { name = "GuildTwo" }
CommunitiesFrame.MemberList.ScrollBox.initialize(guildRow)
runs = {}
hoverHandlers[guildRow]("whisper")
Check("pooled guild hover keys resolve the current member", OneAction("whisper", "GuildTwo") and guildRow.hooks == 1)
runs, guildRow.isInvitation = {}, true
Click(guildRow)
guildRow.isInvitation = false
clubInfo.clubType = Enum.ClubType.BattleNet
Click(guildRow)
clubInfo.clubType = Enum.ClubType.Guild
guildRow.memberInfo = nil
Click(guildRow)
Check("guild invitations, Battle.net clubs and missing members keep their default clicks", #runs == 0)

-- Chat captures only player links and exposes current names even without a visible click cover.
local line = { text = "[Leader]: LFM", visible = true }
function line:GetText() return self.text end
function line:IsVisible() return self.visible end
local function Hover(link)
  registryCallbacks["ChatFrame.OnHyperlinkEnter"](nil, "ChatFrame1", link, "[Leader]", line, 10, 2, 40, 12)
end
local function ClickCover(button) FireScript(cover, "OnClick", button or "LeftButton") end
Reset()
Hover("player:Leader:12:CHANNEL")
local name, chatFrame, active = ns.GetHoveredChatTarget()
Check("native keys can resolve a chat hover without a modifier or cover", not cover.shown and name == "Leader" and chatFrame == "ChatFrame1" and active)
registryCallbacks["ChatFrame.OnHyperlinkLeave"]()
name, chatFrame, active = ns.GetHoveredChatTarget()
Check("leaving an uncovered link clears its native-key target", name == nil and chatFrame == nil and active == false)

Reset("invite")
Hover("player:Leader:12:CHANNEL")
Check("the cover catches configured buttons over exactly the linked name",
  cover.shown and cover.clicks[1] == "AnyUp" and cover.anchor.region == line and cover.anchor.x == 10
    and cover.anchor.y == 2 and cover.width == 40 and cover.height == 12)
registryCallbacks["ChatFrame.OnHyperlinkLeave"]()
Check("the cover taking the mouse keeps the name", cover.shown and ns.GetHoveredChatTarget() == "Leader")
ClickCover()
Check("a cover click runs the action without forwarding Blizzard's whisper", OneAction("invite", "Leader") and runs[1].chatFrame == "ChatFrame1" and #forwarded == 0)
line.text = "[Other]: hi"
name, chatFrame, active = ns.GetHoveredChatTarget()
ClickCover()
Check("a redrawn chat line cancels its target and cover", name == nil and active == true and #runs == 1 and not cover.shown)
name, chatFrame, active = ns.GetHoveredChatTarget()
Check("the invalidated chat target is then fully cleared", name == nil and active == false)
line.text = "[Leader]: LFM"
Hover("player:Leader:12:CHANNEL")
line.visible = false
name, chatFrame, active = ns.GetHoveredChatTarget()
Check("a hidden chat line cannot remain a native-key target", name == nil and active == true and not cover.shown)
line.visible = true
Hover("player:Leader:12:CHANNEL")
line.text = secret
name, chatFrame, active = ns.GetHoveredChatTarget()
Check("a line that becomes secret is discarded safely", name == nil and active == true and not cover.shown)
line.text = "[Leader]: LFM"

Reset("whisper")
Hover("player:Leader:12:CHANNEL")
Check("a left-button whisper keeps Blizzard's own click", not cover.shown)
lockdown = true
hooks.SetItemRef("player:Leader", nil, "LeftButton", "ChatFrame1")
Check("Blizzard's existing whisper avoids the shortcut gate even in lockdown", clickCalls == 0 and #runs == 0)
Reset("friend")
chatLink = true
Hover("player:Leader:12:CHANNEL")
Check("CHATLINK left-click keeps Blizzard's insert-name or Who action", not cover.shown)
hooks.SetItemRef("player:Leader", nil, "LeftButton", "ChatFrame1")
Check("the post-hook still runs the configured CHATLINK action", OneAction("friend", "Leader"))
Reset("whisper", "RightButton")
Hover("player:Leader:12:CHANNEL")
ClickCover("RightButton")
Check("a configured right-button whisper uses the cover", cover.shown and OneAction("whisper", "Leader"))

Reset("invite")
shortcuts.RightButton = "friend"
Hover("player:Leader:12:CHANNEL")
ClickCover("LeftButton")
ClickCover("RightButton")
Check("one held modifier can dispatch different actions on different chat buttons", #runs == 2 and runs[1].action == "invite" and runs[2].action == "friend")
runs = {}
ClickCover("MiddleButton")
Check("an unrelated covered click is forwarded with its original link and frame",
  #runs == 0 and #forwarded == 1 and forwarded[1].link == "player:Leader:12:CHANNEL"
    and forwarded[1].label == "[Leader]" and forwarded[1].button == "MiddleButton" and forwarded[1].chatFrame == "ChatFrame1")
Reset("invite", "RightButton")
Hover("player:Leader:12:CHANNEL")
ClickCover("LeftButton")
Check("a right-button shortcut does not consume the ordinary left click", #runs == 0 and #forwarded == 1 and forwarded[1].button == "LeftButton")

Reset()
nativeActions.Button4 = "invite"
Hover("player:Leader:12:CHANNEL")
ClickCover("Button4")
Check("a native mouse binding gets a cover fallback with click shortcuts disabled", cover.shown and OneAction("invite", "Leader"))
nativeActions, runs = {}, {}
FireScript(cover, "OnEvent", "UPDATE_BINDINGS")
Check("changing native bindings updates the chat cover", not cover.shown)
shortcuts.LeftButton, nativeActions.LeftButton, chatLink = "invite", "friend", true
FireScript(cover, "OnEvent", "UPDATE_BINDINGS")
ClickCover()
Check("a native command takes priority over a modifier-click and CHATLINK", cover.shown and OneAction("friend", "Leader"))
Reset("invite")
lockdown = true
Hover("player:Leader:12:CHANNEL")
hooks.SetItemRef("player:Leader", nil, "LeftButton", "ChatFrame1")
Check("lockdown leaves the cover hidden and refuses shortcut actions", not cover.shown and #runs == 0)

Reset("invite")
for _, invalid in ipairs({ { "item", "item:6948" }, { "empty player", "player:" }, { "secret", secret }, { "non-string", {} } }) do
  Hover(invalid[2])
  hooks.SetItemRef(invalid[2], nil, "LeftButton", "ChatFrame1")
  name, chatFrame, active = ns.GetHoveredChatTarget()
  Check(invalid[1] .. " links cannot become targets", not cover.shown and #runs == 0 and not active)
end
line.text = secret
Hover("player:Leader")
Check("a secret line is never captured at hover entry", not cover.shown and ns.GetHoveredChatTarget() == nil)
line.text = "[Leader]: LFM"
Hover("playerCommunity:CommunityPlayer:12")
ClickCover()
Check("community player links resolve their actual player name", OneAction("invite", "CommunityPlayer"))

runs = {}
FireScript(messageFrame, "OnHyperlinkEnter", "player:GuildChatPlayer:12", "[GuildChatPlayer]", line, 0, 0, 50, 12)
ClickCover()
Check("Communities chat hooks expose player names without a chat-window frame", OneAction("invite", "GuildChatPlayer") and runs[1].chatFrame == nil)
shortcuts = {}
FireScript(cover, "OnEvent", "MODIFIER_STATE_CHANGED")
Check("letting go of the modifier removes the cover", not cover.shown)
shortcuts.LeftButton = "invite"
FireScript(cover, "OnEvent", "MODIFIER_STATE_CHANGED")
Check("pressing it again over the same name restores the cover", cover.shown)
FireScript(cover, "OnLeave")
FireScript(cover, "OnEvent", "MODIFIER_STATE_CHANGED")
name, chatFrame, active = ns.GetHoveredChatTarget()
Check("leaving the cover drops its target permanently", not cover.shown and name == nil and active == false)
shortcuts = {}
FireScript(messageFrame, "OnHyperlinkEnter", "player:GuildChatPlayer:12", "[GuildChatPlayer]", line, 0, 0, 50, 12)
FireScript(messageFrame, "OnHyperlinkLeave")
name, chatFrame, active = ns.GetHoveredChatTarget()
Check("Communities chat leave clears an uncovered native-key target", name == nil and active == false)

print(failures == 0 and "Hooks: all checks passed" or ("Hooks: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
