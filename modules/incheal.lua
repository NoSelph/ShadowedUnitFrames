local IncHeal = {["frameKey"] = "incHeal", ["colorKey"] = "inc", ["frameLevelMod"] = 2}
ShadowUF.IncHeal = IncHeal
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])

local function ensureCropper(bar, parent)
	if( not bar.cropper ) then
		bar.cropper = CreateFrame("Frame", nil, parent)
		bar.cropper:SetClipsChildren(true)
	end
	return bar.cropper
end

function IncHeal:OnEnable(frame)
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)

	-- Create the shared calculator once per frame
	if( not frame.healCalc ) then
		frame.healCalc = CreateUnitHealPredictionCalculator()
		frame.healCalc:SetHealAbsorbMode(1) -- Total: no cross-reduction between heals and heal absorbs
	end

	-- All prediction events — shared calculator populated once per frame via GetTime() guard
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")

	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame[self.frameKey].total = nil
	frame[self.frameKey]:Hide()
	self:CancelSafetyTicker(frame)
end

-- Populate the shared calculator — called once per frame across all 3 modules
function IncHeal:PopulateCalculator(frame)
	local calc = frame.healCalc
	if( not calc ) then return false end

	local now = GetTime()
	if( frame.healCalcTime == now ) then return frame.healCalcValid end

	frame.healCalcTime = now
	frame.healCalcValid = false

	local ok = pcall(UnitGetDetailedHealPrediction, frame.unit, "player", calc)
	if( not ok ) then
		calc:ResetPredictedValues()
		return false
	end

	frame.healCalcValid = true
	return true
end

-- Safety ticker: forces periodic recalculation while any prediction bar is visible.
-- Catches stale data when WoW events don't fire (e.g. HoT expiry out of combat).
function IncHeal:EnsureSafetyTicker(frame)
	if( frame.healSafetyTicker ) then return end
	frame.healSafetyTicker = C_Timer.NewTicker(0.5, function()
		if( not frame.unit or not UnitExists(frame.unit) ) then
			frame.healSafetyTicker:Cancel()
			frame.healSafetyTicker = nil
			return
		end
		frame.healCalcTime = nil
		local m = ShadowUF.modules
		if( frame.incHeal and frame.incHeal.total ) then m.incHeal:UpdateFrame(frame) end
		if( frame.healAbsorb and frame.healAbsorb.total ) then m.healAbsorb:UpdateFrame(frame) end
		if( frame.incAbsorb and frame.incAbsorb.total ) then m.incAbsorb:UpdateFrame(frame) end
	end)
end

function IncHeal:CancelSafetyTicker(frame)
	if( (frame.incHeal and frame.incHeal.total)
		or (frame.healAbsorb and frame.healAbsorb.total)
		or (frame.incAbsorb and frame.incAbsorb.total) ) then return end
	if( frame.healSafetyTicker ) then
		frame.healSafetyTicker:Cancel()
		frame.healSafetyTicker = nil
	end
end

function IncHeal:OnLayoutApplied(frame)
	local bar = frame[self.frameKey]
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	-- Reset state
	bar.total = nil

	bar:SetSize(frame.healthBar:GetSize())
	bar:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	bar:SetStatusBarColor(ShadowUF.db.profile.healthColors[self.colorKey].r, ShadowUF.db.profile.healthColors[self.colorKey].g, ShadowUF.db.profile.healthColors[self.colorKey].b, ShadowUF.db.profile.bars.alpha)
	bar:GetStatusBarTexture():SetHorizTile(false)
	bar:SetOrientation(frame.healthBar:GetOrientation())
	bar:SetReverseFill(frame.healthBar:GetReverseFill())
	bar:Hide()
	self:CancelSafetyTicker(frame)

	local anchorMode = ShadowUF.db.profile.units[frame.unitType][self.frameKey].anchorMode or "healthBar"
	local cap = ShadowUF.db.profile.units[frame.unitType][self.frameKey].cap or 1.30

	-- Set frame level for healthBar mode (depends on health bar transparency)
	if( anchorMode == "healthBar" ) then
		if( ( ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.backgroundAlpha == 0 ) or ( not ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.alpha == 1 ) ) then
			bar:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
		else
			bar:SetFrameLevel(frame.topFrameLevel - self.frameLevelMod + 3)
		end
	end

	-- Pre-create and configure overflow elements for healthBarOverflow mode
	if( anchorMode == "healthBarOverflow" ) then
		local overflowKey = self.frameKey .. "Overflow"
		if( not frame[overflowKey] ) then
			frame[overflowKey] = ShadowUF.Units:CreateBar(frame)
		end

		local clipKey = self.frameKey .. "OverflowClip"
		if( not frame[clipKey] ) then
			local clip = CreateFrame("Frame", nil, frame.healthBar)
			clip:SetClipsChildren(true)
			frame[clipKey] = clip
		end

		-- Static properties (only change on layout, not per-update)
		local overflowBar = frame[overflowKey]
		overflowBar:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
		overflowBar:SetStatusBarColor(ShadowUF.db.profile.healthColors[self.colorKey].r,
			ShadowUF.db.profile.healthColors[self.colorKey].g,
			ShadowUF.db.profile.healthColors[self.colorKey].b,
			ShadowUF.db.profile.bars.alpha * 0.7)
		overflowBar:GetStatusBarTexture():SetHorizTile(false)
		overflowBar:SetOrientation(frame.healthBar:GetOrientation())
		overflowBar:SetReverseFill(true)
	end
