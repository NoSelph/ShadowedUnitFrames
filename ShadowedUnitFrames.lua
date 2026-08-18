--[[
	Shadowed Unit Frames, Shadowed of Mal'Ganis (US) PvP
]]

ShadowUF = select(2, ...)

local L = ShadowUF.L
ShadowUF.dbRevision = 73
ShadowUF.playerUnit = "player"
ShadowUF.enabledUnits = {}
ShadowUF.modules = {}
ShadowUF.moduleOrder = {}
ShadowUF.unitList = {"player", "pet", "pettarget", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "partytargettarget", "raid", "raidpet", "boss", "bosstarget", "maintank", "maintanktarget", "mainassist", "mainassisttarget", "arena", "arenatarget", "arenapet", "battleground", "battlegroundtarget", "battlegroundpet", "arenatargettarget", "battlegroundtargettarget", "maintanktargettarget", "mainassisttargettarget", "bosstargettarget"}
ShadowUF.fakeUnits = {["targettarget"] = true, ["targettargettarget"] = true, ["pettarget"] = true, ["arenatarget"] = true, ["arenatargettarget"] = true, ["focustarget"] = true, ["focustargettarget"] = true, ["partytarget"] = true, ["raidtarget"] = true, ["bosstarget"] = true, ["maintanktarget"] = true, ["mainassisttarget"] = true, ["battlegroundtarget"] = true, ["partytargettarget"] = true, ["battlegroundtargettarget"] = true, ["maintanktargettarget"] = true, ["mainassisttargettarget"] = true, ["bosstargettarget"] = true}
L.units = {["raidpet"] = L["Raid pet"], ["PET"] = L["Pet"], ["VEHICLE"] = L["Vehicle"], ["arena"] = L["Arena"], ["arenapet"] = L["Arena Pet"], ["arenatarget"] = L["Arena Target"], ["arenatargettarget"] = L["Arena Target of Target"], ["boss"] = L["Boss"], ["bosstarget"] = L["Boss Target"], ["focus"] = L["Focus"], ["focustarget"] = L["Focus Target"], ["mainassist"] = L["Main Assist"], ["mainassisttarget"] = L["Main Assist Target"], ["maintank"] = L["Main Tank"], ["maintanktarget"] = L["Main Tank Target"], ["party"] = L["Party"], ["partypet"] = L["Party Pet"], ["partytarget"] = L["Party Target"], ["pet"] = L["Pet"], ["pettarget"] = L["Pet Target"], ["player"] = L["Player"],["raid"] = L["Raid"], ["target"] = L["Target"], ["targettarget"] = L["Target of Target"], ["targettargettarget"] = L["Target of Target of Target"], ["battleground"] = L["Battleground"], ["battlegroundpet"] = L["Battleground Pet"], ["battlegroundtarget"] = L["Battleground Target"], ["partytargettarget"] = L["Party Target of Target"], ["battlegroundtargettarget"] = L["Battleground Target of Target"], ["maintanktargettarget"] = L["Main Tank Target of Target"], ["mainassisttargettarget"] = L["Main Assist Target of Target"], ["bosstargettarget"] = L["Boss Target of Target"]}
L.shortUnits = {["battleground"] = L["BG"], ["battlegroundtarget"] = L["BG Target"], ["battlegroundpet"] = L["BG Pet"], ["battlegroundtargettarget"] = L["BG ToT"], ["arenatargettarget"] = L["Arena ToT"], ["partytargettarget"] = L["Party ToT"], ["bosstargettarget"] = L["Boss ToT"], ["maintanktargettarget"] = L["MT ToT"], ["mainassisttargettarget"] = L["MA ToT"]}

-- Cache the units so we don't have to concat every time it updates
ShadowUF.unitTarget = setmetatable({}, {__index = function(tbl, unit) rawset(tbl, unit, unit .. "target"); return unit .. "target" end})
ShadowUF.partyUnits, ShadowUF.raidUnits, ShadowUF.raidPetUnits, ShadowUF.bossUnits, ShadowUF.arenaUnits, ShadowUF.battlegroundUnits = {}, {}, {}, {}, {}, {}
ShadowUF.maintankUnits, ShadowUF.mainassistUnits, ShadowUF.raidpetUnits = ShadowUF.raidUnits, ShadowUF.raidUnits, ShadowUF.raidPetUnits
for i=1, MAX_PARTY_MEMBERS do ShadowUF.partyUnits[i] = "party" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidUnits[i] = "raid" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidPetUnits[i] = "raidpet" .. i end
for i=1, MAX_BOSS_FRAMES do ShadowUF.bossUnits[i] = "boss" .. i end
for i=1, 5 do ShadowUF.arenaUnits[i] = "arena" .. i end
for i=1, 4 do ShadowUF.battlegroundUnits[i] = "arena" .. i end

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = false,
			advanced = false,
			tooltipCombat = false,
			tooltipAuraSpellIDs = false,
			bossmodSpellRename = true,
			omnicc = false,
			blizzardcc = true,
			tags = {},
			units = {},
			positions = {},
			range = {},
			filters = {zonewhite = {}, zoneblack = {}},
			customFilters = {},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}, neighborhood = {}},
			hidden = {cast = false, playerPower = true, buffs = false, party = true, raid = false, player = true, pet = true, target = true, focus = true, boss = true, arena = true, playerAltPower = false},
			performance = {
				rangeCheck = 0.50,
				tagMonitorFast = 0.25,
				tagMonitorNormal = 0.50,
				tagMonitorSlow = 1.00,
				fakeCastMonitor = 0.10,
				combatIndicator = 1.00,
			},
		},
	}

	self:LoadUnitDefaults()

	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")

	-- Setup tag cache
	self.tagFunc = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end

			local func, msg = loadstring("return " .. (ShadowUF.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index].func or ""))
			if( func ) then
				func = func()
			elseif( msg ) then
				error(msg, 3)
			end

			tbl[index] = func
			return tbl[index]
	end})

	-- Clear transient test mode flags (not persisted across reload)
	for _, unitCfg in pairs(self.db.profile.units) do
		if( unitCfg.auras ) then unitCfg.auras.testMode = nil end
	end

	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
		self:CheckBuild()
		self:ShowInfoPanel()
	end

	self.db.profile.revision = self.dbRevision
	self:ApplyAuraSpellIDsCVar()
	self:FireModuleEvent("OnInitialize")
	self:HideBlizzardFrames()
	self.Layout:LoadSML()
	self:LoadUnits()
	self.modules.movers:Update()

	local LibDualSpec = LibStub("LibDualSpec-1.0", true)
	if LibDualSpec then LibDualSpec:EnhanceDatabase(self.db, "ShadowedUnitFrames") end
end

-- The CVar doesn't survive a relog, reapply it from the profile
function ShadowUF:ApplyAuraSpellIDsCVar()
	if( C_CVar and C_CVar.SetCVar ) then
		pcall(C_CVar.SetCVar, "tooltipShowAuraSpellIDs", self.db.profile.tooltipAuraSpellIDs and "1" or "0")
	end
end

function ShadowUF.UnitAuraBySpell(unit, spell, filter)
	local auraData
	if type(spell) == "string" then
		-- Only returns real data for whitelisted spells (RequiresNonSecretAura)
		local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, spell, filter)
		if( ok ) then auraData = data end
	elseif type(spell) == "number" then
		-- Index-based iteration errors in combat, spellID lookup doesn't
		-- No filter support on this API, no numeric caller uses one anyway
		local ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spell)
		if( ok ) then auraData = data end
	end
	-- Manual safe unpack for 12.0
	if( not auraData ) then return nil end
	
	return  auraData.name,
			auraData.icon,
			auraData.applications,
			auraData.dispelName,
			auraData.duration,
			auraData.expirationTime,
			auraData.sourceUnit,
			auraData.isStealable,
			auraData.nameplateShowPersonal,
			auraData.spellId,
			auraData.canApplyAura,
			auraData.isBossAura,
			auraData.isFromPlayerOrPlayerPet,
			auraData.nameplateShowAll,
			auraData.timeMod
end

-- Identity-guarded Unit APIs (UnitClass, UnitInRaid, roles...) return secrets for these units, so test once upfront instead of guarding every return
function ShadowUF.IsUnitIdentitySecret(unit)
	if( not (C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret) ) then return false end
	local ok, secret = pcall(C_Secrets.ShouldUnitIdentityBeSecret, unit)
	return ok and secret or false
end

