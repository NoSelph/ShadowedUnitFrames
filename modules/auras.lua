local Auras = {}
local SML = LibStub("LibSharedMedia-3.0")
local canCure = ShadowUF.Units.canCure
ShadowUF:RegisterModule(Auras, "auras", ShadowUF.L["Auras"])

-- Styling placeholders once per config generation is enough
Auras.configStyleGeneration = 1

local AURA_TYPES = {"buffs", "debuffs"}

-- AuraButtons are forbidden under any aura restriction (combat, M+, PvP), combat lockdown alone is too narrow a proxy
local function aurasAreSecret()
	if( C_Secrets and C_Secrets.ShouldAurasBeSecret ) then
		return C_Secrets.ShouldAurasBeSecret()
	end
	return InCombatLockdown() and true or false
end
Auras.AurasAreSecret = aurasAreSecret

-- User dispel palette, handed to Blizzard via customDispelColorMap on our PreserveAsset borders (atlas styles keep the Blizzard look)
local dispelColorMap
local DISPEL_COLOR_TYPES = {"Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage"}

function Auras:GetDispelColorMap()
	if( dispelColorMap ~= nil ) then return dispelColorMap or nil end

	local colors = ShadowUF.db.profile.auraColors and ShadowUF.db.profile.auraColors.dispel
	if( not colors ) then
		dispelColorMap = false
		return nil
	end

	local map = {}
	for dispelType, color in pairs(colors) do
		map[dispelType] = CreateColor(color.r or 1, color.g or 1, color.b or 1)
	end
	dispelColorMap = map
	return map
end

function Auras:InvalidateDispelColorMap()
	dispelColorMap = nil
end

-- Border colors are frozen at button creation, the palette is part of the rebuild signatures
function Auras:GetDispelColorsKey()
	local colors = ShadowUF.db.profile.auraColors and ShadowUF.db.profile.auraColors.dispel
	if( not colors ) then return "" end

	local parts = {}
	for _, dispelType in ipairs(DISPEL_COLOR_TYPES) do
		local color = colors[dispelType]
		if( color ) then
			table.insert(parts, string.format("%.2f%.2f%.2f", color.r or 0, color.g or 0, color.b or 0))
		end
	end
	return table.concat(parts)
end

-- Managed AuraContainers (AuraGroups) drive the live display, legacy buttons only remain for config mode placeholders
local hasContainers = false
do
	if( C_AddOns and C_AddOns.LoadAddOn ) then
		pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
	end
	local ok, result = pcall(function()
		local probe = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
		local hasGroups = type(probe.AddAuraGroup) == "function"
		probe:SetEnabled(false)
		probe:Hide()
		return hasGroups
	end)
	hasContainers = ok and result == true
end
Auras.hasContainers = hasContainers

function Auras:OnEnable(frame)
	frame.auras = frame.auras or {}

	-- Containers self-register UNIT_AURA and manage temp enchants natively
	frame:RegisterNormalEvent("PLAYER_ENTERING_WORLD", self, "Update")
	frame:RegisterNormalEvent("ZONE_CHANGED_NEW_AREA", self, "UpdateFilter")
	frame:RegisterUpdateFunc(self, "Update")

	self:UpdateFilter(frame)
end

function Auras:GetDispelColorCurve(auraType)
	local isBuff = (auraType == "buffs")
	local cacheKey = isBuff and "_buffCurve" or "_debuffCurve"
	
	if( self[cacheKey] ) then return self[cacheKey] end
	if( not C_CurveUtil or not C_CurveUtil.CreateColorCurve ) then return nil end

	local curve = C_CurveUtil.CreateColorCurve()
	-- Use Enum values if available to ensure correct mapping
	local E = Enum and Enum.AuraDispelType
	local noneID = (E and E.None) or 0
	local magicID = (E and E.Magic) or 1
	local curseID = (E and E.Curse) or 2
	local diseaseID = (E and E.Disease) or 3
	local poisonID = (E and E.Poison) or 4
	local bleedID = (E and E.Bleed) or 11

	if( curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step ) then
		curve:SetType(Enum.LuaCurveType.Step)
	end

	-- Hardcode standard colors
	local baseR, baseG, baseB
	if( isBuff ) then
		baseR, baseG, baseB = 0.6, 0.6, 0.6
	else
		baseR, baseG, baseB = 0.8, 0, 0 -- Red
	end
	
	-- Add points using the resolved IDs
	curve:AddPoint(noneID, CreateColor(baseR, baseG, baseB))
	curve:AddPoint(magicID, CreateColor(0.2, 0.6, 1))   -- Magic (Blue)
	curve:AddPoint(curseID, CreateColor(0.6, 0, 1))     -- Curse (Purple)
	curve:AddPoint(diseaseID, CreateColor(0.6, 0.4, 0)) -- Disease (Brown)
	curve:AddPoint(poisonID, CreateColor(0, 0.6, 0))    -- Poison (Green)
	curve:AddPoint(bleedID, CreateColor(baseR, baseG, baseB)) -- Bleed (Red)
	
	self[cacheKey] = curve
	return curve
end

function Auras:OnDisable(frame)
	frame:UnregisterAll(self)
	-- Containers self-register their events and would keep displaying
	self:DisableContainers(frame)
	self:ClearBossDebuffs(frame)
end

function Auras:DisableContainers(frame)
	if( not frame.auras ) then return end
	for _, auraType in ipairs(AURA_TYPES) do
		for i = 1, 6 do
			local group = frame.auras[auraType .. i]
			if( group and group.container ) then
				group.container:SetEnabled(false)
				group.container:Hide()
			end
		end
	end
end

-- Aura positioning code
-- Key is "growH:growV" (e.g. "RIGHT:BOTTOM", "CENTER:TOP")
-- growH = LEFT/RIGHT/CENTER (icon fill direction within a row)
-- growV = TOP/BOTTOM (row stacking direction)

local function getPositionKey(config, forcedGrowH, forcedGrowV)
	local h = forcedGrowH or config.growH or "RIGHT"
	local v = forcedGrowV or config.growV or "BOTTOM"
	return h .. ":" .. v
end

-- Helper to get anchor, growth, and inset for positioning
local function getAnchorInfo(config, group)
	local anchorPoint = group.forcedAnchorPoint or config.anchorPoint
	local growH = group.forcedGrowH or config.growH or "RIGHT"
	local growV = group.forcedGrowV or config.growV or "BOTTOM"
	local inset = (anchorPoint == "FREE") and 0 or ShadowUF.db.profile.backdrop.inset
	return anchorPoint, growH, growV, inset
end

local positionData = setmetatable({}, {
	__index = function(tbl, index)
		local data = {}
		local growH, growV = strsplit(":", index)

		data.isCenterGrowth = (growH == "CENTER")
		local effectiveH = data.isCenterGrowth and "RIGHT" or growH

		data.xMod = (effectiveH == "RIGHT") and 1 or -1
		data.yMod = (growV == "TOP") and 1 or -1

		local auraX = 2
		local colY = 2

		data.initialAnchor = function(button, offset)
			button:ClearAllPoints()
			button:SetPoint(button.point, button.anchorTo, button.relativePoint, button.xOffset, button.yOffset + (data.yMod * offset))
			button.anchorOffset = offset
		end

		local colPoint = ShadowUF.Layout:ReverseDirection(growV)
		data.column = function(button, positionTo, offset)
			button:ClearAllPoints()
			button:SetPoint(colPoint, positionTo, growV, 0, data.yMod * (colY + offset))
		end

		if not data.isCenterGrowth then
			local auraPoint = ShadowUF.Layout:ReverseDirection(effectiveH)
			data.aura = function(button, positionTo)
				button:ClearAllPoints()
				button:SetPoint(auraPoint, positionTo, effectiveH, data.xMod * auraX, 0)
			end
		else
			data.auraRight = function(button, positionTo)
				button:ClearAllPoints()
				button:SetPoint("LEFT", positionTo, "RIGHT", auraX, 0)
			end
			data.auraLeft = function(button, positionTo)
				button:ClearAllPoints()
				button:SetPoint("RIGHT", positionTo, "LEFT", -auraX, 0)
			end
		end

		tbl[index] = data
		return tbl[index]
	end,
})

-- Helper to set first-button properties
local function setupFirstButton(button, config, group, position)
	local anchorPoint, growH, growV, inset = getAnchorInfo(config, group)
	local point, relativePoint = ShadowUF.Layout:GetAuraPoint(anchorPoint, growH, growV)
	button.isAuraAnchor = true
	button.point = point
	button.relativePoint = relativePoint
	button.xOffset = config.x + (position.xMod * inset)
	button.yOffset = config.y + (position.yMod * inset)
	button.anchorTo = group.anchorTo
end

-- Initial button positioning during creation (positionAllButtons* overrides later)
local function positionButton(id, group, config)
	local position = positionData[getPositionKey(config, group.forcedGrowH, group.forcedGrowV)]
	local button = group.buttons[id]
	button.isAuraAnchor = nil

	if( id > 1 ) then
		if( id % config.perRow == 1 or config.perRow == 1 ) then
			position.column(button, group.buttons[id - config.perRow], 0)
			button.isAuraAnchor = true
		elseif( position.isCenterGrowth ) then
			local posInRow = ((id - 1) % config.perRow)
			if posInRow % 2 == 1 then
				position.auraRight(button, group.buttons[id - 1])
			else
				position.auraLeft(button, group.buttons[id - 1])
			end
		else
			position.aura(button, group.buttons[id - 1])
		end
	else
		setupFirstButton(button, config, group, position)
		position.initialAnchor(button, 0)
	end
end


