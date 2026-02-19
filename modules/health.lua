local Health = {}
ShadowUF:RegisterModule(Health, "healthBar", ShadowUF.L["Health bar"], true)

local function getGradientColor(unit)
	if not ShadowUF.db or not ShadowUF.db.profile or not ShadowUF.db.profile.healthColors then
		-- DB not ready yet; safe fallback.
		return 0, 1, 0
	end

	-- Cache curve and rebuild only when profile colors change.
	Health._gradientKey = Health._gradientKey or nil
	Health._gradientCurve = Health._gradientCurve or nil

	local hc = ShadowUF.db.profile.healthColors
	local key = string.format(
		"%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f",
		hc.red.r, hc.red.g, hc.red.b,
		hc.yellow.r, hc.yellow.g, hc.yellow.b,
		hc.green.r, hc.green.g, hc.green.b
	)

	if not Health._gradientCurve or Health._gradientKey ~= key then
		Health._gradientKey = key

		if C_CurveUtil and C_CurveUtil.CreateColorCurve then
			local curve = C_CurveUtil.CreateColorCurve()
			curve:AddPoint(0.0, CreateColor(hc.red.r, hc.red.g, hc.red.b))
			curve:AddPoint(0.5, CreateColor(hc.yellow.r, hc.yellow.g, hc.yellow.b))
			curve:AddPoint(1.0, CreateColor(hc.green.r, hc.green.g, hc.green.b))
			Health._gradientCurve = curve
		else
			Health._gradientCurve = nil
		end
	end

	-- Curve Interpolation
	if UnitHealthPercent and Health._gradientCurve then
		local ok, color = pcall(UnitHealthPercent, unit, true, Health._gradientCurve)
		if ok and color and color.GetRGB then
			return color:GetRGB()
		end
	end

	-- Fallback: solid green
	return hc.green.r, hc.green.g, hc.green.b
end

Health.getGradientColor = getGradientColor

-- ColorCurve for dispellable debuff health bar coloring
local dispelColorCurve = nil

local function getDispelColorCurve()
	if dispelColorCurve then
		return dispelColorCurve
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

	-- Match DebuffTypeColor values
	curve:AddPoint(noneID, CreateColor(0.8, 0, 0, 1))
	curve:AddPoint(magicID, CreateColor(0.2, 0.6, 1, 1))
	curve:AddPoint(curseID, CreateColor(0.6, 0, 1, 1))
	curve:AddPoint(diseaseID, CreateColor(0.6, 0.4, 0, 1))
	curve:AddPoint(poisonID, CreateColor(0, 0.6, 0, 1))

	dispelColorCurve = curve
	return curve
end

function Health:OnEnable(frame)
	if( not frame.healthBar ) then
		frame.healthBar = ShadowUF.Units:CreateBar(frame)
	end
    
    -- ... (Listeners kept same)
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_CONNECTION", self, "Update")
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateColor")
	frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", self, "UpdateColor")
	frame:RegisterUnitEvent("UNIT_TARGETABLE_CHANGED", self, "UpdateColor")

	if( frame.unit == "pet" ) then
		frame:RegisterUnitEvent("UNIT_POWER_UPDATE", self, "UpdateColor")
	end

	if ( ShadowUF.db.profile.units[frame.unitType].healthBar.colorDispel ) then
		frame:RegisterUnitEvent("UNIT_AURA", self, "UpdateAura")
		frame:RegisterUpdateFunc(self, "UpdateAura")
	end
	
	frame:RegisterUpdateFunc(self, "UpdateColor")
	frame:RegisterUpdateFunc(self, "Update")
end

function Health:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Health:UpdateAura(frame)
	local hadDebuff = frame.healthBar.hasDebuffColor
	frame.healthBar.hasDebuffColor = nil

	if( UnitIsFriend(frame.unit, "player") ) then
		-- 12.0: Use RAID_PLAYER_DISPELLABLE filter + ColorCurve
		-- The filter already checks the player's class dispel capability
		local curve = getDispelColorCurve()
		if( curve and C_UnitAuras.GetAuraDispelTypeColor ) then
			local slots = {C_UnitAuras.GetAuraSlots(frame.unit, "HARMFUL|RAID_PLAYER_DISPELLABLE")}
			for i = 2, #slots do
				local auraData = C_UnitAuras.GetAuraDataBySlot(frame.unit, slots[i])
				if( auraData and auraData.auraInstanceID ) then
					local color = C_UnitAuras.GetAuraDispelTypeColor(frame.unit, auraData.auraInstanceID, curve)
					if( color ) then
						frame.healthBar.hasDebuffColor = color
						break
					end
				end
			end
		end
	end

	-- Compare references: nil vs nil = no change, otherwise always update
	if( hadDebuff ~= frame.healthBar.hasDebuffColor ) then
		self:UpdateColor(frame)
	end
end