end

function IncHeal:PositionBar(frame, incAmount, maxHealth)
	local bar = frame[self.frameKey]
	local calc = frame.healCalc

	-- Hide check: if calculator has no secrets, we can safely test < 1
	-- (health values are integers; a sub-1 residual is never a real heal)
	if( calc and not calc:HasSecretValues() ) then
		if( incAmount < 1 or maxHealth <= 0 ) then
			bar.total = nil
			bar:Hide()
			local overflowKey = self.frameKey .. "Overflow"
			if( frame[overflowKey] ) then frame[overflowKey]:Hide() end
			self:CancelSafetyTicker(frame)
			return
		end
	end

	if( not bar.total ) then bar:Show() end
	bar.total = incAmount
	self:EnsureSafetyTicker(frame)
	if( bar.background ) then bar.background:Hide() end

	local anchorMode = ShadowUF.db.profile.units[frame.unitType][self.frameKey].anchorMode or "healthBar"

	if( anchorMode == "overlay" ) then
		self:PositionBarOverlayMode(frame, bar, incAmount, maxHealth)
	elseif( anchorMode == "healthBarOverflow" ) then
		self:PositionBarHealthOverflowMode(frame, bar, incAmount, maxHealth)
	elseif( anchorMode == "frame" ) then
		self:PositionBarFrameMode(frame, bar, incAmount, maxHealth)
	else
		self:PositionBarHealthMode(frame, bar, incAmount, maxHealth)
	end
end

-- Overlay mode: reverse fill overlay on the health texture
function IncHeal:PositionBarOverlayMode(frame, bar, incAmount, maxHealth)
	-- Hide cropper and overflow if they exist
	if( bar.cropper ) then bar.cropper:Hide() end
	if( frame[self.frameKey .. "Overflow"] ) then frame[self.frameKey .. "Overflow"]:Hide() end
	if( frame[self.frameKey .. "OverflowClip"] ) then frame[self.frameKey .. "OverflowClip"]:Hide() end
	local healthTexture = frame.healthBar:GetStatusBarTexture()
	if( not healthTexture ) then bar:Hide(); return end

	bar:SetParent(frame.healthBar)
	bar:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	bar:ClearAllPoints()
	bar:SetReverseFill(true)

	bar:SetPoint("TOPLEFT", healthTexture, "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT", 0, 0)

	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(incAmount)
end

