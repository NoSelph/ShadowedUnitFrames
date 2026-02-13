local Auras = {}
local SML = LibStub("LibSharedMedia-3.0")
local playerUnits = {player = true, vehicle = true, pet = true}
local mainHand, offHand, tempEnchantScan = {time = 0}, {time = 0}
local canCure = ShadowUF.Units.canCure
ShadowUF:RegisterModule(Auras, "auras", ShadowUF.L["Auras"])

function Auras:OnEnable(frame)
	frame.auras = frame.auras or {}

	frame:RegisterNormalEvent("PLAYER_ENTERING_WORLD", self, "Update")
	frame:RegisterUnitEvent("UNIT_AURA", self, "Update")
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
	
	-- Add a "Cap" point to catch any IDs higher than Poison (e.g. Bleeds if they are > 4)
	-- This forces them to fallback to Base Color (Red for Debuffs) instead of clamping to Green
	local capID = math.max(noneID, magicID, curseID, diseaseID, poisonID) + 1
	curve:AddPoint(capID, CreateColor(baseR, baseG, baseB))
	curve:AddPoint(255, CreateColor(baseR, baseG, baseB)) -- Safety max
	
    -- Ensure the curve covers the range
    if( curve.SetMinMaxValues ) then
	    curve:SetMinMaxValues(0, 255)
    end
	
	self[cacheKey] = curve
	return curve
end

function Auras:OnDisable(frame)
	frame:UnregisterAll(self)
	self:ClearBossDebuffs(frame)
end

-- Aura positioning code
-- Definitely some of the more unusual code I've done, not sure I really like this method
-- but it does allow more flexibility with how things are anchored without me having to hardcode the 10 different growth methods
local function load(text)
	local result, err = loadstring(text)
	if( err ) then
		error(err, 3)
		return nil
	end

	return result()
end

local positionData = setmetatable({}, {
	__index = function(tbl, index)
		local data = {}
		local columnGrowth = ShadowUF.Layout:GetColumnGrowth(index)
		local auraGrowth = ShadowUF.Layout:GetAuraGrowth(index)
		data.xMod = (columnGrowth == "RIGHT" or auraGrowth == "RIGHT") and 1 or -1
		data.yMod = (columnGrowth ~= "TOP" and auraGrowth ~= "TOP") and -1 or 1

		local auraX, colX, auraY, colY, xOffset, yOffset, initialXOffset, initialYOffset = 0, 0, 0, 0, "", "", "", ""
		if( columnGrowth == "LEFT" or columnGrowth == "RIGHT" ) then
			colX = 1
			xOffset = " + offset"
			initialXOffset = string.format(" + (%d * offset)", data.xMod)
			auraY = 3
			data.isSideGrowth = true
		elseif( columnGrowth == "TOP" or columnGrowth == "BOTTOM" ) then
			colY = 2
			yOffset = " + offset"
			initialYOffset = string.format(" + (%d * offset)", data.yMod)
			auraX = 2
		end

		data.initialAnchor = load(string.format([[return function(button, offset)
			button:ClearAllPoints()
			button:SetPoint(button.point, button.anchorTo, button.relativePoint, button.xOffset%s, button.yOffset%s)
			button.anchorOffset = offset
		end]], initialXOffset, initialYOffset))
		data.column = load(string.format([[return function(button, positionTo, offset)
			button:ClearAllPoints()
			button:SetPoint("%s", positionTo, "%s", %d * (%d%s), %d * (%d%s)) end
		]], ShadowUF.Layout:ReverseDirection(columnGrowth), columnGrowth, data.xMod, colX, xOffset, data.yMod, colY, yOffset))
		data.aura = load(string.format([[return function(button, positionTo)
			button:ClearAllPoints()
			button:SetPoint("%s", positionTo, "%s", %d, %d) end
		]], ShadowUF.Layout:ReverseDirection(auraGrowth), auraGrowth, data.xMod * auraX, data.yMod * auraY))

		tbl[index] = data
		return tbl[index]
	end,
})

