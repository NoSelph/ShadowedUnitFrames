-- I am undecided if this is a brilliant idea or an insane one
local L = ShadowUF.L
local Movers = {}
local originalEnvs = {}
local unitConfig = {}
local attributeBlacklist = {["showplayer"] = true, ["showraid"] = true, ["showparty"] = true, ["showsolo"] = true, ["initial-unitwatch"] = true}
local playerClass = select(2, UnitClass("player"))
local noop = function() end
local OnDragStop, OnDragStart, configEnv, teardownTestFrame
local testConfigEnv
local testOriginalEnvs = {}
ShadowUF:RegisterModule(Movers, "movers")

-- This is the fun part, the env to fake units and make them show up as examples
local function getValue(func, unit, value)
	unit = string.gsub(unit, "(%d+)", "")
	if( unitConfig[func .. unit] == nil ) then unitConfig[func .. unit] = value end
	return unitConfig[func .. unit]
end

local function createConfigEnv()
	if( configEnv ) then return end
	configEnv = setmetatable({
		GetRaidTargetIndex = function(unit) return getValue("GetRaidTargetIndex", unit, math.random(1, 8)) end,
		GetLootMethod = function(unit) return "master", 0, 0 end,
		GetComboPoints = function() return MAX_COMBO_POINTS end,
		UnitInRaid = function() return true end,
		UnitInParty = function() return true end,
		UnitIsUnit = function(unitA, unitB) return unitB == "player" and true or false end,
		UnitIsDeadOrGhost = function(unit) return false end,
		UnitIsConnected = function(unit) return true end,
		UnitLevel = function(unit) return GetMaxLevelForPlayerExpansion() end,
		UnitIsPlayer = function(unit) return unit ~= "boss" and unit ~= "pet" and not string.match(unit, "(%w+)pet") end,
		UnitHealth = function(unit) return getValue("UnitHealth", unit, math.random(20000, 50000)) end,
		UnitIsQuestBoss = function(unit) return unit == "target" or unit == "focus" end,
		UnitIsWildBattlePet = function(unit) return unit == "target" or unit == "focus" end,
		UnitBattlePetType = function(unit)
			if( unit == "target" or unit == "focus" ) then
				return getValue("UnitBattlePetType", unit, math.random(#(PET_TYPE_SUFFIX)))
			end
		end,
		GetArenaOpponentSpec = function(unitID)
			return getValue("GetArenaOpponentSpec", unitID, math.random(250, 270))
		end,
		UnitHealthMax = function(unit) return 50000 end,
		UnitPower = function(unit, powerType)
			if( powerType == Enum.PowerType.HolyPower or powerType == Enum.PowerType.SoulShards or powerType == Enum.PowerType.Essence ) then
				return 3
			elseif( powerType == Enum.PowerType.Chi) then
				return 4
			end

			return getValue("UnitPower", unit, math.random(20000, 50000))
		end,
		UnitGetTotalHealAbsorbs = function(unit)
			return getValue("UnitGetTotalHealAbsorbs", unit, math.random(5000, 10000))
		end,
		UnitGetIncomingHeals = function(unit)
			return getValue("UnitGetIncomingHeals", unit, math.random(10000, 15000))
		end,
		UnitGetTotalAbsorbs = function(unit)
			return getValue("UnitGetTotalAbsorbs", unit, math.random(2500, 5000))
		end,
		UnitGetDetailedHealPrediction = function(unit, healerUnit, calculator)
			local unitKey = string.gsub(unit, "(%d+)", "")
			calculator:SetPredictedValues({
				health = getValue("UnitHealth", unitKey, math.random(20000, 50000)),
				healthMax = 50000,
				totalIncomingHeals = getValue("UnitGetIncomingHeals", unitKey, math.random(10000, 15000)),
				totalIncomingHealsFromHealer = 0,
				totalDamageAbsorbs = getValue("UnitGetTotalAbsorbs", unitKey, math.random(2500, 5000)),
				totalHealAbsorbs = getValue("UnitGetTotalHealAbsorbs", unitKey, math.random(5000, 10000)),
			})
		end,
		UnitPowerMax = function(unit, powerType)
			if( powerType == Enum.PowerType.Rage or powerType == Enum.PowerType.Energy or powerType == Enum.PowerType.RunicPower
			 or powerType == Enum.PowerType.LunarPower or powerType == Enum.PowerType.Maelstrom or powerType == Enum.PowerType.Insanity
			 or powerType == Enum.PowerType.Fury or powerType == Enum.PowerType.Pain ) then
				return 100
			elseif( powerType == Enum.PowerType.Focus ) then
				return 120
			elseif( powerType == Enum.PowerType.ComboPoints or powerType == Enum.PowerType.SoulShards or powerType == Enum.PowerType.HolyPower
			     or powerType == Enum.PowerType.Chi or powerType == Enum.PowerType.Essence ) then
				return 5
			elseif( powerType == Enum.PowerType.Runes ) then
				return 6
			elseif( powerType == Enum.PowerType.ArcaneCharges ) then
				return 4
			end

			return 50000
		end,
		UnitHasIncomingResurrection = function(unit) return true end,
		UnitInOtherParty = function(unit) return getValue("UnitInOtherParty", unit, math.random(0, 1) == 1) end,
		UnitPhaseReason = function(unit) return nil end,
		UnitExists = function(unit) return true end,
		UnitGUID = function(unit) return "Player-0-00000000" end,
		UnitPowerPercent = function(unit, powerType, unmodified, curve) return getValue("UnitPowerPercent", unit, math.random(20, 100)) end,
		UnitHealthPercent = function(unit, usePredicted, curve) return getValue("UnitHealthPercent", unit, math.random(20, 100)) end,
		UnitHealthMissing = function(unit) return getValue("UnitHealthMissing", unit, math.random(5000, 15000)) end,
		UnitPowerMissing = function(unit) return getValue("UnitPowerMissing", unit, math.random(5000, 15000)) end,
		UnitIsGroupLeader = function() return true end,
		UnitIsPVP = function(unit) return true end,
		UnitIsDND = function(unit) return false end,
		UnitIsAFK = function(unit) return false end,
		UnitFactionGroup = function(unit) return _G.UnitFactionGroup("player") end,
		UnitAffectingCombat = function() return true end,
		UnitThreatSituation = function() return 0 end,
		UnitDetailedThreatSituation = function() return nil end,
		UnitCastingInfo = function(unit)
			-- 1 -> 10: spell, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID
			local data = unitConfig["UnitCastingInfo" .. unit] or {}
			if( not data[5] or GetTime() < data[5] ) then
				data[1] = L["Test spell"]
				data[2] = L["Test spell"]
				data[3] = "Interface\\Icons\\Spell_Nature_Rejuvenation"
				data[4] = GetTime() * 1000
				data[5] = data[4] + 60000
				data[6] = false
				data[7] = math.floor(GetTime())
				data[8] = math.random(0, 100) < 25
				data[9] = 1000
				unitConfig["UnitCastingInfo" .. unit] = data
			end

			return unpack(data)
		end,
		UnitIsFriend = function(unit) return unit ~= "target" and unit ~= ShadowUF.fakeUnits[unit] and unit ~= "arena" end,
		GetReadyCheckStatus = function(unit)
			local status = getValue("GetReadyCheckStatus", unit, math.random(1, 3))
			return status == 1 and "ready" or status == 2 and "notready" or "waiting"
		end,
		GetPartyAssignment = function(type, unit)
			local assignment = getValue("GetPartyAssignment", unit, math.random(1, 2) == 1 and "MAINTANK" or "MAINASSIST")
			return assignment == type
		end,
		UnitGroupRolesAssigned = function(unit)
			local role = getValue("UnitGroupRolesAssigned", unit, math.random(1, 3))
			return role == 1 and "TANK" or (role == 2 and "HEALER" or (role == 3 and "DAMAGER"))
		end,
		UnitPowerType = function(unit)
			local powerType = math.random(0, 4)
			powerType = getValue("UnitPowerType", unit, powerType == 4 and 6 or powerType)

			return powerType, powerType == 0 and "MANA" or powerType == 1 and "RAGE" or powerType == 2 and "FOCUS" or powerType == 3 and "ENERGY" or powerType == 6 and "RUNIC_POWER"
		end,
		UnitStagger = function(unit)
			if( unit ~= "player" ) then return nil end
			return getValue("UnitStagger", math.random(2000, 10000))
		end,
		UnitAura = function(unit, id, filter)
			if( type(id) ~= "number" or id > 40 ) then return end

			local texture = filter == "HELPFUL" and "Interface\\Icons\\Spell_Nature_Rejuvenation" or "Interface\\Icons\\Ability_DualWield"
			local mod = id % 5
			local auraType = mod == 0 and "Magic" or mod == 1 and "Curse" or mod == 2 and "Poison" or mod == 3 and "Disease" or "none"
			return L["Test Aura"], texture, id, auraType, 0, 0, "player", id % 6 == 0
		end,
		-- Modern WoW 11.0+ aura API mock
		AuraUtil = setmetatable({
			ForEachAura = function(unit, filter, maxCount, func, usePackedAura)
				-- Generate mock auras for preview
				local count = math.min(maxCount or 8, 8)
				for i = 1, count do
					local mod = i % 5
					local auraType = mod == 0 and "Magic" or mod == 1 and "Curse" or mod == 2 and "Poison" or mod == 3 and "Disease" or ""
					local isBuff = filter and string.find(filter, "HELPFUL")

					local auraData = {
						name = L["Test Aura"],
						icon = isBuff and "Interface\\Icons\\Spell_Nature_Rejuvenation" or "Interface\\Icons\\Ability_DualWield",
						applications = i % 3 == 0 and math.random(1, 5) or 0,
						dispelName = auraType ~= "" and auraType or nil,
						duration = 300,
						expirationTime = GetTime() + 300 - (i * 20),
						sourceUnit = i % 2 == 0 and "player" or "target",
						isStealable = isBuff and i % 4 == 0,
						isFromPlayerOrPlayerPet = i % 2 == 0,
						isBossAura = i % 7 == 0,
						spellId = 1000 + i,
						auraInstanceID = i,
						nameplateShowAll = true,
						canApplyAura = i % 3 == 0,
					}

					if usePackedAura then
						func(auraData)
					else
						func(auraData.name, auraData.icon, auraData.applications, auraData.dispelName,
							auraData.duration, auraData.expirationTime, auraData.sourceUnit, auraData.isStealable,
							false, auraData.spellId, false, auraData.isBossAura, auraData.isFromPlayerOrPlayerPet,
							false, false, auraData.auraInstanceID)
					end
				end
			end,
		}, { __index = _G.AuraUtil }),
		UnitName = function(unit)
			local unitID = string.match(unit, "(%d+)")
			if( unitID ) then
				return string.format("%s #%d", L.units[string.gsub(unit, "(%d+)", "")] or unit, unitID)
			end

			return L.units[unit]
		end,
		UnitClass = function(unit)
			local classToken = getValue("UnitClass", unit, CLASS_SORT_ORDER[math.random(1, #(CLASS_SORT_ORDER))])
			return LOCALIZED_CLASS_NAMES_MALE[classToken], classToken
		end,
	}, {
		__index = _G,
		__newindex = function(tbl, key, value) _G[key] = value end,
	})
end

-- Child units have to manually be added to the list to make sure they function properly
-- For the party header in placeholder mode, the 5th SGH child is always created (via startingIndex=-4) and represents the player slot when units.party.showPlayer is on.
local function prepareChildUnits(header, ...)
	local isParty = header.unitType == "party"
	local showPlayer = isParty and ShadowUF.db.profile.units.party.showPlayer

	for i=1, select("#", ...) do
		local frame = select(i, ...)
		if( frame.unitType ) then
			if( isParty and i == 5 ) then
				-- The extra slot used to mirror the live showPlayer behavior.
				-- We use a fake "party5" unit so testConfigEnv's digit-stripping routes API calls through the "party" testModeUnits entry and the standalone player frame stays unaffected.
				ShadowUF.Units.frameList[frame] = true
				frame.placeholderUnit = "party5"
				frame:SetAttribute("unit", "party5")

				if( showPlayer ) then
					if( frame.isPlaceholderHidden ) then
						frame.isPlaceholderHidden = nil
						frame:SetAttribute("statehidden", nil)
						UnregisterUnitWatch(frame)
						frame:SetAttribute("state-unitexists", true)
						frame:FullUpdate()
						frame:Show()
					end
				else
					frame.isPlaceholderHidden = true
					frame:SetAttribute("statehidden", true)
					UnregisterUnitWatch(frame)
					frame:Hide()
				end
			elseif( not frame.configUnitID and not frame.placeholderUnit ) then
				ShadowUF.Units.frameList[frame] = true
				frame.configUnitID = header.groupID and (header.groupID * 5) - 5 + i or i
				frame:SetAttribute("unit", ShadowUF[header.unitMappedType .. "Units"][frame.configUnitID])
			end
		end
	end
end

local function OnEnter(self)
	local tooltip = self.tooltipText or self.unitID and string.format("%s #%d", L.units[self.unitType], self.unitID) or L.units[self.unit] or self.unit
	local additionalText = ShadowUF.Units.childUnits[self.unitType] and L["Child units cannot be dragged, you will have to reposition them through /shadowuf."]

	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(tooltip, 1, 0.81, 0, 1, true)
	if( additionalText ) then GameTooltip:AddLine(additionalText, 0.90, 0.90, 0.90, 1) end
	GameTooltip:Show()
end

local function OnLeave(self)
	GameTooltip:Hide()
end

-- Unlocking every frame at once blows past one execution's CPU budget
-- Steps are queued per module (unit type) and drained over as many ticks as needed
local STAGE_BUDGET = 6
local stageQueue, stageHead, stageTail, stageDriver = {}, 1, 0

local function queueStage(step)
	stageTail = stageTail + 1
	stageQueue[stageTail] = step
end

local function runStages()
	-- Combat can start mid drain, the remaining steps are protected calls and the lock watcher restores everything anyway
	if( InCombatLockdown() ) then
		stageQueue, stageHead, stageTail = {}, 1, 0
		stageDriver:Hide()
		return
	end

	local started = debugprofilestop()
	while( stageHead <= stageTail ) do
		local step = stageQueue[stageHead]
		stageQueue[stageHead] = nil
		stageHead = stageHead + 1

		-- A step with more work than fits a slice hands back a continuation, it goes in front to keep phase order
		local continuation = step()
		if( continuation ) then
			stageHead = stageHead - 1
			stageQueue[stageHead] = continuation
		end

		-- Another addon can restart the profiler under us, a negative delta just ends the slice
		local elapsed = debugprofilestop() - started
		if( elapsed < 0 or elapsed >= STAGE_BUDGET ) then return end
	end

	stageHead, stageTail = 1, 0
	stageDriver:Hide()
end

-- Teardown steps cannot be dropped, run everything now (continuations included)
local function flushStages()
	while( stageHead <= stageTail ) do
		local step = stageQueue[stageHead]
		stageQueue[stageHead] = nil
		stageHead = stageHead + 1

		local continuation = step()
		if( continuation ) then
			stageHead = stageHead - 1
			stageQueue[stageHead] = continuation
		end
	end

	stageHead, stageTail = 1, 0
	if( stageDriver ) then
		stageDriver:Hide()
		stageDriver:UnregisterEvent("PLAYER_REGEN_DISABLED")
	end
end

-- armFlush is set by teardown drains, their protected calls must complete inside the regen window if combat starts
local function startStages(armFlush)
	if( not stageDriver ) then
		stageDriver = CreateFrame("Frame")
		stageDriver:Hide()
		stageDriver:SetScript("OnUpdate", runStages)
		stageDriver:SetScript("OnEvent", function()
			stageDriver:UnregisterEvent("PLAYER_REGEN_DISABLED")
			flushStages()
		end)
	end
	if( armFlush ) then
		stageDriver:RegisterEvent("PLAYER_REGEN_DISABLED")
	end
	stageDriver:Show()
end

-- Anything still queued belongs to the state we are leaving
local function cancelStages()
	stageQueue, stageHead, stageTail = {}, 1, 0
	if( stageDriver ) then
		stageDriver:Hide()
		stageDriver:UnregisterEvent("PLAYER_REGEN_DISABLED")
	end
end

-- The combat auto-lock keeps only the protected teardown inside the regen window, the per-type reloads replay here
-- Bounded drain no matter how big the setup grows; if combat re-enters mid replay the queue drops and the next config action re-lays out
local lockReloadWatcher
local function armLockReloads()
	if( not lockReloadWatcher ) then
		lockReloadWatcher = CreateFrame("Frame")
		lockReloadWatcher:SetScript("OnEvent", function(watcher)
			watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
			for _, unitType in ipairs(ShadowUF.unitList) do
				queueStage(function() ShadowUF.Layout:Reload(unitType) end)
			end
			startStages()
		end)
	end
	lockReloadWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Test mode mirrors the unlock auto-lock: protected teardown inside the regen window, reloads replay at regen
local testLockWatcher
local function armTestLock()
	if( not testLockWatcher ) then
		testLockWatcher = CreateFrame("Frame")
		testLockWatcher:SetScript("OnEvent", function(watcher)
			watcher:UnregisterEvent("PLAYER_REGEN_DISABLED")
			if( not next(Movers.testModeUnits) ) then return end

			local snapshot = {}
			for unitType in pairs(Movers.testModeUnits) do snapshot[#snapshot + 1] = unitType end
			for _, unitType in ipairs(snapshot) do
				Movers:DisableTestMode(unitType, true, true)
			end

			for _, unitCfg in pairs(ShadowUF.db.profile.units) do
				if( unitCfg.auras ) then unitCfg.auras.testMode = nil end
			end
			local ACR = LibStub("AceConfigRegistry-3.0", true)
			if( ACR ) then ACR:NotifyChange("ShadowedUF") end

			DEFAULT_CHAT_FRAME:AddMessage(L["You have entered combat, test mode has been disabled."])
		end)
	end
	testLockWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local function disarmTestLock()
	if( testLockWatcher ) then
		testLockWatcher:UnregisterEvent("PLAYER_REGEN_DISABLED")
	end
end

local function setupConfigHeader(header)
	-- Force show headers hidden by state monitors
	-- so SecureGroupHeaderTemplate creates children with negative startingIndex
	if( ShadowUF.db.profile.units[header.unitType].enabled and not header:IsShown() ) then
		header:Show()
	end

	for key in pairs(attributeBlacklist) do
		header:SetAttribute(key, nil)
	end

	local config = ShadowUF.db.profile.units[header.unitType]
	if( config.frameSplit ) then
		header:SetAttribute("startingIndex", -4)
	elseif( config.maxColumns ) then
		local maxUnits = MAX_RAID_MEMBERS
		if( config.filters ) then
			for _, enabled in pairs(config.filters) do
				if( not enabled ) then
					maxUnits = maxUnits - 5
				end
			end
		end

		header:SetAttribute("startingIndex", -math.min(config.maxColumns * config.unitsPerColumn, maxUnits) + 1)
	elseif( ShadowUF[header.unitType .. "Units"] ) then
		-- Party gets an extra slot to host the placeholder player frame
		local extra = (header.unitType == "party") and 1 or 0
		header:SetAttribute("startingIndex", -#(ShadowUF[header.unitType .. "Units"]) + 1 - extra)
	end

	header.startingIndex = header:GetAttribute("startingIndex")
	header:SetMovable(true)
	prepareChildUnits(header, header:GetChildren())
end

local function setupConfigFrame(frame)
	if( frame.configMode ) then
		-- Units visible, but it's not supposed to be
		if( frame:IsVisible() and ( not ShadowUF.db.profile.units[frame.unitType].enabled or frame.isPlaceholderHidden ) ) then
			RegisterUnitWatch(frame, frame.hasStateWatch)
			if( not UnitExists(frame.unit) ) then frame:Hide() end

		-- Unit's not visible and it's enabled so it should
		elseif( not frame.isPlaceholderHidden and not frame:IsVisible() and ShadowUF.db.profile.units[frame.unitType].enabled ) then
			UnregisterUnitWatch(frame)

			frame:SetAttribute("state-unitexists", true)
			frame:FullUpdate()
			frame:Show()
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].enabled ) then
		frame.originalUnit = frame:GetAttribute("unit")
		frame.originalOnEnter = frame.OnEnter
		frame.originalOnLeave = frame.OnLeave
		frame.originalOnUpdate = frame:GetScript("OnUpdate")
		frame:SetMovable(not ShadowUF.Units.childUnits[frame.unitType])
		frame:SetScript("OnDragStop", OnDragStop)
		frame:SetScript("OnDragStart", OnDragStart)
		frame.OnEnter = OnEnter
		frame.OnLeave = OnLeave
		frame:SetScript("OnEvent", nil)
		frame:SetScript("OnUpdate", nil)
		frame:RegisterForDrag("LeftButton")
		frame.configMode = true
		frame.unitOwner = nil
		frame.originalMenu = frame.menu
		frame.menu = nil

		local unit
		if( frame.placeholderUnit ) then
			unit = frame.placeholderUnit
		elseif( frame.isChildUnit ) then
			local unitFormat = string.gsub(string.gsub(frame.unitType, "target$", "%%dtarget"), "pet$", "pet%%d")
			unit = string.format(unitFormat, frame.parent.configUnitID or "")
		else
			unit = frame.unitType .. (frame.configUnitID or "")
		end

		ShadowUF.Units.OnAttributeChanged(frame, "unit", unit)

		if( frame.healthBar ) then frame.healthBar:SetScript("OnUpdate", nil) end
		if( frame.powerBar ) then frame.powerBar:SetScript("OnUpdate", nil) end
		if( frame.indicators ) then frame.indicators:SetScript("OnUpdate", nil) end

		UnregisterUnitWatch(frame)
		frame:FullUpdate()
		if( frame.isPlaceholderHidden ) then
			frame:Hide()
		else
			frame:Show()
		end
	end
end

local function setupUnits(unitType)
	for frame in pairs(ShadowUF.Units.frameList) do
		if( not unitType or frame.unitType == unitType ) then
			setupConfigFrame(frame)
		end
	end
end

function Movers:Enable()
	-- Header attributes are protected, unlocking has to wait for the regen
	if( InCombatLockdown() ) then
		ShadowUF.db.profile.locked = true
		ShadowUF:Print(L["Unit frames cannot be unlocked while in combat."])
		local ACR = LibStub("AceConfigRegistry-3.0", true)
		if( ACR ) then ACR:NotifyChange("ShadowedUF") end
		return
	end

	-- Clear any active test modes before entering full config mode
	if( next(self.testModeUnits) ) then
		disarmTestLock()
		for func, env in pairs(testOriginalEnvs) do
			setfenv(func, env)
			testOriginalEnvs[func] = nil
		end
		-- Full teardown, not just flag clearing: the config setup re-snapshots originalUnit/originalOnUpdate and must not capture faked values
		for frame in pairs(ShadowUF.Units.frameList) do
			if( self.testModeUnits[frame.unitType] and frame.configMode ) then
				teardownTestFrame(frame)
			end
		end
		wipe(self.testModeUnits)
		self.testModeEnvActive = false
		for _, unitCfg in pairs(ShadowUF.db.profile.units) do
			if( unitCfg.auras ) then unitCfg.auras.testMode = nil end
		end
	end

	createConfigEnv()

	-- Setup the test env
	if( not self.isEnabled ) then
		for _, func in pairs(ShadowUF.tagFunc) do
			if( type(func) == "function" ) then
				originalEnvs[func] = getfenv(func)
				setfenv(func, configEnv)
			end
		end

		for _, module in pairs(ShadowUF.modules) do
			if( module.moduleName ) then
				for key, func in pairs(module) do
					if( type(func) == "function" ) then
						originalEnvs[module[key]] = getfenv(module[key])
						setfenv(module[key], configEnv)
					end
				end
			end
		end
	end

	-- Config mode is on from here, the display streams in over the next few ticks
	self.isEnabled = true
	cancelStages()

	-- One step per header: zone headers are force created here, then the secure template spawns its children
	local headerKeys, seenHeader = {}, {}
	for key in pairs(ShadowUF.Units.headerFrames) do
		headerKeys[#headerKeys + 1] = key
		seenHeader[key] = true
	end
	for type in pairs(ShadowUF.Units.zoneUnits) do
		if( ShadowUF.db.profile.units[type].enabled and not seenHeader[type] ) then
			headerKeys[#headerKeys + 1] = type
			seenHeader[type] = true
		end
	end

	for _, key in ipairs(headerKeys) do
		local isZone = ShadowUF.Units.zoneUnits[key] and ShadowUF.db.profile.units[key] and ShadowUF.db.profile.units[key].enabled
		queueStage(function()
			if( isZone ) then ShadowUF.Units:InitializeFrame(key) end

			local header = ShadowUF.Units.headerFrames[key]
			if( header ) then setupConfigHeader(header) end
		end)
	end

	-- Then the frames themselves, one module at a time, time-boxed per frame so a 6+6 aura profile cannot overflow a slice
	for _, unitType in ipairs(ShadowUF.unitList) do
		local pending
		local function step()
			if( not pending ) then
				pending = {}
				for frame in pairs(ShadowUF.Units.frameList) do
					if( frame.unitType == unitType ) then
						pending[#pending + 1] = frame
					end
				end
			end

			local started = debugprofilestop()
			while( true ) do
				local frame = table.remove(pending)
				if( not frame ) then return end
				setupConfigFrame(frame)

				local elapsed = debugprofilestop() - started
				if( elapsed < 0 or elapsed >= STAGE_BUDGET ) then
					return #pending > 0 and step or nil
				end
			end
		end
		queueStage(step)
	end

	-- Child units are created along the way, one last sweep picks up whatever appeared
	queueStage(function() setupUnits() end)

	queueStage(function()
		for unitType in pairs(ShadowUF.Units.zoneUnits) do
			local header = ShadowUF.Units.headerFrames[unitType]
			if( ShadowUF.db.profile.units[unitType].enabled and header ) then
				header:SetAttribute("childChanged", 1)
			end
		end
	end)

	startStages()

	-- Don't show the dialog if the configuration is opened through the configmode spec
	if( not self.isConfigModeSpec ) then
		self:CreateInfoFrame()
		self.infoFrame:Show()
	elseif( self.infoFrame ) then
		self.infoFrame:Hide()
	end
end

local function setupTestFrame(frame, unitType)
	frame.originalUnit = frame:GetAttribute("unit")
	frame.originalOnUpdate = frame:GetScript("OnUpdate")
	frame.configMode = true
	frame.unitOwner = nil

	local unit
	if( frame.placeholderUnit ) then
		unit = frame.placeholderUnit
	elseif( frame.isChildUnit ) then
		local unitFormat = string.gsub(string.gsub(unitType, "target$", "%%dtarget"), "pet$", "pet%%d")
		unit = string.format(unitFormat, frame.parent and frame.parent.configUnitID or "")
	else
		unit = unitType .. (frame.configUnitID or "")
	end

	frame:SetAttribute("state-unitexists", true)
	ShadowUF.Units.OnAttributeChanged(frame, "unit", unit)

	frame:SetScript("OnEvent", nil)
	frame:SetScript("OnUpdate", nil)
	if( frame.healthBar ) then frame.healthBar:SetScript("OnUpdate", nil) end
	if( frame.powerBar ) then frame.powerBar:SetScript("OnUpdate", nil) end
	if( frame.indicators ) then frame.indicators:SetScript("OnUpdate", nil) end

	UnregisterUnitWatch(frame)
	frame:FullUpdate()
	if( frame.isPlaceholderHidden ) then
		frame:Hide()
	else
		frame:Show()
	end
end

teardownTestFrame = function(frame)
	frame.configMode = nil
	frame.unitOwner = nil
	frame.unit = nil
	frame.configUnitID = nil
	if( frame.isPlaceholderHidden ) then
		frame.isPlaceholderHidden = nil
		frame:SetAttribute("statehidden", nil)
		frame:Show()
	end
	-- Restore before clearing placeholderUnit, the attribute cascade must still see the flag to skip ghost children
	frame:SetAttribute("unit", frame.originalUnit)
	frame.placeholderUnit = nil
	frame:SetScript("OnEvent", frame:IsVisible() and ShadowUF.Units.OnEvent or nil)
	frame:SetScript("OnUpdate", frame.originalOnUpdate)

	if( frame.isChildUnit ) then
		ShadowUF.Units.OnAttributeChanged(frame, "unit", SecureButton_GetModifiedUnit(frame))
	end

	RegisterUnitWatch(frame, frame.hasStateWatch)
	if( not UnitExists(frame.unit) ) then frame:Hide() end
end

local function teardownConfigFrame(frame)
	if( frame.isMoving ) then
		frame:GetScript("OnDragStop")(frame)
	end

	frame.configMode = nil
	frame.unitOwner = nil
	frame.unit = nil
	frame.configUnitID = nil
	if( frame.isPlaceholderHidden ) then
		frame.isPlaceholderHidden = nil
		frame:SetAttribute("statehidden", nil)
		frame:Show()
	end
	frame.menu = frame.originalMenu
	frame.originalMenu = nil
	frame.Hide = frame.originalHide
	-- Restore before clearing placeholderUnit, the attribute cascade must still see the flag to skip ghost children
	frame:SetAttribute("unit", frame.originalUnit)
	frame.placeholderUnit = nil
	frame:SetScript("OnDragStop", nil)
	frame:SetScript("OnDragStart", nil)
	frame:SetScript("OnEvent", frame:IsVisible() and ShadowUF.Units.OnEvent or nil)
	frame:SetScript("OnUpdate", frame.originalOnUpdate)
	frame.OnEnter = frame.originalOnEnter
	frame.OnLeave = frame.originalOnLeave
	frame:SetMovable(false)
	frame:RegisterForDrag()

	if( frame.isChildUnit ) then
		ShadowUF.Units.OnAttributeChanged(frame, "unit", SecureButton_GetModifiedUnit(frame))
	end

	RegisterUnitWatch(frame, frame.hasStateWatch)
	if( not UnitExists(frame.unit) ) then frame:Hide() end
end

function Movers:Disable(immediate, deferReloads)
	if( not self.isEnabled ) then return nil end
	immediate = immediate or InCombatLockdown()

	-- Whatever is left of the unlock belongs to the state we are leaving
	cancelStages()

	for func, env in pairs(originalEnvs) do
		setfenv(func, env)
		originalEnvs[func] = nil
	end

	local pending
	local function frameStep()
		if( not pending ) then
			pending = {}
			for frame in pairs(ShadowUF.Units.frameList) do
				if( frame.configMode ) then
					pending[#pending + 1] = frame
				end
			end
		end

		local started = debugprofilestop()
		while( true ) do
			local frame = table.remove(pending)
			if( not frame ) then return end
			teardownConfigFrame(frame)

			local elapsed = debugprofilestop() - started
			if( elapsed < 0 or elapsed >= STAGE_BUDGET ) then
				return #pending > 0 and frameStep or nil
			end
		end
	end
	queueStage(frameStep)

	for type, header in pairs(ShadowUF.Units.headerFrames) do
		queueStage(function()
			header:SetMovable(false)
			header:SetAttribute("startingIndex", 1)
			header:SetAttribute("initial-unitWatch", true)

			if( header.unitType == type or type == "raidParent" ) then
				ShadowUF.Units:ReloadHeader(header.unitType)
			end
		end)
	end

	queueStage(function() ShadowUF.Units:CheckPlayerZone(true) end)

	-- Defer heavy Layout, reload until combat ends
	if( deferReloads ) then
		armLockReloads()
	else
		for _, unitType in ipairs(ShadowUF.unitList) do
			queueStage(function() ShadowUF.Layout:Reload(unitType) end)
		end
	end

	queueStage(function()
		-- Don't store these so everything can be GCed
		unitConfig = {}
	end)

	-- The auto-lock watcher fires inside the regen window, protected teardown must finish before the lockdown
	if( immediate ) then
		flushStages()
	else
		startStages(true)
	end

	if( self.infoFrame ) then
		self.infoFrame:Hide()
	end

	self.isConfigModeSpec = nil
	self.isEnabled = nil

	-- Clear any active test modes since config mode restores everything
	disarmTestLock()
	wipe(self.testModeUnits)
	self.testModeEnvActive = false
end

-- Shows a full placeholder frame for a specific unit type
-- Uses a separate testConfigEnv that only fakes data for test mode unit types
Movers.testModeUnits = {}
Movers.testModeEnvActive = false

local function createTestConfigEnv()
	if( testConfigEnv ) then return end
	createConfigEnv()

	-- Build an env that delegates to configEnv fakes only for test mode unit types and to _G for everything else.
	local cache = {}
	testConfigEnv = setmetatable({}, {
		__index = function(tbl, key)
			-- Check cache first
			if( cache[key] ~= nil ) then return cache[key] end

			local fakeVal = rawget(configEnv, key)
			local realVal = _G[key]

			-- If the fake is a function and so is the real one, create a smart wrapper
			if( type(fakeVal) == "function" and type(realVal) == "function" ) then
				cache[key] = function(firstArg, ...)
					if( type(firstArg) == "string" ) then
						local ut = string.gsub(firstArg, "(%d+)", "")
						if( Movers.testModeUnits[ut] ) then
							return fakeVal(firstArg, ...)
						end
					end
					return realVal(firstArg, ...)
				end
				return cache[key]
			end

			-- For non-functions or fake-only values, use fake if available
			local val = fakeVal ~= nil and fakeVal or realVal
			cache[key] = val
			return val
		end,
		__newindex = function(tbl, key, value) _G[key] = value end,
	})

	-- UnitExists must always be overridden (no first-arg unit type matching needed for some calls)
	cache["UnitExists"] = function(unit)
		if( type(unit) == "string" ) then
			local ut = string.gsub(unit, "(%d+)", "")
			if( Movers.testModeUnits[ut] ) then return true end
		end
		return _G.UnitExists(unit)
	end
end

function Movers:EnableTestMode(unitType)
	if( self.isEnabled ) then return end

	self.testModeUnits[unitType] = true
	armTestLock()
	createTestConfigEnv()

	-- setfenv all modules/tags into testConfigEnv (once, shared across test mode units)
	if( not self.testModeEnvActive ) then
		for _, func in pairs(ShadowUF.tagFunc) do
			if( type(func) == "function" ) then
				testOriginalEnvs[func] = getfenv(func)
				setfenv(func, testConfigEnv)
			end
		end

		for _, module in pairs(ShadowUF.modules) do
			if( module.moduleName ) then
				for key, func in pairs(module) do
					if( type(func) == "function" ) then
						testOriginalEnvs[module[key]] = getfenv(module[key])
						setfenv(module[key], testConfigEnv)
					end
				end
			end
		end

		self.testModeEnvActive = true
	end

	-- One step for the header, then the frames trickle in like the global unlock does
	queueStage(function()
		if( not Movers.testModeUnits[unitType] ) then return end

		-- For header-based units, force-create and show the header
		if( ShadowUF.Units.headerUnits[unitType] or ShadowUF.Units.zoneUnits[unitType] ) then
			if( ShadowUF.Units.zoneUnits[unitType] ) then
				ShadowUF.Units:InitializeFrame(unitType)
			end

			local header = ShadowUF.Units.headerFrames[unitType]
			if( header ) then
				if( not header:IsShown() ) then
					header:Show()
				end

				for key in pairs(attributeBlacklist) do
					header:SetAttribute(key, nil)
				end

				local config = ShadowUF.db.profile.units[unitType]
				if( config.frameSplit ) then
					header:SetAttribute("startingIndex", -4)
				elseif( config.maxColumns ) then
					local maxUnits = MAX_RAID_MEMBERS
					if( config.filters ) then
						for _, enabled in pairs(config.filters) do
							if( not enabled ) then maxUnits = maxUnits - 5 end
						end
					end
					header:SetAttribute("startingIndex", -math.min(config.maxColumns * config.unitsPerColumn, maxUnits) + 1)
				elseif( ShadowUF[unitType .. "Units"] ) then
					-- Party gets an extra slot to host the placeholder player frame
					local extra = (unitType == "party") and 1 or 0
					header:SetAttribute("startingIndex", -#(ShadowUF[unitType .. "Units"]) + 1 - extra)
				end

				header.startingIndex = header:GetAttribute("startingIndex")
				prepareChildUnits(header, header:GetChildren())
			end
		end
	end)

	-- Activate placeholders on frames of this unit type, time-boxed per frame
	local pending
	local function frameStep()
		if( not Movers.testModeUnits[unitType] ) then return end

		if( not pending ) then
			pending = {}
			for frame in pairs(ShadowUF.Units.frameList) do
				if( frame.unitType == unitType and not frame.configMode and ShadowUF.db.profile.units[unitType].enabled ) then
					pending[#pending + 1] = frame
				end
			end
		end

		local started = debugprofilestop()
		while( true ) do
			local frame = table.remove(pending)
			if( not frame ) then return end
			setupTestFrame(frame, unitType)

			local elapsed = debugprofilestop() - started
			if( elapsed < 0 or elapsed >= STAGE_BUDGET ) then
				return #pending > 0 and frameStep or nil
			end
		end
	end
	queueStage(frameStep)
	startStages()
end

function Movers:DisableTestMode(unitType, immediate, deferReloads)
	if( self.isEnabled ) then return end
	immediate = immediate or InCombatLockdown()

	self.testModeUnits[unitType] = nil
	if( not next(self.testModeUnits) ) then disarmTestLock() end

	-- Restore frames of this unit type, time-boxed per frame
	local pending
	local function frameStep()
		if( not pending ) then
			pending = {}
			for frame in pairs(ShadowUF.Units.frameList) do
				if( frame.unitType == unitType and frame.configMode ) then
					pending[#pending + 1] = frame
				end
			end
		end

		local started = debugprofilestop()
		while( true ) do
			local frame = table.remove(pending)
			if( not frame ) then return end
			teardownTestFrame(frame)

			local elapsed = debugprofilestop() - started
			if( elapsed < 0 or elapsed >= STAGE_BUDGET ) then
				return #pending > 0 and frameStep or nil
			end
		end
	end
	queueStage(frameStep)

	-- Restore header for header-based units
	queueStage(function()
		local header = ShadowUF.Units.headerFrames[unitType]
		if( header ) then
			header:SetAttribute("startingIndex", 1)
			header:SetAttribute("initial-unitWatch", true)
			if( header.unitType == unitType ) then
				ShadowUF.Units:ReloadHeader(unitType)
			end
		end
	end)

	-- If no more test mode units, restore all setfenv
	-- Steps re-check the state, a test mode re-enabled during the drain keeps its environment
	if( not next(self.testModeUnits) and self.testModeEnvActive ) then
		queueStage(function()
			if( next(Movers.testModeUnits) ) then return end

			for func, env in pairs(testOriginalEnvs) do
				setfenv(func, env)
				testOriginalEnvs[func] = nil
			end
			Movers.testModeEnvActive = false
			unitConfig = {}
		end)

		-- The full reload is the heaviest part, one unit type per step; on combat entry it replays at regen instead
		if( deferReloads ) then
			armLockReloads()
		else
			for _, reloadType in ipairs(ShadowUF.unitList) do
				queueStage(function()
					if( next(Movers.testModeUnits) ) then return end
					ShadowUF.Layout:Reload(reloadType)
				end)
			end
		end
	end

	if( immediate ) then
		flushStages()
	else
		startStages(true)
	end
end

OnDragStart = function(self)
	if( not self:IsMovable() ) then return end

	if( self.unitType == "raid" and ShadowUF.Units.headerFrames.raidParent and ShadowUF.Units.headerFrames.raidParent:IsVisible() ) then
		self = ShadowUF.Units.headerFrames.raidParent
	else
		self = ShadowUF.Units.headerFrames[self.unitType] or ShadowUF.Units.unitFrames[self.unitType]
	end

	self.isMoving = true
	self:StartMoving()
end

OnDragStop = function(self)
	if( not self:IsMovable() ) then return end
	if( self.unitType == "raid" and ShadowUF.Units.headerFrames.raidParent and ShadowUF.Units.headerFrames.raidParent:IsVisible() ) then
		self = ShadowUF.Units.headerFrames.raidParent
	else
		self = ShadowUF.Units.headerFrames[self.unitType] or ShadowUF.Units.unitFrames[self.unitType]
	end

	self.isMoving = nil
	self:StopMovingOrSizing()

	-- When dragging the frame around, Blizzard changes the anchoring based on the closet portion of the screen
	-- When a widget is near the top left it uses top left, near the left it uses left and so on, which messes up positioning for header frames
	local scale = (self:GetScale() * UIParent:GetScale()) or 1
	local position = ShadowUF.db.profile.positions[self.unitType]
	local point, _, relativePoint, x, y = self:GetPoint()

	-- Figure out the horizontal anchor
	if( self.isHeaderFrame ) then
		if( ShadowUF.db.profile.units[self.unitType].attribAnchorPoint == "RIGHT" ) then
			x = self:GetRight()
			point = "RIGHT"
		else
			x = self:GetLeft()
			point = "LEFT"
		end

		if( ShadowUF.db.profile.units[self.unitType].attribPoint == "BOTTOM" ) then
			y = self:GetBottom()
			point = "BOTTOM" .. point
		else
			y = self:GetTop()
			point = "TOP" .. point
		end

		relativePoint = "BOTTOMLEFT"
		position.bottom = self:GetBottom() * scale
		position.top = self:GetTop() * scale
	end

	position.anchorTo = "UIParent"
	position.movedAnchor = nil
	position.anchorPoint = ""
	position.point = point
	position.relativePoint = relativePoint
	position.x = x * scale
	position.y = y * scale

	ShadowUF.Layout:AnchorFrame(UIParent, self, ShadowUF.db.profile.positions[self.unitType])

	-- Unlock the parent frame from the mover now too
	if( self.parent ) then
		ShadowUF.Layout:AnchorFrame(UIParent, self.parent, ShadowUF.db.profile.positions[self.parent.unitType])
	end

	-- Notify the configuration it can update itself now
	local ACR = LibStub("AceConfigRegistry-3.0", true)
	if( ACR ) then
		ACR:NotifyChange("ShadowedUF")
	end
end

function Movers:Update()
	if( not ShadowUF.db.profile.locked ) then
		self:Enable()
	else
		self:Disable()

		if( next(self.testModeUnits) ) then
			local snapshot = {}
			for unitType in pairs(self.testModeUnits) do snapshot[unitType] = true end
			for unitType in pairs(snapshot) do
				self:DisableTestMode(unitType)
				self:EnableTestMode(unitType)
			end
		end
	end
end

function Movers:CreateInfoFrame()
	if( self.infoFrame ) then return end

	-- Show an info frame that users can lock the frames through
	local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetClampedToScreen(true)
	frame:SetWidth(300)
	frame:SetHeight(115)
	frame:RegisterForDrag("LeftButton")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:SetScript("OnEvent", function(f)
		if( not ShadowUF.db.profile.locked and f:IsVisible() ) then
			ShadowUF.db.profile.locked = true
			-- Combat is starting, the protected teardown must run inside this event's window, the reloads replay at regen
			Movers:Disable(true, true)

			DEFAULT_CHAT_FRAME:AddMessage(L["You have entered combat, unit frames have been locked."])
		end
	end)
	frame:SetScript("OnDragStart", function(f)
		f:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
	end)
	frame:SetBackdrop({
		  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		  edgeSize = 26,
		  insets = {left = 9, right = 9, top = 9, bottom = 9},
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 225)

	frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
	frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	frame.titleBar:SetPoint("TOP", 0, 8)
	frame.titleBar:SetWidth(350)
	frame.titleBar:SetHeight(45)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOP", 0, 0)
	frame.title:SetText("Shadowed Unit Frames")

	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.text:SetText(L["The unit frames you see are examples, they are not perfect and do not show all the data they normally would.|n|nYou can hide them by locking them through /shadowuf or clicking the button below."])
	frame.text:SetPoint("TOPLEFT", 12, -22)
	frame.text:SetWidth(frame:GetWidth() - 20)
	frame.text:SetJustifyH("LEFT")

	frame.lock = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.lock:SetText(L["Lock frames"])
	frame.lock:SetHeight(20)
	frame.lock:SetWidth(100)
	frame.lock:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 8)
	frame.lock:SetScript("OnEnter", OnEnter)
	frame.lock:SetScript("OnLeave", OnLeave)
	frame.lock.tooltipText = L["Locks the unit frame positionings hiding the mover boxes."]
	frame.lock:SetScript("OnClick", function()
		ShadowUF.db.profile.locked = true
		Movers:Update()
	end)

	frame.unlink = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.unlink:SetText(L["Unlink frames"])
	frame.unlink:SetHeight(20)
	frame.unlink:SetWidth(100)
	frame.unlink:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 8)
	frame.unlink:SetScript("OnEnter", OnEnter)
	frame.unlink:SetScript("OnLeave", OnLeave)
	frame.unlink.tooltipText = L["WARNING: This will unlink all frames from each other so you can move them without another frame moving with it."]
	frame.unlink:SetScript("OnClick", function()
		for f in pairs(ShadowUF.Units.frameList) do
			if( not ShadowUF.Units.childUnits[f.unitType] and f:GetScript("OnDragStart") and f:GetScript("OnDragStop") ) then
				f:GetScript("OnDragStart")(f)
				f:GetScript("OnDragStop")(f)
			end
		end

		Movers:Update()
	end)

	self.infoFrame = frame
end
