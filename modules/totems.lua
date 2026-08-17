local Totems = {}
local totemColors = {}
local MAX_TOTEMS = MAX_TOTEMS

local playerClass = select(2, UnitClass("player"))
if( playerClass == "MONK" ) then
	MAX_TOTEMS = 1
	ShadowUF:RegisterModule(Totems, "totemBar", ShadowUF.L["Statue bar"], true, "MONK", {1, 2})
elseif( playerClass == "SHAMAN" ) then
	ShadowUF:RegisterModule(Totems, "totemBar", ShadowUF.L["Totem bar"], true, "SHAMAN")
end

ShadowUF.BlockTimers:Inject(Totems, "TOTEM_TIMER")
ShadowUF.DynamicBlocks:Inject(Totems)

function Totems:SecureLockable()
	return MAX_TOTEMS > 1
end

function Totems:OnEnable(frame)
	if( not frame.totemBar ) then
		frame.totemBar = CreateFrame("Frame", nil, frame)
		frame.totemBar.totems = {}
		frame.totemBar.blocks = frame.totemBar.totems

		local priorities = (playerClass == "SHAMAN") and SHAMAN_TOTEM_PRIORITIES or STANDARD_TOTEM_PRIORITIES

		for id=1, MAX_TOTEMS do
			local totem = ShadowUF.Units:CreateBar(frame.totemBar)
			totem:SetMinMaxValues(0, 1)
			totem:SetValue(0)
			totem.id = MAX_TOTEMS == 1 and 1 or priorities[id]
			totem.parent = frame

			if( id > 1 ) then
				totem:SetPoint("TOPLEFT", frame.totemBar.totems[id - 1], "TOPRIGHT", 1, 0)
			else
				totem:SetPoint("TOPLEFT", frame.totemBar, "TOPLEFT", 0, 0)
			end

			table.insert(frame.totemBar.totems, totem)
		end

		if( playerClass == "MONK" ) then
			totemColors[1] = ShadowUF.db.profile.powerColors.STATUE
		else
			totemColors[1] = {r = 1, g = 0, b = 0.4}
			totemColors[2] = {r = 0, g = 1, b = 0.4}
			totemColors[3] = {r = 0, g = 0.4, b = 1}
			totemColors[4] = {r = 0.90, g = 0.90, b = 0.90}
		end
	end

	frame:RegisterNormalEvent("PLAYER_TOTEM_UPDATE", self, "Update")
	frame:RegisterUpdateFunc(self, "UpdateVisibility")
	frame:RegisterUpdateFunc(self, "Update")
end

function Totems:OnDisable(frame)
	frame:UnregisterAll(self)
	frame:UnregisterUpdateFunc(self, "Update")

	for _, totem in pairs(frame.totemBar.totems) do
	    totem:Hide()
    end
end

function Totems:OnLayoutApplied(frame)
	if( not frame.visibility.totemBar ) then return end

	local barWidth = (frame.totemBar:GetWidth() - (MAX_TOTEMS - 1)) / MAX_TOTEMS
	local config = ShadowUF.db.profile.units[frame.unitType].totemBar

	for _, totem in pairs(frame.totemBar.totems) do
		totem:SetHeight(frame.totemBar:GetHeight())
		totem:SetWidth(barWidth)
		totem:SetOrientation(ShadowUF.db.profile.units[frame.unitType].totemBar.vertical and "VERTICAL" or "HORIZONTAL")
		totem:SetReverseFill(ShadowUF.db.profile.units[frame.unitType].totemBar.reverse and true or false)
		totem:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
		totem:GetStatusBarTexture():SetHorizTile(false)

		if not config.icon then
			totem.background:SetTexture(ShadowUF.Layout.mediaPath.statusbar)
		end

		if( config.background or config.invert ) then
			totem.background:Show()
		else
			totem.background:Hide()
		end

		frame:SetBlockColor(totem, "totemBar", totemColors[totem.id].r, totemColors[totem.id].g, totemColors[totem.id].b)

		if config.icon then
			totem.background:SetVertexColor(1, 1, 1, 1)
			local tex = totem:GetStatusBarTexture()
			local r, g, b = tex:GetVertexColor()
			local alpha = ShadowUF.db.profile.bars.alpha
			tex:SetVertexColor(r, g, b, alpha < 1 and alpha or 0.7)
		end

		if( config.secure ) then
			totem.secure = totem.secure or CreateFrame("Button", frame:GetName() .. "Secure" .. totem.id, totem, "SecureUnitButtonTemplate")
			totem.secure:RegisterForClicks("RightButtonUp")
			totem.secure:SetAllPoints(totem)
			totem.secure:SetAttribute("type2", "destroytotem")
			totem.secure:SetAttribute("*totem-slot*", totem.id)
			totem.secure:Show()

		elseif( totem.secure ) then
			totem.secure:Hide()
		end
	end

	self:Update(frame)