local function positionButton(id,  group, config)
	local position = positionData[group.forcedAnchorPoint or config.anchorPoint]
	local button = group.buttons[id]
	button.isAuraAnchor = nil

	-- Alright, in order to find out where an aura group is going to be anchored to certain buttons need
	-- to be flagged as suitable anchors visually, this speeds it up because this data is cached and doesn't
	-- have to be recalculated unless auras are specifically changed
	if( id > 1 ) then
		if( position.isSideGrowth and id <= config.perRow ) then
			button.isAuraAnchor = true
		end

		if( id % config.perRow == 1 or config.perRow == 1 ) then
			position.column(button, group.buttons[id - config.perRow], 0)

			if( not position.isSideGrowth ) then
				button.isAuraAnchor = true
			end
		else
			position.aura(button, group.buttons[id - 1])
		end
	else
		button.isAuraAnchor = true
		button.point = ShadowUF.Layout:GetPoint(config.anchorPoint)
		button.relativePoint = ShadowUF.Layout:GetRelative(config.anchorPoint)
		button.xOffset = config.x + (position.xMod * ShadowUF.db.profile.backdrop.inset)
		button.yOffset = config.y + (position.yMod * ShadowUF.db.profile.backdrop.inset)
		button.anchorTo = group.anchorTo

		position.initialAnchor(button, 0)
	end
end


-- Aura button functions
-- Updates the X seconds left on aura tooltip while it's shown
local function updateTooltip(self)
	if( not GameTooltip:IsForbidden() and GameTooltip:IsOwned(self) ) then
		if( self.filter == "HELPFUL" ) then
			GameTooltip:SetUnitBuff(self.unit, self.auraID, self.filter)
		elseif( self.filter == "HARMFUL" ) then
			GameTooltip:SetUnitDebuff(self.unit, self.auraID, self.filter)
		else
			GameTooltip:SetUnitAura(self.unit, self.auraID, self.filter)
		end
	end
end

local function showTooltip(self)
	if( not ShadowUF.db.profile.locked ) then return end
	if( GameTooltip:IsForbidden() ) then return end
	if( ShadowUF.db.profile.tooltipCombat and InCombatLockdown() ) then return end

	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	if( self.filter == "TEMP" ) then
		GameTooltip:SetInventoryItem("player", self.auraID)
		self:SetScript("OnUpdate", nil)
	else
		if( self.filter == "HELPFUL" ) then
			GameTooltip:SetUnitBuff(self.unit, self.auraID, self.filter)
		elseif( self.filter == "HARMFUL" ) then
			GameTooltip:SetUnitDebuff(self.unit, self.auraID, self.filter)
		else
			GameTooltip:SetUnitAura(self.unit, self.auraID, self.filter)
		end
		
		self:SetScript("OnUpdate", updateTooltip)
	end
end

local function hideTooltip(self)
	self:SetScript("OnUpdate", nil)
	if not GameTooltip:IsForbidden() then
		GameTooltip:Hide()
	end
end

local function cancelAura(self, mouseButton)
	if( mouseButton ~= "RightButton" ) then return end
	if( InCombatLockdown() ) then return end
	if( not self.filter or not self.filter:find("HELPFUL") ) then return end
	if( not self.unit or not UnitIsUnit(self.unit, "player") ) then return end
	
	if( self.auraInstanceID ) then
		local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", self.auraInstanceID)
		if( auraData and auraData.name ) then
			CancelSpellByName(auraData.name)
		end
	end
end