-- Reaction tri-state for the dispel displays, "assist" = can be helped, "attack" = can be harmed, "none" = neither (cross-faction with warmode off, friendly neutrals)
-- UnitCanAssist/UnitCanAttack are authoritative but can return secret booleans on restricted maps, the reaction pair never does and covers duels (friend AND enemy) as hostile
function ShadowUF.GetUnitReactionState(unit)
	local ok, value = pcall(UnitCanAssist, "player", unit)
	if( ok and not issecretvalue(value) ) then
		if( value ) then return "assist" end
		local okAttack, attack = pcall(UnitCanAttack, "player", unit)
		if( okAttack and not issecretvalue(attack) ) then
			return attack and "attack" or "none"
		end
	end

	local okFriend, friend = pcall(UnitIsFriend, unit, "player")
	local okEnemy, enemy = pcall(UnitIsEnemy, unit, "player")
	local isEnemy = okEnemy and enemy and true or false
	if( okFriend and friend and not isEnemy ) then return "assist" end
	return isEnemy and "attack" or "none"
end

-- Units out of the area of interest (other instance, phase, or simply too far) forward aura data the container filters cannot evaluate, so every section ends up matching everything
-- Unknown states count as reachable, an unusable token is already caught by the SetUnit pcalls
function ShadowUF.IsUnitReachable(unit)
	local ok, connected = pcall(UnitIsConnected, unit)
	if( ok and not issecretvalue(connected) and not connected ) then return false end

	local okVisible, visible = pcall(UnitIsVisible, unit)
	if( okVisible and not issecretvalue(visible) and not visible ) then return false end

	return true
end

function ShadowUF:CheckBuild()
	local build = select(4, GetBuildInfo())
	if( self.db.profile.wowBuild == build ) then return end

	-- Nothing to add here right now
	self.db.profile.wowBuild = build
end

