local Indicators = {}
ShadowUF:RegisterModule(Indicators, "auraIndicators", ShadowUF.L["Aura indicators"])

Indicators.auraFilters = {"curable"}

local GetSpellTexture = C_Spell.GetSpellTexture

-- Blizzard non-secret spell whitelist (Midnight launch hotfix)
-- These spells return non-secret AuraData even in combat on party/raid units.
-- Source: Meorawr (Blizzard) announcement — data hotfix, not yet in API docs.
Indicators.whitelistedSpells = {
	-- Evoker
	[355941] = { name = "Dream Breath", group = "Evoker" },
	[363502] = { name = "Dream Flight", group = "Evoker" },
	[364343] = { name = "Echo", group = "Evoker" },
	[366155] = { name = "Reversion", group = "Evoker" },
	[367364] = { name = "Echo Reversion", group = "Evoker" },
	[369459] = { name = "Source of Magic", group = "Evoker" },
	[373267] = { name = "Lifebind", group = "Evoker" },
	[376788] = { name = "Echo Dream Breath", group = "Evoker" },
	[360827] = { name = "Blistering Scales", group = "Evoker" },
	[381732] = { name = "Blessing of the Bronze (DK)", group = "Evoker" },
	[381741] = { name = "Blessing of the Bronze (DH)", group = "Evoker" },
	[381746] = { name = "Blessing of the Bronze (Druid)", group = "Evoker" },
	[381748] = { name = "Blessing of the Bronze (Evoker)", group = "Evoker" },
	[381749] = { name = "Blessing of the Bronze (Hunter)", group = "Evoker" },
	[381750] = { name = "Blessing of the Bronze (Mage)", group = "Evoker" },
	[381751] = { name = "Blessing of the Bronze (Monk)", group = "Evoker" },
	[381752] = { name = "Blessing of the Bronze (Paladin)", group = "Evoker" },
	[381753] = { name = "Blessing of the Bronze (Priest)", group = "Evoker" },
	[381754] = { name = "Blessing of the Bronze (Rogue)", group = "Evoker" },
	[381756] = { name = "Blessing of the Bronze (Shaman)", group = "Evoker" },
	[381757] = { name = "Blessing of the Bronze (Warlock)", group = "Evoker" },
	[381758] = { name = "Blessing of the Bronze (Warrior)", group = "Evoker" },
	[395152] = { name = "Ebon Might", group = "Evoker" },
	[395296] = { name = "Ebon Might", group = "Evoker" },
	[409895] = { name = "Verdant Embrace", group = "Evoker" },
	[410089] = { name = "Prescience", group = "Evoker" },
	[410263] = { name = "Inferno's Blessing", group = "Evoker" },
	[410686] = { name = "Symbiotic Bloom", group = "Evoker" },
	[439530] = { name = "Symbiotic Blooms", group = "Evoker" },
	[413984] = { name = "Shifting Sands", group = "Evoker" },
	-- Druid
	[774]    = { name = "Rejuvenation", group = "Druid" },
	[1126]   = { name = "Mark of the Wild", group = "Druid" },
	[8936]   = { name = "Regrowth", group = "Druid" },
	[33763]  = { name = "Lifebloom", group = "Druid" },
	[48438]  = { name = "Wild Growth", group = "Druid" },
	[155777] = { name = "Germination", group = "Druid" },
	[405189] = { name = "Overflowing Power", group = "Druid" },
	[474754] = { name = "Symbiotic Relationship", group = "Druid" },
	-- Priest
	[17]     = { name = "Power Word: Shield", group = "Priest" },
	[139]    = { name = "Renew", group = "Priest" },
	[21562]  = { name = "Power Word: Fortitude", group = "Priest" },
	[41635]  = { name = "Prayer of Mending", group = "Priest" },
	[77489]  = { name = "Echo of Light", group = "Priest" },
	[194384] = { name = "Atonement", group = "Priest" },
	[431381] = { name = "Dawnlight", group = "Priest" },
	[1253593]= { name = "Void Shield", group = "Priest" },
	[1300008]= { name = "Power Word: Shield (Unfolding Vision)", group = "Priest" },
	[1300009]= { name = "Void Shield (Unfolding Vision)", group = "Priest" },
	-- Monk
	[115175] = { name = "Soothing Mist", group = "Monk" },
	[119611] = { name = "Renewing Mist", group = "Monk" },
	[124682] = { name = "Enveloping Mist", group = "Monk" },
	[450769] = { name = "Aspect of Harmony", group = "Monk" },
	[1292922]= { name = "Coalescence", group = "Monk" },
	-- Shaman
	[974]    = { name = "Earth Shield", group = "Shaman" },
	[20608]  = { name = "Reincarnation", group = "Shaman" },
	[61295]  = { name = "Riptide", group = "Shaman" },
	[207400] = { name = "Ancestral Vigor", group = "Shaman" },
	[319773] = { name = "Windfury Weapon", group = "Shaman" },
	[319778] = { name = "Flametongue Weapon", group = "Shaman" },
	[382021] = { name = "Earthliving Weapon", group = "Shaman" },
	[382022] = { name = "Earthliving Weapon", group = "Shaman" },
	[382024] = { name = "Earthliving Weapon", group = "Shaman" },
	[383648] = { name = "Earth Shield", group = "Shaman" },
	[444490] = { name = "Hydrobubble", group = "Shaman" },
	[457481] = { name = "Tidecaller's Guard", group = "Shaman" },
	[457496] = { name = "Tidecaller's Guard", group = "Shaman" },
	[462742] = { name = "Thunderstrike Ward", group = "Shaman" },
	[462757] = { name = "Thunderstrike Ward", group = "Shaman" },
	[344179] = { name = "Maelstrom Weapon", group = "Shaman" },
	[462854] = { name = "Skyfury", group = "Shaman" },
	-- Paladin
	[53563]  = { name = "Beacon of Light", group = "Paladin" },
	[156322] = { name = "Eternal Flame", group = "Paladin" },
	[156910] = { name = "Beacon of Faith", group = "Paladin" },
	[433568] = { name = "Rite of Sanctification", group = "Paladin" },
	[433583] = { name = "Rite of Adjuration", group = "Paladin" },
	[200025] = { name = "Beacon of Virtue", group = "Paladin" },
	[1244893]= { name = "Beacon of the Savior", group = "Paladin" },
	-- Mage
	[1459]   = { name = "Arcane Intellect", group = "Mage" },
	[205473] = { name = "Icicles", group = "Mage" },
	-- Warrior
	[6673]   = { name = "Battle Shout", group = "Warrior" },
	-- Hunter
	[260286] = { name = "Tip of the Spear", group = "Hunter" },
	-- Demon Hunter
	[1217607]= { name = "Void Metamorphosis", group = "Demon Hunter" },
	[1225789]= { name = "Void Metamorphosis", group = "Demon Hunter" },
	-- Rogue
	[2823]   = { name = "Deadly Poison", group = "Rogue" },
	[3408]   = { name = "Crippling Poison", group = "Rogue" },
	[5761]   = { name = "Numbing Poison", group = "Rogue" },
	[8679]   = { name = "Wound Poison", group = "Rogue" },
	[315584] = { name = "Instant Poison", group = "Rogue" },
	[381637] = { name = "Atrophic Poison", group = "Rogue" },
	[381664] = { name = "Amplifying Poison", group = "Rogue" },
	-- General
	[8690]   = { name = "Hearthstone", group = "General" },
	-- Debuffs
	[26013]  = { name = "Deserter", group = "Debuffs" },
	[57723]  = { name = "Exhaustion", group = "Debuffs" },
	[57724]  = { name = "Sated", group = "Debuffs" },
	[71041]  = { name = "Dungeon Deserter", group = "Debuffs" },
	[80354]  = { name = "Temporal Displacement", group = "Debuffs" },
	[95809]  = { name = "Insanity", group = "Debuffs" },
	[160455] = { name = "Fatigued", group = "Debuffs" },
	[264689] = { name = "Fatigued", group = "Debuffs" },
	[390435] = { name = "Exhaustion", group = "Debuffs" },
	-- Skyriding
	[427490] = { name = "Ride Along Available", group = "Skyriding" },
	[447959] = { name = "Ride Along Active", group = "Skyriding" },
	[447960] = { name = "Ride Along Inactive", group = "Skyriding" },
}