local function updateButton(id, group, config)
	local button = group.buttons[id]
	if( not button ) then
		group.buttons[id] = CreateFrame("Button", nil, group)

		button = group.buttons[id]
		button:SetScript("OnEnter", showTooltip)
		button:SetScript("OnLeave", hideTooltip)
		button:RegisterForClicks("RightButtonUp")

		button.cooldown = CreateFrame("Cooldown", group.parent:GetName() .. "Aura" .. group.type .. id .. "Cooldown", button, "CooldownFrameTemplate")
		button.cooldown:SetAllPoints(button)
		button.cooldown:SetReverse(true)
		button.cooldown:SetDrawEdge(false)
		button.cooldown:SetDrawSwipe(true)
		button.cooldown:SetSwipeColor(0, 0, 0, 0.8)
		button.cooldown:Hide()

		button.stack = button:CreateFontString(nil, "OVERLAY")
		button.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 10, "OUTLINE")
		button.stack:SetShadowColor(0, 0, 0, 1.0)
		button.stack:SetShadowOffset(0.50, -0.50)
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
	-- button.cooldown.noCooldownCount = ShadowUF.db.profile.omnicc
	-- OmniCC support removed / automated by Blizzard text now.
	
	-- If 'blizzardcc' is true ("Disable Blizzard Cooldown Count"), we HIDE valid numbers.
	-- If false, we SHOW valid numbers.
	button.cooldown:SetHideCountdownNumbers(ShadowUF.db.profile.blizzardcc)
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)
	button.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", math.floor((config.size * 0.60) + 0.5), "OUTLINE")

	button:SetScript("OnClick", cancelAura)
	button.parent = group.parent
	button:ClearAllPoints()
	button:Hide()

	-- Position the button quickly
	positionButton(id, group, config)
	
	-- Update Cooldown Text Styling
	Auras:UpdateCooldownText(button)
end

function Auras:UpdateCooldownText(button)
	if( not button or not button.cooldown ) then return end

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
		-- Apply Font Settings
		local fontDetails = ShadowUF.db.profile.font
		local font = SML:Fetch("font", fontDetails.cooldownName or fontDetails.name)
		local size = fontDetails.cooldownSize or fontDetails.size
		local outline = fontDetails.cooldownOutline
		if( outline == nil ) then outline = fontDetails.extra end -- Fallback to general setting if specific not set
		
		text:SetFont(font, size, outline)
		
		-- Apply Color
		local color = fontDetails.cooldownColor
		if( color ) then
			text:SetTextColor(color.r, color.g, color.b, color.a or 1)
		else
			text:SetTextColor(1, 1, 1, 1)
		end
	end
end

-- Let the mover access this for creating aura things
Auras.updateButton = updateButton

