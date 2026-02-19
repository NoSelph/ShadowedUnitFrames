local Highlight = {}
local goldColor, mouseColor = {r = 0.75, g = 0.75, b = 0.35}, {r = 0.75, g = 0.75, b = 0.50}
local rareColor, eliteColor = {r = 0, g = 0.63, b = 1}, {r = 1, g = 0.81, b = 0}

ShadowUF:RegisterModule(Highlight, "highlight", ShadowUF.L["Highlight"])

-- 12.0: ColorCurve for dispellable debuff highlighting
local highlightColorCurve = nil

function Highlight:GetColorCurve()
	if highlightColorCurve then
		return highlightColorCurve
	end

	if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then
		return nil
	end

	local curve = C_CurveUtil.CreateColorCurve()
	local E = Enum and Enum.AuraDispelType
	local noneID = (E and E.None) or 0
	local magicID = (E and E.Magic) or 1
	local curseID = (E and E.Curse) or 2
	local diseaseID = (E and E.Disease) or 3
	local poisonID = (E and E.Poison) or 4

	if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
		curve:SetType(Enum.LuaCurveType.Step)
	end

	-- RAID_PLAYER_DISPELLABLE already filters by class, so all types get full alpha
	curve:AddPoint(noneID, CreateColor(0.8, 0, 0, 1))
	curve:AddPoint(magicID, CreateColor(0.2, 0.6, 1, 1))
	curve:AddPoint(curseID, CreateColor(0.6, 0, 1, 1))
	curve:AddPoint(diseaseID, CreateColor(0.6, 0.4, 0, 1))
	curve:AddPoint(poisonID, CreateColor(0, 0.6, 0, 1))

	if curve.SetMinMaxValues then
		curve:SetMinMaxValues(0, 255)
	end

	highlightColorCurve = curve
	return curve
end

-- Might seem odd to hook my code in the core manually, but HookScript is ~40% slower due to it being a secure hook
local function OnEnter(frame)
	if( ShadowUF.db.profile.units[frame.unitType].highlight.mouseover ) then
		frame.highlight.hasMouseover = true
		Highlight:Update(frame)
	end

	frame.highlight.OnEnter(frame)
end

local function OnLeave(frame)
	if( ShadowUF.db.profile.units[frame.unitType].highlight.mouseover ) then
		frame.highlight.hasMouseover = nil
		Highlight:Update(frame)
	end

	frame.highlight.OnLeave(frame)
end

function Highlight:OnEnable(frame)
	if( not frame.highlight ) then
		frame.highlight = CreateFrame("Frame", nil, frame)
		frame.highlight:SetFrameLevel(frame.topFrameLevel)
		frame.highlight:SetAllPoints(frame)
		frame.highlight:SetSize(1, 1)

		frame.highlight.top = frame.highlight:CreateTexture(nil, "OVERLAY")
		frame.highlight.top:SetBlendMode("ADD")
		frame.highlight.top:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
		frame.highlight.top:SetPoint("TOPLEFT", frame, ShadowUF.db.profile.backdrop.inset, -ShadowUF.db.profile.backdrop.inset)
		frame.highlight.top:SetPoint("TOPRIGHT", frame, -ShadowUF.db.profile.backdrop.inset, ShadowUF.db.profile.backdrop.inset)
		frame.highlight.top:SetHeight(30)
		frame.highlight.top:SetTexCoord(0.3125, 0.625, 0, 0.3125)
		frame.highlight.top:SetHorizTile(false)

		frame.highlight.left = frame.highlight:CreateTexture(nil, "OVERLAY")
		frame.highlight.left:SetBlendMode("ADD")
		frame.highlight.left:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
		frame.highlight.left:SetPoint("TOPLEFT", frame, ShadowUF.db.profile.backdrop.inset, -ShadowUF.db.profile.backdrop.inset)
		frame.highlight.left:SetPoint("BOTTOMLEFT", frame, -ShadowUF.db.profile.backdrop.inset, ShadowUF.db.profile.backdrop.inset)
		frame.highlight.left:SetWidth(30)
		frame.highlight.left:SetTexCoord(0, 0.3125, 0.3125, 0.625)
		frame.highlight.left:SetHorizTile(false)

		frame.highlight.right = frame.highlight:CreateTexture(nil, "OVERLAY")
		frame.highlight.right:SetBlendMode("ADD")
		frame.highlight.right:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
		frame.highlight.right:SetPoint("TOPRIGHT", frame, -ShadowUF.db.profile.backdrop.inset, -ShadowUF.db.profile.backdrop.inset)
		frame.highlight.right:SetPoint("BOTTOMRIGHT", frame, 0, ShadowUF.db.profile.backdrop.inset)
		frame.highlight.right:SetWidth(30)
		frame.highlight.right:SetTexCoord(0.625, 0.93, 0.3125, 0.625)
		frame.highlight.right:SetHorizTile(false)

		frame.highlight.bottom = frame.highlight:CreateTexture(nil, "OVERLAY")
		frame.highlight.bottom:SetBlendMode("ADD")
		frame.highlight.bottom:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
		frame.highlight.bottom:SetPoint("BOTTOMLEFT", frame, ShadowUF.db.profile.backdrop.inset, ShadowUF.db.profile.backdrop.inset)
		frame.highlight.bottom:SetPoint("BOTTOMRIGHT", frame, -ShadowUF.db.profile.backdrop.inset, ShadowUF.db.profile.backdrop.inset)
		frame.highlight.bottom:SetHeight(30)
		frame.highlight.bottom:SetTexCoord(0.3125, 0.625, 0.625, 0.93)
		frame.highlight.bottom:SetHorizTile(false)
		frame.highlight:Hide()
	end

	frame.highlight.top:SetHeight(ShadowUF.db.profile.units[frame.unitType].highlight.size)
	frame.highlight.bottom:SetHeight(ShadowUF.db.profile.units[frame.unitType].highlight.size)
	frame.highlight.left:SetWidth(ShadowUF.db.profile.units[frame.unitType].highlight.size)
	frame.highlight.right:SetWidth(ShadowUF.db.profile.units[frame.unitType].highlight.size)


	if( ShadowUF.db.profile.units[frame.unitType].highlight.aggro ) then
		frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateThreat")
		frame:RegisterUpdateFunc(self, "UpdateThreat")
	end

	if( ShadowUF.db.profile.units[frame.unitType].highlight.attention and frame.unitType ~= "target" and frame.unitType ~= "focus" ) then
		frame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "UpdateAttention")
		frame:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "UpdateAttention")
		frame:RegisterUpdateFunc(self, "UpdateAttention")
	end

	if( ShadowUF.db.profile.units[frame.unitType].highlight.debuff ) then
		frame:RegisterUnitEvent("UNIT_AURA", self, "UpdateAura")
		frame:RegisterUpdateFunc(self, "UpdateAura")
	end

	if( ShadowUF.db.profile.units[frame.unitType].highlight.mouseover and not frame.highlight.OnEnter ) then
		frame.highlight.OnEnter = frame.OnEnter
		frame.highlight.OnLeave = frame.OnLeave

		frame.OnEnter = OnEnter
		frame.OnLeave = OnLeave
	end

	if( ShadowUF.db.profile.units[frame.unitType].highlight.rareMob or ShadowUF.db.profile.units[frame.unitType].highlight.eliteMob ) then
		frame:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", self, "UpdateClassification")
		frame:RegisterUpdateFunc(self, "UpdateClassification")
	end