Indicators.auraConfig = setmetatable({}, {
	__index = function(tbl, index)
		local aura = ShadowUF.db.profile.auraIndicators.auras[tostring(index)]
		if( not aura ) then
			tbl[index] = false
		else
			local func, msg = loadstring("return " .. aura)
			if( func ) then
				func = func()
			elseif( msg ) then
				error(msg, 3)
			end

			tbl[index] = func
			if( not tbl[index].group ) then tbl[index].group = "Miscellaneous" end
		end

		return tbl[index]
end})

local playerUnits = {player = true, vehicle = true, pet = true}
local backdropTbl = {bgFile = "Interface\\Addons\\ShadowedUnitFrames\\mediabackdrop", edgeFile = "Interface\\Addons\\ShadowedUnitFrames\\media\\backdrop", tile = true, tileSize = 1, edgeSize = 1}

function Indicators:OnProfileChange()
	table.wipe(self.auraConfig)
end

function Indicators:OnEnable(frame)
	-- Not going to create the indicators we want here, will do that when we do the layout stuff
	frame.auraIndicators = frame.auraIndicators or CreateFrame("Frame", nil, frame)
	frame.auraIndicators:SetFrameLevel(4)
	frame.auraIndicators:Show()

	-- Of course, watch for auras
	frame:RegisterUnitEvent("UNIT_AURA", self, "UpdateAuras")
	-- UNIT_FACTION re-runs the slot mute gate when reaction flips without a unit change (mind control, duels)
	frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateAuras")
	-- Instance and phase transitions move units in and out of the area of interest
	frame:RegisterUnitEvent("UNIT_PHASE", self, "UpdateAuras")
	frame:RegisterUnitEvent("UNIT_CONNECTION", self, "UpdateAuras")
	frame:RegisterUpdateFunc(self, "UpdateAuras")
end

function Indicators:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.auraIndicators:Hide()
	self:DisableIndicatorSlots(frame)
end