-- Create an aura anchor as well as the buttons to contain it
local function updateGroup(self, groupKey, config, reverseConfig)
	self.auras[groupKey] = self.auras[groupKey] or CreateFrame("Frame", nil, self.highFrame)

	local group = self.auras[groupKey]
	group.buttons = group.buttons or {}

	group.maxAuras = config.perRow * config.maxRows
	group.totalAuras = 0
	group.temporaryEnchants = 0
	group.groupKey = groupKey
	group.parent = self
	group.anchorTo = self
	group:SetFrameLevel(self.highFrame:GetFrameLevel() + 1)
	group:Show()

	-- Temp enchants only for player buffs frame 1
	if( self.unit == "player" and groupKey == "buffs1" ) then
		mainHand.time = 0
		offHand.time = 0
		group:SetScript("OnUpdate", config.temporary and tempEnchantScan or nil)
	else
		group:SetScript("OnUpdate", nil)
	end

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
	-- Hide all existing aura buttons first
	if( frame.auras ) then
		for auraType, _ in pairs({buffs = true, debuffs = true}) do
			for i = 1, 4 do
				local groupKey = auraType .. i
				if( frame.auras[groupKey] and frame.auras[groupKey].buttons ) then
					for _, button in pairs(frame.auras[groupKey].buttons) do
						button:Hide()
					end
				end
			end
		end
	end

	if( not frame.visibility.auras ) then return end

	-- Setup enabled aura frames
	for _, auraType in pairs({"buffs", "debuffs"}) do
		local typeConfig = config.auras[auraType]
		if( typeConfig ) then
			for i = 1, 4 do
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
	
	for i = 1, 4 do
		local buffsConfig = config.auras.buffs and config.auras.buffs[i]
		local debuffsConfig = config.auras.debuffs and config.auras.debuffs[i]
		local buffsGroup = frame.auras["buffs" .. i]
		local debuffsGroup = frame.auras["debuffs" .. i]
		
		if( buffsConfig and buffsConfig.enabled and debuffsConfig and debuffsConfig.enabled and buffsGroup and debuffsGroup ) then
			if( buffsConfig.anchorOn ) then
				-- Buffs anchored to Debuffs
				frame.auras.anchorPairs[i] = {
					parent = debuffsGroup,
					child = buffsGroup,
					parentConfig = debuffsConfig,
					childConfig = buffsConfig
				}
				buffsGroup.forcedAnchorPoint = debuffsConfig.anchorPoint
			elseif( debuffsConfig.anchorOn ) then
				-- Debuffs anchored to Buffs
				frame.auras.anchorPairs[i] = {
					parent = buffsGroup,
					child = debuffsGroup,
					parentConfig = buffsConfig,
					childConfig = debuffsConfig
				}
				debuffsGroup.forcedAnchorPoint = buffsConfig.anchorPoint
			end
		end
	end

	self:UpdateFilter(frame)
	
	-- Setup Boss Debuffs if enabled
	if config.auras.bossDebuffs and config.auras.bossDebuffs.enabled then
		self:SetupBossDebuffs(frame, config.auras.bossDebuffs)
	else
		self:ClearBossDebuffs(frame)
	end
end

-- Private Auras (Boss Debuffs) support
-- Current implementation only works with stable unit tokens (player, party, raid)
local AddPrivateAuraAnchor = C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor
local RemovePrivateAuraAnchor = C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor
local privateAuraUnits = {
	player = true,
	party = true,
	raid = true,
}

function Auras:ClearBossDebuffs(frame)
	if not frame.bossDebuffs then return end

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
	end

	local container = frame.bossDebuffs.container
	local perRow = config.perRow or 3
	local maxRows = config.maxRows or 1
	local maxAuras = perRow * maxRows
	local iconSize = config.size or 32
	local spacing = 2

	-- Calculate total size
	local totalWidth = (iconSize * perRow) + (spacing * (perRow - 1))
	local totalHeight = (iconSize * maxRows) + (spacing * (maxRows - 1))

	container:SetSize(totalWidth, totalHeight)
	container:ClearAllPoints()

	-- Position based on anchorPoint
	local point = ShadowUF.Layout:GetPoint(config.anchorPoint)
	local relativePoint = ShadowUF.Layout:GetRelative(config.anchorPoint)
	container:SetPoint(point, frame, relativePoint, config.x or 0, config.y or 0)
	container:SetFrameLevel(frame.highFrame:GetFrameLevel() + 2)
	container:Show()

	-- Store config for update
	frame.bossDebuffs.config = config
	frame.bossDebuffs.maxAuras = maxAuras
	frame.bossDebuffs.perRow = perRow
	frame.bossDebuffs.iconSize = iconSize
	frame.bossDebuffs.spacing = spacing

	-- Force update
	frame.bossDebuffs.unit = nil
	Auras:UpdateBossDebuffs(frame)
end

function Auras:UpdateBossDebuffs(frame)
	if not frame.bossDebuffs or not frame.bossDebuffs.container then return end

	if not privateAuraUnits[frame.unitType] then return end

	-- Config mode: show placeholders (same pattern as scanConfigMode for regular auras)
	if frame.configMode then
		self:ShowBossDebuffsPlaceholders(frame)
		return
	end

	-- Hide placeholders when leaving config mode
	if frame.bossDebuffs.testButtons then
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
	"Interface\\Icons\\Spell_Shadow_CurseOfTongues",
	"Interface\\Icons\\Spell_Fire_Incinerate",
	"Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
	"Interface\\Icons\\Spell_Nature_Earthquake",
	"Interface\\Icons\\Spell_Fire_FelFlameRing",
}

