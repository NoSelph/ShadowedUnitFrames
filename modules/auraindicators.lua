local Indicators = {}
ShadowUF:RegisterModule(Indicators, "auraIndicators", ShadowUF.L["Aura indicators"])

Indicators.auraFilters = {"boss", "curable"}

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
	[410089] = { name = "Prescience", group = "Evoker" },
	[410263] = { name = "Inferno's Blessing", group = "Evoker" },
	[410686] = { name = "Symbiotic Bloom", group = "Evoker" },
	[413984] = { name = "Shifting Sands", group = "Evoker" },
	-- Druid
	[774]    = { name = "Rejuvenation", group = "Druid" },
	[1126]   = { name = "Mark of the Wild", group = "Druid" },
	[8936]   = { name = "Regrowth", group = "Druid" },
	[33763]  = { name = "Lifebloom", group = "Druid" },
	[48438]  = { name = "Wild Growth", group = "Druid" },
	[155777] = { name = "Germination", group = "Druid" },
	[474754] = { name = "Symbiotic Relationship", group = "Druid" },
	-- Priest
	[17]     = { name = "Power Word: Shield", group = "Priest" },
	[139]    = { name = "Renew", group = "Priest" },
	[21562]  = { name = "Power Word: Fortitude", group = "Priest" },
	[41635]  = { name = "Prayer of Mending", group = "Priest" },
	[77489]  = { name = "Echo of Light", group = "Priest" },
	[194384] = { name = "Atonement", group = "Priest" },
	[1253593]= { name = "Void Shield", group = "Priest" },
	-- Monk
	[115175] = { name = "Soothing Mist", group = "Monk" },
	[119611] = { name = "Renewing Mist", group = "Monk" },
	[124682] = { name = "Enveloping Mist", group = "Monk" },
	[450769] = { name = "Aspect of Harmony", group = "Monk" },
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
	[462854] = { name = "Skyfury", group = "Shaman" },
	-- Paladin
	[53563]  = { name = "Beacon of Light", group = "Paladin" },
	[156322] = { name = "Eternal Flame", group = "Paladin" },
	[156910] = { name = "Beacon of Faith", group = "Paladin" },
	[433568] = { name = "Rite of Sanctification", group = "Paladin" },
	[433583] = { name = "Rite of Adjuration", group = "Paladin" },
	[1244893]= { name = "Beacon of the Savior", group = "Paladin" },
	-- Mage
	[1459]   = { name = "Arcane Intellect", group = "Mage" },
	[205473] = { name = "Icicles", group = "Mage" },
	-- Warrior
	[6673]   = { name = "Battle Shout", group = "Warrior" },
	-- Hunter
	[260286] = { name = "Tip of the Spear", group = "Hunter" },
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

function Indicators:OnEnable(frame)
	-- Not going to create the indicators we want here, will do that when we do the layout stuff
	frame.auraIndicators = frame.auraIndicators or CreateFrame("Frame", nil, frame)
	frame.auraIndicators:SetFrameLevel(4)
	frame.auraIndicators:Show()

	-- Of course, watch for auras
	frame:RegisterUnitEvent("UNIT_AURA", self, "UpdateAuras")
	frame:RegisterUpdateFunc(self, "UpdateAuras")
end

function Indicators:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.auraIndicators:Hide()
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
			indicator:SetFrameLevel(frame.topFrameLevel + 2)
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
			indicator.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 12, "OUTLINE")
			indicator.stack:SetShadowColor(0, 0, 0, 1.0)
			indicator.stack:SetShadowOffset(0.8, -0.8)
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

		ShadowUF.Layout:AnchorFrame(frame, indicator, indicatorConfig)

		-- Let the auras module quickly access indicators without having to use index
		frame.auraIndicators[key] = indicator

		id = id + 1
	end
end

local playerClass = select(2, UnitClass("player"))
local filterMap = {}
local canCure = ShadowUF.Units.canCure
for _, key in pairs(Indicators.auraFilters) do filterMap[key] = "filter-" .. key end

local function checkFilterAura(frame, type, isFriendly, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff)
	local category
	if( isFriendly and canCure[auraType] and type == "debuffs" ) then
		category = "curable"
	elseif( isBossDebuff ) then
		category = "boss"
	else
		return
	end

	local applied = false

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

			applied = true
		end
	end

	return applied
end

local function checkSpecificAura(frame, type, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff)
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

	return true
end

local auraList = {}
local function scanAuras(frame, filter, type)
	local isFriendly = not UnitIsEnemy(frame.unit, "player")

	-- 12.0: pcall for compound unit tokens (same pattern as auras.lua)
	local ok, slots = pcall(function() return {C_UnitAuras.GetAuraSlots(frame.unit, filter)} end)
	if( not ok ) then return end

	for i = 2, #slots do
		local index = slots[i]
		local auraData = C_UnitAuras.GetAuraDataBySlot(frame.unit, index)
		if( auraData ) then
			-- 12.0: pcall to silently skip secret auras in combat.
			-- Whitelisted spells (non-secret) pass through; secret auras error
			-- on boolean tests (e.g. "if auraData.name then") and are caught here.
			pcall(function()
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

					local result = checkFilterAura(frame, type, isFriendly, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff)
					if( not result ) then
						checkSpecificAura(frame, type, name, texture, count, auraType, duration, endTime, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff)
					end

					auraList[name] = true
				end
			end)
		end
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
				indicator:SetBackdropColor(0, 0, 0, 0)
			else
				indicator.texture:SetColorTexture(indicator.colorR, indicator.colorG, indicator.colorB)
				indicator:SetBackdropColor(0, 0, 0, 1)
			end

			-- Show aura stack
			if( indicator.showStack and indicator.spellStack > 1 ) then
				indicator.stack:SetText(indicator.spellStack)
				indicator.stack:Show()
			else
				indicator.stack:Hide()
			end

			indicator:Show()
		else
			indicator:Hide()
		end
	end
end

function Indicators:UpdateAuras(frame)
	for k in pairs(auraList) do auraList[k] = nil end
	for key, config in pairs(ShadowUF.db.profile.auraIndicators.indicators) do
		local indicator = frame.auraIndicators[key]
		if( indicator ) then
			indicator.priority = -1

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

	-- Scan auras
	scanAuras(frame, "HELPFUL", "buffs")
	scanAuras(frame, "HARMFUL", "debuffs")

	-- Check for any indicators that are triggered due to something missing
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