end

function Highlight:OnLayoutApplied(frame)
	if( frame.visibility.highlight ) then
		self:OnDisable(frame)
		self:OnEnable(frame)
	end
end

function Highlight:OnDisable(frame)
	frame:UnregisterAll(self)

	frame.highlight.hasDebuffColor = nil
	frame.highlight.hasThreat = nil
	frame.highlight.hasAttention = nil
	frame.highlight.hasMouseover = nil

	frame.highlight:Hide()

	if( frame.highlight.OnEnter ) then
		frame.OnEnter = frame.highlight.OnEnter
		frame.OnLeave = frame.highlight.OnLeave

		frame.highlight.OnEnter = nil
		frame.highlight.OnLeave = nil
	end
end

function Highlight:Update(frame)
	local color
	local useSecretColor = false
	
	if frame.highlight.hasDebuffColor then
		useSecretColor = true
		color = frame.highlight.hasDebuffColor
	elseif frame.highlight.hasThreat then
		color = ShadowUF.db.profile.healthColors.hostile
	elseif frame.highlight.hasAttention then
		color = goldColor
	elseif frame.highlight.hasMouseover then
		color = mouseColor
	elseif ShadowUF.db.profile.units[frame.unitType].highlight.rareMob and ( frame.highlight.hasClassification == "rareelite" or frame.highlight.hasClassification == "rare" ) then
		color = rareColor
	elseif ShadowUF.db.profile.units[frame.unitType].highlight.eliteMob and frame.highlight.hasClassification == "elite" then
		color = eliteColor
	end

	if color then
		local r, g, b, a
		if useSecretColor then
			-- Secret color from ColorCurve
			r, g, b, a = color:GetRGBA()
		else
			-- Regular color table
			r, g, b = color.r, color.g, color.b
			a = ShadowUF.db.profile.units[frame.unitType].highlight.alpha
		end
		
		frame.highlight.top:SetVertexColor(r, g, b, a)
		frame.highlight.left:SetVertexColor(r, g, b, a)
		frame.highlight.bottom:SetVertexColor(r, g, b, a)
		frame.highlight.right:SetVertexColor(r, g, b, a)
		frame.highlight:Show()
	else
		frame.highlight:Hide()
	end
end

function Highlight:UpdateThreat(frame)
	frame.highlight.hasThreat = UnitThreatSituation(frame.unit) == 3 or nil
	self:Update(frame)
end

function Highlight:UpdateAttention(frame)
	frame.highlight.hasAttention = UnitIsUnit(frame.unit, "target") or UnitIsUnit(frame.unit, "focus") or nil
	self:Update(frame)
end

function Highlight:UpdateClassification(frame)
	frame.highlight.hasClassification = UnitClassification(frame.unit)
	self:Update(frame)
end

function Highlight:UpdateAura(frame)
	frame.highlight.hasDebuffColor = nil
	
	if not UnitIsFriend(frame.unit, "player") then
		self:Update(frame)
		return
	end
	
	-- 12.0: Use RAID_PLAYER_DISPELLABLE filter + ColorCurve for dispellable debuff highlighting
	local curve = self:GetColorCurve()
	if not curve or not C_UnitAuras.GetAuraDispelTypeColor then
		self:Update(frame)
		return
	end

	-- GetAuraSlots rejects compound unit tokens and player names
	local results = {pcall(C_UnitAuras.GetAuraSlots, frame.unit, "HARMFUL|RAID_PLAYER_DISPELLABLE")}
	if not results[1] then
		self:Update(frame)
		return
	end
	for i = 3, #results do
		local auraData = C_UnitAuras.GetAuraDataBySlot(frame.unit, results[i])
		if auraData and auraData.auraInstanceID then
			local color = C_UnitAuras.GetAuraDispelTypeColor(frame.unit, auraData.auraInstanceID, curve)
			if color then
				frame.highlight.hasDebuffColor = color
				break
			end
		end
	end

	self:Update(frame)
end