-- Dynamic layout: pixel-based flow wrapping when enlarged auras are present
local function positionAllButtonsDynamic(group, config)
	local position = positionData[getPositionKey(config, group.forcedGrowH, group.forcedGrowV)]
	local normalSize = config.size
	local maxRowWidth = config.perRow * normalSize

	local currentRowWidth = 0
	local rowFirst = nil
	local prevButton = nil
	-- Center growth tracking
	local rightEnd, leftEnd, rowCenter, rowPos

	for id = 1, group.totalAuras do
		local button = group.buttons[id]
		if( not button or not button:IsShown() ) then break end

		local effectiveWidth = normalSize * button:GetScale()
		local needsNewRow = (id > 1) and (currentRowWidth + effectiveWidth > maxRowWidth)

		button.isAuraAnchor = nil

		if( id == 1 ) then
			setupFirstButton(button, config, group, position)
			position.initialAnchor(button, 0)
			rowFirst = button
			currentRowWidth = effectiveWidth
			if position.isCenterGrowth then
				rowCenter = button
				rightEnd = button
				leftEnd = button
				rowPos = 0
			end
		elseif( needsNewRow ) then
			local anchorTo = position.isCenterGrowth and rowCenter or rowFirst
			position.column(button, anchorTo, 0)
			button.isAuraAnchor = true
			rowFirst = button
			currentRowWidth = effectiveWidth
			if position.isCenterGrowth then
				rowCenter = button
				rightEnd = button
				leftEnd = button
				rowPos = 0
			end
		elseif( position.isCenterGrowth ) then
			rowPos = rowPos + 1
			if rowPos % 2 == 1 then
				position.auraRight(button, rightEnd)
				rightEnd = button
			else
				position.auraLeft(button, leftEnd)
				leftEnd = button
			end
			currentRowWidth = currentRowWidth + effectiveWidth
		else
			position.aura(button, prevButton)
			currentRowWidth = currentRowWidth + effectiveWidth
		end

		prevButton = button
	end
end

-- Config-mode placeholders only, the live layout is the container's flow layout
local function positionAllButtons(group, config)
	positionAllButtonsDynamic(group, config)
end