function Auras:ShowBossDebuffsPlaceholders(frame)
	local bd = frame.bossDebuffs
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

			button.cooldown = CreateFrame("Cooldown", (frame:GetName() or "SUFBossAura") .. "BossAura" .. i .. "Cooldown", button, "CooldownFrameTemplate")
			button.cooldown:SetAllPoints(button)
			button.cooldown:SetReverse(true)
			button.cooldown:SetDrawEdge(false)
			button.cooldown:SetDrawSwipe(true)
			button.cooldown:SetSwipeColor(0, 0, 0, 0.8)
			button.cooldown:Hide()

			button.stack = button:CreateFontString(nil, "OVERLAY")
			button.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", 10, "OUTLINE")
			button.stack:SetShadowColor(0, 0, 0, 1.0)
			button.stack:SetShadowOffset(0.50, -0.50)
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
		button.stack:SetFont("Interface\\AddOns\\ShadowedUnitFrames\\media\\fonts\\Myriad Condensed Web.ttf", math.floor((iconSize * 0.60) + 0.5), "OUTLINE")
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

-- Temporary enchant support
local timeElapsed = 0
local function updateTemporaryEnchant(frame, slot, tempData, hasEnchant, enchantId, timeLeft, charges)
	-- If there's less than a 750 millisecond differences in the times, we don't need to bother updating.
	-- Any sort of enchant takes more than 0.750 seconds to cast so it's impossible for the user to have two
	-- temporary enchants with that little difference, as totems don't really give pulsing auras anymore.
	charges = charges or 0
	if( tempData.has and tempData.enchantId == enchantId and ( timeLeft < tempData.time and ( tempData.time - timeLeft ) < 750 ) ) then return false end

	-- Some trickys magic, we can't get the start time of temporary enchants easily.
	-- So will save the first time we find when a new enchant is added
	if( timeLeft > tempData.time or not tempData.has ) then
		tempData.startTime = GetTime()
	end

	tempData.has = hasEnchant
	tempData.time = timeLeft
	tempData.charges = charges
	tempData.enchantId = enchantId

	local config = ShadowUF.db.profile.units[frame.parent.unitType].auras[frame.type]

	-- Create any buttons we need
	if( #(frame.buttons) < frame.temporaryEnchants ) then
		updateButton(frame.temporaryEnchants, frame, config)
	end

	local button = frame.buttons[frame.temporaryEnchants]

	-- Purple border
	button.border:SetVertexColor(0.50, 0, 0.50)

	-- Show the cooldown ring
	if( not ShadowUF.db.profile.auras.disableCooldown ) then
		button.cooldown:SetCooldown(tempData.startTime, timeLeft / 1000)
		button.cooldown:Show()
	end

	-- Size it
	button:SetHeight(config.size)
	button:SetWidth(config.size)
	button.border:SetHeight(config.size + 1)
	button.border:SetWidth(config.size + 1)

	-- Stack + icon + show! Never understood why, auras sometimes return 1 for stack even if they don't stack
	button.auraID = slot
	button.filter = "TEMP"
	button.unit = nil
	button.icon:SetTexture(GetInventoryItemTexture("player", slot))
	button.stack:SetText(charges > 1 and charges or "")
	button:Show()
end

-- Unfortunately, temporary enchants have basically no support beyond hacks. So we will hack!
tempEnchantScan = function(self, elapsed)
	if( self.parent.unit == self.parent.vehicleUnit and self.lastTemporary > 0 ) then
		mainHand.has = false
		offHand.has = false

		self.temporaryEnchants = 0
		self.lastTemporary = 0

		Auras:Update(self.parent)
		return
	end

	timeElapsed = timeElapsed + elapsed
	if( timeElapsed < 0.50 ) then return end
	timeElapsed = timeElapsed - 0.50


	local hasMain, mainTimeLeft, mainCharges, mainEnchantId, hasOff, offTimeLeft, offCharges, offEnchantId = GetWeaponEnchantInfo()
	self.temporaryEnchants = 0

	if( hasMain ) then
		self.temporaryEnchants = self.temporaryEnchants + 1
		updateTemporaryEnchant(self, 16, mainHand, hasMain, mainEnchantId, mainTimeLeft or 0, mainCharges)
		mainHand.time = mainTimeLeft or 0
	end

	mainHand.has = hasMain

	if( hasOff and self.temporaryEnchants < self.maxAuras ) then
		self.temporaryEnchants = self.temporaryEnchants + 1
		updateTemporaryEnchant(self, 17, offHand, hasOff, offEnchantId, offTimeLeft or 0, offCharges)
		offHand.time = offTimeLeft or 0
	end

	offHand.has = hasOff

	-- Update if totals changed
	if( self.lastTemporary ~= self.temporaryEnchants ) then
		self.lastTemporary = self.temporaryEnchants
		Auras:Update(self.parent)
	end
end

-- 12.0: Aura filtering now done via API filters (PLAYER, RAID, etc.) instead of addon-side lists
-- This function is kept as a stub for compatibility with existing calls
function Auras:UpdateFilter(frame)
	-- No-op: filtering handled by C_UnitAuras API
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
	if( isRemovable and not isFriendly and not ShadowUF.db.profile.auras.disableColor ) then
		button.border:SetVertexColor(ShadowUF.db.profile.auraColors.removable.r, ShadowUF.db.profile.auraColors.removable.g, ShadowUF.db.profile.auraColors.removable.b)
	elseif( not ShadowUF.db.profile.auras.disableColor ) then
		-- 12.0: GetAuraDispelTypeColor to color auras.
		if( C_UnitAuras.GetAuraDispelTypeColor and C_CurveUtil ) then
			local curve = Auras:GetDispelColorCurve(type)
			if( curve ) then
				local color = C_UnitAuras.GetAuraDispelTypeColor(frame.parent.unit, auraInstanceID, curve)
				if( color ) then
					button.border:SetVertexColor(color:GetRGB())
				else
					if( type == "buffs" ) then
						button.border:SetVertexColor(0.6, 0.6, 0.6)
					else
						button.border:SetVertexColor(0.8, 0, 0)
					end
				end
			else
				button.border:SetVertexColor(0.8, 0, 0)
			end
		end
	else
		button.border:SetVertexColor(0.60, 0.60, 0.60)
	end

	-- Show the cooldown ring
	-- 12.0: Simplified - always show timers if enabled (ALL) or for player auras (PLAYER)
	if( not ShadowUF.db.profile.auras.disableCooldown and durationObject and ( config.timers.ALL or ( isPlayerAura and config.timers.PLAYER ) ) ) then
		local durationInfo = C_UnitAuras.GetAuraDuration(frame.parent.unit, auraInstanceID)
		if( durationInfo ) then
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
		button:SetScale(config.selfScale or 1.30)
	else
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
		button.stack:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(frame.parent.unit, auraInstanceID, 2))
		button.stack:Show()
	end
	
	button:Show()
