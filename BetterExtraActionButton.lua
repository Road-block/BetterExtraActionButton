
-- luacheck: globals UIPARENT_MANAGED_FRAME_POSITIONS ExtraAbilityContainer ExtraActionBarFrame ExtraActionButton1 ZoneAbilityFrame
-- luacheck: globals BetterExtraActionBarDB Bartender4

local ADDON_NAME = ...
BetterExtraActionBarDB = BetterExtraActionBarDB or {}
local db

local function Print(...) print("|cff33ff99BetterExtraActionBar|r:", ...) end

-- masque shenanigans, may look terrible with background texture enabled! (the button border is part of the texture)
local MSQ = LibStub and LibStub("Masque", true)
if MSQ then
	MSQ:Group("BetterExtraActionButton"):AddButton(ExtraActionButton1, nil, "Action")
	-- Need to dynamically skin ZoneAbilityFrame.SpellButtonContainer.contentFramePool.activeObjects
	--  or ZoneAbilityFrame.SpellButtonContainer:GetChildren()
end

-- don't manage the frame for me, thanks, and don't adjust other frames to account for it
ExtraAbilityContainer.ignoreFramePositionManager = true
for k, v in next, UIPARENT_MANAGED_FRAME_POSITIONS do
	v.extraAbilityContainer = nil
end

-- decouple from MainMenuBar
ExtraAbilityContainer:SetParent(UIParent)
ExtraAbilityContainer.SetParent = function() end -- mine. fuck off.
ExtraAbilityContainer:SetMovable(true)
ExtraAbilityContainer:SetUserPlaced(false)

-- the way i move the frame is pretty backward, yea, i know
local overlay = CreateFrame("Frame", nil, ExtraAbilityContainer)
overlay:SetPoint("TOPLEFT", -4, 4)
overlay:SetPoint("BOTTOMRIGHT", 4, -4)
overlay:EnableMouse(true)
overlay:EnableMouseWheel(true)

local frame = ExtraAbilityContainer
local unlocked = nil
local moving = nil

local function SavePosition()
	local x, y = frame:GetCenter() -- nil when not shown
	if not x or not y then return end
	local s = frame:GetEffectiveScale()
	db.point = "BOTTOMLEFT"
	db.x, db.y = x*s, y*s
end

local function RestorePosition()
	if not db.point then return end
	local s = frame:GetEffectiveScale()
	local x, y = db.x/s, db.y/s
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

local function UpdateArt()
	local frames = ExtraAbilityContainer.frames
	if #frames ~= 1 then return end
	local f = frames[1].frame

	local artwork
	if f == ExtraActionBarFrame then
		artwork = ExtraActionButton1.style
	elseif f == ZoneAbilityFrame then
		artwork = ZoneAbilityFrame.Style
	else
		-- print("panic!", f:GetName())
		return
	end

	artwork:SetDesaturated(unlocked)

	if unlocked then
		artwork:SetAlpha(0.6)
	elseif db.hidebg then
		artwork:SetAlpha(0)
	else
		artwork:SetAlpha(1)
	end
end

local function SetScale(scale)
	if not unlocked or InCombatLockdown() then return end
	frame:SetScale(scale)
	db.scale = scale

	RestorePosition()
end

overlay:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" and unlocked then
		frame:StartMoving()
		moving = true
	end
end)

overlay:SetScript("OnMouseUp", function(self, button)
	if button == "RightButton" then
		unlocked = not unlocked
		UpdateArt()

	elseif button == "MiddleButton" then
		SetScale(1)

	elseif moving then
		moving = nil
		frame:StopMovingOrSizing()
		frame:SetUserPlaced(false)
		SavePosition()
	end
end)

overlay:SetScript("OnMouseWheel", function(self, delta)
	local scale = frame:GetScale() + (0.1 * delta)
	SetScale(scale)
end)

local function OnShow(self)
	-- make sure we're skinned
	if MSQ then
		MSQ:Group("BetterExtraActionButton"):ReSkin()
	end

	-- make sure the background is doing what it should be doing
	UpdateArt()
end
overlay:SetScript("OnShow", OnShow)

overlay:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		self:UnregisterEvent("ADDON_LOADED")
		-- per char settings, could have just used SavedVariablesPerCharacter but meh
		local key = (UnitName("player")) .. " - " .. GetRealmName()
		if not BetterExtraActionBarDB[key] then
			BetterExtraActionBarDB[key] = {}
		end
		db = BetterExtraActionBarDB[key]
	elseif event == "PLAYER_LOGIN" then
		if Bartender4 and Bartender4.db:GetNamespace("ExtraActionBar").profile.enabled then
			C_Timer.After(7, function()
				Print("You have Bartender4's Extra Action Bar module enabled! This could cause issues and you should disable it.")
			end)
		end

		frame:SetScale(db.scale or 1)

		-- make sure we're sane
		if not db.point or not db.x or not db.y then
			db.point = nil
			db.x = nil
			db.y = nil
		end

		if not db.point then
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
			SavePosition()
		else
			RestorePosition()
		end

		-- beautify the frame incase it's already shown
		OnShow()
	end
end)
overlay:RegisterEvent("PLAYER_LOGIN")
overlay:RegisterEvent("ADDON_LOADED")



ZoneAbilityFrame:HookScript("OnShow", function(self)
	-- suddenly ZAB, hide the frame
	local bar = ExtraActionBarFrame
	if bar:IsShown() and bar.button.icon:GetTexture() == 132311 then
		bar:Hide()
		ExtraAbilityContainer:RemoveFrame(bar)
		OnShow(overlay)
	end
end)

local function ToggleButton()
	-- don't mess with it if it's active
	if HasExtraActionBar() or ZoneAbilityFrame:IsShown() or InCombatLockdown() then
		return
	end

	-- show/hide a test EAB
	local bar = ExtraActionBarFrame
	if bar:IsShown() then
		bar.intro:Stop()
		bar.outro:Play()
	else
		bar:Show()
		bar.button.style:SetTexture("Interface\\ExtraButton\\Default")
		bar.button.icon:SetTexture(132311) -- ability_seal
		bar.button.icon:SetVertexColor(1, 1, 1)
		bar.button.icon:Show()
		bar.button.NormalTexture:SetVertexColor(1, 1, 1)
		bar.button:Show()
		ExtraAbilityContainer:AddFrame(bar, 100)
		bar.outro:Stop()
		bar.intro:Play()
	end
end

SLASH_BETTEREXTRABUTTONBAR1 = "/beab"
SLASH_BETTEREXTRABUTTONBAR2 = "/eab"
SlashCmdList["BETTEREXTRABUTTONBAR"] = function(input)
	if input == "reset" then
		-- reset position in case the frame is under the ui or offscreen
		if not InCombatLockdown() then
			frame:SetScale(1)
			db.scale = nil
			db.point, db.x, db.y = nil, nil, nil

			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 120)
			SavePosition()

			Print("Position reset.")
		else
			Print("Unable to reset the button's position while in combat!")
		end

	elseif input == "lock" then
		unlocked = not unlocked
		if unlocked and not frame:IsShown() then
			ToggleButton()
		end
		UpdateArt()

	elseif input == "toggle" then
		ToggleButton()

	elseif input == "togglebg" then
		-- show/hide the fancy background texture
		db.hidebg = not db.hidebg or nil
		UpdateArt()

	else
		-- should probably have soooooomething
		print("Usage: /beab [reset||lock||toggle||togglebg]")
		print("Reset the button position, lock/unlock the button, toggle showing the button, or toggle showing the button artwork")

	end
end