function Indicators:OnLayoutApplied(frame)
	if( not frame.auraIndicators ) then return end

	-- Create indicators
	local id = 1
	for key, indicatorConfig in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
		-- Create indicator as needed
		local indicator = frame.auraIndicators["indicator-" .. id]
		if( not indicator ) then
			indicator = CreateFrame("Frame", nil, frame.auraIndicators, BackdropTemplateMixin and "BackdropTemplate" or nil)
			indicator:SetFrameLevel(frame.topFrameLevel + 6)
			indicator.texture = indicator:CreateTexture(nil, "OVERLAY")
			indicator.texture:SetPoint("CENTER", indicator)
			indicator:SetAlpha(indicatorConfig.alpha)
			indicator:SetBackdrop(backdropTbl)
			indicator:SetBackdropColor(0, 0, 0, 1)
			indicator:SetBackdropBorderColor(0, 0, 0, 0)

			indicator.cooldown = CreateFrame("Cooldown", nil, indicator, "CooldownFrameTemplate")
			indicator.cooldown:SetReverse(true)
			indicator.cooldown:SetPoint("CENTER", 0, -1)
			indicator.cooldown:SetHideCountdownNumbers(true)

			indicator.stack = indicator:CreateFontString(nil, "OVERLAY")
			ShadowUF:SetFontAndShadow(indicator.stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 12, "OUTLINE", 0, 0, 0, 1.0, 0.8, -0.8)
			indicator.stack:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 1, 0)
			indicator.stack:SetWidth(18)
			indicator.stack:SetHeight(10)
			indicator.stack:SetJustifyH("RIGHT")

			frame.auraIndicators["indicator-" .. id] = indicator
		end

		-- Quick access
		indicator.filters = ShadowUF.db.profile.auraIndicators.filters[key]
		indicator.config = ShadowUF.db.profile.units[frame.unitType].auraIndicators

		-- Set up the sizing options
		indicator:SetHeight(indicatorConfig.height)
		indicator.texture:SetWidth(indicatorConfig.width - 1)
		indicator:SetWidth(indicatorConfig.width)
		indicator.texture:SetHeight(indicatorConfig.height - 1)

		if( not indicator.border ) then
			indicator.border = indicator:CreateTexture(nil, "OVERLAY", nil, 1)
			indicator.border:SetPoint("CENTER", indicator)
		end
		indicator.border:SetWidth(indicatorConfig.width + 1)
		indicator.border:SetHeight(indicatorConfig.height + 1)
		local borderType = ShadowUF.db.profile.auras.borderType
		if( borderType == "blizzard" ) then
			indicator.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
			indicator.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		elseif( borderType ~= "" ) then
			indicator.border:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. borderType)
			indicator.border:SetTexCoord(0, 1, 0, 1)
		end
		indicator.border:SetVertexColor(0.6, 0.6, 0.6)
		indicator.border:Hide()

		-- Indicators survive layout reloads, so a pandemic color change must be pushed onto existing pandemic overlays
		if( indicator.pandemic ) then
			local pandemicColor = ShadowUF.db.profile.auraColors.pandemic
			indicator.pandemic:SetColorTexture(pandemicColor and pandemicColor.r or 1, pandemicColor and pandemicColor.g or 1, pandemicColor and pandemicColor.b or 1, pandemicColor and pandemicColor.a or 0.35)
		end

		ShadowUF.Layout:AnchorFrame(frame, indicator, indicatorConfig)

		-- Let the auras module quickly access indicators without having to use index
		frame.auraIndicators[key] = indicator

		id = id + 1
	end

	-- Combat slots anchor onto the indicator frames created above
	self:BuildIndicatorSlots(frame)
end

local playerClass = select(2, UnitClass("player"))
local filterMap = {}
local canCure = ShadowUF.Units.canCure
for _, key in pairs(Indicators.auraFilters) do filterMap[key] = "filter-" .. key end

-- Fallback for out-of-combat rendering, compute the pandemic window manually here.
-- We can deduce the start time at any point by subtracting the base duration from the extended duration, yielding the constant carryover cap.
local function getPandemicStart(unit, auraInstanceID, caster, endTime)
	if( not ShadowUF.db.profile.auras.pandemic or not auraInstanceID or not caster or not playerUnits[caster] ) then return nil end

	local ok, start = pcall(function()
		local extended = C_UnitAuras.GetRefreshExtendedDuration(unit, auraInstanceID)
		local base = C_UnitAuras.GetAuraBaseDuration(unit, auraInstanceID)
		if( issecretvalue(extended) or issecretvalue(base) ) then return nil end
		if( not extended or not base ) then return nil end
		local carryover = extended - base
		if( carryover <= 0 or not endTime or endTime <= 0 ) then return nil end
		return endTime - carryover
	end)
	return ok and start or nil
end

local function checkFilterAura(frame, type, isFriendly, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, auraInstanceID)
	local category
	if( isFriendly and canCure[auraType] and type == "debuffs" ) then
		category = "curable"
	elseif( not isFriendly and type == "buffs" and auraInstanceID and frame.auraIndicators.slotsAssist == "attack" ) then
		-- Purgeable/soothable buffs on the hostile side, same token as the combat slot
		-- slotsAssist is stamped at the top of every UpdateAuras; units we can't harm (cross-faction warmode off) never take this branch
		local ok, filteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, frame.unit, auraInstanceID, "HELPFUL|RAID_PLAYER_DISPELLABLE")
		if( ok and not issecretvalue(filteredOut) and not filteredOut ) then
			category = "curable"
		end
	end
	if( not category ) then return end

	local applied = false
	local pandemicStart = getPandemicStart(frame.unit, auraInstanceID, caster, endTime)

	for key, config in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
		local indicator = frame.auraIndicators[key]
		if( indicator and indicator.config.enabled and indicator.filters[category].enabled and not ShadowUF.db.profile.units[frame.unitType].auraIndicators[filterMap[category]] ) then
			indicator.showStack = config.showStack
			indicator.priority = indicator.filters[category].priority
			indicator.showIcon = true
			indicator.showDuration = indicator.filters[category].duration
			indicator.spellDuration = duration
			indicator.spellEnd = endTime
			indicator.spellIcon = texture
			indicator.spellName = name
			indicator.spellStack = count
			indicator.colorR = nil
			indicator.colorG = nil
			indicator.colorB = nil
			indicator.pandemicStart = pandemicStart
			indicator.dispelName = auraType
			indicator.dispelHarmful = type == "debuffs"

			applied = true
		end
	end

	return applied
end

