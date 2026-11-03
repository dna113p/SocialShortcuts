-- Checks the raid container hook and the Group Finder invite in Core/Hooks.lua against stubs of the client.
-- Run from the repo root: lua Tests/Hooks.lua
local hooks, notices, invites, runs = {}, {}, 0, {}
hooksecurefunc = function(target, method, hook)
  if type(target) == "string" then target, method, hook = nil, target, method end
  hooks[method] = hook
end

local function NewFrame(fields)
  local frame = fields or {}
  frame.hooks = 0
  frame.HookScript = function(self) self.hooks = self.hooks + 1 end
  return frame
end

TargetFrame = NewFrame({ totFrame = NewFrame() })
FocusFrame = NewFrame({ totFrame = NewFrame() })
PartyFrame = { PartyMemberFramePool = { EnumerateActive = function() return next, {} end } }
LFGWhoListFrame = { ScrollBox = { ForEachFrame = function() end } }
ScrollUtil = { AddInitializedFrameCallback = function() end }
UIErrorsFrame = { AddExternalErrorMessage = function(_, message) table.insert(notices, message) end }
C_LFGList = { GetSearchResultInfo = function(id) return { leaderName = "Leader" .. id } end }
LFGBrowseUtil_GetInviteActionForResult = function(id)
  if id == 1 then return "Invite", function() invites = invites + 1 end end
  return "Invite", nil
end

local raidFrame, groupFrame, flaggedFrame = NewFrame({ frameType = "raid" }), NewFrame(), NewFrame({ frameType = "flagged" })
CompactRaidFrameContainer = { frameUpdateList = { normal = { raidFrame, groupFrame } } }
local loadedAddOns = { Blizzard_CompactRaidFrames = true, Blizzard_GroupFinder_VanillaStyle = true }
EventUtil = {
  ContinueOnAddOnLoaded = function(name, callback)
    if loadedAddOns[name] then callback() end
  end,
}

local picked, pickCalls = nil, 0
IsModifiedClick = function() return false end
local ns = {
  HeldAction = function() return picked end,
  PickAction = function() pickCalls = pickCalls + 1 return picked end,
  RunAction = function(action, name) table.insert(runs, action .. " " .. name) end,
}
assert(loadfile("Core/Hooks.lua"))("SocialShortcuts", ns)

local failures = 0
local function Check(label, condition)
  print((condition and "  pass  " or "  FAIL  ") .. label)
  if not condition then failures = failures + 1 end
end

Check("a frame the container already holds is hooked at install", raidFrame.hooks == 1)
Check("a group frame in the same list is left alone", groupFrame.hooks == 0)
table.insert(CompactRaidFrameContainer.frameUpdateList.normal, flaggedFrame)
hooks.GetUnitFrame(CompactRaidFrameContainer, "raid2", "flagged")
Check("a frame handed out later is hooked", flaggedFrame.hooks == 1)
Check("a frame is never hooked twice", raidFrame.hooks == 1)

picked = "invite"
hooks.LFGBrowseSearchEntry_OnClick({ resultID = 1 }, "LeftButton")
Check("an eligible listing gets Blizzard's invite", invites == 1 and #notices == 0 and #runs == 0)
hooks.LFGBrowseSearchEntry_OnClick({ resultID = 2 }, "LeftButton")
Check("an ineligible listing gets a notice, no invite", invites == 1 and #notices == 1 and #runs == 0)
picked = "whisper"
hooks.LFGBrowseSearchEntry_OnClick({ resultID = 2 }, "LeftButton")
Check("whisper still goes to the leader", runs[1] == "whisper Leader2")

pickCalls = 0
hooks.SetItemRef("player:Name", nil, "LeftButton")
Check("a chat whisper Blizzard makes never reaches the gate or its notice", pickCalls == 0 and #runs == 1)

print(failures == 0 and "Hooks: all checks passed" or ("Hooks: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
