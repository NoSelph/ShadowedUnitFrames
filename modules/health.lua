local Health = {}
ShadowUF:RegisterModule(Health, "healthBar", ShadowUF.L["Health bar"], true)

local function getGradientColor(unit)
	if not ShadowUF.db or not ShadowUF.db.profile or not ShadowUF.db.profile.healthColors then
		-- DB not ready yet; safe fallback.
		return 0, 1, 0
	end

	-- Cache curve and rebuild only when profile colors change.
	Health._gradientCurve = Health._gradientCurve or nil

	local hc = ShadowUF.db.profile.healthColors
	local changed = not Health._gradientCurve
		or Health._gcRR ~= hc.red.r or Health._gcRG ~= hc.red.g or Health._gcRB ~= hc.red.b
		or Health._gcYR ~= hc.yellow.r or Health._gcYG ~= hc.yellow.g or Health._gcYB ~= hc.yellow.b
		or Health._gcGR ~= hc.green.r or Health._gcGG ~= hc.green.g or Health._gcGB ~= hc.green.b

	if changed then
		Health._gcRR, Health._gcRG, Health._gcRB = hc.red.r, hc.red.g, hc.red.b
		Health._gcYR, Health._gcYG, Health._gcYB = hc.yellow.r, hc.yellow.g, hc.yellow.b
		Health._gcGR, Health._gcGG, Health._gcGB = hc.green.r, hc.green.g, hc.green.b

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
		if ok and type(color) == "table" and color.GetRGB then
			return color:GetRGB()
		end
	end

	-- Fallback: solid green
	return hc.green.r, hc.green.g, hc.green.b
end

Health.getGradientColor = getGradientColor

-- A hidden AuraSlot drives a colored overlay stretched over the health bar when a player-dispellable debuff is up
-- Blizzard handle the rest, we never read aura data
local function containersAvailable()
	local auras = ShadowUF.modules.auras
	return auras and auras.hasContainers
end

local pendingDispelSlots = {}
local dispelRegenWatcher
local function queueDispelSlot(frame)
	pendingDispelSlots[frame] = true
	if( not dispelRegenWatcher ) then
		dispelRegenWatcher = CreateFrame("Frame")
		dispelRegenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		dispelRegenWatcher:SetScript("OnEvent", function()
			for pendingFrame in pairs(pendingDispelSlots) do
				pendingDispelSlots[pendingFrame] = nil
				Health:UpdateDispelSlot(pendingFrame)
			end
		end)
	end
end

-- Each mode flips between debuffs on units we can assist and purgeable/soothable buffs on the rest.
-- There is no player-scoped token for buffs, harmful+raid for debuffs
local DISPEL_FILTERS = {
	PLAYER_DISPELLABLE = { assist = "HARMFUL|RAID", noassist = "HELPFUL|RAID_PLAYER_DISPELLABLE" },
	RAID_PLAYER_DISPELLABLE = { assist = "HARMFUL|RAID_PLAYER_DISPELLABLE", noassist = "HELPFUL|RAID_PLAYER_DISPELLABLE" },
	DISPELLABLE = { assist = "HARMFUL|DISPELLABLE", noassist = "HELPFUL|DISPELLABLE" },
}

-- Old configs stored a boolean, true was the player-scoped behavior
local function getDispelFilters(value)
	if( value == true ) then value = "PLAYER_DISPELLABLE" end
	return value and DISPEL_FILTERS[value]
end
Health.GetDispelFilters = getDispelFilters

-- UnitCanAssist can return secret booleans on restricted maps, nil means unreadable
local function isUnitAssist(unit)
	local ok, assist = pcall(UnitCanAssist, "player", unit)
	if( not ok or issecretvalue(assist) ) then return nil end
	return assist and true or false
end
Health.IsUnitAssist = isUnitAssist

local function createDispelSlot(frame, dispelFilter)
	if( frame.healthBar.dispelSlot ) then return true end
	-- AuraContainer creation is a Lua error in combat, retry after regen
	if( InCombatLockdown() ) then
		queueDispelSlot(frame)
		return false
	end

	pcall(function()
		local container = CreateFrame("AuraContainer", nil, frame.healthBar, "CustomAuraContainerTemplate")
		container:SetPoint("TOPLEFT", frame.healthBar)
		container:SetSize(1, 1)

		local slotButton = container:AddAuraSlot("dispel", dispelFilter, {
			initializeFrame = function(button)
				-- Anchoring must happen here, after creation the button is forbidden whenever auras are secret (M+ reload included)
				button:ClearAllPoints()
				button:SetAllPoints(frame.healthBar)
				button:SetFrameLevel(frame.healthBar:GetFrameLevel() + 2)

				local overlay = button:CreateTexture(nil, "OVERLAY")
				-- Tint only the filled portion, anchoring to the status bar texture keeps the actual health amount readable
				local fill = frame.healthBar.GetStatusBarTexture and frame.healthBar:GetStatusBarTexture()
				overlay:SetAllPoints(fill or button)
				overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
				-- Keep the health fill readable under the dispel tint
				overlay:SetAlpha(0.5)
				-- PreserveAsset tints our overlay texture by dispel type
				pcall(button.SetAuraBorder, button, overlay, { style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3, showWhenHarmful = true, showWhenHelpful = true, customDispelColorMap = ShadowUF.modules.auras.GetDispelColorMap and ShadowUF.modules.auras:GetDispelColorMap() or nil })
				button:SetMouseMotionEnabled(false)
			end,
		})

		frame.healthBar.dispelSlot = container
		frame.healthBar.dispelSlotFilter = dispelFilter
		frame.healthBar.dispelColorsKey = ShadowUF.modules.auras.GetDispelColorsKey and ShadowUF.modules.auras:GetDispelColorsKey() or ""

	end)
	return frame.healthBar.dispelSlot ~= nil