local function checkSpecificAura(frame, type, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, auraInstanceID)
	-- Not relevant
	if( not ShadowUF.db.profile.auraIndicators.auras[name] and not ShadowUF.db.profile.auraIndicators.auras[tostring(spellID)] ) then return end

	local auraConfig = Indicators.auraConfig[name] or Indicators.auraConfig[spellID]

	-- Only player auras
	if( auraConfig.player and not playerUnits[caster] ) then return end

	local indicator = auraConfig and frame.auraIndicators[auraConfig.indicator]

	-- No indicator or not enabled
	if( not indicator or not indicator.enabled ) then return end
	-- Missing aura only
	if( auraConfig.missing ) then return end

	-- Disabled on a class level
	if( ShadowUF.db.profile.auraIndicators.disabled[playerClass][name] or ShadowUF.db.profile.auraIndicators.disabled[playerClass][tostring(spellID)] ) then return end
	-- Disabled aura group by unit
	if( ShadowUF.db.profile.units[frame.unitType].auraIndicators[auraConfig.group] ) then return end


	-- If the indicator is not restricted to the player only, then will give the player a slightly higher priority
	local priority = auraConfig.priority
	local color = auraConfig
	if( not auraConfig.player and playerUnits[caster] ) then
		priority = priority + 0.1
		color = auraConfig.selfColor or auraConfig
	end

	if( priority <= indicator.priority ) then return end

	indicator.showStack = ShadowUF.db.profile.auraIndicators.indicators[auraConfig.indicator].showStack
	indicator.priority = priority
	indicator.showIcon = auraConfig.icon
	indicator.showDuration = auraConfig.duration
	indicator.spellDuration = duration
	indicator.spellEnd = endTime
	indicator.spellIcon = texture
	indicator.spellName = name
	indicator.spellStack = count
	indicator.colorR = color.r
	indicator.colorG = color.g
	indicator.colorB = color.b
	indicator.pandemicStart = getPandemicStart(frame.unit, auraInstanceID, caster, endTime)
	indicator.dispelName = auraType
	indicator.dispelHarmful = type == "debuffs"

	return true
end

local auraList = {}

local function aurasAreSecret()
	local auras = ShadowUF.modules.auras
	return auras and auras.AurasAreSecret and auras.AurasAreSecret() or false
end

-- Both processors run under their caller's pcall, a secret aura errors on the auraData.name test and gets skipped while whitelisted spells pass through
-- a skipped aura also stays out of auraList, the missing-aura pass depends on that
local function processConfiguredAura(frame, auraData)
	if( auraData.name ) then
		-- The type arg is unused by checkSpecificAura, best-effort only
		local aType = auraData.isHarmful and "debuffs" or "buffs"
		checkSpecificAura(frame, aType, auraData.name, auraData.icon, auraData.applications, auraData.dispelName, auraData.duration, auraData.expirationTime, auraData.sourceUnit, auraData.isStealable, auraData.nameplateShowPersonal, auraData.spellId, auraData.canApplyAura, auraData.isBossAura, auraData.auraInstanceID)
		auraList[auraData.name] = true
		if( auraData.spellId ) then auraList[tostring(auraData.spellId)] = true end
	end
end

local function processSlotAura(frame, type, isFriendly, auraData)
	if( auraData.name ) then
		local name = auraData.name
		local texture = auraData.icon
		local count = auraData.applications
		local auraType = auraData.dispelName
		local duration = auraData.duration
		local endTime = auraData.expirationTime
		local caster = auraData.sourceUnit
		local isRemovable = auraData.isStealable
		local nameplateShowPersonal = auraData.nameplateShowPersonal
		local spellID = auraData.spellId
		local canApplyAura = auraData.canApplyAura
		local isBossDebuff = auraData.isBossAura

		local result = checkFilterAura(frame, type, isFriendly, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, auraData.auraInstanceID)
		if( not result ) then
			checkSpecificAura(frame, type, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, auraData.auraInstanceID)
		end

		auraList[name] = true
		if spellID then auraList[tostring(spellID)] = true end
	end
end

-- GetAuraSlots returns (continuationToken, slot1, ...) forwarded straight into the varargs, iteration starts at 2 to skip the token
local function scanAuraSlots(frame, type, isFriendly, unit, ...)
	for i = 2, select("#", ...) do
		local index = select(i, ...)
		-- Slot-based access errors while auras are secret, skip silently
		local okData, auraData = pcall(C_UnitAuras.GetAuraDataBySlot, unit, index)
		if( okData and auraData ) then
			pcall(processSlotAura, frame, type, isFriendly, auraData)
		end
	end
end

local function fetchAuraSlots(frame, type, isFriendly, filter)
	return scanAuraSlots(frame, type, isFriendly, frame.unit, C_UnitAuras.GetAuraSlots(frame.unit, filter))
end

local function scanAuras(frame, filter, type)
	-- Slot iteration errors for every unit while auras are secret, the slot containers own the display there
	if( aurasAreSecret() ) then return end

	-- UnitIsFriend=true during duels, UnitIsEnemy=false for neutrals
	-- Combine both: true only for actual friendlies (not neutrals, not duel targets)
	local isEnemy = UnitIsEnemy(frame.unit, "player")
	local isFriendly = UnitIsFriend(frame.unit, "player") and not isEnemy

	-- pcall for compound unit tokens (same pattern as auras.lua)
	pcall(fetchAuraSlots, frame, type, isFriendly, filter)
end

