local Highlight = {}
local goldColor, mouseColor = {r = 0.75, g = 0.75, b = 0.35}, {r = 0.75, g = 0.75, b = 0.50}
local rareColor, eliteColor = {r = 0, g = 0.63, b = 1}, {r = 1, g = 0.81, b = 0}

ShadowUF:RegisterModule(Highlight, "highlight", ShadowUF.L["Highlight"])

-- Four AuraSlots (one per border edge) on the same filter track the top dispellable debuff, Blizzard colors each edge by dispel type and shows/hides them together
-- Replaces the legacy scan, which errors in combat
-- Independent from the legacy threat/mouseover highlight (both can show at once)
local function containersAvailable()
	local auras = ShadowUF.modules.auras
	return auras and auras.hasContainers
end

local pendingDispelSlots = {}
local dispelRegenWatcher
local function queueDispelSlots(frame)
	pendingDispelSlots[frame] = true
	if( not dispelRegenWatcher ) then
		dispelRegenWatcher = CreateFrame("Frame")
		dispelRegenWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		dispelRegenWatcher:SetScript("OnEvent", function()
			for pendingFrame in pairs(pendingDispelSlots) do
				pendingDispelSlots[pendingFrame] = nil
				Highlight:UpdateDispelSlots(pendingFrame)
			end
		end)
	end
end

-- Geometry/texcoords mirror the legacy edge textures built in OnEnable
local HIGHLIGHT_EDGES = {
	top = { coords = {0.3125, 0.625, 0, 0.3125}, horizontal = true,
		anchor = function(button, frame, inset, size)
			button:SetPoint("TOPLEFT", frame, inset, -inset)
			button:SetPoint("TOPRIGHT", frame, -inset, inset)
			button:SetHeight(size)
		end },
	left = { coords = {0, 0.3125, 0.3125, 0.625}, horizontal = false,
		anchor = function(button, frame, inset, size)
			button:SetPoint("TOPLEFT", frame, inset, -inset)
			button:SetPoint("BOTTOMLEFT", frame, -inset, inset)
			button:SetWidth(size)
		end },
	right = { coords = {0.625, 0.93, 0.3125, 0.625}, horizontal = false,
		anchor = function(button, frame, inset, size)
			button:SetPoint("TOPRIGHT", frame, -inset, -inset)
			button:SetPoint("BOTTOMRIGHT", frame, 0, inset)
			button:SetWidth(size)
		end },
	bottom = { coords = {0.3125, 0.625, 0.625, 0.93}, horizontal = true,
		anchor = function(button, frame, inset, size)
			button:SetPoint("BOTTOMLEFT", frame, inset, inset)
			button:SetPoint("BOTTOMRIGHT", frame, -inset, inset)
			button:SetHeight(size)
		end },
}

local function getDispelFilters(value)
	local healthMod = ShadowUF.modules.healthBar
	return healthMod and healthMod.GetDispelFilters and healthMod.GetDispelFilters(value)
end

-- Neither side applies on units we can neither help nor harm (cross-faction warmode off), mute via never-matching candidates
local MUTE_CANDIDATES = { includeDispelTypes = {} }

local function createDispelSlots(frame, dispelFilter)
	if( frame.highlight.dispelSlots ) then return true end
	-- AuraContainer creation is a Lua error in combat, retry after regen
	if( InCombatLockdown() ) then
		queueDispelSlots(frame)
		return false
	end

	local config = ShadowUF.db.profile.units[frame.unitType].highlight
	local inset = ShadowUF.db.profile.backdrop.inset
	local alpha = config.alpha or 1

	pcall(function()
		-- Parent to the unit frame, NOT frame.highlight, the legacy highlight hides itself whenever it has nothing to show and that would hide us too
		local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
		container:SetPoint("TOPLEFT", frame)
		container:SetSize(1, 1)

		local slotButtons, overlays = {}, {}
		for edge, info in pairs(HIGHLIGHT_EDGES) do
			local slotButton = container:AddAuraSlot("dispel-" .. edge, dispelFilter, {
				initializeFrame = function(button)
					-- Anchoring must happen here, after creation the button is forbidden whenever auras are secret (M+ reload included)
					button:ClearAllPoints()
					info.anchor(button, frame, inset, config.size)
					button:SetFrameLevel(frame.highlight:GetFrameLevel() + 1)

					local overlay = button:CreateTexture(nil, "OVERLAY")
					overlay:SetAllPoints(button)
					overlay:SetBlendMode("ADD")
					overlay:SetTexture("Interface\\AddOns\\ShadowedUnitFrames\\media\\textures\\highlight")
					overlay:SetTexCoord(info.coords[1], info.coords[2], info.coords[3], info.coords[4])
					overlay:SetHorizTile(false)
					overlay:SetAlpha(alpha)
					overlays[edge] = overlay
					-- PreserveAsset tints our overlay texture by dispel type
					pcall(button.SetAuraBorder, button, overlay, { style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3, showWhenHarmful = true, showWhenHelpful = true, customDispelColorMap = ShadowUF.modules.auras.GetDispelColorMap and ShadowUF.modules.auras:GetDispelColorMap() or nil })
					button:SetMouseMotionEnabled(false)
				end,
			})
			slotButtons[edge] = slotButton
		end

		frame.highlight.dispelSlots = container
		frame.highlight.dispelSlotFilter = dispelFilter
		frame.highlight.dispelSlotButtons = slotButtons
		frame.highlight.dispelOverlays = overlays
		frame.highlight.dispelColorsKey = ShadowUF.modules.auras.GetDispelColorsKey and ShadowUF.modules.auras:GetDispelColorsKey() or ""
	end)
	return frame.highlight.dispelSlots ~= nil