end

function Health:UpdateDispelSlot(frame)
	local filters = getDispelFilters(ShadowUF.db.profile.units[frame.unitType].healthBar.colorDispel)
	if( not filters ) then
		local container = frame.healthBar.dispelSlot
		if( container ) then
			container:SetEnabled(false)
			if( not InCombatLockdown() ) then container:Hide() end
		end
		return
	end

	-- Border colors are frozen at creation, a palette change retires the slot so it gets rebuilt with the new colors (out of restrictions only)
	local auras = ShadowUF.modules.auras
	local colorsKey = auras.GetDispelColorsKey and auras:GetDispelColorsKey() or ""
	if( frame.healthBar.dispelSlot and frame.healthBar.dispelColorsKey ~= colorsKey
		and not InCombatLockdown() and not (auras.AurasAreSecret and auras.AurasAreSecret()) ) then
		frame.healthBar.dispelSlot:SetEnabled(false)
		frame.healthBar.dispelSlot:Hide()
		frame.healthBar.dispelSlot = nil
	end

	if( not frame.healthBar.dispelSlot and not createDispelSlot(frame, filters.assist) ) then return end

	local container = frame.healthBar.dispelSlot
	local inCombat = InCombatLockdown()

	-- Pick the side matching the unit's reaction, keep the current filter while it's unreadable
	local dispelFilter = frame.healthBar.dispelSlotFilter or filters.assist
	if( frame.unit and not frame.configMode ) then
		local assist = isUnitAssist(frame.unit)
		if( assist == true ) then
			dispelFilter = filters.assist
		elseif( assist == false ) then
			dispelFilter = filters.noassist
		end
	end

	-- Slot filter strings are runtime-mutable, mode and reaction switches apply live
	if( frame.healthBar.dispelSlotFilter ~= dispelFilter ) then
		if( pcall(container.SetAuraSlotFilterString, container, "dispel", dispelFilter) ) then
			frame.healthBar.dispelSlotFilter = dispelFilter
		end
	end
	if( frame.unit and not frame.configMode ) then
		local ok = pcall(container.SetUnit, container, frame.unit)
		container:SetEnabled(ok and true or false)
		if( ok ) then
			if( not inCombat ) then container:Show() end
			pcall(container.UpdateAllAuras, container)
		elseif( not inCombat ) then
			container:Hide()
		end
	else
		container:SetEnabled(false)
		if( not inCombat ) then container:Hide() end
	end
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

	local colorDispel = ShadowUF.db.profile.units[frame.unitType].healthBar.colorDispel
	if( containersAvailable() ) then
		if( getDispelFilters(colorDispel) ) then
			-- The slot self-updates, we only track unit identity
			-- UNIT_FACTION re-runs the friendliness gate (MC, duels)
			frame:RegisterUpdateFunc(self, "UpdateDispelSlot")
			frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateDispelSlot")
		elseif( frame.healthBar.dispelSlot ) then
			-- Option turned off, silence the existing slot container
			frame.healthBar.dispelSlot:SetEnabled(false)
			if( not InCombatLockdown() ) then frame.healthBar.dispelSlot:Hide() end
		end
	end

	frame:RegisterUpdateFunc(self, "UpdateColor")
	frame:RegisterUpdateFunc(self, "Update")
end

function Health:OnDisable(frame)
	frame:UnregisterAll(self)
	if( frame.healthBar and frame.healthBar.dispelSlot ) then
		frame.healthBar.dispelSlot:SetEnabled(false)
		frame.healthBar.dispelSlot:Hide()
	end
end

-- A secret class token can't index our color tables, but C_ClassColor.GetClassColor takes secrets and SetBlockColor does no arithmetic on r/g/b
-- So the Blizzard palette color applies directly, custom profile class colors stay out-of-combat only
local function applySecretClassColor(frame, unit)
	if( not (C_ClassColor and C_ClassColor.GetClassColor and issecretvalue) ) then return false end

	local class = select(2, UnitClass(unit))
	if( not issecretvalue(class) ) then return false end

	local ok, classColor = pcall(C_ClassColor.GetClassColor, class)
	if( not ok or not classColor ) then return false end

	frame:SetBarColor("healthBar", classColor:GetRGB())
	return true
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
		else
			local reaction = UnitReaction(unit, "player")
			if reaction then
				if( reaction > 4 ) then
					color = ShadowUF.db.profile.healthColors.friendly
				elseif( reaction == 4 ) then
					color = ShadowUF.db.profile.healthColors.neutral
				else
					color = ShadowUF.db.profile.healthColors.hostile
				end
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].healthBar.colorType == "class" and (UnitIsPlayer(unit) or unit == "pet" or UnitPlayerOrPetInRaid(unit) or UnitPlayerOrPetInParty(unit)) ) then
		local class = (unit == "pet") and "PET" or frame:UnitClassToken()
		color = class and ShadowUF.db.profile.classColors[class]
		if( not color and unit ~= "pet" and applySecretClassColor(frame, unit) ) then
			return
		end
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
			-- Arena tokens have secret identities in combat
			if( issecretvalue and issecretvalue(class) ) then
				if( applySecretClassColor(frame, unit2) ) then return end
				class = nil
			end
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
	if( not unit or not UnitExists(unit) ) then return end

	local isOffline = not UnitIsConnected(unit)
	frame.isDead = UnitIsDeadOrGhost(unit)

	local okH, currentHealth = pcall(UnitHealth, unit)
	local okM, maxHealth = pcall(UnitHealthMax, unit)
	if( not okH or not okM ) then return end

	frame.healthBar.currentHealth = currentHealth
	frame.healthBar:SetMinMaxValues(0, maxHealth)

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