--No more slot iteration in combat, so each configured indicator aura is fetched directly by spell ID or name instead
--These direct lookups only resolve whitelisted spells, but for those they keep working in combat
--Safe to run after scanAuras (anything the scan already displayed is skipped by checkSpecificAura's priority guard)
local function scanConfiguredAuras(frame)
	if( not Indicators.auraConfig ) then return end

	for key in pairs(Indicators.auraConfig) do
		local spellID = tonumber(key)
		local okData, auraData
		if( spellID ) then
			okData, auraData = pcall(C_UnitAuras.GetUnitAuraBySpellID, frame.unit, spellID)
		else
			okData, auraData = pcall(C_UnitAuras.GetAuraDataBySpellName, frame.unit, key, "HELPFUL")
			if( not okData or not auraData ) then
				okData, auraData = pcall(C_UnitAuras.GetAuraDataBySpellName, frame.unit, key, "HARMFUL")
			end
		end

		if( okData and auraData ) then
			-- Whitelisted spells return real data, pcall covers stray secrets
			pcall(processConfiguredAura, frame, auraData)
		end
	end
end

-- Healer HoTs aren't whitelisted, so the point-query channel loses them in combat
-- Fallback is one AuraSlot per spellID-keyed indicator aura, Blizzard matches the spell and we never read aura data
-- HELPFUL only, the gate ignores spell filters on secret harmful auras (the slot would show any debuff)
-- Slots show whenever auras are secret, even out of combat (M+/encounters/PvP)
-- No dungeon enter/leave event, PLAYER_REGEN_DISABLED covers the pre-lockdown Show and regen + UpdateAuras handle the rest
local slotContainerFrames = {}
local pendingSlotBuilds = {}
local slotCombatWatcher

local function updateSlotVisibility(frame)
	local container = frame.auraIndicators and frame.auraIndicators.slotContainer
	if( not container ) then return end

	if( aurasAreSecret() and frame:IsVisible() ) then
		pcall(container.Show, container)
	else
		pcall(container.Hide, container)
	end
end

local function ensureSlotCombatWatcher()
	if( slotCombatWatcher ) then return end
	slotCombatWatcher = CreateFrame("Frame")
	slotCombatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
	slotCombatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	slotCombatWatcher:SetScript("OnEvent", function(_, event)
		local show = event == "PLAYER_REGEN_DISABLED"
		if( not show ) then
			for frame in pairs(pendingSlotBuilds) do
				pendingSlotBuilds[frame] = nil
				if( frame.auraIndicators ) then
					Indicators:BuildIndicatorSlots(frame)
				end
			end
		end
		for frame in pairs(slotContainerFrames) do
			local container = frame.auraIndicators and frame.auraIndicators.slotContainer
			if( container ) then
				if( show and frame:IsVisible() ) then
					pcall(container.Show, container)
				elseif( not show ) then
					updateSlotVisibility(frame)
				end
			end
		end
	end)
end

local function retireIndicatorSlots(frame)
	local container = frame.auraIndicators and frame.auraIndicators.slotContainer
	if( container ) then
		container:SetEnabled(false)
		if( not InCombatLockdown() ) then container:Hide() end
		frame.auraIndicators.slotContainer = nil
	end
	if( frame.auraIndicators ) then
		frame.auraIndicators.slotIdentity = nil
		frame.auraIndicators.slotRecords = nil
		frame.auraIndicators.slotsAssist = nil
	end
	slotContainerFrames[frame] = nil
end

function Indicators:DisableIndicatorSlots(frame)
	pendingSlotBuilds[frame] = nil
	retireIndicatorSlots(frame)
end


-- Swapped in place of a slot's candidate filters to mute it, an empty include set can never match an aura and dispel type candidates ignore the identity gate.
-- A HARMFUL|HELPFUL filter string matches everything rather than nothing, so muting must go through candidate filters.
local MUTE_CANDIDATES = { includeDispelTypes = {} }

-- Slot button styling; anchoring happens here too since the button is forbidden after creation whenever auras are secret (M+ reload included)
local function makeIndicatorSlotStyler(display, isHarmful)
	return function(button)
		if( display.anchorTo ) then
			button:ClearAllPoints()
			button:SetAllPoints(display.anchorTo)
		end
		if( display.frameLevel ) then
			button:SetFrameLevel(display.frameLevel)
		end

		local texture = button:CreateTexture(nil, "OVERLAY")
		texture:SetAllPoints(button)
		if( display.icon ) then
			texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			pcall(button.SetIcon, button, texture)

			local borderType = ShadowUF.db.profile.auras.borderType
			if( borderType == "blizzard" ) then
				if( not isHarmful ) then
					local base = button:CreateTexture(nil, "OVERLAY")
					base:SetPoint("TOPLEFT", button, -1, 1)
					base:SetPoint("BOTTOMRIGHT", button, 1, -1)
					base:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
					base:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
					base:SetVertexColor(0.6, 0.6, 0.6)
				end
				local dispel = button:CreateTexture(nil, "OVERLAY", nil, 1)
				dispel:SetPoint("TOPLEFT", button, -1, 1)
				dispel:SetPoint("BOTTOMRIGHT", button, 1, -1)
				dispel:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
				dispel:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
				pcall(button.AddDispelTypeTexture, button, dispel, { style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3, showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = isHarmful or nil })
			elseif( borderType ~= "" ) then
				local border = button:CreateTexture(nil, "OVERLAY")
				border:SetPoint("TOPLEFT", button, -1, 1)
				border:SetPoint("BOTTOMRIGHT", button, 1, -1)
				border:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. borderType)
				border:SetVertexColor(0.6, 0.6, 0.6)

				local dispel = button:CreateTexture(nil, "OVERLAY", nil, 1)
				dispel:SetPoint("TOPLEFT", button, -1, 1)
				dispel:SetPoint("BOTTOMRIGHT", button, 1, -1)
				dispel:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. borderType)
				pcall(button.SetAuraBorder, button, dispel, { style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3, showWhenHarmful = true, showWhenHelpful = true, customDispelColorMap = ShadowUF.modules.auras.GetDispelColorMap and ShadowUF.modules.auras:GetDispelColorMap() or nil })
			end
		else
			texture:SetColorTexture(display.r or 1, display.g or 1, display.b or 1)
		end

		if( display.duration ) then
			local cooldown = CreateFrame("Cooldown", nil, button, "SUF_AuraCooldownTemplate")
			cooldown:SetAllPoints(button)
			cooldown:SetReverse(true)
			cooldown:SetHideCountdownNumbers(true)
			pcall(button.SetDurationCooldown, button, cooldown)
		end

		if( display.showStack ) then
			local stack = button:CreateFontString(nil, "OVERLAY")
			ShadowUF:SetFontAndShadow(stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 10, "OUTLINE", 0, 0, 0, 1.0, 0.8, -0.8)
			stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
			stack:SetJustifyH("RIGHT")
			pcall(button.SetApplicationCount, button, stack, {})
		end

		-- Only the player's own auras ever get a pandemic window, so no per-slot gating is needed
		-- Slot icons live in OVERLAY sublevel 0 (dispel border at 1), the pandemic texture goes above both
		if( ShadowUF.db.profile.auras.pandemic and ShadowUF.modules.auras.CreatePandemicOverlay ) then
			local overlay = ShadowUF.modules.auras:CreatePandemicOverlay(button, "OVERLAY", 2)
			pcall(button.AddPandemicRegion, button, overlay)
		end

		button:SetMouseMotionEnabled(false)
	end