end


-- Generate test auras for config mode preview
local function scanConfigMode(parent, frame, type, config, displayConfig, filter)
	local testCount = config.perRow * config.maxRows
	local isBuff = (type == "buffs")
	
	for i = 1, testCount do
		local mod = i % 5
		local auraType = mod == 0 and "Magic" or mod == 1 and "Curse" or mod == 2 and "Poison" or mod == 3 and "Disease" or ""
		
		-- Create test data
		local name = ShadowUF.L["Test Aura"]
		local texture = isBuff and "Interface\\Icons\\Spell_Nature_Rejuvenation" or "Interface\\Icons\\Ability_DualWield"
		local count = i % 3 == 0 and math.random(1, 5) or 0
		local isPlayerAura = i % 2 == 0
		local isRemovable = (type == "debuffs" and i % 3 == 0) or (type == "buffs" and i % 4 == 0)
		local spellID = 1000 + i
		local auraInstanceID = i
		
		-- Create any buttons we need
		frame.totalAuras = frame.totalAuras + 1
		if( #(frame.buttons) < frame.totalAuras ) then
			updateButton(frame.totalAuras, frame, config)
		end
		
		local button = frame.buttons[frame.totalAuras]
		
		-- Set border color based on aura type
		if( not ShadowUF.db.profile.auras.disableColor ) then
			if( isRemovable and not isBuff ) then
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
		else
			button.border:SetVertexColor(0.60, 0.60, 0.60)
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
		
		-- Size it
		button:SetHeight(config.size)
		button:SetWidth(config.size)
		button.border:SetHeight(config.size + 1)
		button.border:SetWidth(config.size + 1)
		
		-- Set button properties
		button.auraID = i
		button.auraInstanceID = auraInstanceID
		button.filter = filter
		button.unit = frame.parent.unit
		button.icon:SetTexture(texture)
		
		-- Stack count
		if( button.stack ) then
			button.stack:SetText(count > 0 and count or "")
			button.stack:Show()
		end
		
		button:Show()
		
		if( frame.totalAuras >= frame.maxAuras ) then break end
	end
	
	for i=frame.totalAuras + 1, #(frame.buttons) do frame.buttons[i]:Hide() end
end

-- Scan for auras
-- Helper: process a single auraData and call renderAura
local function processAura(parent, frame, type, config, displayConfig, filter, unit, isFriendly, curable, index, auraData)
	local name = auraData.name or "Unknown"
	local texture = auraData.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
	local count = auraData.applications
	local durationObject = auraData
	local baseFilter = (type == "debuffs") and "HARMFUL" or "HELPFUL"

	local isPlayerAura = (config.filter == "PLAYER") or
		not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraData.auraInstanceID, baseFilter .. "|PLAYER")

	local isRaid = (config.filter == "RAID") or
		not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraData.auraInstanceID, baseFilter .. "|RAID")

	local isStealable = false
	if( type == "buffs" ) then
		isStealable = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraData.auraInstanceID, "HELPFUL|STEALABLE")
	end

	local canApplyAura = (type == "buffs") and isRaid
	local isRemovable = (type == "debuffs" and isRaid) or (type == "buffs" and isStealable)
	local caster = isPlayerAura and "player" or nil
	local spellID = auraData.spellId or 0
	local auraType = auraData.dispelName

	renderAura(parent, frame, type, config, displayConfig, index, filter, isFriendly, curable, name, texture, count, auraType, durationObject, caster, isRemovable, auraData.nameplateShowPersonal, spellID, canApplyAura, isPlayerAura, auraData.auraInstanceID)