function Health:UpdateColor(frame)
	frame.healthBar.hasReaction = nil
	frame.healthBar.hasPercent = nil
	frame.healthBar.wasOffline = nil

	local color
	local unit = frame.unit
	local reactionType = ShadowUF.db.profile.units[frame.unitType].healthBar.reactionType
	if( not UnitIsConnected(unit) ) then
		frame.healthBar.wasOffline = true
		frame:SetBarColor("healthBar", ShadowUF.db.profile.healthColors.offline.r, ShadowUF.db.profile.healthColors.offline.g, ShadowUF.db.profile.healthColors.offline.b)
		return
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorDispel and frame.healthBar.hasDebuffColor ) then
		-- 12.0: Color from GetAuraDispelTypeColor (may contain secret RGB, accepted by SetVertexColor)
		local r, g, b = frame.healthBar.hasDebuffColor:GetRGB()
		frame:SetBarColor("healthBar", r, g, b)
		return
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorAggro and UnitThreatSituation(frame.unit) == 3 ) then
		frame:SetBarColor("healthBar", ShadowUF.db.profile.healthColors.aggro.r, ShadowUF.db.profile.healthColors.aggro.g, ShadowUF.db.profile.healthColors.aggro.b)
		return
	elseif( frame.inVehicle ) then
		color = ShadowUF.db.profile.classColors.VEHICLE
	elseif( not UnitPlayerControlled(unit) and UnitIsTapDenied(unit) and UnitCanAttack("player", unit) ) then
		color = ShadowUF.db.profile.healthColors.tapped
	elseif( not UnitPlayerOrPetInRaid(unit) and not UnitPlayerOrPetInParty(unit) and ( ( ( reactionType == "player" or reactionType == "both" ) and UnitPlayerControlled(unit) and not UnitIsFriend(unit, "player") ) or ( ( reactionType == "npc" or reactionType == "both" )  and not UnitPlayerControlled(unit) ) ) ) then
		if( not UnitIsFriend(unit, "player") and UnitPlayerControlled(unit) ) then
			if( UnitCanAttack("player", unit) ) then
				color = ShadowUF.db.profile.healthColors.hostile
			else
				color = ShadowUF.db.profile.healthColors.enemyUnattack
			end
		elseif( UnitReaction(unit, "player") ) then
			local reaction = UnitReaction(unit, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColors.friendly
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColors.neutral
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColors.hostile
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "class" and (UnitIsPlayer(unit) or unit == "pet") ) then
		local class = (unit == "pet") and "PET" or frame:UnitClassToken()
		color = class and ShadowUF.db.profile.classColors[class]
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "playerclass" and unit == "pet") then
		local class = select(2, UnitClass("player"))
		color = class and ShadowUF.db.profile.classColors[class]
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "playerclass" and (frame.unitType == "partypet" or frame.unitType == "raidpet" or frame.unitType == "arenapet") and (frame.parent or frame.unitType == "raidpet") ) then
		local unit2
		if frame.unitType == "raidpet" then
			local id = string.match(frame.unit, "raidpet(%d+)")
			if id then
				unit2 = "raid" .. id
			end
		elseif frame.parent then
			unit2 = frame.parent.unit
		end
		if unit2 then
			local class = select(2, UnitClass(unit2))
			color = class and ShadowUF.db.profile.classColors[class]
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "static" ) then
		color = ShadowUF.db.profile.healthColors.static
	end

	if( color ) then
		frame:SetBarColor("healthBar", color.r, color.g, color.b)
	else
		frame.healthBar.hasPercent = true
		
		-- 12.0: Check for Curve
		local curve = getGradientColor(unit) -- Returns Curve or RGB values (multiple returns)
		if( type(curve) == "userdata" ) then
		    -- It is a Curve. Bypass SetBarColor to avoid crash.
		    -- Apply directly.
		    if( frame.healthBar.SetStatusBarColorCurve ) then
		        frame.healthBar:SetStatusBarColorCurve(curve)
		    elseif( frame.healthBar.SetColorCurve ) then
		        frame.healthBar:SetColorCurve(curve)
		    end
		    
		    -- Set static background (Cannot darken a secret curve)
		    -- Using a standard dark grey
		    if( frame.healthBar.background ) then
		        frame.healthBar.background:SetVertexColor(0.2, 0.2, 0.2, 1)
		    end
		else
		    -- Manual RGB (Legacy Fallback)
		    frame:SetBarColor("healthBar", getGradientColor(unit))
		end
	end
end

function Health:Update(frame)
	local unit = frame.unit
	local isOffline = not UnitIsConnected(unit)
	frame.isDead = UnitIsDeadOrGhost(unit)
	frame.healthBar.currentHealth = UnitHealth(unit)
	frame.healthBar:SetMinMaxValues(0, UnitHealthMax(unit))

	-- Safe SetValue
	local isDead = UnitIsDeadOrGhost(unit)
	local isConnected = UnitIsConnected(unit)
	local val = isDead and 0 or not isConnected and 0 or frame.healthBar.currentHealth
	
	-- Try to set the value directly (even if secret).
	pcall(frame.healthBar.SetValue, frame.healthBar, val)

	-- Unit is offline, fill bar up + grey it
	if( isOffline ) then
		frame.healthBar.wasOffline = true
		frame.unitIsOnline = nil
		frame:SetBarColor("healthBar", ShadowUF.db.profile.healthColors.offline.r, ShadowUF.db.profile.healthColors.offline.g, ShadowUF.db.profile.healthColors.offline.b)
	-- The unit was offline, but they no longer are so we need to do a forced color update
	elseif( frame.healthBar.wasOffline ) then
		frame.healthBar.wasOffline = nil
		self:UpdateColor(frame)
	-- Color health by percentage
	elseif( frame.healthBar.hasPercent ) then
		-- 12.0: Check for Curve
		local curve = getGradientColor(frame.unit)
		if( type(curve) == "userdata" ) then
		    -- Curve Logic
		    if( frame.healthBar.SetStatusBarColorCurve ) then
		        frame.healthBar:SetStatusBarColorCurve(curve)
		    elseif( frame.healthBar.SetColorCurve ) then
		        frame.healthBar:SetColorCurve(curve)
		    end
		    
		    -- Background update not needed here as UpdateColor handles it, 
		    -- but to be safe and consistent with non-UpdateColor flows:
		    if( frame.healthBar.background ) then
		         frame.healthBar.background:SetVertexColor(0.2, 0.2, 0.2, 1)
		    end
		else
		    -- Manual Logic
		    frame:SetBarColor("healthBar", getGradientColor(frame.unit))
		end
	end
end