end

function Indicators:BuildIndicatorSlots(frame)
	-- Container creation and slot styling are blocked under lockdown, the watcher replays queued builds at regen
	if( InCombatLockdown() ) then
		pendingSlotBuilds[frame] = true
		ensureSlotCombatWatcher()
		return
	end
	pendingSlotBuilds[frame] = nil

	local auras = ShadowUF.modules.auras
	if( not (auras and auras.hasContainers) ) then return end

	local unitConfig = ShadowUF.db.profile.units[frame.unitType].auraIndicators
	local tracked, categorySlots, signatureParts

	if( unitConfig and unitConfig.enabled ) then
		-- Collect spell ID-keyed indicator auras eligible for combat slots
		for key in pairs(ShadowUF.db.profile.auraIndicators.auras) do
			local spellID = tonumber(key)
			local auraConfig = spellID and Indicators.auraConfig[key]
			if( auraConfig and not auraConfig.missing
				and not ShadowUF.db.profile.auraIndicators.disabled[playerClass][key]
				and not unitConfig[auraConfig.group] ) then
				local indicatorConfig = ShadowUF.db.profile.auraIndicators.indicators[auraConfig.indicator]
				if( indicatorConfig and (indicatorConfig.friendly or indicatorConfig.hostile) and frame.auraIndicators[auraConfig.indicator] ) then
					tracked = tracked or {}
					signatureParts = signatureParts or {}
					tracked[spellID] = auraConfig
					table.insert(signatureParts, spellID .. "@" .. auraConfig.indicator .. "@" .. tostring(auraConfig.player) .. "@" .. tostring(auraConfig.icon) .. "@" .. tostring(auraConfig.duration) .. "@" .. tostring(indicatorConfig.showStack) .. "@" .. tostring(auraConfig.priority) .. "@" .. tostring(indicatorConfig.friendly) .. "@" .. tostring(indicatorConfig.hostile))
				end
			end
		end

		-- Category filters (boss/curable) can move to slots, the legacy scan feeding them is empty in combat and dispel-type/boolean candidate filters aren't identity-gated
		for key, indicatorConfig in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
			local filters = ShadowUF.db.profile.auraIndicators.filters[key]
			if( filters and (indicatorConfig.friendly or indicatorConfig.hostile) and frame.auraIndicators[key] ) then
				for _, category in ipairs(Indicators.auraFilters) do
					local filterCfg = filters[category]
					local unitDisabled = unitConfig["filter-" .. category]
					if( filterCfg and filterCfg.enabled and not unitDisabled ) then
						categorySlots = categorySlots or {}
						signatureParts = signatureParts or {}
						table.insert(categorySlots, { key = key, category = category, duration = filterCfg.duration, showStack = indicatorConfig.showStack, priority = filterCfg.priority, friendly = indicatorConfig.friendly, hostile = indicatorConfig.hostile })
						table.insert(signatureParts, "cat@" .. key .. "@" .. category .. "@" .. tostring(filterCfg.duration) .. "@" .. tostring(indicatorConfig.showStack) .. "@" .. tostring(filterCfg.priority) .. "@" .. tostring(indicatorConfig.friendly) .. "@" .. tostring(indicatorConfig.hostile))
					end
				end
			end
		end
	end

	-- Frames can't be deleted, only rebuild when the tracked set changed
	local signature
	if( signatureParts ) then
		table.sort(signatureParts)
		-- Border styling is frozen at slot creation
		local auras = ShadowUF.modules.auras
		local colorsKey = auras.GetDispelColorsKey and auras:GetDispelColorsKey() or ""
		signature = ShadowUF.db.profile.auras.borderType .. "#" .. tostring(ShadowUF.db.profile.auras.pandemic) .. "#" .. colorsKey .. "##" .. table.concat(signatureParts, ";")
	end
	if( frame.auraIndicators.slotContainer and frame.auraIndicators.slotSignature == signature ) then
		pcall(frame.auraIndicators.slotContainer.SetUnit, frame.auraIndicators.slotContainer, frame.unit)
		return
	end

	retireIndicatorSlots(frame)
	frame.auraIndicators.slotSignature = signature
	if( not tracked and not categorySlots ) then return end

	local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame.auraIndicators, "CustomAuraContainerTemplate")
	if( not ok or not container ) then return end
	container:SetPoint("TOPLEFT", frame.auraIndicators)
	container:SetSize(1, 1)
	container:Hide()

	-- Overlapping slots of the same indicator stack and the configured priority drives the draw order
	-- Each slot gets a 2-level band (button + its child cooldown) so a lower slot's swipe can never bleed through the icon drawn above it, even when priorities are equal (deterministic key tiebreak)
	local descriptors = {}
	if( tracked ) then
		for spellID, auraConfig in pairs(tracked) do
			local indicatorConfig = ShadowUF.db.profile.auraIndicators.indicators[auraConfig.indicator]
			local candidateFilters = { includeSpellIDs = { [spellID] = true } }
			if( auraConfig.player ) then
				candidateFilters.isFromPlayerOrPlayerPet = true
			end

			-- Blizzard skips spell ID candidate filters for helpful auras on units we can't assist and for harmful ones on units we can (fail-open, every aura passes and lights the slot).
			-- Each reaction side gets its own slot, only active where the filter is enforced, which also makes DoT tracking on enemies work (enforced there even for secret spells)
			if( indicatorConfig.friendly ) then
				table.insert(descriptors, {
					indicator = auraConfig.indicator,
					priority = auraConfig.priority or 0,
					key = "spellh" .. spellID,
					filter = "HELPFUL",
					activeWhen = "assist",
					display = { icon = auraConfig.icon, r = auraConfig.r, g = auraConfig.g, b = auraConfig.b, duration = auraConfig.duration, showStack = indicatorConfig.showStack },
					options = { candidateFilters = candidateFilters },
				})
			end
			if( indicatorConfig.hostile ) then
				table.insert(descriptors, {
					indicator = auraConfig.indicator,
					priority = auraConfig.priority or 0,
					key = "spelld" .. spellID,
					filter = "HARMFUL",
					activeWhen = "noassist",
					display = { icon = auraConfig.icon, r = auraConfig.r, g = auraConfig.g, b = auraConfig.b, duration = auraConfig.duration, showStack = indicatorConfig.showStack },
					options = { candidateFilters = candidateFilters },
				})
			end
		end
	end

	if( categorySlots ) then
		for _, slot in ipairs(categorySlots) do
			if( slot.category == "curable" ) then
				if( slot.friendly ) then
					table.insert(descriptors, { indicator = slot.key, priority = slot.priority or 0, key = "curable-" .. slot.key, filter = "HARMFUL|RAID", activeWhen = "assist", display = { icon = true, duration = slot.duration, showStack = slot.showStack }, options = {} })
				end
				if( slot.hostile ) then
					-- Purgeable/soothable buffs on the hostile side, the group-scoped token is the only one for helpful auras
					table.insert(descriptors, { indicator = slot.key, priority = slot.priority or 0, key = "curableh-" .. slot.key, filter = "HELPFUL|RAID_PLAYER_DISPELLABLE", activeWhen = "noassist", display = { icon = true, duration = slot.duration, showStack = slot.showStack }, options = {} })
				end
			end
		end
	end

	table.sort(descriptors, function(a, b)
		if( a.indicator ~= b.indicator ) then return a.indicator < b.indicator end
		if( a.priority ~= b.priority ) then return a.priority < b.priority end
		return a.key < b.key
	end)

	local indicatorRank = {}
	local slotRecords = {}
	for _, descriptor in ipairs(descriptors) do
		indicatorRank[descriptor.indicator] = (indicatorRank[descriptor.indicator] or 0) + 1
		descriptor.display.anchorTo = frame.auraIndicators[descriptor.indicator]
		descriptor.display.frameLevel = frame.topFrameLevel + 7 + indicatorRank[descriptor.indicator] * 2
		descriptor.options.initializeFrame = makeIndicatorSlotStyler(descriptor.display, string.find(descriptor.filter, "HARMFUL", 1, true) ~= nil)
		if( pcall(container.AddAuraSlot, container, descriptor.key, descriptor.filter, descriptor.options) ) then
			slotRecords[descriptor.key] = { candidates = descriptor.options.candidateFilters, activeWhen = descriptor.activeWhen }
		end
	end

	pcall(container.SetUnit, container, frame.unit)
	frame.auraIndicators.slotContainer = container
	frame.auraIndicators.slotRecords = slotRecords
	frame.auraIndicators.slotIdentity = nil
	frame.auraIndicators.slotsAssist = nil
	frame.auraIndicators.slotsReachable = nil
	slotContainerFrames[frame] = true
	ensureSlotCombatWatcher()