end

local function scan(parent, frame, type, config, displayConfig, filter)
	if( frame.totalAuras >= frame.maxAuras or not config.enabled ) then return end

	-- Config mode: show test auras
	if( frame.parent.configMode ) then
		return scanConfigMode(parent, frame, type, config, displayConfig, filter)
	end

	if not frame.parent.unit then return end
	local unit = frame.parent.unit

	-- UnitIsFriend returns true during a duel, which breaks stealable/curable detection
	local isFriendly = not UnitIsEnemy(unit, "player")
	local curable = (isFriendly and type == "debuffs")

	-- 12.0: All aura APIs use UnitTokenRestrictedForAddOns which blocks compound unit tokens
	-- (focustarget, boss1target, etc.) except "targettarget" which is explicitly exempted.
	-- pcall to silently skip unsupported units instead of throwing errors.
	local ok, slots = pcall(function() return {C_UnitAuras.GetAuraSlots(unit, filter)} end)
	if( not ok ) then
		for i = frame.totalAuras + 1, #(frame.buttons) do frame.buttons[i]:Hide() end
		return
	end

	-- Index 1 is continuation token, slots start at 2
	for i = 2, #slots do
		local index = slots[i]
		local auraData = C_UnitAuras.GetAuraDataBySlot(unit, index)
		if( auraData ) then
			processAura(parent, frame, type, config, displayConfig, filter, unit, isFriendly, curable, i - 1, auraData)
		end
		if( frame.totalAuras >= frame.maxAuras ) then break end
	end

	for i=frame.totalAuras + 1, #(frame.buttons) do frame.buttons[i]:Hide() end