function ShadowUF:CheckUpgrade()
	local revision = self.db.profile.revision or self.dbRevision

	-- Drop "only show if missing" from spells that aren't whitelisted (absence needs a point query)
	if( C_Secrets and C_Secrets.GetSpellAuraSecrecy and Enum.SecrecyLevel and self.db.profile.auraIndicators ) then
		local missing = self.db.profile.auraIndicators.missing
		local auras = self.db.profile.auraIndicators.auras
		if( missing ) then
			for aura in pairs(missing) do
				local ok, secrecy = pcall(C_Secrets.GetSpellAuraSecrecy, tonumber(aura) or aura)
				if( ok and secrecy ~= Enum.SecrecyLevel.NeverSecret ) then
					missing[aura] = nil
					if( auras and auras[aura] ) then
						auras[aura] = auras[aura]:gsub("missing%s*=%s*true;?", "")
					end
				end
			end
		end
	end
	-- Automatically add missing border colors to legacy profiles without changing existing ones.
	local auraColors = self.db.profile.auraColors
	if( not auraColors ) then
		auraColors = {}
		self.db.profile.auraColors = auraColors
	end
	auraColors.dispel = auraColors.dispel or {}
	local paletteDefaults = {
		Magic = {r = 0.2, g = 0.6, b = 1},
		Curse = {r = 0.6, g = 0, b = 1},
		Disease = {r = 0.6, g = 0.4, b = 0},
		Poison = {r = 0, g = 0.6, b = 0},
		Bleed = {r = 0.8, g = 0, b = 0},
		Enrage = {r = 1, g = 0.6, b = 0},
	}
	for dispelType, color in pairs(paletteDefaults) do
		if( not auraColors.dispel[dispelType] ) then
			auraColors.dispel[dispelType] = {r = color.r, g = color.g, b = color.b}
		end
	end
	auraColors.removable = auraColors.removable or {r = 1, g = 0.70, b = 0.10}
	auraColors.pandemic = auraColors.pandemic or {r = 1, g = 1, b = 1, a = 0.35}

	if( revision <= 72 ) then
		-- Dispel display modes are now stored as filter mode strings
		for _, unitCfg in pairs(self.db.profile.units) do
			if( unitCfg.highlight and unitCfg.highlight.debuff == true ) then
				unitCfg.highlight.debuff = "PLAYER_DISPELLABLE"
			end
			if( unitCfg.healthBar and unitCfg.healthBar.colorDispel == true ) then
				unitCfg.healthBar.colorDispel = "PLAYER_DISPELLABLE"
			end
		end
	end
	if( revision <= 71 ) then
		-- Aura frame text settings sit behind an explicit opt-in, a stored 0 offset means unset so it doesn't count as a customization
		local textKeys = {"timerAnchor", "timerX", "timerY", "stackAnchor", "stackX", "stackY", "cooldownFontSize", "cooldownFontColor", "stackFontSize", "stackFontColor", "disableBlizzardCC", "disableStacks"}
		for _, unitCfg in pairs(self.db.profile.units) do
			if( unitCfg.auras ) then
				for _, auraType in pairs({"buffs", "debuffs"}) do
					if( type(unitCfg.auras[auraType]) == "table" ) then
						for _, frameCfg in pairs(unitCfg.auras[auraType]) do
							if( type(frameCfg) == "table" ) then
								for _, key in pairs({"timerX", "timerY", "stackX", "stackY"}) do
									if( frameCfg[key] == 0 ) then frameCfg[key] = nil end
								end
								for _, key in pairs(textKeys) do
									if( frameCfg[key] ~= nil ) then
										frameCfg.textOverride = true
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if( revision <= 70 ) then
		-- Right-click cancel opt-out moved from the per aura frame clickThrough to a global toggle, carry over player buff settings
		local playerBuffs = self.db.profile.units.player and self.db.profile.units.player.auras and self.db.profile.units.player.auras.buffs
		if( type(playerBuffs) == "table" ) then
			for _, frameCfg in pairs(playerBuffs) do
				if( type(frameCfg) == "table" and frameCfg.clickThrough ) then
					self.db.profile.auras.disableCancel = true
				end
			end
		end
		for _, unitCfg in pairs(self.db.profile.units) do
			if( unitCfg.auras ) then
				for _, auraType in pairs({"buffs", "debuffs"}) do
					if( type(unitCfg.auras[auraType]) == "table" ) then
						for _, frameCfg in pairs(unitCfg.auras[auraType]) do
							if( type(frameCfg) == "table" ) then
								frameCfg.clickThrough = nil
							end
						end
					end
				end
			end
		end

		-- Blizzard filter disabled for buffs, haven't seen anything useful returned
		for _, unitCfg in pairs(self.db.profile.units) do
			if( unitCfg.auras and type(unitCfg.auras.buffs) == "table" ) then
				for _, frameCfg in pairs(unitCfg.auras.buffs) do
					if( type(frameCfg) == "table" ) then
						if( frameCfg.filter == "BLIZZARD" ) then frameCfg.filter = "ALL" end
						if( type(frameCfg.sections) == "table" ) then
							for _, section in pairs(frameCfg.sections) do
								if( type(section) == "table" and section.filter == "BLIZZARD" ) then
									section.filter = "ALL"
								end
							end
						end
					end
				end
			end
		end

		-- Removed debuff filters, a remap that would duplicate an existing filter disables the frame (or drops the section) instead
		local removedDebuffFilters = {["BLIZZARD"] = "ALL", ["RAID_IN_COMBAT"] = "ALL", ["PLAYER|RAID_IN_COMBAT"] = "PLAYER", ["PLAYER|RAID"] = "PLAYER"}
		for _, unitCfg in pairs(self.db.profile.units) do
			if( unitCfg.auras and type(unitCfg.auras.debuffs) == "table" ) then
				local usedFilters = {}
				for _, frameCfg in pairs(unitCfg.auras.debuffs) do
					if( type(frameCfg) == "table" and frameCfg.enabled and not removedDebuffFilters[frameCfg.filter] ) then
						usedFilters[frameCfg.filter or "ALL"] = true
					end
				end

				for _, frameCfg in pairs(unitCfg.auras.debuffs) do
					if( type(frameCfg) == "table" ) then
						local mapped = removedDebuffFilters[frameCfg.filter]
						if( mapped ) then
							frameCfg.filter = mapped
							if( frameCfg.enabled and usedFilters[mapped] ) then
								frameCfg.enabled = false
							elseif( frameCfg.enabled ) then
								usedFilters[mapped] = true
							end
						end

						if( type(frameCfg.sections) == "table" ) then
							local own = frameCfg.filter or "ALL"
							local sectionFilters = {}
							for _, section in pairs(frameCfg.sections) do
								if( type(section) == "table" and section.filter and not removedDebuffFilters[section.filter] ) then
									sectionFilters[section.filter] = true
								end
							end
							for index, section in pairs(frameCfg.sections) do
								local sectionMapped = type(section) == "table" and removedDebuffFilters[section.filter]
								if( sectionMapped ) then
									if( sectionMapped == own or sectionFilters[sectionMapped] ) then
										frameCfg.sections[index] = nil
									else
										section.filter = sectionMapped
										sectionFilters[sectionMapped] = true
									end
								end
							end
						end
					end
				end
			end
		end

		-- isBossAura isn't reliable
		if( self.db.profile.auraIndicators and self.db.profile.auraIndicators.filters ) then
			for _, indicatorFilters in pairs(self.db.profile.auraIndicators.filters) do
				indicatorFilters.boss = nil
			end
		end
		for _, unitCfg in pairs(self.db.profile.units) do
			if( unitCfg.auraIndicators ) then
				unitCfg.auraIndicators["filter-boss"] = nil
			end
		end

		-- Merge the zone whitelists/blacklists into the custom filters — same data, one creation UI, zone assignments just point at the unified lists now
		local filters = self.db.profile.filters
		local customs = self.db.profile.customFilters
		if( filters and customs ) then
			local renames = {}
			local function migrateLists(lists, mode)
				if( not lists ) then return end
				for name, list in pairs(lists) do
					local target = name
					while( customs[target] ) do target = target .. "*" end

					local spells = {}
					for key in pairs(list) do
						local spellID = tonumber(key)
						if( spellID ) then spells[spellID] = true end
					end

					customs[target] = { mode = mode, spells = spells }
					renames[mode .. name] = target
				end
			end
			migrateLists(filters.whitelists, "include")
			migrateLists(filters.blacklists, "exclude")

			if( filters.zonewhite ) then
				for slot, name in pairs(filters.zonewhite) do
					filters.zonewhite[slot] = renames["include" .. name]
				end
			end
			if( filters.zoneblack ) then
				for slot, name in pairs(filters.zoneblack) do
					filters.zoneblack[slot] = renames["exclude" .. name]
				end
			end

			filters.whitelists = nil
			filters.blacklists = nil
		end

		-- Aura indicators dropped on compound unit tokens, the aura APIs reject them
		for unit, unitCfg in pairs(self.db.profile.units) do
			if( self.fakeUnits[unit] and unit ~= "targettarget" and unit ~= "focustarget" ) then
				unitCfg.auraIndicators = nil
			end
		end
	end
	if (revision <= 62 ) then
		-- evoker setup
		self.db.profile.classColors.EVOKER = {r = 0.20, g = 0.58, b = 0.50}
		self.db.profile.powerColors.ESSENCE = {r = 0.40, g = 0.80, b = 1.00}
		self.db.profile.units.player.essence = {enabled = true, anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -8, y = 6, size = 12, spacing = -2, growth = "LEFT", isBar = true, showAlways = true}
	end
	if (revision <= 61 ) then
		if self.db.profile.bars.texture == "Smooth" then
			self.db.profile.bars.texture = "Smoother"
		end
	end
	if (revision <= 60 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" or unit == "mainassist" or unit == "maintank" ) then
				config.indicators.sumPending = {enabled = true, anchorPoint = "C", size = 40, x = 0, y = 0, anchorTo = "$parent"}
			end
		end
	end
	if (revision <= 59 ) then
		self.db.profile.font.shadowX = 1.0
		self.db.profile.font.shadowY = -1.0
	end
	if( revision <= 58 ) then
		for unit, config in pairs(self.db.profile.units) do
			if config.text then
				local i = 1
				while i <= #config.text do
					local text
					if rawget(config.text, i) or i <= #(self.defaults.profile.units[unit].text) then
						text = config.text[i]
					end

					if not text then
						table.remove(config.text, i)
					elseif text.anchorTo == "$demonicFuryBar" or text.anchorTo == "$eclipseBar" or text.anchorTo == "$burningEmbersBar" or text.anchorTo == "$monkBar" then
						table.remove(config.text, i)
					elseif i > 6 and text.default and text.anchorTo == "$emptyBar" then
						table.remove(config.text, i)
					else
						if text.anchorTo == "$emptyBar" and text.name == L["Left text"] then
							text.width = 0.50
						end

						i = i + 1
					end
				end

				if not config.text[6] or config.text[6].anchorTo ~= "$emptyBar" then
					table.insert(config.text, 6, {enabled = true, width = 0.60, name = L["Right text"], text = "", anchorTo = "$emptyBar", anchorPoint = "CRI", size = 0, x = -3, y = 0, default = true})
				else
					config.text[6].width = 0.60
					config.text[6].name = L["Right text"]
					config.text[6].anchorPoint = "CRI"
					config.text[6].size = 0
					config.text[6].x = -3
					config.text[6].y = 0
					config.text[6].default = true
				end
			end
		end
	end

	if( revision <= 56 ) then
		-- new classes
		self.db.profile.classColors.DEMONHUNTER = {r = 0.64, g = 0.19, b = 0.79}

		-- new power types
		self.db.profile.powerColors.INSANITY = {r = 0.40, g = 0, b = 0.80}
		self.db.profile.powerColors.MAELSTROM = {r = 0.00, g = 0.50, b = 1.00}
		self.db.profile.powerColors.FURY = {r = 0.788, g = 0.259, b = 0.992}
		self.db.profile.powerColors.PAIN = {r = 1, g = 0, b = 0}
		self.db.profile.powerColors.LUNAR_POWER = {r = 0.30, g = 0.52, b = 0.90}
		self.db.profile.powerColors.ARCANECHARGES = {r = 0.1, g = 0.1, b = 0.98}

		-- new bars
		local config = self.db.profile.units
		config.player.priestBar = {enabled = true, background = true, height = 0.40, order = 70}
		config.player.shamanBar = {enabled = true, background = true, height = 0.40, order = 70}
		config.player.arcaneCharges = {enabled = true, anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -8, y = 6, size = 12, spacing = -2, growth = "LEFT", isBar = true, showAlways = true}

		-- clean out old bars
		config.player.demonicFuryBar = nil
		config.player.burningEmbersBar = nil
		config.player.shadowOrbs = nil
		config.player.eclipseBar = nil
		config.player.monkBar = nil
	end

	if( revision <= 49 ) then
		ShadowUF:LoadDefaultLayout(true)
	end

	if( revision <= 49 ) then
		if( ShadowUF.db.profile.font.extra == "MONOCHROME" ) then
			ShadowUF.db.profile.font.extra = ""
		end
	end

	if( revision <= 47 ) then
		local config = self.db.profile.units
		config.player.comboPoints = config.target.comboPoints
	end

	if( revision <= 46 ) then
		local config = self.db.profile.units.arena
		config.indicators.arenaSpec = {enabled = true, anchorPoint = "LC", size = 28, x = 0, y = 0, anchorTo = "$parent"}
		config.indicators.lfdRole = {enabled = true, anchorPoint = "BR", size = 14, x = 3, y = 14, anchorTo = "$parent"}
	end

	if( revision <= 45 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.auras ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					local aura = config.auras[key]
					aura.show = aura.show or {}
					aura.show.player = true
					aura.show.boss = true
					aura.show.raid = true
					aura.show.misc = true
				end
			end
		end
	end
	
	-- Migrate old auras config to new multi-frame structure
	if( revision <= 63 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.auras ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					local oldAura = config.auras[key]
					-- Check if this is old format (has 'enabled' at top level, not a numbered table)
					if( oldAura and oldAura.enabled ~= nil and oldAura[1] == nil ) then
						-- Migrate to new structure: old config becomes frame 1
						local newFrame = {
							enabled = oldAura.enabled,
							temporary = (unit == "player"),
							filter = "ALL", -- Default to showing all
							perRow = oldAura.perRow or 10,
							maxRows = oldAura.maxRows or 4,
							size = oldAura.size or 16,
							selfScale = oldAura.selfScale or 1.30,
							anchorPoint = oldAura.anchorPoint or (key == "buffs" and "TL" or "BL"),
							x = oldAura.x or 0,
							y = oldAura.y or 0,
							enlarge = oldAura.enlarge or {},
							timers = oldAura.timers or {ALL = true},
						}
						-- Create new structure with frame 1
						config.auras[key] = {
							[1] = newFrame,
							[2] = {enabled = false, filter = "PLAYER", perRow = 10, maxRows = 2, size = 16, selfScale = 1.30, anchorPoint = newFrame.anchorPoint, x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
							[3] = {enabled = false, filter = key == "debuffs" and "RAID_PLAYER_DISPELLABLE" or "RAID", perRow = 10, maxRows = 2, size = 16, selfScale = 1.30, anchorPoint = newFrame.anchorPoint, x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
							[4] = {enabled = false, filter = "RAID", perRow = 10, maxRows = 2, size = 16, selfScale = 1.30, anchorPoint = newFrame.anchorPoint, x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
							[5] = {enabled = false, filter = key == "debuffs" and "CROWD_CONTROL" or "BIG_DEFENSIVE", perRow = 10, maxRows = 2, size = 16, selfScale = 1.30, anchorPoint = newFrame.anchorPoint, x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
							[6] = {enabled = false, filter = "IMPORTANT", perRow = 10, maxRows = 2, size = 16, selfScale = 1.30, anchorPoint = newFrame.anchorPoint, x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
						}
					end
				end
				-- Add bossDebuffs if not present
				if( not config.auras.bossDebuffs ) then
					config.auras.bossDebuffs = {enabled = false, size = 32, maxAuras = 3, anchorPoint = "C", x = 0, y = 0}
				end
			end
		end
	end

	-- Clean up temporary = true on non-player unit types
	if( revision <= 64 ) then
		for unit, config in pairs(self.db.profile.units) do
			if unit ~= "player" and config.auras then
				for _, key in pairs({"buffs", "debuffs"}) do
					local typeConfig = config.auras[key]
					if typeConfig then
						for i = 1, 6 do
							if typeConfig[i] then
								typeConfig[i].temporary = nil
							end
						end
					end
				end
			end
		end
	end

	-- Disable auras on compound unit tokens (boss1target, party1target, etc.)
	if( revision <= 65 ) then
		local nonCompound = { ["targettarget"] = true, ["focustarget"] = true }
		for unit, config in pairs(self.db.profile.units) do
			if( config.auras and ShadowUF.fakeUnits[unit] and not nonCompound[unit] ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					if( config.auras[key] ) then
						for i = 1, 6 do
							if( config.auras[key][i] ) then
								config.auras[key][i].enabled = false
							end
						end
					end
				end
			end
		end
	end
	if( revision <= 66 ) then
		-- Remove override lists (no longer used in 12.0)
		self.db.profile.filters.zoneoverride = nil
		self.db.profile.filters.overridelists = nil
		-- Convert old string spell keys to numeric spellIDs in whitelists/blacklists
		for _, lists in pairs({self.db.profile.filters.whitelists, self.db.profile.filters.blacklists}) do
			for _, filter in pairs(lists) do
				local toAdd, toRemove = {}, {}
				for key, val in pairs(filter) do
					if val == true and type(key) == "string" then
						local numID = tonumber(key)
						if numID then
							toRemove[#toRemove + 1] = key
							toAdd[numID] = true
						else
							toRemove[#toRemove + 1] = key
						end
					end
				end
				for _, key in ipairs(toRemove) do filter[key] = nil end
				for id, val in pairs(toAdd) do filter[id] = val end
			end
		end
	end

	-- Migrate old anchorPoint codes to new system (anchorPoint + growH + growV)
	if( revision <= 67 ) then
		local anchorMigration = {
			TL  = {a = "TOPLEFT",     h = "RIGHT", v = "BOTTOM"},
			TR  = {a = "TOPRIGHT",    h = "LEFT",  v = "BOTTOM"},
			BL  = {a = "BOTTOMLEFT",  h = "RIGHT", v = "TOP"},
			BR  = {a = "BOTTOMRIGHT", h = "LEFT",  v = "TOP"},
			TC  = {a = "TOP",         h = "LEFT",  v = "BOTTOM"},
			BC  = {a = "BOTTOM",      h = "LEFT",  v = "TOP"},
			RT  = {a = "TOPRIGHT",    h = "RIGHT", v = "BOTTOM"},
			RB  = {a = "BOTTOMRIGHT", h = "RIGHT", v = "TOP"},
			LT  = {a = "TOPLEFT",     h = "LEFT",  v = "BOTTOM"},
			LB  = {a = "BOTTOMLEFT",  h = "LEFT",  v = "TOP"},
			LC  = {a = "LEFT",        h = "LEFT",  v = "BOTTOM"},
			RC  = {a = "RIGHT",       h = "RIGHT", v = "BOTTOM"},
			C   = {a = "CENTER",      h = "RIGHT", v = "BOTTOM"},
			CLI = {a = "LEFT",        h = "RIGHT", v = "BOTTOM"},
			CRI = {a = "RIGHT",       h = "LEFT",  v = "BOTTOM"},
			TLI = {a = "TOPLEFT",     h = "RIGHT", v = "BOTTOM"},
			TRI = {a = "TOPRIGHT",    h = "LEFT",  v = "BOTTOM"},
			BLI = {a = "BOTTOMLEFT",  h = "RIGHT", v = "TOP"},
			BRI = {a = "BOTTOMRIGHT", h = "LEFT",  v = "TOP"},
		}

		for unit, config in pairs(self.db.profile.units) do
			if( config.auras ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					local typeConfig = config.auras[key]
					if( typeConfig ) then
						for i = 1, 6 do
							local fc = typeConfig[i]
							if( fc and fc.anchorPoint ) then
								local m = anchorMigration[fc.anchorPoint]
								if( m ) then
									fc.anchorPoint = m.a
									fc.growH = fc.growH or m.h
									fc.growV = fc.growV or m.v
								end
							end
						end
					end
				end
				if( config.auras.bossDebuffs ) then
					local m = anchorMigration[config.auras.bossDebuffs.anchorPoint]
					if( m ) then
						config.auras.bossDebuffs.anchorPoint = m.a
					end
				end
			end
		end
	end

	-- Migrate BLIZZARD filter for unit types that no longer support it
	if revision <= 68 then
		local blizzardAllowed = {target = true, focus = true}
		for unit, config in pairs(self.db.profile.units) do
			if not blizzardAllowed[unit] and config.auras then
				for _, key in pairs({"buffs", "debuffs"}) do
					local typeConfig = config.auras[key]
					if typeConfig then
						for i = 1, 6 do
							if typeConfig[i] and typeConfig[i].filter == "BLIZZARD" then
								typeConfig[i].filter = (key == "buffs") and "PLAYER" or "ALL"
							end
						end
					end
				end
			end
		end
	end
	if( revision <= 69 ) then
		local f = self.db.profile.font
		if( f ) then
			if( f.shadowEnabled == nil ) then f.shadowEnabled = true end
			if( not f.shadowColor ) then f.shadowColor = {r = 0, g = 0, b = 0, a = 1} end
			if( f.shadowX == nil ) then f.shadowX = 1.0 end
			if( f.shadowY == nil ) then f.shadowY = -1.0 end
		end
	end
end

local function zoneEnabled(zone, zoneList)
	if( type(zoneList) == "string" ) then
		return zone == zoneList
	end

	for id, row in pairs(zoneList) do
		if( zone == row ) then return true end
	end

	return false
end

function ShadowUF:LoadUnits()
	-- CanHearthAndResurrectFromArea() returns true for world pvp areas, according to BattlefieldFrame.lua
	local instanceType = CanHearthAndResurrectFromArea() and "pvp" or select(2, IsInInstance())
	if( instanceType == "scenario" ) then instanceType = "party" end
	if( instanceType == "interior" ) then instanceType = "neighborhood" end

	if( not instanceType ) then instanceType = "none" end

	for _, type in pairs(self.unitList) do
		local enabled = self.db.profile.units[type].enabled
		if( ShadowUF.Units.zoneUnits[type] ) then
			enabled = enabled and zoneEnabled(instanceType, ShadowUF.Units.zoneUnits[type])
		elseif( instanceType ~= "none" ) then
			if( self.db.profile.visibility[instanceType][type] == false ) then
				enabled = false
			elseif( self.db.profile.visibility[instanceType][type] == true ) then
				enabled = true
			end
		end

		self.enabledUnits[type] = enabled

		if( enabled ) then
			self.Units:InitializeFrame(type)
		else
			self.Units:UninitializeFrame(type)
		end
	end
end

function ShadowUF:LoadUnitDefaults()
	for _, unit in pairs(self.unitList) do
		self.defaults.profile.positions[unit] = {point = "", relativePoint = "", anchorPoint = "", anchorTo = "UIParent", x = 0, y = 0}

		-- Aura APIs reject compound unit tokens, their aura frames default to disabled (same boundary as the Auras tab)
		local aurasBlocked = self.fakeUnits[unit] and unit ~= "targettarget" and unit ~= "focustarget"

		-- The reason why the defaults are so sparse, is because the layout needs to specify most of this. The reason I set tables here is basically
		-- as an indication that hey, the unit wants this, if it doesn't that it won't want it.
		self.defaults.profile.units[unit] = {
			enabled = false, height = 0, width = 0, scale = 1.0,
			healthBar = {enabled = true},
			powerBar = {enabled = true},
			emptyBar = {enabled = false},
			portrait = {enabled = false},
			castBar = {enabled = false, name = {}, time = {}},
			text = {
				{enabled = true, name = L["Left text"], text = "[name]", anchorPoint = "CLI", anchorTo = "$healthBar", width = 0.50, size = 0, x = 3, y = 0, default = true},
				{enabled = true, name = L["Right text"], text = "[curmaxhp]", anchorPoint = "CRI", anchorTo = "$healthBar", width = 0.60, size = 0, x = -3, y = 0, default = true},
				{enabled = true, name = L["Left text"], text = "[level] [race]", anchorPoint = "CLI", anchorTo = "$powerBar", width = 0.50, size = 0, x = 3, y = 0, default = true},
				{enabled = true, name = L["Right text"], text = "[curmaxpp]", anchorPoint = "CRI", anchorTo = "$powerBar", width = 0.60, size = 0, x = -3, y = 0, default = true},
				{enabled = true, name = L["Left text"], text = "", anchorTo = "$emptyBar", anchorPoint = "CLI", width = 0.50, size = 0, x = 3, y = 0, default = true},
				{enabled = true, name = L["Right text"], text = "", anchorTo = "$emptyBar", anchorPoint = "CRI", width = 0.60, size = 0, x = -3, y = 0, default = true},
				['*'] = {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0},
			},
			indicators = {raidTarget = {enabled = true, size = 0}},
			highlight = {},
			auras = {
				buffs = {
					[1] = {enabled = not aurasBlocked, temporary = (unit == "player"), filter = "ALL", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "TOPLEFT", growH = "RIGHT", growV = "BOTTOM", x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
					[2] = {enabled = false, filter = "PLAYER", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "TOPLEFT", growH = "RIGHT", growV = "BOTTOM", x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
					[3] = {enabled = false, filter = "RAID", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "TOPLEFT", growH = "RIGHT", growV = "BOTTOM", x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
					[4] = {enabled = false, filter = "BIG_DEFENSIVE", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "TOPLEFT", growH = "RIGHT", growV = "BOTTOM", x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
					[5] = {enabled = false, filter = "EXTERNAL_DEFENSIVE", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "TOPLEFT", growH = "RIGHT", growV = "BOTTOM", x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
					[6] = {enabled = false, filter = "IMPORTANT", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "TOPLEFT", growH = "RIGHT", growV = "BOTTOM", x = 0, y = 0, enlarge = {}, timers = {ALL = true}},
				},
				debuffs = {
					[1] = {enabled = not aurasBlocked, filter = "ALL", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "BOTTOMLEFT", growH = "RIGHT", growV = "TOP", x = 0, y = 0, enlarge = {PLAYER = true}, timers = {ALL = true}},
					[2] = {enabled = false, filter = "PLAYER", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "BOTTOMLEFT", growH = "RIGHT", growV = "TOP", x = 0, y = 0, enlarge = {PLAYER = true}, timers = {ALL = true}},
					[3] = {enabled = false, filter = "RAID_PLAYER_DISPELLABLE", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "BOTTOMLEFT", growH = "RIGHT", growV = "TOP", x = 0, y = 0, enlarge = {PLAYER = true}, timers = {ALL = true}},
					[4] = {enabled = false, filter = "RAID", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "BOTTOMLEFT", growH = "RIGHT", growV = "TOP", x = 0, y = 0, enlarge = {PLAYER = true}, timers = {ALL = true}},
					[5] = {enabled = false, filter = "CROWD_CONTROL", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "BOTTOMLEFT", growH = "RIGHT", growV = "TOP", x = 0, y = 0, enlarge = {PLAYER = true}, timers = {ALL = true}},
					[6] = {enabled = false, filter = "IMPORTANT", anchorMode = "COLUMN", perRow = 10, maxRows = 1, size = 16, selfScale = 1.30, anchorPoint = "BOTTOMLEFT", growH = "RIGHT", growV = "TOP", x = 0, y = 0, enlarge = {PLAYER = true}, timers = {ALL = true}},
				},
				-- Boss debuffs (Private Auras) - player only
				bossDebuffs = {enabled = false, size = 32, perRow = 3, maxRows = 1, anchorPoint = "CENTER", x = 0, y = 0, showCooldown = true, showCooldownNumbers = true},
			},
		}

		if( not aurasBlocked ) then
			self.defaults.profile.units[unit].auraIndicators = {enabled = false}
		end

		if( not self.fakeUnits[unit] ) then
			self.defaults.profile.units[unit].combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0}

			if( unit ~= "battleground" and unit ~= "battlegroundpet" and unit ~= "arena" and unit ~= "arenapet" and unit ~= "boss" ) then
				self.defaults.profile.units[unit].incHeal = {enabled = true, cap = 1.20, anchorMode = "healthBar", barSize = 1.0, barAlign = "CENTER", frameEdge = "END"}
				self.defaults.profile.units[unit].incAbsorb = {enabled = true, cap = 1.30, anchorMode = "healthBar", barSize = 1.0, barAlign = "CENTER", frameEdge = "END"}
				self.defaults.profile.units[unit].healAbsorb = {enabled = true, cap = 1.30, anchorMode = "healthBar", barSize = 1.0, barAlign = "CENTER", frameEdge = "END"}
			end
		end

		if( unit ~= "player" ) then
			self.defaults.profile.units[unit].range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0}

			if( not string.match(unit, "pet") ) then
				self.defaults.profile.units[unit].indicators.class = {enabled = false, size = 19}
			end
		end

		if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" or unit == "mainassist" or unit == "maintank" ) then
			self.defaults.profile.units[unit].indicators.leader = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.masterLoot = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.role = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.status = {enabled = false, size = 19}
			self.defaults.profile.units[unit].indicators.resurrect = {enabled = true}
			self.defaults.profile.units[unit].indicators.sumPending = {enabled = true}

			if( unit ~= "focus" and unit ~= "target" ) then
				self.defaults.profile.units[unit].indicators.ready = {enabled = true, size = 0}
			end
		end

		if( unit == "battleground" ) then
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
		end

		self.defaults.profile.units[unit].altPowerBar = {enabled = not ShadowUF.fakeUnits[unit]}
	end

	-- PLAYER
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.healthBar.predicted = true
	self.defaults.profile.units.player.powerBar.predicted = true
	self.defaults.profile.units.player.indicators.status.enabled = true
	self.defaults.profile.units.player.runeBar = {enabled = false}
	self.defaults.profile.units.player.totemBar = {enabled = false}
	self.defaults.profile.units.player.druidBar = {enabled = false}
	self.defaults.profile.units.player.priestBar = {enabled = true}
	self.defaults.profile.units.player.shamanBar = {enabled = true}
	self.defaults.profile.units.player.xpBar = {enabled = false}
	self.defaults.profile.units.player.fader = {enabled = false}
	self.defaults.profile.units.player.soulShards = {enabled = true, isBar = true}
	self.defaults.profile.units.player.arcaneCharges = {enabled = true, isBar = true}
	self.defaults.profile.units.player.staggerBar = {enabled = true}
	self.defaults.profile.units.player.comboPoints = {enabled = true, isBar = true}
	self.defaults.profile.units.player.holyPower = {enabled = true, isBar = true}
	self.defaults.profile.units.player.chi = {enabled = true, isBar = true}
	self.defaults.profile.units.player.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.player.auraPoints = {enabled = false, isBar = true}
	self.defaults.profile.units.player.essence = {enabled = true, isBar = true}
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})

    -- PET
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.pet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.pet.xpBar = {enabled = false}
    -- FOCUS
	self.defaults.profile.units.focus.enabled = true
	self.defaults.profile.units.focus.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.focus.indicators.lfdRole = {enabled = false, size = 0, x = 0, y = 0}
	self.defaults.profile.units.focus.indicators.questBoss = {enabled = true, size = 0, x = 0, y = 0}
	-- FOCUSTARGET
	self.defaults.profile.units.focustarget.enabled = true
	self.defaults.profile.units.focustarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- TARGET
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.indicators.lfdRole = {enabled = false, size = 0, x = 0, y = 0}
	self.defaults.profile.units.target.indicators.questBoss = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.target.comboPoints = {enabled = false, isBar = true}
	self.defaults.profile.units.target.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- TARGETTARGET/TARGETTARGETTARGET
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.targettargettarget.enabled = true
	-- PARTY
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1
	self.defaults.profile.units.party.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.party.combatText.enabled = false
	self.defaults.profile.units.party.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.party.indicators.phase = {enabled = true, size = 0, x = 0, y = 0}
	-- ARENA
	self.defaults.profile.units.arena.enabled = false
	self.defaults.profile.units.arena.attribPoint = "TOP"
	self.defaults.profile.units.arena.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.arena.auras.debuffs.maxRows = 1
	self.defaults.profile.units.arena.auras.buffs.maxRows = 1
	self.defaults.profile.units.arena.offset = 0
	self.defaults.profile.units.arena.indicators.arenaSpec = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.arena.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.arena.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- BATTLEGROUND
	self.defaults.profile.units.battleground.enabled = false
	self.defaults.profile.units.battleground.attribPoint = "TOP"
	self.defaults.profile.units.battleground.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.battleground.auras.debuffs.maxRows = 1
	self.defaults.profile.units.battleground.auras.buffs.maxRows = 1
	self.defaults.profile.units.battleground.offset = 0
	self.defaults.profile.units.battleground.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- BOSS
	self.defaults.profile.units.boss.enabled = false
	self.defaults.profile.units.boss.attribPoint = "TOP"
	self.defaults.profile.units.boss.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.boss.auras.debuffs.maxRows = 1
	self.defaults.profile.units.boss.auras.buffs.maxRows = 1
	self.defaults.profile.units.boss.offset = 0
	self.defaults.profile.units.boss.altPowerBar.enabled = true
	self.defaults.profile.units.boss.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- RAID
	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"
	self.defaults.profile.units.raid.sortMethod = "INDEX"
	self.defaults.profile.units.raid.attribPoint = "TOP"
	self.defaults.profile.units.raid.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raid.offset = 0
	self.defaults.profile.units.raid.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raid.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raid.combatText.enabled = false
	self.defaults.profile.units.raid.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- RAID PET
	self.defaults.profile.units.raidpet.groupBy = "GROUP"
	self.defaults.profile.units.raidpet.sortOrder = "ASC"
	self.defaults.profile.units.raidpet.sortMethod = "INDEX"
	self.defaults.profile.units.raidpet.attribPoint = "TOP"
	self.defaults.profile.units.raidpet.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raidpet.offset = 0
	self.defaults.profile.units.raidpet.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raidpet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raidpet.combatText.enabled = false
	-- MAINTANK
	self.defaults.profile.units.maintank.roleFilter = "TANK"
	self.defaults.profile.units.maintank.groupFilter = "MAINTANK"
	self.defaults.profile.units.maintank.groupBy = "GROUP"
	self.defaults.profile.units.maintank.sortOrder = "ASC"
	self.defaults.profile.units.maintank.sortMethod = "INDEX"
	self.defaults.profile.units.maintank.attribPoint = "TOP"
	self.defaults.profile.units.maintank.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.maintank.offset = 0
	self.defaults.profile.units.maintank.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- MAINASSIST
	self.defaults.profile.units.mainassist.groupFilter = "MAINASSIST"
	self.defaults.profile.units.mainassist.groupBy = "GROUP"
	self.defaults.profile.units.mainassist.sortOrder = "ASC"
	self.defaults.profile.units.mainassist.sortMethod = "INDEX"
	self.defaults.profile.units.mainassist.attribPoint = "TOP"
	self.defaults.profile.units.mainassist.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.mainassist.offset = 0
	self.defaults.profile.units.mainassist.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYPET
	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "RB"
	self.defaults.profile.units.partypet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGETTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}

	-- Aura indicators
	self.defaults.profile.auraIndicators = {
		disabled = {},
		missing = {},
		linked = {},
		indicators = {
			["tl"] = {name = L["Top Left"], anchorPoint = "TLI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = 4, y = -4, friendly = true, hostile = true},
			["tr"] = {name = L["Top Right"], anchorPoint = "TRI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = -3, y = -3, friendly = true, hostile = true},
			["bl"] = {name = L["Bottom Left"], anchorPoint = "BLI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = 4, y = 4, friendly = true, hostile = true},
			["br"] = {name = L["Bottom Right"], anchorPoint = "BRI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = -4, y = -4, friendly = true, hostile = true},
			["c"] = {name = L["Center"], anchorPoint = "C", anchorTo = "$parent", height = 20, width = 20, alpha = 1.0, x = 0, y = 0, friendly = true, hostile = true},
		},
		filters = {
			["tl"] = {boss = {priority = 100}, curable = {priority = 100}},
			["tr"] = {boss = {priority = 100}, curable = {priority = 100}},
			["bl"] = {boss = {priority = 100}, curable = {priority = 100}},
			["br"] = {boss = {priority = 100}, curable = {priority = 100}},
			["c"] = {boss = {priority = 100}, curable = {priority = 100}},
		},
		auras = {
			-- Resto Druid
			["774"] = [[{r=0.58, group="Druid", indicator="tr", g=0.28, player=true, duration=true, b=0.62, priority=100, alpha=1}]],
			["8936"] = [[{r=0.12, group="Druid", indicator="br", g=0.46, player=true, duration=true, b=0.12, priority=100, alpha=1}]],
			["33763"] = [[{r=0.23, group="Druid", indicator="tl", g=1, player=true, duration=true, alpha=1, priority=0, b=0.2}]],
			["48438"] = [[{r=0.55, group="Druid", indicator="", g=1, player=true, duration=true, b=0.39, priority=100, alpha=1}]],
			["155777"] = [[{r=0.58, group="Druid", indicator="tr", g=0.28, player=true, duration=true, b=0.62, priority=100, alpha=1}]],
			-- Disc Priest
			["17"] = [[{r=1, group="Priest", indicator="tl", g=0.42, player=true, alpha=1, duration=true, b=0.58, priority=0}]],
			["194384"] = [[{r=1, group="Priest", indicator="tl", g=0.82, player=true, alpha=1, duration=true, b=0.30, priority=10}]],
			-- Holy Priest
			["139"] = [[{r=0.24, group="Priest", indicator="tr", g=1, player=true, alpha=1, duration=true, b=0.40, priority=10}]],
			["41635"] = [[{r=1, group="Priest", indicator="br", g=0.90, player=true, duration=false, alpha=1, b=0, priority=50}]],
			["77489"] = [[{r=0.90, group="Priest", indicator="", g=0.90, player=true, duration=true, alpha=1, b=0.90, priority=0}]],
			-- Mistweaver Monk
			["119611"] = [[{r=0.26, group="Monk", indicator="tl", g=0.76, player=true, duration=true, alpha=1, b=0.54, priority=0}]],
			["124682"] = [[{r=0.51, group="Monk", indicator="br", g=1, player=true, duration=true, b=0.91, alpha=1, priority=100}]],
			["115175"] = [[{r=0.26, group="Monk", indicator="", g=0.76, player=true, duration=true, alpha=1, b=0.54, priority=0}]],
			["450769"] = [[{r=0.80, group="Monk", indicator="", g=0.60, player=true, duration=true, alpha=1, b=0.20, priority=0}]],
			-- Restoration Shaman
			["61295"] = [[{r=0.18, group="Shaman", indicator="tl", g=0.4, player=true, alpha=1, duration=true, b=1, priority=0}]],
			["974"] = [[{r=0.18, group="Shaman", indicator="", g=0.80, player=true, alpha=1, duration=true, b=0.44, priority=0}]],
			-- Holy Paladin
			["53563"] = [[{r=0.64, group="Paladin", indicator="tr", g=0.25, player=true, alpha=1, b=0.73, priority=100, duration=false}]],
			["156910"] = [[{r=0.64, group="Paladin", indicator="tr", g=0.25, player=true, alpha=1, b=0.73, priority=90, duration=false}]],
			["156322"] = [[{r=1, group="Paladin", indicator="br", g=0.60, player=true, alpha=1, b=0.20, priority=50, duration=true}]],
			-- Preservation Evoker
			["364343"] = [[{r=0.20, group="Evoker", indicator="tr", g=0.80, player=true, alpha=1, b=0.40, priority=100, duration=true}]],
			["366155"] = [[{r=0.20, group="Evoker", indicator="tl", g=0.80, player=true, alpha=1, b=0.40, priority=0, duration=true}]],
			["355941"] = [[{r=0.20, group="Evoker", indicator="", g=0.80, player=true, alpha=1, b=0.40, priority=0, duration=true}]],
			-- Augmentation Evoker
			["410089"] = [[{r=0.95, group="Evoker", indicator="tl", g=0.75, player=true, alpha=1, b=0.30, priority=100, duration=true}]],
			["395152"] = [[{r=0.55, group="Evoker", indicator="tl", g=0.20, player=true, alpha=1, b=0.80, priority=90, duration=true}]],
		}
	}

	for classToken in pairs(RAID_CLASS_COLORS) do
		self.defaults.profile.auraIndicators.disabled[classToken] = {}
	end
end

-- Module APIs
function ShadowUF:RegisterModule(module, key, name, isBar, class, spec, level)
	-- Prevent duplicate registration for deprecated plugin
	if( key == "auraIndicators" and C_AddOns.IsAddOnLoaded("ShadowedUF_Indicators") and self.modules.auraIndicators ) then
		self:Print(L["WARNING! ShadowedUF_Indicators has been deprecated as v4 and is now built in. Please delete ShadowedUF_Indicators, your configuration will be saved."])
		return
	end

	self.modules[key] = module

	module.moduleKey = key
	module.moduleHasBar = isBar
	module.moduleName = name
	module.moduleClass = class
	module.moduleLevel = level

	if( type(spec) == "number" ) then
		module.moduleSpec = {}
		module.moduleSpec[spec] = true
	elseif( type(spec) == "table" ) then
		module.moduleSpec = {}
		for _, id in pairs(spec) do
			module.moduleSpec[id] = true
		end
	end

	table.insert(self.moduleOrder, module)
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for _, module in pairs(self.moduleOrder) do
		if( module[event] ) then
			-- Errors still hit the error handler, but a broken module doesn't starve the others of their layout/enable events anymore
			xpcall(module[event], CallErrorHandler, module, frame, unit)
		end
	end
end

-- Profiles changed
-- I really dislike this solution, but if we don't do it then there is setting issues
-- because when copying a profile, AceDB-3.0 fires OnProfileReset -> OnProfileCopied
-- SUF then sees that on the new reset profile has no profile, tries to load one in
-- ... followed by the profile copying happen and it doesn't copy everything correctly
-- due to variables being reset already.
local resetTimer
function ShadowUF:ProfileReset()
	if( not resetTimer ) then
		resetTimer = CreateFrame("Frame")
		resetTimer:SetScript("OnUpdate", function(f)
			ShadowUF:ProfilesChanged()
			f:Hide()
		end)
	end

	resetTimer:Show()
end

-- Options paths that end in protected calls queue their apply step here, coalesced by key
local regenWatcher
function ShadowUF:DeferUntilRegen(key, callback, message)
	if( not regenWatcher ) then
		regenWatcher = CreateFrame("Frame")
		regenWatcher.pending = {}
		regenWatcher:SetScript("OnEvent", function(watcher)
			watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
			local pending = watcher.pending
			watcher.pending = {}
			for _, pendingCallback in pairs(pending) do
				pendingCallback()
			end
		end)
	end
	if( not regenWatcher.pending[key] and message ) then
		self:Print(message)
	end
	regenWatcher.pending[key] = callback
	regenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local profileChangeWatcher
function ShadowUF:ProfilesChanged()
	if( self.layoutImporting ) then return end
	-- Rebuilding every frame goes through protected calls, replay the whole thing at regen
	if( InCombatLockdown() ) then
		if( not profileChangeWatcher ) then
			profileChangeWatcher = CreateFrame("Frame")
			profileChangeWatcher:SetScript("OnEvent", function(watcher)
				watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
				ShadowUF:ProfilesChanged()
			end)
		end
		if( not profileChangeWatcher:IsEventRegistered("PLAYER_REGEN_ENABLED") ) then
			profileChangeWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
			self:Print(L["Profile changes will be applied after combat."])
		end
		return
	end
	if( resetTimer ) then resetTimer:Hide() end

	-- Unlock and test modes never survive a profile switch, the new profile always starts locked
	local movers = self.modules.movers
	if( movers ) then
		if( movers.isEnabled ) then
			movers:Disable(true)
		elseif( movers.testModeUnits and next(movers.testModeUnits) ) then
			local snapshot = {}
			for unitType in pairs(movers.testModeUnits) do snapshot[unitType] = true end
			for unitType in pairs(snapshot) do
				movers:DisableTestMode(unitType, true)
			end
		end
	end
	self.db.profile.locked = true
	for _, unitCfg in pairs(self.db.profile.units) do
		if( unitCfg.auras ) then unitCfg.auras.testMode = nil end
	end

	self.db:RegisterDefaults(self.defaults)

	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
		self:CheckBuild()
	end

	self.db.profile.revision = self.dbRevision
	self:ApplyAuraSpellIDsCVar()

	self:FireModuleEvent("OnProfileChange")
	self:LoadUnits()
	self:HideBlizzardFrames()
	self.Layout:CheckMedia()
	self.Units:ProfileChanged()
	self.modules.movers:Update()

	-- Config trees that enumerate profile data need a rebuild, no-op while the options addon isn't loaded
	if( self.Config and self.Config.ProfilesChanged ) then
		self.Config:ProfilesChanged()
	end

	-- The reset path runs deferred, an open config dialog has already refreshed against the pre-layout state
	local ACR = LibStub("AceConfigRegistry-3.0", true)
	if( ACR ) then ACR:NotifyChange("ShadowedUF") end
end

ShadowUF.noop = function() end
ShadowUF.hiddenFrame = CreateFrame("Frame")
ShadowUF.hiddenFrame:Hide()

local rehideFrame = function(self)
	if( not InCombatLockdown() ) then
		self:Hide()
	end
end

local function basicHideBlizzardFrames(...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		frame:UnregisterAllEvents()
		frame:HookScript("OnShow", rehideFrame)
		frame:Hide()
	end
end

local hookedFrames = {}

-- Hide a Blizzard frame but preserve specific events for aura tracking (Blizzard filter).
local function hideBlizzardFrameKeepAuras(frame, keepEvents)
	if not InCombatLockdown() then
		UnregisterUnitWatch(frame)
	end
	frame:UnregisterAllEvents()
	for _, event in ipairs(keepEvents) do
		if event == "UNIT_AURA" then
			frame:RegisterUnitEvent(event, frame.unit)
		else
			frame:RegisterEvent(event)
		end
	end
	frame:Hide()

	if frame.manabar then frame.manabar:UnregisterAllEvents() end
	if frame.healthbar then frame.healthbar:UnregisterAllEvents() end
	if frame.spellbar then frame.spellbar:UnregisterAllEvents() end
	if frame.powerBarAlt then frame.powerBarAlt:UnregisterAllEvents() end

	if not InCombatLockdown() then
		frame:SetParent(ShadowUF.hiddenFrame)
	end
	frame:HookScript("OnShow", rehideFrame)

	if not hookedFrames[frame] then
		hooksecurefunc(frame, "SetParent", function(self, parent)
			if parent ~= ShadowUF.hiddenFrame then
				if not InCombatLockdown() or not self:IsProtected() then
					self:SetParent(ShadowUF.hiddenFrame)
				end
			end
		end)
		hookedFrames[frame] = true
	end
end

local function hideBlizzardFrames(...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		-- Unit watch state lives on a protected manager, always blocked in combat regardless of the frame
		if( InCombatLockdown() ) then
			ShadowUF:DeferUntilRegen(frame, function()
				UnregisterUnitWatch(frame)
				frame:Hide()
				frame:SetParent(ShadowUF.hiddenFrame)
			end)
		else
			UnregisterUnitWatch(frame)
		end
		frame:UnregisterAllEvents()
		if( not InCombatLockdown() or not frame:IsProtected() ) then
			frame:Hide()
		end

		if( frame.manabar ) then frame.manabar:UnregisterAllEvents() end
		if( frame.healthbar ) then frame.healthbar:UnregisterAllEvents() end
		if( frame.spellbar ) then frame.spellbar:UnregisterAllEvents() end
		if( frame.powerBarAlt ) then frame.powerBarAlt:UnregisterAllEvents() end

		if( not InCombatLockdown() ) then
			frame:SetParent(ShadowUF.hiddenFrame)
		end
		frame:HookScript("OnShow", rehideFrame)

		-- Prevent Blizzard from reparenting the frame away from hiddenFrame
		if( not hookedFrames[frame] ) then
			hooksecurefunc(frame, "SetParent", function(self, parent)
				if( parent ~= ShadowUF.hiddenFrame ) then
					if( not InCombatLockdown() or not self:IsProtected() ) then
						self:SetParent(ShadowUF.hiddenFrame)
					end
				end
			end)
			hookedFrames[frame] = true
		end
	end
end

-- Check if any aura frame on this unit type uses the Blizzard filter
local function unitUsesBlizzardFilter(unitType)
	local cfg = ShadowUF.db.profile.units[unitType]
	if not cfg or not cfg.auras then return false end
	for _, auraType in pairs({"buffs", "debuffs"}) do
		local t = cfg.auras[auraType]
		if t then
			for i = 1, 6 do
				if t[i] and t[i].filter == "BLIZZARD" then return true end
			end
		end
	end
	return false
end

local active_hiddens = {}
function ShadowUF:HideBlizzardFrames()
	if( self.db.profile.hidden.cast and not active_hiddens.cast ) then
		hideBlizzardFrames(PlayerCastingBarFrame, PetCastingBarFrame)
	end

	if( self.db.profile.hidden.party and not active_hiddens.party ) then
		if( PartyFrame ) then
			hideBlizzardFrames(PartyFrame)
			for memberFrame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
				if memberFrame.HealthBarContainer and memberFrame.HealthBarContainer.HealthBar then
					hideBlizzardFrames(memberFrame, memberFrame.HealthBarContainer.HealthBar, memberFrame.ManaBar)
				else
					hideBlizzardFrames(memberFrame, memberFrame.HealthBar, memberFrame.ManaBar)
				end
			end
			PartyFrame.PartyMemberFramePool:ReleaseAll()
		else
			for i=1, MAX_PARTY_MEMBERS do
				local name = "PartyMemberFrame" .. i
				hideBlizzardFrames(_G[name], _G[name .. "HealthBar"], _G[name .. "ManaBar"])
			end
		end

		-- This stops the compact party frame from being shown
		UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")

		-- This just makes sure
		if( CompactPartyFrame ) then
			hideBlizzardFrames(CompactPartyFrame)
		end
	end

	if( CompactRaidFrameManager ) then
		if( self.db.profile.hidden.raid and not active_hiddens.raidTriggered ) then
			active_hiddens.raidTriggered = true

			local function hideRaid()
				CompactRaidFrameManager:UnregisterAllEvents()
				CompactRaidFrameContainer:UnregisterAllEvents()
				if( InCombatLockdown() ) then return end

				CompactRaidFrameManager:Hide()
				local shown = CompactRaidFrameManager_GetSetting("IsShown")
				if( shown and shown ~= "0" ) then
					CompactRaidFrameManager_SetSetting("IsShown", "0")
				end
			end

			hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
				if( self.db.profile.hidden.raid ) then
					hideRaid()
				end
			end)

			hideRaid()
			CompactRaidFrameContainer:HookScript("OnShow", hideRaid)
			CompactRaidFrameManager:HookScript("OnShow", hideRaid)
		end
	end

	if( self.db.profile.hidden.buffs and not active_hiddens.buffs ) then
		hideBlizzardFrames(BuffFrame, DebuffFrame)
	end

	if( self.db.profile.hidden.player and not active_hiddens.player ) then
		hideBlizzardFrames(PlayerFrame, AlternatePowerBar)

		-- We keep these in case someone is still using the default auras, otherwise it messes up vehicle stuff
		PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		PlayerFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
		PlayerFrame:SetMovable(true)
		PlayerFrame:SetUserPlaced(true)
		PlayerFrame:SetDontSavePosition(true)
	end

	if( self.db.profile.hidden.playerPower and not active_hiddens.playerPower ) then
		basicHideBlizzardFrames(RuneFrame, WarlockPowerFrame, MonkHarmonyBarFrame, PaladinPowerBarFrame, MageArcaneChargesFrame, EssencePlayerFrame)
	end

	if( self.db.profile.hidden.pet and not active_hiddens.pet ) then
		hideBlizzardFrames(PetFrame)
	end

	if( self.db.profile.hidden.target and not active_hiddens.target ) then
		if unitUsesBlizzardFilter("target") and TargetFrame then
			hideBlizzardFrameKeepAuras(TargetFrame, {"UNIT_AURA", "PLAYER_TARGET_CHANGED"})
			hideBlizzardFrames(ComboFrame, TargetFrameToT)
		else
			hideBlizzardFrames(TargetFrame, ComboFrame, TargetFrameToT)
		end
	end

	if( self.db.profile.hidden.focus and not active_hiddens.focus ) then
		if unitUsesBlizzardFilter("focus") and FocusFrame then
			hideBlizzardFrameKeepAuras(FocusFrame, {"UNIT_AURA", "PLAYER_FOCUS_CHANGED"})
			hideBlizzardFrames(FocusFrameToT)
		else
			hideBlizzardFrames(FocusFrame, FocusFrameToT)
		end
	end

	if( self.db.profile.hidden.boss and not active_hiddens.boss ) then
		hideBlizzardFrames(BossTargetFrameContainer)

		for i=1, MAX_BOSS_FRAMES do
			local name = "Boss" .. i .. "TargetFrame"
			if _G[name].TargetFrameContent then
				if _G[name].TargetFrameContent.TargetFrameContentMain.HealthBarsContainer then
					hideBlizzardFrames(_G[name], _G[name].TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar, _G[name].TargetFrameContent.TargetFrameContentMain.ManaBar)
				else
					hideBlizzardFrames(_G[name], _G[name].TargetFrameContent.TargetFrameContentMain.HealthBar, _G[name].TargetFrameContent.TargetFrameContentMain.ManaBar)
				end
			else
				hideBlizzardFrames(_G[name], _G[name .. "HealthBar"], _G[name .. "ManaBar"])
			end
		end
	end

	if( self.db.profile.hidden.arena and not active_hiddens.arenaTriggered ) then
		active_hiddens.arenaTriggered = true

		-- Hide CompactArenaFrame if it already exists (e.g. /reload inside arena)
		if CompactArenaFrame then
			hideBlizzardFrames(CompactArenaFrame)
		end

		-- Hook CompactArenaFrame_Generate to catch dynamic creation
		if CompactArenaFrame_Generate and not active_hiddens.arenaHooked then
			hooksecurefunc("CompactArenaFrame_Generate", function()
				if CompactArenaFrame then
					hideBlizzardFrames(CompactArenaFrame)
				end
			end)
			active_hiddens.arenaHooked = true
		end
	end

	if( self.db.profile.hidden.playerAltPower and not active_hiddens.playerAltPower ) then
		hideBlizzardFrames(PlayerPowerBarAlt)
	end

	-- As a reload is required to reset the hidden hooks, we can just set this to true if anything is true
	for type, flag in pairs(self.db.profile.hidden) do
		if( flag ) then
			active_hiddens[type] = true
		end
	end
end

-- Upgrade info
local infoMessages = {
	-- Old messages we don't need anymore
	{}, {},
	{
		L["You must restart Shadowed Unit Frames."],
		L["If you don't, you will be unable to use any combo point features (Chi, Holy Power, Combo Points, Aura Points, etc) until you do so."]
	}
}

function ShadowUF:ShowInfoPanel()
	local infoID = ShadowUF.db.global.infoID or 0
	if( ShadowUF.ComboPoints and infoID < 3 ) then infoID = 3 end

	ShadowUF.db.global.infoID = #(infoMessages)
	if( infoID < 0 or infoID >= #(infoMessages) ) then return end

	local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetWidth(500)
	frame:SetHeight(285)
	frame:SetBackdrop({
		  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		  edgeSize = 26,
		  insets = {left = 9, right = 9, top = 9, bottom = 9},
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

	frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
	frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	frame.titleBar:SetPoint("TOP", 0, 8)
	frame.titleBar:SetWidth(350)
	frame.titleBar:SetHeight(45)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOP", 0, 0)
	frame.title:SetText("Shadowed Unit Frames")

	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.text:SetText(table.concat(infoMessages[ShadowUF.db.global.infoID], "\n"))
	frame.text:SetPoint("TOPLEFT", 12, -22)
	frame.text:SetWidth(frame:GetWidth() - 20)
	frame.text:SetJustifyH("LEFT")
	frame:SetHeight(frame.text:GetHeight() + 70)

	frame.hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.hide:SetText(L["Ok"])
	frame.hide:SetHeight(20)
	frame.hide:SetWidth(100)
	frame.hide:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
	frame.hide:SetScript("OnClick", function(f)
		f:GetParent():Hide()
	end)
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Shadow UF|r: " .. msg)
end

function ShadowUF:SafeMath(func, ...)
	local success, result = pcall(func, ...)
	if( success ) then
		return result
	end
	return nil
end

function ShadowUF:SafeFormatLargeNumber(number)
	if( type(number) ~= "number" ) then
		return number
	end
	
	local success, result = pcall(ShadowUF.FormatLargeNumber, self, number)
	if( success ) then
		return result
	end
	
	-- Fallback for secret values: return raw number as string (trusted)
	return tostring(number)
end

function ShadowUF:SafeSmartFormatNumber(number)
	if( type(number) ~= "number" ) then
		return number
	end

	local success, result = pcall(ShadowUF.SmartFormatNumber, self, number)
	if( success ) then
		return result
	end

	return string.format("%s", number)
end

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS["Shadowed Unit Frames"] = function(mode)
	if( mode == "ON" ) then
		ShadowUF.db.profile.locked = false
		ShadowUF.modules.movers.isConfigModeSpec = true
	elseif( mode == "OFF" ) then
		ShadowUF.db.profile.locked = true
	end

	ShadowUF.modules.movers:Update()
end

SLASH_SHADOWEDUF1 = "/suf"
SLASH_SHADOWEDUF2 = "/shadowuf"
SLASH_SHADOWEDUF3 = "/shadoweduf"
SLASH_SHADOWEDUF4 = "/shadowedunitframes"
SlashCmdList["SHADOWEDUF"] = function(msg)
	msg = msg and string.lower(msg)
	if( msg and string.match(msg, "^profile (.+)") ) then
		local profile = string.match(msg, "^profile (.+)")

		for id, name in pairs(ShadowUF.db:GetProfiles()) do
			if( string.lower(name) == profile ) then
				ShadowUF.db:SetProfile(name)
				ShadowUF:Print(string.format(L["Changed profile to %s."], name))
				return
			end
		end

		ShadowUF:Print(string.format(L["Cannot find any profiles named \"%s\"."], profile))
		return
	end

	local loaded, reason = C_AddOns.LoadAddOn("ShadowedUF_Options")
	if( not ShadowUF.Config ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["Failed to load ShadowedUF_Options, cannot open configuration. Error returned: %s"], reason and _G["ADDON_" .. reason] or ""))
		return
	end

	ShadowUF.Config:Open()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( event == "PLAYER_LOGIN" ) then
		ShadowUF:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif( event == "ADDON_LOADED" and addon == "Blizzard_CompactRaidFrames" ) then
		ShadowUF:HideBlizzardFrames()
	end
end)