-- Aura button functions
-- instanceID tooltip setters error while auras are secret, pcall keeps hover safe
-- Only config-mode placeholders use this, the containers handle live tooltips and right-click cancel natively
local function updateButton(id, group, config)
	local button = group.buttons[id]
	if( not button ) then
		group.buttons[id] = CreateFrame("Button", nil, group)

		button = group.buttons[id]

		button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button.cooldown:SetDrawEdge(false)
		button.cooldown:SetDrawSwipe(true)
		button.cooldown:SetSwipeColor(0, 0, 0, ShadowUF.db.profile.auras.cooldownSwipeAlpha or 0.8)
		button.cooldown:Hide()

		button.stack = button:CreateFontString(nil, "OVERLAY")
		button.stack:SetHeight(1)
		button.stack:SetWidth(1)
		button.stack:SetAllPoints(button)
		button.stack:SetJustifyV("BOTTOM")
		button.stack:SetJustifyH("RIGHT")

		button.border = button:CreateTexture(nil, "OVERLAY")
		button.border:SetPoint("CENTER", button)

		button.icon = button:CreateTexture(nil, "BACKGROUND")
		button.icon:SetAllPoints(button)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end

	if( ShadowUF.db.profile.auras.borderType == "" ) then
		button.border:Hide()
	elseif( ShadowUF.db.profile.auras.borderType == "blizzard" ) then
		button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		button.border:Show()
	else
		button.border:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. ShadowUF.db.profile.auras.borderType)
		button.border:SetTexCoord(0, 1, 0, 1)
		button.border:Show()
	end

	-- Set the button sizing
	-- Per-frame override for Blizzard Cooldown Count, fallback to global
	local hideCC = config.disableBlizzardCC
	if hideCC == nil then hideCC = ShadowUF.db.profile.blizzardcc end
	button.cooldown:SetHideCountdownNumbers(hideCC)
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)
	ShadowUF:SetFontAndShadow(button.stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", math.floor((config.size * 0.60) + 0.5), "OUTLINE", 0, 0, 0, 1.0, 0.50, -0.50)

	button.parent = group.parent
	button:ClearAllPoints()
	button:Hide()

	-- Position the button quickly
	positionButton(id, group, config)
	
	-- Update Cooldown Text Styling
	Auras:UpdateCooldownText(button, config)
end

function Auras:UpdateCooldownText(button, config)
	if( not button or not button.cooldown ) then return end

	button.cooldown:SetSwipeColor(0, 0, 0, ShadowUF.db.profile.auras.cooldownSwipeAlpha or 0.8)

	-- Try to get the cooldown text region if we haven't already
	if( not button.cooldown.timerText ) then
		for _, region in pairs({button.cooldown:GetRegions()}) do
			if( region:GetObjectType() == "FontString" ) then
				button.cooldown.timerText = region
				break
			end
		end
	end

	local text = button.cooldown.timerText
	if( text ) then
		-- Apply Font Settings: per-frame override → global aura font → general font
		local fontDetails = ShadowUF.db.profile.font
		local font = SML:Fetch("font", (config and config.cooldownFont) or fontDetails.cooldownName or fontDetails.name)
		local size = (config and config.cooldownFontSize) or fontDetails.cooldownSize or fontDetails.size
		local outline = (config and config.cooldownFontOutline) or fontDetails.cooldownOutline
		if( outline == nil ) then outline = fontDetails.extra end

		text:SetFont(font, size, outline)

		-- Apply Color: per-frame override → global aura font color
		local color = (config and config.cooldownFontColor) or fontDetails.cooldownColor
		if( color ) then
			text:SetTextColor(color.r, color.g, color.b, color.a or 1)
		else
			text:SetTextColor(1, 1, 1, 1)
		end
	end
end

-- Let the mover access this for creating aura things
Auras.updateButton = updateButton

-- Container-based display (AuraContainer + AuraGroups)
-- Blizzard's untainted code reads/filters/sorts the auras and drives the buttons, we just describe the groups up front
-- Filters/sort/caps are runtime-mutable; structural changes still recreate the container, out of combat only, the protected-inherited container can't be hidden or moved in combat

local pendingRebuilds = {}
local regenWatcher, rebuildAnnounced
-- announce is for user config changes made in combat, internal deferrals (spawns mid-fight, re-styles, M+ deaths) queue silently (or spam è_é)
local function queueContainerRebuild(frame, announce)
	pendingRebuilds[frame] = true

	if( announce and not rebuildAnnounced ) then
		rebuildAnnounced = true
		ShadowUF:Print(ShadowUF.L["Some aura changes are deferred while combat restrictions are active (combat, dungeons, raids)."])
	end

	if( not regenWatcher ) then
		regenWatcher = CreateFrame("Frame")
		regenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		regenWatcher:SetScript("OnEvent", function()
			rebuildAnnounced = nil
			for pendingFrame in pairs(pendingRebuilds) do
				pendingRebuilds[pendingFrame] = nil
				if( pendingFrame.visibility and pendingFrame.visibility.auras ) then
					Auras:OnLayoutApplied(pendingFrame, ShadowUF.db.profile.units[pendingFrame.unitType])
				end
			end
		end)
	end
end

-- Config changed in combat means the layout pipeline may be partially skipped, queue every aura-visible frame for a rebuild at regen
function Auras:QueueAllContainerRebuilds()
	for frame in pairs(ShadowUF.Units.frameList) do
		if( frame.visibility and frame.visibility.auras ) then
			queueContainerRebuild(frame, true)
		end
	end
end

local FLOW_H = { LEFT = "Left", RIGHT = "Right", CENTER = "Right" }
local FLOW_V = { TOP = "Up", BOTTOM = "Down" }

-- Pre-Sections UI, one filter split into PLAYER/!PLAYER groups when "enlarge my auras" is on (negation keeps the union duplicate-free)
local function splitTokens(filterValue)
	local tokens = {}
	if( filterValue and filterValue ~= "ALL" and filterValue ~= "BLIZZARD" and not filterValue:find("^CUSTOM:") ) then
		for token in string.gmatch(filterValue, "[^|]+") do
			if( token ~= "ALL" ) then
				tokens[token] = true
			end
		end
	end
	return tokens
end

local function buildSections(auraType, config)
	local base = auraType == "buffs" and "HELPFUL" or "HARMFUL"
	local filterValue = config.filter or "ALL"
	-- CUSTOM:<name> = base filter + spell ID candidate filters resolved at runtime
	local customFilter = filterValue:match("^CUSTOM:(.+)")
	local filterString = base
	if( filterValue ~= "ALL" and filterValue ~= "BLIZZARD" and not customFilter ) then
		filterString = base .. "|" .. filterValue
	end

	-- BLIZZARD: replicate the default UI's aura selection via ProcessAura metadata, needs SetAuraProcessingPolicy(ProcessAura) on the container
	local processedAuraType
	if( filterValue == "BLIZZARD" and AuraUtil and AuraUtil.AuraUpdateChangedType ) then
		processedAuraType = auraType == "buffs" and AuraUtil.AuraUpdateChangedType.Buff or AuraUtil.AuraUpdateChangedType.Debuff
	end

	local sections = {}
	local largeSize = math.floor(config.size * (config.selfScale or 1.30) + 0.5)
	local sortMethod = config.sortMethod
	if( config.enlarge and config.enlarge.PLAYER and not filterString:find("PLAYER", nil, true) ) then
		table.insert(sections, { filterString = filterString .. "|PLAYER", size = largeSize, auraType = auraType, customFilter = customFilter, processedAuraType = processedAuraType, sortMethod = sortMethod, tokens = splitTokens(filterValue .. "|PLAYER") })
		table.insert(sections, { filterString = filterString .. "|!PLAYER", size = config.size, auraType = auraType, customFilter = customFilter, processedAuraType = processedAuraType, sortMethod = sortMethod, tokens = splitTokens(filterValue) })
	elseif( config.enlarge and config.enlarge.PLAYER ) then
		-- Filter is already player-only; everything shows enlarged
		table.insert(sections, { filterString = filterString, size = largeSize, auraType = auraType, customFilter = customFilter, processedAuraType = processedAuraType, sortMethod = sortMethod, tokens = splitTokens(filterValue) })
	else
		table.insert(sections, { filterString = filterString, size = config.size, auraType = auraType, customFilter = customFilter, processedAuraType = processedAuraType, sortMethod = sortMethod, tokens = splitTokens(filterValue) })
	end

	if( config.sections ) then
		for i = 1, 5 do
			local extra = config.sections[i]
			if( extra and extra.filter and extra.enabled ~= false ) then
				local extraFilter = extra.filter
				local extraCustom = extraFilter:match("^CUSTOM:(.+)")
				local fs = base
				if( extraFilter ~= "ALL" and extraFilter ~= "BLIZZARD" and not extraCustom ) then
					fs = fs .. "|" .. extraFilter
				end
				local extraProcessed
				if( extraFilter == "BLIZZARD" and AuraUtil and AuraUtil.AuraUpdateChangedType ) then
					extraProcessed = auraType == "buffs" and AuraUtil.AuraUpdateChangedType.Buff or AuraUtil.AuraUpdateChangedType.Debuff
				end
				table.insert(sections, { filterString = fs, size = extra.size or config.size, auraType = auraType, customFilter = extraCustom, processedAuraType = extraProcessed, sortMethod = extra.sortMethod, maxCount = extra.maxCount, tokens = splitTokens(extraFilter) })
			end
		end
	end

	-- Disjoint cascade, every section negates the tokens of previous sections it doesn't share
	-- A section whose tokens are a subset of a later one's (RAID before PLAYER|RAID, catch-all before anything) also negates the later section's extra tokens, ceding the intersection to the more specific one
	-- "Show only" customs sit outside the cascade, they own their spell list and every other section cedes those spells (see UpdateContainerCandidateFilters)
	-- "Hide" customs are catch-alls
	local function isSubset(a, b)
		for token in pairs(a) do
			if( not b[token] ) then return false end
		end
		return true
	end

	local customFiltersDB = ShadowUF.db.profile.customFilters or {}
	local function isIncludeCustom(section)
		if( not section.customFilter ) then return false end
		local custom = customFiltersDB[section.customFilter]
		return not custom or custom.mode ~= "exclude"
	end

	for index, section in ipairs(sections) do
		if( not isIncludeCustom(section) ) then
			local seen = {}
			for negated in section.filterString:gmatch("|!([^|]+)") do
				seen[negated] = true
			end
			for otherIndex, other in ipairs(sections) do
				if( otherIndex < index or (otherIndex > index and isSubset(section.tokens, other.tokens)) ) then
					for token in pairs(other.tokens) do
						if( not section.tokens[token] and not seen[token] ) then
							seen[token] = true
							section.filterString = section.filterString .. "|!" .. token
						end
					end
				end
			end
		end
	end
	return sections
end

-- Numeric keys only, the zone assignment scopes where it applies
local function buildSpellIDMap(filterList)
	if( not filterList ) then return nil end

	local map
	for key in pairs(filterList) do
		local spellID = tonumber(key)
		if( spellID ) then
			map = map or {}
			map[spellID] = true
		end
	end
	return map
end

-- Everything frozen at container creation goes in the signature; runtime-mutable settings (anchor, growth, row width, unit) stay out
-- Returns (structural, full), filter strings/sort/caps are runtime-mutable so when only those differ the container is updated in place
local function getContainerSignature(group, config, sections)
	local structural, runtime = {}, {}
	for _, section in ipairs(sections) do
		-- Sizes are runtime too, the re-style loop resizes stored buttons so the size slider doesn't recreate containers
		table.insert(runtime, section.filterString .. "@" .. section.size .. "@" .. (section.sortMethod or "") .. "@" .. (section.maxCount or ""))
	end
	local hideCC = config.disableBlizzardCC
	if( hideCC == nil ) then hideCC = ShadowUF.db.profile.blizzardcc end
	table.insert(structural, tostring(#sections))
	table.insert(structural, ShadowUF.db.profile.auras.borderType)
	table.insert(structural, Auras:GetDispelColorsKey())
	table.insert(structural, tostring(hideCC))
	table.insert(structural, tostring(ShadowUF.db.profile.auras.disableCooldown))
	table.insert(structural, tostring(group.canCancel))
	table.insert(structural, tostring(config.disableRemovableColor))
	table.insert(structural, tostring(config.temporary and group.parent.unit == "player" and group.type == "buffs"))
	table.insert(runtime, tostring(config.perRow * config.maxRows))
	local structuralSignature = table.concat(structural, ";")
	return structuralSignature, structuralSignature .. "##" .. table.concat(runtime, ";")
end

-- Regions must be children of the button (forbidden aspect inheritance) and templates with scripts are rejected, everything is created here at runtime
local function makeButtonInitializer(group, config, section, sectionIndex)
	local size = section.size
	local auraType = section.auraType or group.type
	local hideCC = config.disableBlizzardCC
	if( hideCC == nil ) then hideCC = ShadowUF.db.profile.blizzardcc end
	local borderType = ShadowUF.db.profile.auras.borderType
	local canCancel = group.canCancel
	-- Per-frame opt-out of the dispel tinting, custom borders only (the blizzard style IS the dispel border, cutting it would leave none)
	local noDispelTint = config.disableRemovableColor

	return function(button)
		-- No API to enumerate a group's frames, keep our own list
		-- sectionIndex (0 = item enchantment) lets the re-style loop resize without recreating the container
		local record = { button = button, sectionIndex = sectionIndex }
		table.insert(group.containerButtons, record)
		button:SetSize(size, size)

		local icon = button:CreateTexture(nil, "BACKGROUND")
		icon:SetAllPoints(button)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button:SetIcon(icon)

		-- The SetAuraBorder region only shows when dispellable, so it needs its own art on top of a separate always-visible neutral border
		if( borderType == "blizzard" ) then
			local dispel = button:CreateTexture(nil, "OVERLAY")
			dispel:SetPoint("CENTER", button)
			dispel:SetSize(size + 1, size + 1)
			record.dispel = dispel
			pcall(button.SetAuraBorder, button, dispel, { style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon or 1, showWhenHarmful = true, showWhenHelpful = true })
		elseif( borderType ~= "" ) then
			local border = button:CreateTexture(nil, "OVERLAY")
			border:SetPoint("CENTER", button)
			border:SetSize(size + 1, size + 1)
			border:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. borderType)
			if( auraType == "debuffs" ) then
				border:SetVertexColor(0.8, 0, 0)
			else
				border:SetVertexColor(0.6, 0.6, 0.6)
			end
			record.border = border

			if( not noDispelTint ) then
				local dispel = button:CreateTexture(nil, "OVERLAY", nil, 1)
				dispel:SetPoint("CENTER", button)
				dispel:SetSize(size + 1, size + 1)
				dispel:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. borderType)
				record.dispel = dispel
				-- PreserveAsset keeps our border art and only tints it by dispel type
				pcall(button.SetAuraBorder, button, dispel, { style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3, showWhenHarmful = true, showWhenHelpful = true, customDispelColorMap = Auras:GetDispelColorMap() })
			end
		end

		local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		cooldown:SetAllPoints(button)
		cooldown:SetReverse(true)
		cooldown:SetDrawEdge(false)
		cooldown:SetDrawSwipe(true)
		cooldown:SetSwipeColor(0, 0, 0, ShadowUF.db.profile.auras.cooldownSwipeAlpha or 0.8)
		cooldown:SetHideCountdownNumbers(hideCC)
		if( not ShadowUF.db.profile.auras.disableCooldown ) then
			pcall(button.SetDurationCooldown, button, cooldown)
		end
		record.cooldown = cooldown
		Auras:UpdateCooldownText(record, config)

		local stack = button:CreateFontString(nil, "OVERLAY")
		ShadowUF:SetFontAndShadow(stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", math.floor((size * 0.60) + 0.5), "OUTLINE", 0, 0, 0, 1.0, 0.50, -0.50)
		stack:SetAllPoints(button)
		stack:SetJustifyV("BOTTOM")
		stack:SetJustifyH("RIGHT")
		record.stack = stack
		-- No formatter option, it errors on secret values
		pcall(button.SetApplicationCount, button, stack, {})

		if( canCancel ) then
			-- Blizzard-side click handler (CancelAuraByInstanceID), no taint
			pcall(button.SetCancelAuraButtons, button, "RightButtonUp")
		end
		button:SetMouseMotionEnabled(ShadowUF.db.profile.locked and true or false)
		-- "exceptAuras" keeps aura tooltips visible in combat
		local tooltipMode = ShadowUF.db.profile.tooltipCombat
		pcall(button.SetHideTooltipInCombat, button, (tooltipMode == true or tooltipMode == "all") and true or false)
	end
end

local function columnRelativePoint(point, growV)
	if( growV == "TOP" ) then
		return (point:gsub("BOTTOM", "TOP")), 2
	else
		return (point:gsub("TOP", "BOTTOM")), -2
	end
end

-- extraSections come from a SEQUENTIAL-anchored partner group
local function configureGroupContainer(frame, group, config, extraSections)
	local sections = buildSections(group.type, config)
	if( extraSections ) then
		for _, section in ipairs(extraSections) do
			table.insert(sections, section)
		end
	end

	group.canCancel = (frame.unit == "player" and group.type == "buffs" and not config.clickThrough) or nil
	local structural, signature = getContainerSignature(group, config, sections)

	if( group.container and group.containerSignature ~= signature ) then
		-- Same group structure (count/sizes/style) and only filters/sort/caps changed, update the groups in place
		local fastPathed = false
		if( group.containerStructural == structural and group.container.SetAuraGroupFilterString ) then
			fastPathed = true
			local maxAuras = config.perRow * config.maxRows
			for index, section in ipairs(sections) do
				local key = "section" .. index
				local sortValue = AuraContainerSortMethod and AuraContainerSortMethod[section.sortMethod or "Default"] or 0
				-- The direction argument is mandatory (validated enum)
				local sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0
				local okFilter = pcall(group.container.SetAuraGroupFilterString, group.container, key, section.filterString)
				local okSort = pcall(group.container.SetAuraGroupSortMethod, group.container, key, sortValue, sortDirection)
				local okMax = pcall(group.container.SetAuraGroupMaxFrameCount, group.container, key, section.maxCount or maxAuras)
				if( not (okFilter and okSort and okMax) ) then
					fastPathed = false
					break
				end
			end
		end

		if( fastPathed ) then
			group.containerSignature = signature
		elseif( InCombatLockdown() ) then
			-- Containers inherit protection from the secure unit frame and Hide is silently blocked in combat, leave the old container untouched and rebuild after regen
			queueContainerRebuild(frame)
			return
		else
			-- Groups can't be removed so retire the old container, frames can't be deleted but a disabled hidden one unregisters its events
			group.container:SetEnabled(false)
			group.container:Hide()
			group.container = nil
		end
	end

	if( not group.container ) then
		-- Creating a container in combat works but positioning it under a protected unit frame is blocked (it would render nowhere), keep deferring to regen
		if( InCombatLockdown() ) then
			queueContainerRebuild(frame)
			return
		end

		local ok, container = pcall(CreateFrame, "AuraContainer", nil, group, "CustomAuraContainerTemplate")
		if( not ok or not container ) then return end

		group.container = container
		group.containerSignature = signature
		group.containerStructural = structural
		group.containerButtons = {}
		container:SetFrameLevel(group:GetFrameLevel() + 1)

		-- BLIZZARD-filter sections need ProcessAura metadata on the container
		local needsProcessPolicy = false
		for _, section in ipairs(sections) do
			if( section.processedAuraType ) then needsProcessPolicy = true break end
		end
		if( needsProcessPolicy and CustomAuraContainerAuraProcessingPolicy ) then
			pcall(container.SetAuraProcessingPolicy, container, CustomAuraContainerAuraProcessingPolicy.ProcessAura, {})
		end

		local maxAuras = config.perRow * config.maxRows
		for index, section in ipairs(sections) do
			-- Visible counts are secret so totals can't be balanced across sections, each one is capped on its own
			local addOk, err = pcall(container.AddAuraGroup, container, "section" .. index, section.filterString, {
				maxFrameCount = section.maxCount or maxAuras,
				initializeFrame = makeButtonInitializer(group, config, section, index),
				candidateFilters = section.processedAuraType and { processedAuraType = section.processedAuraType } or nil,
				sortMethod = AuraContainerSortMethod and section.sortMethod and AuraContainerSortMethod[section.sortMethod] or nil,
			})
			if( not addOk and not group.hasContainerError ) then
				ShadowUF:Print("Error adding aura group '" .. tostring(section.filterString) .. "' (logged once): " .. tostring(err))
				group.hasContainerError = true
			end
		end

		-- Native temp weapon enchants, appended to the flow layout
		if( config.temporary and frame.unit == "player" and group.type == "buffs" ) then
			local slots = AuraContainerItemEnchantmentSlot or { MainHand = 0, OffHand = 1 }
			local enchantSection = { size = config.size, auraType = "buffs" }
			pcall(container.AddItemEnchantment, container, slots.MainHand, { initializeFrame = makeButtonInitializer(group, config, enchantSection, 0) })
			pcall(container.AddItemEnchantment, container, slots.OffHand, { initializeFrame = makeButtonInitializer(group, config, enchantSection, 0) })
		end
	end

	-- Same-signature reconfigures (e.g. switching between two custom filters) still need fresh section descriptors for the candidate filter pass
	group.containerSections = sections

	-- The container inherits frame protection (SetPoint blocked in combat), freeze position changes and replay the config at regen
	if( InCombatLockdown() ) then
		queueContainerRebuild(frame)
		return
	end

	-- Runtime-configurable (position, growth, row width, unit)
	local container = group.container
	local growH = config.growH or "RIGHT"
	local growV = config.growV or "BOTTOM"
	local point, relativePoint = ShadowUF.Layout:GetAuraPoint(config.anchorPoint, growH, growV)
	local inset = (config.anchorPoint == "FREE") and 0 or ShadowUF.db.profile.backdrop.inset
	local position = positionData[getPositionKey(config)]

	container:ClearAllPoints()
	container:SetPoint(point, group.anchorTo, relativePoint, config.x + (position.xMod * inset), config.y + (position.yMod * inset))
	local setAnchorPoint = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
	local setGrowthDirection = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
	local setMaximumLineSize = container.SetFlowLayoutMaximumLineSize or container.SetAuraLayoutRowWidth
	-- Center growth, the flow layout can't alternate around the origin so centering comes from the auto-sized box anchored by its centered edge (TOP/BOTTOM above)
	-- The flow inside still fills from a corner or the icons would spill out of the box
	local flowPoint = point
	if( growH == "CENTER" ) then
		flowPoint = (growV == "TOP") and "BOTTOMLEFT" or "TOPLEFT"
	end
	pcall(setAnchorPoint, container, flowPoint)
	if( AnchorUtil and AnchorUtil.FlowDirection ) then
		pcall(setGrowthDirection, container, AnchorUtil.FlowDirection[FLOW_H[growH]], AnchorUtil.FlowDirection[FLOW_V[growV]])
	end
	pcall(setMaximumLineSize, container, config.perRow * (config.size + 2))

	container:Show()

	-- Buttons are forbidden while auras are secret (any restriction, not just combat lockdown), skip the re-style and replay it through the rebuild queue
	if( aurasAreSecret() ) then
		queueContainerRebuild(frame)
		return
	end

	-- Tooltip policy, cooldown fonts and sizes are runtime-mutable on stored buttons; timerText only exists once a cooldown has run
	local motionEnabled = ShadowUF.db.profile.locked and true or false
	local tooltipMode = ShadowUF.db.profile.tooltipCombat
	local hideAuraTooltips = (tooltipMode == true or tooltipMode == "all") and true or false
	for _, record in ipairs(group.containerButtons) do
		-- Sizes are runtime (not in the structural signature), resize the button and its regions to the current section size
		local size
		if( record.sectionIndex == 0 ) then
			size = config.size
		elseif( record.sectionIndex and sections[record.sectionIndex] ) then
			size = sections[record.sectionIndex].size
		end
		if( size ) then
			record.button:SetSize(size, size)
			if( record.border ) then record.border:SetSize(size + 1, size + 1) end
			if( record.dispel ) then record.dispel:SetSize(size + 1, size + 1) end
			if( record.stack ) then
				ShadowUF:SetFontAndShadow(record.stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", math.floor((size * 0.60) + 0.5), "OUTLINE", 0, 0, 0, 1.0, 0.50, -0.50)
			end
		end

		pcall(record.button.SetMouseMotionEnabled, record.button, motionEnabled)
		pcall(record.button.SetHideTooltipInCombat, record.button, hideAuraTooltips)
		Auras:UpdateCooldownText(record, config)
	end

	-- Containers don't receive OnSizeChanged (aspect), re-run the flow layout to reposition resized buttons
	pcall(container.UpdateAllAuras, container)
end

-- Called from OnLayoutApplied once anchor pairs are known
-- SEQUENTIAL pairs merge the child's groups into the parent's container (buffs/debuffs are disjoint filters, no duplicates)
function Auras:ConfigureContainers(frame, config)
	local mergedPairs = {}
	if( frame.auras.anchorPairs ) then
		for i = 1, 6 do
			local pair = frame.auras.anchorPairs[i]
			if( pair and pair.sequential ) then
				mergedPairs[pair.child] = pair
			end
		end
	end

	for _, auraType in ipairs(AURA_TYPES) do
		local typeConfig = config.auras[auraType]
		if( typeConfig ) then
			for i = 1, 6 do
				local frameConfig = typeConfig[i]
				local group = frame.auras[auraType .. i]
				if( group and frameConfig and frameConfig.enabled ) then
					group.containerDisabled = nil
					if( mergedPairs[group] ) then
						-- Child of a sequential pair: its auras live in the parent's container
						group.containerMerged = true
						if( group.container ) then
							group.container:SetEnabled(false)
							group.container:Hide()
						end
					else
						group.containerMerged = nil
						local extraSections
						for _, pair in pairs(mergedPairs) do
							if( pair.parent == group ) then
								extraSections = buildSections(pair.child.type, pair.childConfig)
								break
							end
						end
						configureGroupContainer(frame, group, frameConfig, extraSections)
					end
				elseif( group and group.container ) then
					-- Group disabled by config, silence its container (the flag keeps UpdateContainers from re-enabling it, Hide is blocked in combat so replay at regen)
					group.containerDisabled = true
					if( InCombatLockdown() ) then
						queueContainerRebuild(frame)
					else
						group.container:SetEnabled(false)
						group.container:Hide()
					end
				end
			end
		end
	end

	-- Column pairs anchor the child's container to the parent's, containers auto-resize so the column tracks the parent's visible footprint
	if( frame.auras.anchorPairs ) then
		for i = 1, 6 do
			local pair = frame.auras.anchorPairs[i]
			if( pair and not pair.sequential and pair.parent.container and pair.child.container ) then
				local growH = pair.parentConfig.growH or "RIGHT"
				local growV = pair.parentConfig.growV or "BOTTOM"
				local point = ShadowUF.Layout:GetAuraPoint(pair.parentConfig.anchorPoint, growH, growV)
				local rel, offset = columnRelativePoint(point, growV)
				pair.child.container:ClearAllPoints()
				pair.child.container:SetPoint(point, pair.parent.container, rel, 0, offset)
			end
		end
	end

	-- Containers may have just been (re)created: apply zone filters now
	self:UpdateContainerCandidateFilters(frame)
end

-- Candidate filters are runtime-mutable (unlike filter strings), filter edits and zone changes need no rebuild
-- Blizzard ignores spell ID filters on friendly-unit debuffs and enemy-unit buffs (identity gate), those lists just do nothing there
function Auras:UpdateContainerCandidateFilters(frame)
	if( not frame.auras ) then return end
	local whitelist = frame.auras.whitelist
	local blacklist = frame.auras.blacklist
	local customFilters = ShadowUF.db.profile.customFilters or {}

	for _, auraType in ipairs(AURA_TYPES) do
		for i = 1, 6 do
			local group = frame.auras[auraType .. i]
			if( group and group.container and group.containerSections ) then
				-- "Show only" customs own their spells wherever they sit, every other section cedes them and between customs the first one wins
				local allCustomSpells
				for _, section in ipairs(group.containerSections) do
					local custom = section.customFilter and customFilters[section.customFilter]
					if( custom and custom.mode ~= "exclude" and custom.spells ) then
						allCustomSpells = allCustomSpells or {}
						for spellID in pairs(custom.spells) do
							allCustomSpells[spellID] = true
						end
					end
				end

				local carriedExcludes
				for index, section in ipairs(group.containerSections) do
					local include, exclude
					local custom = section.customFilter and customFilters[section.customFilter]
					if( custom and custom.spells ) then
						if( custom.mode == "exclude" ) then
							exclude = CopyTable(custom.spells)
							if( allCustomSpells ) then
								for spellID in pairs(allCustomSpells) do
									exclude[spellID] = true
								end
							end
						else
							include = custom.spells
							exclude = carriedExcludes and CopyTable(carriedExcludes) or nil
						end
					else
						-- Zone-assigned lists apply on their own, the assignment (zone x unit type) is the opt-in
						include = buildSpellIDMap(whitelist)
						exclude = buildSpellIDMap(blacklist)
						if( allCustomSpells ) then
							exclude = exclude and CopyTable(exclude) or {}
							for spellID in pairs(allCustomSpells) do
								exclude[spellID] = true
							end
						end
					end

					local filters
					if( include or exclude ) then
						filters = { includeSpellIDs = include, excludeSpellIDs = exclude }
					end
					-- Setting candidate filters replaces the whole table, keep the BLIZZARD metadata alive across refreshes
					if( section.processedAuraType ) then
						filters = filters or {}
						filters.processedAuraType = section.processedAuraType
					end
					pcall(group.container.SetAuraGroupCandidateFilters, group.container, "section" .. index, filters)

					if( custom and custom.mode ~= "exclude" and custom.spells ) then
						carriedExcludes = carriedExcludes or {}
						for spellID in pairs(custom.spells) do
							carriedExcludes[spellID] = true
						end
					end
				end
			end
		end
	end
end

-- The container refreshes itself on UNIT_AURA (never read that payload), we only track unit identity here
function Auras:UpdateContainers(frame)
	-- Live path owns the containers again, let config mode redo its pass if we go back to it
	frame.auras.containersToggled = nil

	-- SetUnit early-outs on an unchanged token, so retargets (same token, different unit) need an UpdateAllAuras kick
	-- Kicking every call makes polled compound units (targettarget...) flash twice a second, so only kick when the resolved identity changed (or on event updates when it's secret)
	local identity
	if( frame.unit and not ShadowUF.IsUnitIdentitySecret(frame.unit) ) then
		local ok, guid = pcall(UnitGUID, frame.unit)
		if( ok ) then identity = guid end
	end

	for _, auraType in ipairs(AURA_TYPES) do
		for i = 1, 6 do
			local group = frame.auras[auraType .. i]
			local container = group and group.container
			if( container and not group.containerMerged and not group.containerDisabled ) then
				if( frame.unit ) then
					local ok = pcall(container.SetUnit, container, frame.unit)
					if( ok ) then
						container:SetEnabled(true)
						-- Show is blocked in combat (inherited protection)
						if( not InCombatLockdown() ) then
							container:Show()
						end

						local kick
						if( identity ~= nil ) then
							kick = group.containerIdentity ~= identity
						else
							kick = not frame.pollingUpdate
						end
						group.containerIdentity = identity
						if( kick ) then
							pcall(container.UpdateAllAuras, container)
						end
					else
						-- Token rejected (compound units, etc.), keep it quiet
						container:SetEnabled(false)
					end
				else
					container:SetEnabled(false)
				end
			end
		end
	end

	self:UpdateBossDebuffs(frame)
end

-- Config mode swaps containers off and legacy placeholder buttons in
-- Called on every config mode update, skip the container calls once they are already in the wanted state
function Auras:SetContainersEnabled(frame, enabled)
	if( frame.auras.containersToggled == enabled ) then return end
	frame.auras.containersToggled = enabled

	for _, auraType in ipairs(AURA_TYPES) do
		for i = 1, 6 do
			local group = frame.auras[auraType .. i]
			if( group and group.container ) then
				group.container:SetEnabled(enabled and not group.containerMerged or false)
				if( enabled and not group.containerMerged ) then
					group.container:Show()
				else
					group.container:Hide()
				end
			end
		end
	end
end

-- Create an aura anchor as well as the buttons to contain it
local function updateGroup(self, groupKey, config, reverseConfig)
	self.auras[groupKey] = self.auras[groupKey] or CreateFrame("Frame", nil, self.highFrame)

	local group = self.auras[groupKey]
	group.buttons = group.buttons or {}

	group.maxAuras = config.perRow * config.maxRows
	group.totalAuras = 0
	group.temporaryEnchants = 0
	group.lastTemporary = 0
	group.groupKey = groupKey
	group.parent = self
	if( config.anchorPoint == "FREE" and self.unit == "player" ) then
		group.anchorTo = UIParent
	else
		group.anchorTo = self
	end
	group:SetFrameLevel(self.highFrame:GetFrameLevel() + 1)
	group:Show()

	-- Temp enchants are handled natively by the container (AddItemEnchantment)
	group:SetScript("OnUpdate", nil)

	-- Extract base type from groupKey
	local baseType = groupKey:match("^(%a+)%d*$") or groupKey
	group.type = baseType
	group.filter = baseType == "buffs" and "HELPFUL" or baseType == "debuffs" and "HARMFUL" or ""

	for id, button in pairs(group.buttons) do
		updateButton(id, group, config)
	end
end

-- Update aura positions based off of configuration
-- Support multiple frames per type
function Auras:OnLayoutApplied(frame, config)
	-- Any aura config change lands here, placeholder styling from older generations is stale
	self.configStyleGeneration = self.configStyleGeneration + 1

	-- Hide all existing aura buttons first
	if( frame.auras ) then
		for auraType, _ in pairs({buffs = true, debuffs = true}) do
			for i = 1, 6 do
				local groupKey = auraType .. i
				if( frame.auras[groupKey] and frame.auras[groupKey].buttons ) then
					for _, button in pairs(frame.auras[groupKey].buttons) do
						button:Hide()
					end
				end
			end
		end
	end

	if( not frame.visibility.auras ) then
		self:DisableContainers(frame)
		return
	end

	-- Setup enabled aura frames
	for _, auraType in pairs({"buffs", "debuffs"}) do
		local typeConfig = config.auras[auraType]
		if( typeConfig ) then
			for i = 1, 6 do
				local frameConfig = typeConfig[i]
				if( frameConfig and frameConfig.enabled ) then
					local groupKey = auraType .. i
					-- Create the unique frame for this slot
					updateGroup(frame, groupKey, frameConfig, nil)
					-- Store the aura type for scan()
					frame.auras[groupKey].auraType = auraType
					frame.auras[groupKey].frameIndex = i
					frame.auras[groupKey].filterType = frameConfig.filter
				end
			end
		end
	end

	-- Setup anchor-to-anchor logic
	frame.auras.anchorPairs = {}

	for i = 1, 6 do
		local buffsConfig = config.auras.buffs and config.auras.buffs[i]
		local debuffsConfig = config.auras.debuffs and config.auras.debuffs[i]
		local buffsGroup = frame.auras["buffs" .. i]
		local debuffsGroup = frame.auras["debuffs" .. i]

		-- Clear pair state on both groups, a previous layout may have stamped it and frames persist across reloads
		if( buffsGroup ) then
			buffsGroup.skipScan = nil
			buffsGroup.forcedAnchorPoint = nil
			buffsGroup.forcedGrowH = nil
			buffsGroup.forcedGrowV = nil
			buffsGroup.configPairRepositioned = nil
		end
		if( debuffsGroup ) then
			debuffsGroup.skipScan = nil
			debuffsGroup.forcedAnchorPoint = nil
			debuffsGroup.forcedGrowH = nil
			debuffsGroup.forcedGrowV = nil
			debuffsGroup.configPairRepositioned = nil
		end

		if( buffsConfig and buffsConfig.enabled and debuffsConfig and debuffsConfig.enabled and buffsGroup and debuffsGroup ) then
			local anchorOnConfig, parentGroup, childGroup, parentConfig, childConfig
			if( buffsConfig.anchorOn ) then
				anchorOnConfig = buffsConfig
				parentGroup, childGroup = debuffsGroup, buffsGroup
				parentConfig, childConfig = debuffsConfig, buffsConfig
			elseif( debuffsConfig.anchorOn ) then
				anchorOnConfig = debuffsConfig
				parentGroup, childGroup = buffsGroup, debuffsGroup
				parentConfig, childConfig = buffsConfig, debuffsConfig
			end

			if( anchorOnConfig ) then
				local isSequential = (anchorOnConfig.anchorMode == "SEQUENTIAL")
				frame.auras.anchorPairs[i] = {
					parent = parentGroup,
					child = childGroup,
					parentConfig = parentConfig,
					childConfig = childConfig,
					sequential = isSequential,
				}
				childGroup.forcedAnchorPoint = parentConfig.anchorPoint
					childGroup.forcedGrowH = parentConfig.growH
					childGroup.forcedGrowV = parentConfig.growV

				if( isSequential ) then
					-- Sequential mode: child scans into parent group, expand parent capacity
					parentGroup.maxAuras = parentGroup.maxAuras + childGroup.maxAuras
					childGroup.skipScan = true
				end
			end
		end
	end

	self:UpdateFilter(frame)

	-- Build/refresh the managed containers now that anchor pairs are known
	if( hasContainers ) then
		self:ConfigureContainers(frame, config)
	end

	-- Setup Boss Debuffs if enabled
	if config.auras.bossDebuffs and config.auras.bossDebuffs.enabled then
		self:SetupBossDebuffs(frame, config.auras.bossDebuffs)
	else
		self:ClearBossDebuffs(frame)
	end
end

-- Private Auras (Boss Debuffs) support
-- Only works with stable unit tokens (player, party, raid, maintank, mainassist)
local AddPrivateAuraAnchor = C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor
local RemovePrivateAuraAnchor = C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor
local privateAuraUnits = {
	player = true,
	party = true,
	raid = true,
	maintank = true,
	mainassist = true,
}

function Auras:ClearBossDebuffs(frame)
	if not frame.bossDebuffs then return end

	frame.bossDebuffs.configStamp = nil
	frame.bossDebuffs.signature = nil

	local anchors = frame.bossDebuffs.anchorIDs
	if anchors and RemovePrivateAuraAnchor then
		for i = 1, #anchors do
			if anchors[i] then
				RemovePrivateAuraAnchor(anchors[i])
				anchors[i] = nil
			end
		end
	end

	-- Hide config mode placeholders
	if frame.bossDebuffs.testButtons then
		for i = 1, #frame.bossDebuffs.testButtons do
			frame.bossDebuffs.testButtons[i]:Hide()
		end
	end

	if frame.bossDebuffs.container then
		frame.bossDebuffs.container:Hide()
	end
	frame.bossDebuffs.unit = nil
end

function Auras:SetupBossDebuffs(frame, config)
	if not privateAuraUnits[frame.unitType] then
		self:ClearBossDebuffs(frame)
		return
	end

	-- Create container even without AddPrivateAuraAnchor so config mode placeholders work
	if not frame.bossDebuffs then
		frame.bossDebuffs = {}
		frame.bossDebuffs.anchorIDs = {}
		frame.bossDebuffs.testButtons = {}
		frame.bossDebuffs.container = CreateFrame("Frame", nil, frame.highFrame)
		-- 12.0.5, private aura icons ignore frame level on re-apply and end up
		-- behind the parent unit frame. Bumping the container's strata above the unit frame's
		-- strata ("LOW") keeps icons on top regardless of level.
		frame.bossDebuffs.container:SetFrameStrata("MEDIUM")
	end

	-- Every layout pass lands here, redoing the geometry and the private aura anchors is only worth it when the config moved
	local signature = table.concat({config.perRow or 3, config.maxRows or 1, config.size or 32, config.anchorPoint or "CENTER", config.x or 0, config.y or 0, tostring(config.showCooldown), tostring(config.showCooldownNumbers)}, ":")
	if( frame.bossDebuffs.signature == signature ) then return end
	frame.bossDebuffs.signature = signature

	local container = frame.bossDebuffs.container
	local perRow = config.perRow or 3
	local maxRows = config.maxRows or 1
	local maxAuras = perRow * maxRows
	-- Private aura internals (countdown font) are forbidden, so the timer text can't follow iconWidth/iconHeight
	-- Everything is laid out at a fixed base size and the whole container is scaled instead, icons/borders/countdown all follow the configured size
	local BASE_SIZE = 32
	local scale = (config.size or 32) / BASE_SIZE
	local iconSize = BASE_SIZE
	local spacing = 2

	-- Base units, the container scale applies the configured size
	local totalWidth = (iconSize * perRow) + (spacing * (perRow - 1))
	local totalHeight = (iconSize * maxRows) + (spacing * (maxRows - 1))

	container:SetScale(scale)
	container:SetSize(totalWidth, totalHeight)
	container:ClearAllPoints()

	-- A frame's own anchor offsets are in its own scale, divide so the configured offsets stay in screen units
	local relativePoint = config.anchorPoint or "CENTER"
	local anchorFrame = (relativePoint == "FREE") and UIParent or frame
	if relativePoint == "FREE" then relativePoint = "CENTER" end
	container:SetPoint("CENTER", anchorFrame, relativePoint, (config.x or 0) / scale, (config.y or 0) / scale)
	container:SetFrameLevel(frame.highFrame:GetFrameLevel() + 2)
	container:Show()

	-- Store config for update
	frame.bossDebuffs.config = config
	frame.bossDebuffs.maxAuras = maxAuras
	frame.bossDebuffs.perRow = perRow
	frame.bossDebuffs.iconSize = iconSize
	frame.bossDebuffs.spacing = spacing
	frame.bossDebuffs.scale = scale

	-- Force update, sizes just changed so the placeholder styling is stale too
	frame.bossDebuffs.configStamp = nil
	frame.bossDebuffs.unit = nil
	Auras:UpdateBossDebuffs(frame)
end

function Auras:UpdateBossDebuffs(frame)
	if not frame.bossDebuffs or not frame.bossDebuffs.container then return end

	if not privateAuraUnits[frame.unitType] then return end

	-- Config/test mode: show placeholders
	if( frame.configMode ) then
		self:ShowBossDebuffsPlaceholders(frame)
		return
	end

	-- Hide placeholders when leaving config mode, this runs on every live update so only pay it once
	if frame.bossDebuffs.placeholdersShown then
		frame.bossDebuffs.placeholdersShown = nil
		for i = 1, #frame.bossDebuffs.testButtons do
			frame.bossDebuffs.testButtons[i]:Hide()
		end
	end

	if not AddPrivateAuraAnchor then return end

	local unit = frame.unit
	if not unit then
		self:ClearBossDebuffs(frame)
		return
	end

	if frame.bossDebuffs.unit == unit then return end

	-- Clear old anchors
	local anchors = frame.bossDebuffs.anchorIDs
	if RemovePrivateAuraAnchor then
		for i = 1, #anchors do
			if anchors[i] then
				RemovePrivateAuraAnchor(anchors[i])
				anchors[i] = nil
			end
		end
	end

	local config = frame.bossDebuffs.config
	local container = frame.bossDebuffs.container
	local maxAuras = frame.bossDebuffs.maxAuras
	local perRow = frame.bossDebuffs.perRow
	local iconSize = frame.bossDebuffs.iconSize
	local spacing = frame.bossDebuffs.spacing

	-- Create anchor points for Private Auras
	for i = 1, maxAuras do
		local row = math.floor((i - 1) / perRow)
		local col = (i - 1) % perRow
		local xOffset = col * (iconSize + spacing)
		local yOffset = -row * (iconSize + spacing)

		local auraAnchor = {
			unitToken = unit,
			auraIndex = i,
			parent = container,
			showCountdownFrame = config.showCooldown ~= false,
			showCountdownNumbers = config.showCooldownNumbers ~= false,
			isContainer = false,
			iconInfo = {
				iconWidth = iconSize,
				iconHeight = iconSize,
				borderScale = iconSize / 18,
				iconAnchor = {
					point = "TOPLEFT",
					relativeTo = container,
					relativePoint = "TOPLEFT",
					offsetX = xOffset,
					offsetY = yOffset,
				},
			},
		}

		local anchorID = AddPrivateAuraAnchor(auraAnchor)
		if anchorID then
			anchors[i] = anchorID
		end
	end

	frame.bossDebuffs.unit = unit
end

-- Config mode placeholders for Private Auras
-- Same visual structure as scanConfigMode buttons (icon, border, cooldown, stack)
-- Grid positioning matches the real AddPrivateAuraAnchor layout
local bossTestTextures = {
	"Interface\\Icons\\Spell_Shadow_AuraOfDarkness",
	"Interface\\Icons\\Spell_Shadow_Possession",
	"Interface\\Icons\\Spell_Fire_Incinerate",
	"Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
	"Interface\\Icons\\Spell_Nature_Earthquake",
	"Interface\\Icons\\Spell_Fire_FelFlameRing",
}

function Auras:ShowBossDebuffsPlaceholders(frame)
	local bd = frame.bossDebuffs

	-- Fake data styled from the boss debuff config alone, only a real config change (Setup/Clear) invalidates it
	if( bd.configStamp ) then
		for i = 1, bd.maxAuras do
			local button = bd.testButtons[i]
			if( button ) then button:Show() end
		end
		bd.placeholdersShown = true
		return
	end
	bd.configStamp = true
	bd.placeholdersShown = true

	local container = bd.container
	local maxAuras = bd.maxAuras
	local perRow = bd.perRow
	local iconSize = bd.iconSize
	local spacing = bd.spacing
	local config = bd.config

	for i = 1, maxAuras do
		local button = bd.testButtons[i]
		if not button then
			-- Same structure as updateButton: icon, border, cooldown, stack
			button = CreateFrame("Button", nil, container)

			button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
			button.cooldown:SetAllPoints(button)
			button.cooldown:SetReverse(true)
			button.cooldown:SetDrawEdge(false)
			button.cooldown:SetDrawSwipe(true)
			button.cooldown:SetSwipeColor(0, 0, 0, ShadowUF.db.profile.auras.cooldownSwipeAlpha or 0.8)
			button.cooldown:Hide()

			button.stack = button:CreateFontString(nil, "OVERLAY")
			ShadowUF:SetFontAndShadow(button.stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 10, "OUTLINE", 0, 0, 0, 1.0, 0.50, -0.50)
			button.stack:SetHeight(1)
			button.stack:SetWidth(1)
			button.stack:SetAllPoints(button)
			button.stack:SetJustifyV("BOTTOM")
			button.stack:SetJustifyH("RIGHT")

			button.border = button:CreateTexture(nil, "OVERLAY")
			button.border:SetPoint("CENTER", button)

			button.icon = button:CreateTexture(nil, "BACKGROUND")
			button.icon:SetAllPoints(button)
			button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

			bd.testButtons[i] = button
		end

		-- Sizing (same as updateButton)
		button:SetSize(iconSize, iconSize)
		button.border:SetSize(iconSize + 1, iconSize + 1)
		ShadowUF:SetFontAndShadow(button.stack, "Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", math.floor((iconSize * 0.60) + 0.5), "OUTLINE", 0, 0, 0, 1.0, 0.50, -0.50)
		button.cooldown:SetHideCountdownNumbers(ShadowUF.db.profile.blizzardcc)

		-- Grid position (matches AddPrivateAuraAnchor layout)
		local row = math.floor((i - 1) / perRow)
		local col = (i - 1) % perRow
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", container, "TOPLEFT", col * (iconSize + spacing), -row * (iconSize + spacing))

		-- Test texture
		local texIndex = ((i - 1) % #bossTestTextures) + 1
		button.icon:SetTexture(bossTestTextures[texIndex])

		-- Border (same logic as updateButton)
		if ShadowUF.db.profile.auras.borderType == "" then
			button.border:Hide()
		elseif ShadowUF.db.profile.auras.borderType == "blizzard" then
			button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
			button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
			button.border:Show()
		else
			button.border:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\border-" .. ShadowUF.db.profile.auras.borderType)
			button.border:SetTexCoord(0, 1, 0, 1)
			button.border:Show()
		end
		button.border:SetVertexColor(0.80, 0.20, 0.80)

		-- Test cooldown
		if config.showCooldown ~= false then
			button.cooldown:SetCooldown(GetTime() - (i * 15), 300)
			button.cooldown:Show()
		else
			button.cooldown:Hide()
		end

		-- Test stack (some with stacks like scanConfigMode)
		local testStacks = (i % 3 == 0) and math.random(2, 5) or 0
		button.stack:SetText(testStacks > 0 and testStacks or "")

		Auras:UpdateCooldownText(button)
		button:Show()
	end

	-- Hide extra buttons from previous config
	for i = maxAuras + 1, #bd.testButtons do
		bd.testButtons[i]:Hide()
	end
end

-- Zone-based aura filtering (blacklist/whitelist per zone + unit type)
local filterDefault = {}
function Auras:UpdateFilter(frame)
	if not frame.auras then return end
	local zone = select(2, IsInInstance()) or "none"
	if( zone == "scenario" ) then zone = "party" end
	if( zone == "interior" ) then zone = "neighborhood" end

	-- Zone assignments point at the unified custom filters, only accept a list whose mode matches the assignment slot
	local customs = ShadowUF.db.profile.customFilters or filterDefault
	local white = ShadowUF.db.profile.filters.zonewhite[zone .. frame.unitType]
	local black = ShadowUF.db.profile.filters.zoneblack[zone .. frame.unitType]
	local whiteList = white and customs[white]
	local blackList = black and customs[black]
	frame.auras.whitelist = (whiteList and whiteList.mode ~= "exclude") and whiteList.spells or filterDefault
	frame.auras.blacklist = (blackList and blackList.mode == "exclude") and blackList.spells or filterDefault

	-- Push the zone filters onto the containers as candidate filters
	if( hasContainers ) then
		self:UpdateContainerCandidateFilters(frame)
	end
end



-- 12.0: categorizeAura function removed - filtering is now done via API filters directly

local function renderAura(parent, frame, type, config, displayConfig, index, filter, isFriendly, curable, name, texture, count, auraType, durationObject, caster, isRemovable, nameplateShowPersonal, spellID, canApplyAura, isPlayerAura, auraInstanceID)

	-- Create any buttons we need
	frame.totalAuras = frame.totalAuras + 1
	if( #(frame.buttons) < frame.totalAuras ) then
		-- Get the correct config for this frame
		local unitConfig = ShadowUF.db.profile.units[frame.parent.unitType]
		local auraConfig = unitConfig.auras[frame.type]
		local frameIndex = frame.frameIndex or 1
		local frameConfig = auraConfig and auraConfig[frameIndex] or config
		updateButton(frame.totalAuras, frame, frameConfig)
	end

	-- Show debuff border, or a special colored border if it's stealable
	local button = frame.buttons[frame.totalAuras]
	if( isRemovable and not config.disableRemovableColor ) then
		button.border:SetVertexColor(ShadowUF.db.profile.auraColors.removable.r, ShadowUF.db.profile.auraColors.removable.g, ShadowUF.db.profile.auraColors.removable.b)
	else
		local curve = C_UnitAuras.GetAuraDispelTypeColor and C_CurveUtil and Auras:GetDispelColorCurve(type)
		local color
		if( curve ) then
			-- Errors while auras are secret (RequiresUnitAuraAccess)
			local okColor, result = pcall(C_UnitAuras.GetAuraDispelTypeColor, frame.parent.unit, auraInstanceID, curve)
			color = okColor and result or nil
		end
		if( color ) then
			button.border:SetVertexColorFromBoolean(true, color, color)
		elseif( type == "buffs" ) then
			button.border:SetVertexColor(0.6, 0.6, 0.6)
		else
			button.border:SetVertexColor(0.8, 0, 0)
		end
	end

	-- Show the cooldown ring
	-- 12.0: Simplified - always show timers if enabled (ALL) or for player auras (PLAYER)
	if( not ShadowUF.db.profile.auras.disableCooldown and durationObject and ( config.timers.ALL or ( isPlayerAura and config.timers.PLAYER ) ) ) then
		-- Requires unit aura access, errors while auras are secret
		local okDuration, durationInfo = pcall(C_UnitAuras.GetAuraDuration, frame.parent.unit, auraInstanceID)
		if( okDuration and durationInfo ) then
			button.cooldown:SetCooldownFromDurationObject(durationInfo)
			button.cooldown:Show()
		else
			button.cooldown:Hide()
		end
	else
		button.cooldown:Hide()
	end

	-- Size it
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)

	-- Scale player auras if enlarge.PLAYER is enabled
	if isPlayerAura and config.enlarge and config.enlarge.PLAYER then
		button.isSelfScaled = true
		button:SetScale(config.selfScale or 1.30)
	else
		button.isSelfScaled = nil
		button:SetScale(1)
	end

	-- Stack + icon + show!
	button.auraID = index
	button.auraInstanceID = auraInstanceID
	button.filter = filter
	button.unit = frame.parent.unit
	button.icon:SetTexture(texture)
	
	-- Stack count
	if( button.stack ) then
		-- Errors while auras are secret (RequiresUnitAuraAccess)
		-- Never boolean-test countText, it can be a secret string (SetText takes secrets, Lua truth tests don't)
		local okCount, countText = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, frame.parent.unit, auraInstanceID, 2)
		if( okCount ) then
			button.stack:SetText(countText)
		else
			button.stack:SetText("")
		end
		button.stack:Show()
	end
	
	button:Show()
end


-- Generate test auras for config mode preview
-- One test texture per section so the batches are visually distinct
local configTestTextures = {
	buffs = {"Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Spell_Nature_Regeneration", "Interface\\Icons\\Spell_Holy_FlashHeal", "Interface\\Icons\\Spell_Nature_LightningShield", "Interface\\Icons\\Spell_Holy_DevotionAura"},
	debuffs = {"Interface\\Icons\\Ability_DualWield", "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Ability_Rogue_Rupture", "Interface\\Icons\\Spell_Fire_Immolation", "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", "Interface\\Icons\\Spell_Nature_CorrosiveBreath"},
}

local function scanConfigMode(parent, frame, type, config, displayConfig, filter)
	local totalBudget = config.perRow * config.maxRows
	local isBuff = (type == "buffs")
	local textures = configTestTextures[type] or configTestTextures.buffs

	-- Mirror the live container, one batch of test icons per section with the section's size and cap (sorting aside, the data is fake anyway)
	-- Enlarge is covered too, buildSections encodes it as its own section
	local sections = buildSections(type, config)
	local sectionCount = #sections
	local baseShare = math.max(1, math.floor(totalBudget / sectionCount))

	local i = 0
	for sectionIndex, section in ipairs(sections) do
		local share = (sectionIndex == sectionCount) and (totalBudget - baseShare * (sectionCount - 1)) or baseShare
		if( section.maxCount and section.maxCount > 0 and share > section.maxCount ) then
			share = section.maxCount
		end
		local scale = section.size / config.size
		local texture = textures[((sectionIndex - 1) % #textures) + 1]

		for _ = 1, share do
			i = i + 1

			-- Create any buttons we need
			frame.totalAuras = frame.totalAuras + 1
			if( #(frame.buttons) < frame.totalAuras ) then
				updateButton(frame.totalAuras, frame, config)
			end

			local button = frame.buttons[frame.totalAuras]

			-- Fake data does not change, restyle only when the config generation moved
			if( button.configStamp ~= Auras.configStyleGeneration ) then
				button.configStamp = Auras.configStyleGeneration

				local mod = i % 5
				local auraType = mod == 0 and "Magic" or mod == 1 and "Curse" or mod == 2 and "Poison" or mod == 3 and "Disease" or ""
				local count = i % 3 == 0 and math.random(1, 5) or 0
				local isPlayerAura = i % 2 == 0
				local isRemovable = (type == "debuffs" and i % 3 == 0) or (type == "buffs" and i % 4 == 0)

				-- Set border color based on aura type
				if( isRemovable and not isBuff and not config.disableRemovableColor ) then
					button.border:SetVertexColor(ShadowUF.db.profile.auraColors.removable.r, ShadowUF.db.profile.auraColors.removable.g, ShadowUF.db.profile.auraColors.removable.b)
				elseif( auraType == "Magic" ) then
					button.border:SetVertexColor(0.2, 0.6, 1)
				elseif( auraType == "Curse" ) then
					button.border:SetVertexColor(0.6, 0, 1)
				elseif( auraType == "Disease" ) then
					button.border:SetVertexColor(0.6, 0.4, 0)
				elseif( auraType == "Poison" ) then
					button.border:SetVertexColor(0, 0.6, 0)
				elseif( isBuff ) then
					button.border:SetVertexColor(0.6, 0.6, 0.6)
				else
					button.border:SetVertexColor(0.8, 0, 0)
				end

				-- Show cooldown for test
				if( not ShadowUF.db.profile.auras.disableCooldown and ( config.timers.ALL or ( isPlayerAura and config.timers.PLAYER ) ) ) then
					local duration = 300
					local startTime = GetTime() - (i * 20)
					button.cooldown:SetCooldown(startTime, duration)
					button.cooldown:Show()
				else
					button.cooldown:Hide()
				end

				-- Size it (base size, the section size comes from the scale)
				button:SetHeight(config.size)
				button:SetWidth(config.size)
				button.border:SetHeight(config.size + 1)
				button.border:SetWidth(config.size + 1)

				button:SetScale(scale)
				button.isSelfScaled = scale ~= 1 and true or nil

				-- Set button properties
				button.auraID = i
				button.auraInstanceID = i
				button.filter = filter
				button.unit = frame.parent.unit
				button.icon:SetTexture(texture)

				-- Stack count
				if( button.stack ) then
					button.stack:SetText(count > 0 and count or "")
					button.stack:Show()
				end
			end

			button:Show()

			if( frame.totalAuras >= frame.maxAuras ) then break end
		end
		if( frame.totalAuras >= frame.maxAuras ) then break end
	end

	for i=frame.totalAuras + 1, #(frame.buttons) do frame.buttons[i]:Hide() end
end

-- Scan for auras
-- Helper: process a single auraData and call renderAura
-- Live scanning is gone (containers drive the real display), these shims only feed the config-mode placeholder renderer
local function scan(parent, frame, type, config, displayConfig, filter)
	if( frame.totalAuras >= frame.maxAuras or not config.enabled ) then return end

	if( frame.parent.configMode ) then
		return scanConfigMode(parent, frame, type, config, displayConfig, filter)
	end
end

local function scanBlizzard(parent, frame, type, config, displayConfig)
	if( frame.totalAuras >= frame.maxAuras or not config.enabled ) then return end

	if( frame.parent.configMode ) then
		local baseFilter = (type == "buffs") and "HELPFUL" or "HARMFUL"
		return scanConfigMode(parent, frame, type, config, displayConfig, baseFilter)
	end
end

-- Child takes over the parent's own position
local function anchorChildToBase(config, group, childGroup)
	local position = positionData[getPositionKey(config)]
	local growH = config.growH or "RIGHT"
	local growV = config.growV or "BOTTOM"
	local inset = (config.anchorPoint == "FREE") and 0 or ShadowUF.db.profile.backdrop.inset
	local point, relativePoint = ShadowUF.Layout:GetAuraPoint(config.anchorPoint, growH, growV)
	childGroup.buttons[1]:ClearAllPoints()
	childGroup.buttons[1]:SetPoint(point, group.anchorTo, relativePoint, config.x + (position.xMod * inset), config.y + (position.yMod * inset))
end

local function anchorGroupToGroup(frame, config, group, childConfig, childGroup)
	if( not childGroup.buttons[1] ) then return end

	if( group.totalAuras == 0 ) then
		return anchorChildToBase(config, group, childGroup)
	end

	-- IsShown, not IsVisible: config mode computes this while the frame itself is still hidden
	local anchorTo
	for i=#(group.buttons), 1, -1 do
		local button = group.buttons[i]
		if( button.isAuraAnchor and button:IsShown() ) then
			anchorTo = button
			break
		end
	end

	-- Anchoring to nil would silently leave the whole child group unpositioned
	if( not anchorTo ) then
		return anchorChildToBase(config, group, childGroup)
	end

	local position = positionData[getPositionKey(childConfig, childGroup.forcedGrowH, childGroup.forcedGrowV)]
	position.column(childGroup.buttons[1], anchorTo, 2)
end

Auras.anchorGroupToGroup = anchorGroupToGroup

-- Do an update and figure out what we need to scan
-- Support multiple frames per type
function Auras:Update(frame)
	-- Containers self-refresh on UNIT_AURA, config mode falls through to the legacy pipeline for placeholder rendering
	if( hasContainers ) then
		if( frame.configMode ) then
			self:SetContainersEnabled(frame, false)
		else
			return self:UpdateContainers(frame)
		end
	end

	local config = ShadowUF.db.profile.units[frame.unitType].auras

	-- Pair members need a full reposition in config mode, their legacy buttons are created lazily and only a layout pass gives button 1 a base anchor otherwise
	local pairMembers
	if( frame.configMode and frame.auras.anchorPairs ) then
		for i = 1, 6 do
			local pair = frame.auras.anchorPairs[i]
			if( pair ) then
				pairMembers = pairMembers or {}
				pairMembers[pair.parent] = true
				pairMembers[pair.child] = true
			end
		end
	end

	-- Iterate over all possible aura frames
	for _, auraType in ipairs(AURA_TYPES) do
		local typeConfig = config[auraType]
		if( typeConfig ) then
			for i = 1, 6 do
				local frameConfig = typeConfig[i]
				local groupKey = auraType .. i
				local group = frame.auras[groupKey]

				if( group and frameConfig and frameConfig.enabled and not group.skipScan ) then
					group.totalAuras = (frameConfig.temporary and frame.unit == "player") and group.temporaryEnchants or 0

					local filterValue = frameConfig.filter or "ALL"
					local ok, err

					if filterValue == "BLIZZARD" then
						ok, err = pcall(scanBlizzard, frame.auras, group, auraType, frameConfig, frameConfig)
					else
						local baseFilter = auraType == "buffs" and "HELPFUL" or "HARMFUL"
						local effectiveFilter = baseFilter
						if filterValue ~= "ALL" then
							effectiveFilter = baseFilter .. "|" .. filterValue
						end
						ok, err = pcall(scan, frame.auras, group, auraType, frameConfig, frameConfig, effectiveFilter)
					end
					if not ok and not group.hasErrored then
						ShadowUF:Print("Error scanning " .. groupKey .. " (logged once): " .. tostring(err))
						group.hasErrored = true
					end

					-- Reposition: needed for enlarged auras, center growth, sections, or pair members in config mode
					-- Pair members only need it once to give lazily created buttons their base anchor, the layout reset clears the flag
					local needsPairBase = pairMembers and pairMembers[group] and not group.configPairRepositioned
					if( group.totalAuras > 0 and ((frameConfig.enlarge and frameConfig.enlarge.PLAYER) or frameConfig.growH == "CENTER" or (frameConfig.sections and #frameConfig.sections > 0) or needsPairBase) ) then
						positionAllButtons(group, frameConfig)
						if( pairMembers and pairMembers[group] ) then
							group.configPairRepositioned = true
						end
					end
				end
			end
		end
	end

	-- Apply anchor-to-anchor positioning for each configured pair
	if( frame.auras.anchorPairs ) then
		for i = 1, 6 do
			local pair = frame.auras.anchorPairs[i]
			if( pair ) then
				if( pair.sequential ) then
					-- Sequential mode: scan child auras into parent group (continuing after parent's auras)
					local childAuraType = pair.child.auraType
					local filterValue = pair.childConfig.filter or "ALL"
					local ok, err

					if filterValue == "BLIZZARD" then
						ok, err = pcall(scanBlizzard, frame.auras, pair.parent, childAuraType, pair.childConfig, pair.parentConfig)
					else
						local baseFilter = childAuraType == "buffs" and "HELPFUL" or "HARMFUL"
						local effectiveFilter = filterValue ~= "ALL" and (baseFilter .. "|" .. filterValue) or baseFilter
						ok, err = pcall(scan, frame.auras, pair.parent, childAuraType, pair.childConfig, pair.parentConfig, effectiveFilter)
					end
					if not ok and not pair.parent.hasErrored then
						ShadowUF:Print("Error scanning sequential auras (logged once): " .. tostring(err))
						pair.parent.hasErrored = true
					end

					-- Reposition: same as earlier
					if( pair.parent.totalAuras > 0 and ((pair.parentConfig.enlarge and pair.parentConfig.enlarge.PLAYER) or pair.parentConfig.growH == "CENTER" or (pair.parentConfig.sections and #pair.parentConfig.sections > 0)) ) then
						positionAllButtons(pair.parent, pair.parentConfig)
					end

					-- Hide unused child group buttons
					for j = 1, #(pair.child.buttons) do pair.child.buttons[j]:Hide() end
				elseif( pair.parent and pair.child ) then
					-- Column mode: anchor child group below/after parent group
					anchorGroupToGroup(frame, pair.parentConfig, pair.parent, pair.childConfig, pair.child)
				end
			end
		end
	end
	
	-- Update Boss Debuffs
	self:UpdateBossDebuffs(frame)
end