end

Auras.scan = scan

local function anchorGroupToGroup(frame, config, group, childConfig, childGroup)
	-- Child group has nothing in it yet, so don't care
	if( not childGroup.buttons[1] ) then return end

	-- Group we want to anchor to has nothing in it, takeover the postion
	if( group.totalAuras == 0 ) then
		local position = positionData[config.anchorPoint]
		childGroup.buttons[1]:ClearAllPoints()
		childGroup.buttons[1]:SetPoint(ShadowUF.Layout:GetPoint(config.anchorPoint), group.anchorTo, ShadowUF.Layout:GetRelative(config.anchorPoint), config.x + (position.xMod * ShadowUF.db.profile.backdrop.inset), config.y + (position.yMod * ShadowUF.db.profile.backdrop.inset))
		return
	end

	local anchorTo
	for i=#(group.buttons), 1, -1 do
		local button = group.buttons[i]
		if( button.isAuraAnchor and button:IsVisible() ) then
			anchorTo = button
			break
		end
	end

	local position = positionData[childGroup.forcedAnchorPoint or childConfig.anchorPoint]
	if( position.isSideGrowth ) then
		position.aura(childGroup.buttons[1], anchorTo)
	else
		position.column(childGroup.buttons[1], anchorTo, 2)
	end
end

Auras.anchorGroupToGroup = anchorGroupToGroup

-- Do an update and figure out what we need to scan
-- Support multiple frames per type
function Auras:Update(frame)
	local config = ShadowUF.db.profile.units[frame.unitType].auras
	
	-- Iterate over all possible aura frames
	for _, auraType in pairs({"buffs", "debuffs"}) do
		local typeConfig = config[auraType]
		if( typeConfig ) then
			for i = 1, 4 do
				local frameConfig = typeConfig[i]
				local groupKey = auraType .. i
				local group = frame.auras[groupKey]
				
				if( group and frameConfig and frameConfig.enabled ) then
					group.totalAuras = (groupKey == "buffs1") and group.temporaryEnchants or 0
					
					-- Build the filter string based on configuration
					local baseFilter = auraType == "buffs" and "HELPFUL" or "HARMFUL"
					local filterValue = frameConfig.filter or "ALL"
					local effectiveFilter = baseFilter
					
					if filterValue == "PLAYER" then
						effectiveFilter = baseFilter .. "|PLAYER"
					elseif filterValue == "RAID" then
						effectiveFilter = baseFilter .. "|RAID"
					-- "ALL" = just base filter (no additional filtering)
					end
					
					local ok, err = pcall(scan, frame.auras, group, auraType, frameConfig, frameConfig, effectiveFilter)
					if not ok and not group.hasErrored then
						ShadowUF:Print("Error scanning " .. groupKey .. " (logged once): " .. tostring(err))
						group.hasErrored = true
					end
				end
			end
		end
	end
	
	-- Apply anchor-to-anchor positioning for each configured pair
	-- This dynamically anchors the child group to the last visible aura of the parent group
	if( frame.auras.anchorPairs ) then
		for i = 1, 4 do
			local pair = frame.auras.anchorPairs[i]
			if( pair and pair.parent and pair.child ) then
				anchorGroupToGroup(frame, pair.parentConfig, pair.parent, pair.childConfig, pair.child)
			end
		end
	end
	
	-- Update Boss Debuffs
	self:UpdateBossDebuffs(frame)
end