end

-- The bar fill is timer-driven, this tick only keeps the timer text fresh.
-- Expiry cleanup happens in Update via PLAYER_TOTEM_UPDATE, which fires with a plain slot index.
local function totemMonitor(self, elapsed)
	self.fontString:UpdateTags()
end

function Totems:UpdateVisibility(frame)
	if( frame.totemBar.inVehicle ~= frame.inVehicle ) then
		frame.totemBar.inVehicle = frame.inVehicle

		if( frame.inVehicle ) then
			ShadowUF.Layout:SetBarVisibility(frame, "totemBar", false)
		elseif( MAX_TOTEMS ~= 1 ) then
			self:Update(frame)
		end
	end
end

-- An empty slot yields nil despite the doc's Nilable = false.
local function slotDuration(id)
	local duration = GetTotemDuration(id)
	if not duration then return nil end
	if duration:HasSecretValues() then return duration, true end
	if duration:IsZero() then return nil end
	return duration, false
end

-- GetTotemInfo returns are secret under combat restrictions, so activity is read from GetTotemDuration instead.
-- On secret slots the occupancy boolean routes into SetAlphaFromBoolean, empty slots turn invisible without ever being branched on.
function Totems:Update(frame)
	local numSlots = GetNumTotemSlots and GetNumTotemSlots() or MAX_TOTEMS
	local totalActive = 0
	local anySecret = false
	for _, indicator in pairs(frame.totemBar.totems) do
		local durationObj, foundSlot, secretSlot

		if MAX_TOTEMS == 1 and indicator.id == 1 then
			for id = 1, numSlots do
				durationObj, secretSlot = slotDuration(id)
				if durationObj then
					foundSlot = id
					break
				end
			end
		else
			durationObj, secretSlot = slotDuration(indicator.id)
			foundSlot = durationObj and indicator.id
		end

		if durationObj then
			local have, _, _, _, icon = GetTotemInfo(foundSlot)

			if( ShadowUF.db.profile.units[frame.unitType].totemBar.icon ) then
				-- the icon may be secret, SetTexture accepts it
				indicator.background:SetTexture(icon)
				indicator.background:Show()
			end

			indicator.have = true
			indicator.totemSlot = foundSlot

			indicator:SetMinMaxValues(0, 1)
			indicator:SetTimerDuration(durationObj, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
			indicator:SetScript("OnUpdate", indicator.fontString and totemMonitor or nil)

			if secretSlot then
				anySecret = true
				-- GetTotemInfo may return nothing, and type() reads through secrets
				if type(have) == "boolean" then
					indicator:SetAlphaFromBoolean(have)
				else
					indicator:SetAlpha(1.0)
				end
			else
				indicator:SetAlpha(1.0)
				totalActive = totalActive + 1
			end

		elseif( indicator.have ) then
			indicator.have = nil
			indicator.totemSlot = nil
			indicator:SetScript("OnUpdate", nil)
			indicator:SetMinMaxValues(0, 1)
			indicator:SetValue(0)
			indicator:SetAlpha(1.0)

			if( ShadowUF.db.profile.units[frame.unitType].totemBar.icon ) then
				indicator.background:SetTexture(ShadowUF.Layout.mediaPath.statusbar)
				local config = ShadowUF.db.profile.units[frame.unitType].totemBar
				if not config.background and not config.invert then
					indicator.background:Hide()
				end
			end
		end

		if( indicator.fontString ) then
			indicator.fontString:UpdateTags()
		end
	end

	if( not frame.inVehicle ) then
		if( MAX_TOTEMS == 1 or not ShadowUF.db.profile.units[frame.unitType].totemBar.showAlways ) then
			ShadowUF.Layout:SetBarVisibility(frame, "totemBar", totalActive > 0 or anySecret)
		end
	end
end