-- Health bar with overflow: forward fill for missing health, reverse overlay for overflow
function IncHeal:PositionBarHealthOverflowMode(frame, bar, incAmount, maxHealth)
	local healthTexture = frame.healthBar:GetStatusBarTexture()
	if( not healthTexture ) then bar:Hide(); return end

	-- === FORWARD BAR (standard healthBar cap=1.0) ===
	bar:SetParent(frame.healthBar)
	bar:SetReverseFill(frame.healthBar:GetReverseFill())

	-- Create cropper if needed (caps forward fill to frame bounds)
	local cropper = ensureCropper(bar, frame.healthBar)
	cropper:Show()
	cropper:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	cropper:ClearAllPoints()

	local reverseFill = frame.healthBar:GetReverseFill()

	if( frame.healthBar:GetOrientation() == "HORIZONTAL" ) then
		if( reverseFill ) then
			cropper:SetPoint("RIGHT", healthTexture, "LEFT", 0, 0)
			cropper:SetPoint("LEFT", frame.healthBar, "LEFT", 0, 0)
		else
			cropper:SetPoint("LEFT", healthTexture, "RIGHT", 0, 0)
			cropper:SetPoint("RIGHT", frame.healthBar, "RIGHT", 0, 0)
		end
		cropper:SetHeight(frame.healthBar:GetHeight())
		cropper:SetPoint("TOP", frame.healthBar, "TOP", 0, 0)
	else
		if( reverseFill ) then
			cropper:SetPoint("BOTTOM", healthTexture, "TOP", 0, 0)
			cropper:SetPoint("TOP", frame.healthBar, "TOP", 0, 0)
		else
			cropper:SetPoint("TOP", healthTexture, "BOTTOM", 0, 0)
			cropper:SetPoint("BOTTOM", frame.healthBar, "BOTTOM", 0, 0)
		end
		cropper:SetWidth(frame.healthBar:GetWidth())
		cropper:SetPoint("LEFT", frame.healthBar, "LEFT", 0, 0)
	end

	-- Bar fills inside cropper (forward direction, capped at frame edge)
	bar:SetParent(cropper)
	bar:ClearAllPoints()
	if( frame.healthBar:GetOrientation() == "HORIZONTAL" ) then
		bar:SetWidth(frame.healthBar:GetWidth())
		if( reverseFill ) then
			bar:SetPoint("RIGHT", cropper, "RIGHT", 0, 0)
		else
			bar:SetPoint("LEFT", cropper, "LEFT", 0, 0)
		end
		bar:SetPoint("TOP", cropper, "TOP", 0, 0)
		bar:SetPoint("BOTTOM", cropper, "BOTTOM", 0, 0)
	else
		bar:SetHeight(frame.healthBar:GetHeight())
		if( reverseFill ) then
			bar:SetPoint("BOTTOM", cropper, "BOTTOM", 0, 0)
		else
			bar:SetPoint("TOP", cropper, "TOP", 0, 0)
		end
		bar:SetPoint("LEFT", cropper, "LEFT", 0, 0)
		bar:SetPoint("RIGHT", cropper, "RIGHT", 0, 0)
	end

	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(incAmount)

	-- === OVERFLOW BAR (reverse fill clipped to health texture zone) ===
	local overflowKey = self.frameKey .. "Overflow"
	local overflowBar = frame[overflowKey]
	local clipKey = self.frameKey .. "OverflowClip"
	local clipFrame = frame[clipKey]

	if( not overflowBar or not clipFrame ) then return end

	-- ClipFrame covers only the health texture zone
	clipFrame:ClearAllPoints()
	clipFrame:SetPoint("TOPLEFT", healthTexture, "TOPLEFT", 0, 0)
	clipFrame:SetPoint("BOTTOMRIGHT", healthTexture, "BOTTOMRIGHT", 0, 0)
	clipFrame:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	clipFrame:Show()

	-- Overflow bar: clipped to health zone (static setup done in OnLayoutApplied)
	overflowBar:SetParent(clipFrame)
	overflowBar:ClearAllPoints()
	overflowBar:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
	overflowBar:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)
	overflowBar:SetMinMaxValues(0, maxHealth)
	overflowBar:SetValue(incAmount)
	overflowBar:Show()
end

-- Frame anchor mode: reverse fill from frame edge inward, real values
function IncHeal:PositionBarFrameMode(frame, bar, incAmount, maxHealth)
	-- Hide cropper and overflow if they exist
	if( bar.cropper ) then bar.cropper:Hide() end
	if( frame[self.frameKey .. "Overflow"] ) then frame[self.frameKey .. "Overflow"]:Hide() end
	if( frame[self.frameKey .. "OverflowClip"] ) then frame[self.frameKey .. "OverflowClip"]:Hide() end

	bar:SetParent(frame.healthBar)
	bar:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	bar:ClearAllPoints()
	bar:SetReverseFill(true)

	-- Full health bar size, anchored to the frame edges
	bar:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)

	-- Real values — secrets accepted natively by SetMinMaxValues/SetValue
	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(incAmount)
end