end

-- Each pass bumps the token, so a pending arm timer from the previous aura state can never show a stale overlay
local function updatePandemicOverlay(indicator)
	indicator.pandemicToken = (indicator.pandemicToken or 0) + 1

	local start = indicator.pandemicStart
	if( not start ) then
		if( indicator.pandemic ) then indicator.pandemic:Hide() end
		return
	end

	if( not indicator.pandemic ) then
		-- Icon and border live in OVERLAY 0/1, the pandemic texture goes above both
		indicator.pandemic = ShadowUF.modules.auras:CreatePandemicOverlay(indicator, "OVERLAY", 2)
	end

	local delay = start - GetTime()
	if( delay <= 0 ) then
		indicator.pandemic:Show()
	else
		indicator.pandemic:Hide()
		local token = indicator.pandemicToken
		C_Timer.After(delay + 0.05, function()
			if( indicator.pandemicToken == token and indicator.pandemicStart and indicator:IsShown() ) then
				indicator.pandemic:Show()
			end
		end)
	end
end

function Indicators:UpdateIndicators(frame)
	for key, indicatorConfig in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
		local indicator = frame.auraIndicators[key]
		if( indicator and indicator.enabled and indicator.priority and indicator.priority > -1 ) then
			-- Show a cooldown ring
			if( indicator.showDuration and indicator.spellDuration > 0 and indicator.spellEnd > 0 ) then
				indicator.cooldown:SetCooldown(indicator.spellEnd - indicator.spellDuration, indicator.spellDuration)
			else
				indicator.cooldown:Hide()
			end

			-- Show either the icon, or a solid color
			if( indicator.showIcon and indicator.spellIcon ) then
				indicator.texture:SetTexture(indicator.spellIcon)
				indicator.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				indicator:SetBackdropColor(0, 0, 0, 0)
				if( indicator.border and ShadowUF.db.profile.auras.borderType ~= "" ) then
					local dispelName = not issecretvalue(indicator.dispelName) and indicator.dispelName or nil
					if( ShadowUF.db.profile.auras.borderType == "blizzard" ) then
						-- Blizzard's None fallback is a red that only reads right on debuffs, buffs and unmapped types (Enrage) get the neutral grey instead
						local info = dispelName and AuraUtil and AuraUtil.GetDebuffDisplayInfoTable and AuraUtil.GetDebuffDisplayInfoTable()[dispelName]
						if( AuraUtil and AuraUtil.SetAuraBorderColor and (info or indicator.dispelHarmful) ) then
							AuraUtil.SetAuraBorderColor(indicator.border, dispelName)
						else
							indicator.border:SetVertexColor(0.6, 0.6, 0.6)
						end
					else
						local colorMap = not ShadowUF.db.profile.auraColors.disableDispel and ShadowUF.modules.auras:GetDispelColorMap()
						local color = colorMap and dispelName and colorMap[dispelName]
						if( color ) then
							indicator.border:SetVertexColor(color.r, color.g, color.b)
						else
							indicator.border:SetVertexColor(0.6, 0.6, 0.6)
						end
					end
					indicator.border:Show()
				end
			else
				indicator.texture:SetColorTexture(indicator.colorR, indicator.colorG, indicator.colorB)
				indicator.texture:SetTexCoord(0, 1, 0, 1)
				indicator:SetBackdropColor(0, 0, 0, 1)
				if( indicator.border ) then
					indicator.border:Hide()
				end
			end

			-- Show aura stack
			if( indicator.showStack and indicator.spellStack > 1 ) then
				indicator.stack:SetText(indicator.spellStack)
				indicator.stack:Show()
			else
				indicator.stack:Hide()
			end

			indicator:Show()
			updatePandemicOverlay(indicator)
		else
			indicator:Hide()
			updatePandemicOverlay(indicator)
		end
	end
