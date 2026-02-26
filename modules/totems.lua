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

		totem.background:SetTexture(ShadowUF.Layout.mediaPath.statusbar)

		if( config.background or config.invert ) then
			totem.background:Show()
		else
			totem.background:Hide()
		end

		if( not ShadowUF.db.profile.units[frame.unitType].totemBar.icon ) then
			frame:SetBlockColor(totem, "totemBar", totemColors[totem.id].r, totemColors[totem.id].g, totemColors[totem.id].b)
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

-- Uses GetTotemTimeLeft() instead of manual arithmetic to work with secret values in combat.
-- SetValue() accepts secrets (AllowedWhenTainted), and type() is safe on secrets.
local function totemMonitor(self, elapsed)
	local timeLeft = GetTotemTimeLeft(self.totemSlot)
	if type(timeLeft) == "number" then
		self:SetValue(timeLeft)
	else
		-- nil = totem expired (nil is never secret, safe to test via type())
		self:SetValue(0)
		self:SetScript("OnUpdate", nil)
		self.totemSlot = nil

		if( not self.parent.inVehicle and MAX_TOTEMS == 1 ) then
			ShadowUF.Layout:SetBarVisibility(self.parent, "totemBar", false)
		end
	end

	if( self.fontString ) then
		self.fontString:UpdateTags()
	end
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

-- Helper function to check if a totem is active, handling secret values
local function isTotemActive(have)
	if issecretvalue(have) then
		-- If it's a secret value, the totem exists
		return true
	end
	return have
end

function Totems:Update(frame)
	local numSlots = GetNumTotemSlots and GetNumTotemSlots() or MAX_TOTEMS
	local totalActive = 0
	for _, indicator in pairs(frame.totemBar.totems) do
		local have, _name, start, duration, icon
		local foundTotem = false
		local foundSlot

		if MAX_TOTEMS == 1 and indicator.id == 1 then
			for id = 1, numSlots do
				have, _name, start, duration, icon = GetTotemInfo(id)
				if isTotemActive(have) then
					foundTotem = true
					foundSlot = id
					break
				end
			end
		else
			have, _name, start, duration, icon = GetTotemInfo(indicator.id)
			foundTotem = isTotemActive(have)
			foundSlot = indicator.id
		end

		if foundTotem then
			if( ShadowUF.db.profile.units[frame.unitType].totemBar.icon ) then
				indicator:SetStatusBarTexture(icon)
			end

			indicator.have = true
			indicator.totemSlot = foundSlot

			
			indicator:SetMinMaxValues(0, duration)

			local timeLeft = GetTotemTimeLeft(foundSlot)
			if type(timeLeft) == "number" then
				indicator:SetValue(timeLeft)
				indicator:SetScript("OnUpdate", totemMonitor)
			else
				indicator:SetValue(0)
				indicator:SetScript("OnUpdate", nil)
			end
			indicator:SetAlpha(1.0)

			totalActive = totalActive + 1

		elseif( indicator.have ) then
			indicator.have = nil
			indicator.totemSlot = nil
			indicator:SetScript("OnUpdate", nil)
			indicator:SetMinMaxValues(0, 1)
			indicator:SetValue(0)
		end

		if( indicator.fontString ) then
			indicator.fontString:UpdateTags()
		end
	end

	if( not frame.inVehicle ) then
		if( MAX_TOTEMS == 1 or not ShadowUF.db.profile.units[frame.unitType].totemBar.showAlways ) then
			ShadowUF.Layout:SetBarVisibility(frame, "totemBar", totalActive > 0)
		end
	end
end