-- Health bar anchor mode: forward fill from health edge with cropper cap
function IncHeal:PositionBarHealthMode(frame, bar, incAmount, maxHealth)
	bar:ClearAllPoints()
	bar:SetReverseFill(frame.healthBar:GetReverseFill())

	-- Hide overflow elements if they exist
	if( frame[self.frameKey .. "Overflow"] ) then frame[self.frameKey .. "Overflow"]:Hide() end
	if( frame[self.frameKey .. "OverflowClip"] ) then frame[self.frameKey .. "OverflowClip"]:Hide() end

	local cap = ShadowUF.db.profile.units[frame.unitType][self.frameKey].cap or 1.30
	local healthTexture = frame.healthBar:GetStatusBarTexture()
	if( not healthTexture ) then
		bar:Hide()
		return
	end

	local cropper = ensureCropper(bar, frame.healthBar)
	cropper:Show()
	cropper:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	cropper:ClearAllPoints()

	local reverseFill = frame.healthBar:GetReverseFill()
	local frameSize = 0

	if( frame.healthBar:GetOrientation() == "HORIZONTAL" ) then
		frameSize = frame.healthBar:GetWidth()
		if( reverseFill ) then
			cropper:SetPoint("RIGHT", healthTexture, "LEFT", 0, 0)
		else
			cropper:SetPoint("LEFT", healthTexture, "RIGHT", 0, 0)
		end

		local maxOffset = frameSize * (cap - 1)
		if( reverseFill ) then
			cropper:SetPoint("LEFT", frame.healthBar, "LEFT", -maxOffset, 0)
		else
			cropper:SetPoint("RIGHT", frame.healthBar, "RIGHT", maxOffset, 0)
		end

		cropper:SetHeight(frame.healthBar:GetHeight())
		cropper:SetPoint("TOP", frame.healthBar, "TOP", 0, 0)
	else
		frameSize = frame.healthBar:GetHeight()
		if( reverseFill ) then
			cropper:SetPoint("BOTTOM", healthTexture, "TOP", 0, 0)
		else
			cropper:SetPoint("TOP", healthTexture, "BOTTOM", 0, 0)
		end

		local maxOffset = frameSize * (cap - 1)
		if( reverseFill ) then
			cropper:SetPoint("TOP", frame.healthBar, "TOP", 0, maxOffset)
		else
			cropper:SetPoint("BOTTOM", frame.healthBar, "BOTTOM", 0, -maxOffset)
		end

		cropper:SetWidth(frame.healthBar:GetWidth())
		cropper:SetPoint("LEFT", frame.healthBar, "LEFT", 0, 0)
	end

	bar:SetParent(cropper)
	bar:ClearAllPoints()

	if( frame.healthBar:GetOrientation() == "HORIZONTAL" ) then
		bar:SetWidth(frameSize)
		if( reverseFill ) then
			bar:SetPoint("RIGHT", cropper, "RIGHT", 0, 0)
		else
			bar:SetPoint("LEFT", cropper, "LEFT", 0, 0)
		end
		bar:SetPoint("TOP", cropper, "TOP", 0, 0)
		bar:SetPoint("BOTTOM", cropper, "BOTTOM", 0, 0)
	else
		bar:SetHeight(frameSize)
		if( reverseFill ) then
			bar:SetPoint("BOTTOM", cropper, "BOTTOM", 0, 0)
		else
			bar:SetPoint("TOP", cropper, "TOP", 0, 0)
		end
		bar:SetPoint("LEFT", cropper, "LEFT", 0, 0)
		bar:SetPoint("RIGHT", cropper, "RIGHT", 0, 0)
	end

	-- SetMinMaxValues/SetValue accept secrets natively (AllowedWhenTainted)
	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(incAmount)
end

function IncHeal:UpdateFrame(frame)
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	if( not self:PopulateCalculator(frame) ) then
		frame[self.frameKey].total = nil
		frame[self.frameKey]:Hide()
		return
	end

	local calc = frame.healCalc
	local amount = calc:GetTotalIncomingHeals()
	local maxHealth = calc:GetMaximumHealth()

	-- Stack heal absorbs into incoming heals for healthBar/healthBarOverflow modes
	local anchorMode = ShadowUF.db.profile.units[frame.unitType][self.frameKey].anchorMode or "healthBar"
	if( anchorMode ~= "overlay" and frame.visibility.healAbsorb and not calc:HasSecretValues() ) then
		amount = amount + calc:GetTotalHealAbsorbs()
	end

	self:PositionBar(frame, amount, maxHealth)
end