end

function Indicators:UpdateAuras(frame)
	-- Keep the slots on the current unit token and their visibility in sync with the restriction state
	local slotContainer = frame.auraIndicators and frame.auraIndicators.slotContainer
	if( slotContainer ) then
		pcall(slotContainer.SetUnit, slotContainer, frame.unit)

		-- Out of the area of interest the candidate filters fail open and every aura lights every slot, silence the container there
		if( frame.unit and not frame.configMode ) then
			local reachable = ShadowUF.IsUnitReachable(frame.unit)
			if( frame.auraIndicators.slotsReachable ~= reachable ) then
				frame.auraIndicators.slotsReachable = reachable
				pcall(slotContainer.SetEnabled, slotContainer, reachable)
			end
		end

		-- Each slot only stays active on the side where its spell ID filter is enforced; units that can neither be helped nor harmed (cross-faction warmode off) mute both sides
		if( frame.unit and not frame.configMode and frame.auraIndicators.slotRecords ) then
			local state = ShadowUF.GetUnitReactionState(frame.unit)
			if( frame.auraIndicators.slotsAssist ~= state ) then
				frame.auraIndicators.slotsAssist = state
				for key, record in pairs(frame.auraIndicators.slotRecords) do
					local active = not record.activeWhen
						or (record.activeWhen == "assist" and state == "assist")
						or (record.activeWhen == "noassist" and state == "attack")
					-- Category slots have no candidates, nil is a real value here (clears, the filter string alone matches) and must not fall through to the mute
					if( active ) then
						pcall(slotContainer.SetAuraSlotCandidateFilters, slotContainer, key, record.candidates)
					else
						pcall(slotContainer.SetAuraSlotCandidateFilters, slotContainer, key, MUTE_CANDIDATES)
					end
				end
			end
		end

		-- SetUnit early-outs on an unchanged token, a same-token retarget would keep showing the old unit's auras forever.
		-- Kick a refresh when the resolved identity changes, or on every event-driven update while it's secret (same pattern as Auras:UpdateContainers)
		local identity
		if( frame.unit and not ShadowUF.IsUnitIdentitySecret(frame.unit) ) then
			local ok, guid = pcall(UnitGUID, frame.unit)
			if( ok ) then identity = guid end
		end
		local kick
		if( identity ~= nil ) then
			kick = frame.auraIndicators.slotIdentity ~= identity
		else
			kick = not frame.pollingUpdate
		end
		frame.auraIndicators.slotIdentity = identity
		if( kick ) then
			pcall(slotContainer.UpdateAllAuras, slotContainer)
		end

		if( not InCombatLockdown() ) then
			updateSlotVisibility(frame)
		end
	end

	for k in pairs(auraList) do auraList[k] = nil end
	for key, config in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
		local indicator = frame.auraIndicators[key]
		if( indicator ) then
			indicator.priority = -1
			indicator.pandemicStart = nil
			indicator.dispelName = nil
			indicator.dispelHarmful = nil

			if( UnitIsEnemy(frame.unit, "player") ) then
				indicator.enabled = config.hostile
			else
				indicator.enabled = config.friendly
			end
		end
	end

	-- If they are dead, don't bother showing any indicators yet
	if( UnitIsDeadOrGhost(frame.unit) or not UnitIsConnected(frame.unit) ) then
		self:UpdateIndicators(frame)
		return
	end

	-- Scan auras (category indicators, empty in combat)
	scanAuras(frame, "HELPFUL", "buffs")
	scanAuras(frame, "HARMFUL", "debuffs")

	-- Point-query configured auras (works in combat for non-secret spells)
	scanConfiguredAuras(frame)

	-- Check for any indicators that are triggered due to something missing
	-- No point flagging a missing buff on a unit we can't even buff (RP NPCs, hostiles)
	if( ShadowUF.GetUnitReactionState(frame.unit) ~= "assist" ) then
		self:UpdateIndicators(frame)
		return
	end
	for name in pairs(ShadowUF.db.profile.auraIndicators.missing) do
		if( not auraList[name] and self.auraConfig[name] ) then
			local aura = self.auraConfig[name]
			local indicator = frame.auraIndicators[aura.indicator]
			if( indicator and indicator.enabled and aura.priority > indicator.priority and not ShadowUF.db.profile.auraIndicators.disabled[playerClass][name] ) then
				indicator.priority = aura.priority or -1
				indicator.showIcon = aura.icon
				indicator.showDuration = aura.duration
				indicator.spellDuration = 0
				indicator.spellEnd = 0
				indicator.spellIcon = aura.iconTexture or GetSpellTexture(name)
				indicator.colorR = aura.r
				indicator.colorG = aura.g
				indicator.colorB = aura.b
			end
		end
	end

	-- Now force the indicators to update
	self:UpdateIndicators(frame)
end