end

-- Geometry/alpha are frozen at creation, reapply when the config changes
-- AuraButtons are forbidden while auras are secret (any restriction, not just combat lockdown)
local function refreshDispelSlots(frame)
	local auras = ShadowUF.modules.auras
	if( not frame.highlight.dispelSlotButtons or InCombatLockdown() or (auras and auras.AurasAreSecret and auras.AurasAreSecret()) ) then return end

	local config = ShadowUF.db.profile.units[frame.unitType].highlight
	local inset = ShadowUF.db.profile.backdrop.inset

	for edge, info in pairs(HIGHLIGHT_EDGES) do
		local button = frame.highlight.dispelSlotButtons[edge]
		if( button ) then
			button:ClearAllPoints()
			info.anchor(button, frame, inset, config.size)
		end
		local overlay = frame.highlight.dispelOverlays and frame.highlight.dispelOverlays[edge]
		if( overlay ) then
			overlay:SetAlpha(config.alpha or 1)
		end
	end
end

function Highlight:UpdateDispelSlots(frame)
	local filters = getDispelFilters(ShadowUF.db.profile.units[frame.unitType].highlight.debuff)
	if( not filters ) then
		local container = frame.highlight.dispelSlots
		if( container ) then
			container:SetEnabled(false)
			if( not InCombatLockdown() ) then container:Hide() end
		end
		return
	end

	-- Border colors are frozen at creation, a palette change retires the slots so they get rebuilt with the new colors (out of restrictions only)
	local auras = ShadowUF.modules.auras
	local colorsKey = auras.GetDispelColorsKey and auras:GetDispelColorsKey() or ""
	if( frame.highlight.dispelSlots and frame.highlight.dispelColorsKey ~= colorsKey
		and not InCombatLockdown() and not (auras.AurasAreSecret and auras.AurasAreSecret()) ) then
		frame.highlight.dispelSlots:SetEnabled(false)
		frame.highlight.dispelSlots:Hide()
		frame.highlight.dispelSlots = nil
		frame.highlight.dispelSlotButtons = nil
		frame.highlight.dispelOverlays = nil
		-- The fresh slots start on the assist filter with no candidates, drop the stale mirrors
		frame.highlight.dispelSlotFilter = nil
		frame.highlight.dispelSlotMuted = nil
	end

	if( not frame.highlight.dispelSlots and not createDispelSlots(frame, filters.assist) ) then return end

	local container = frame.highlight.dispelSlots
	local inCombat = InCombatLockdown()

	-- Pick the side matching the unit's reaction, mute when neither side applies
	local dispelFilter = frame.highlight.dispelSlotFilter or filters.assist
	local muted = frame.highlight.dispelSlotMuted
	if( frame.unit and not frame.configMode ) then
		local state = ShadowUF.GetUnitReactionState(frame.unit)
		if( state == "assist" ) then
			dispelFilter = filters.assist
			muted = false
		elseif( state == "attack" ) then
			dispelFilter = filters.noassist
			muted = false
		else
			muted = true
		end
	end

	-- Slot filter strings and candidate filters are runtime-mutable, mode and reaction switches apply live
	if( frame.highlight.dispelSlotFilter ~= dispelFilter ) then
		local switched = true
		for edge in pairs(HIGHLIGHT_EDGES) do
			switched = pcall(container.SetAuraSlotFilterString, container, "dispel-" .. edge, dispelFilter) and switched
		end
		if( switched ) then
			frame.highlight.dispelSlotFilter = dispelFilter
		end
	end
	if( muted ~= frame.highlight.dispelSlotMuted ) then
		local switched = true
		for edge in pairs(HIGHLIGHT_EDGES) do
			switched = pcall(container.SetAuraSlotCandidateFilters, container, "dispel-" .. edge, muted and MUTE_CANDIDATES or nil) and switched
		end
		if( switched ) then
			frame.highlight.dispelSlotMuted = muted
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
		frame.highlight:SetFrameLevel(frame.topFrameLevel + 5)
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

	-- UnitIsUnit returns secret booleans for compound tokens on restricted maps, skip them :[
	if( ShadowUF.db.profile.units[frame.unitType].highlight.attention and not string.find(frame.unitType, "target") and frame.unitType ~= "focus" ) then
		frame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "UpdateAttention")
		frame:RegisterNormalEvent("PLAYER_FOCUS_CHANGED", self, "UpdateAttention")
		frame:RegisterUpdateFunc(self, "UpdateAttention")
	end

	local debuffMode = ShadowUF.db.profile.units[frame.unitType].highlight.debuff
	if( containersAvailable() ) then
		if( getDispelFilters(debuffMode) ) then
			-- The slots self-update, we only track unit identity
			-- UNIT_FACTION re-runs the friendliness gate (MC, duels)
			refreshDispelSlots(frame)
			frame:RegisterUpdateFunc(self, "UpdateDispelSlots")
			frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateDispelSlots")
		elseif( frame.highlight.dispelSlots ) then
			-- Option turned off, silence the existing slot container
			frame.highlight.dispelSlots:SetEnabled(false)
			if( not InCombatLockdown() ) then frame.highlight.dispelSlots:Hide() end
		end
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

	frame.highlight.hasThreat = nil
	frame.highlight.hasAttention = nil
	frame.highlight.hasMouseover = nil

	if( frame.highlight.dispelSlots ) then
		frame.highlight.dispelSlots:SetEnabled(false)
		frame.highlight.dispelSlots:Hide()
	end

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

	if frame.highlight.hasThreat then
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
		local r, g, b = color.r, color.g, color.b
		local a = ShadowUF.db.profile.units[frame.unitType].highlight.alpha

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


