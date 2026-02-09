local IncHeal = {["frameKey"] = "incHeal", ["colorKey"] = "inc", ["frameLevelMod"] = 2}
ShadowUF.IncHeal = IncHeal
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])

function IncHeal:OnEnable(frame)
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")

	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame[self.frameKey]:Hide()
end

function IncHeal:OnLayoutApplied(frame)
	local bar = frame[self.frameKey]
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	if( frame.visibility.healAbsorb ) then
		frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")
	else
		frame:UnregisterSingleEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")
	end

	-- Since we're hiding, reset state
	bar.total = nil

	bar:SetSize(frame.healthBar:GetSize())
	bar:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	bar:SetStatusBarColor(ShadowUF.db.profile.healthColors[self.colorKey].r, ShadowUF.db.profile.healthColors[self.colorKey].g, ShadowUF.db.profile.healthColors[self.colorKey].b, ShadowUF.db.profile.bars.alpha)
	bar:GetStatusBarTexture():SetHorizTile(false)
	bar:SetOrientation(frame.healthBar:GetOrientation())
	bar:SetReverseFill(frame.healthBar:GetReverseFill())
	bar:Hide()

	local cap = ShadowUF.db.profile.units[frame.unitType][self.frameKey].cap or 1.30

	-- When we can cheat and put the incoming bar right behind the health bar, we can efficiently show the incoming heal bar
	-- if the main bar has a transparency set, then we need a more complicated method to stop the health bar from being darker with incoming heals up
	if( ( ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.backgroundAlpha == 0 ) or ( not ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.alpha == 1 ) ) then
		bar.simple = true
		bar:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)

		if( bar:GetOrientation() == "HORIZONTAL" ) then
			bar:SetWidth(frame.healthBar:GetWidth() * cap)
		else
			bar:SetHeight(frame.healthBar:GetHeight() * cap)
		end

		bar:ClearAllPoints()

		local point = bar:GetReverseFill() and "RIGHT" or "LEFT"
		bar:SetPoint("TOP" .. point, frame.healthBar)
		bar:SetPoint("BOTTOM" .. point, frame.healthBar)
	else
		bar.simple = nil
		bar:SetFrameLevel(frame.topFrameLevel - self.frameLevelMod + 3)
		bar:SetWidth(1)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		bar:ClearAllPoints()

		bar.orientation = bar:GetOrientation()
		bar.reverseFill = bar:GetReverseFill()

		if( bar.orientation == "HORIZONTAL" ) then
			bar.healthSize = frame.healthBar:GetWidth()
			bar.positionPoint = bar.reverseFill and "TOPRIGHT" or "TOPLEFT"
			bar.positionRelative = bar.reverseFill and "BOTTOMRIGHT" or "BOTTOMLEFT"
		else
			bar.healthSize = frame.healthBar:GetHeight()
			bar.positionPoint = bar.reverseFill and "TOPLEFT" or "BOTTOMLEFT"
			bar.positionRelative = bar.reverseFill and "TOPRIGHT" or "BOTTOMRIGHT"
		end

		bar.positionMod = bar.reverseFill and -1 or 1
		bar.maxSize = bar.healthSize * cap
	end
end

function IncHeal:PositionBar(frame, incAmount)
	local bar = frame[self.frameKey]

	-- If incoming is <= 0 or health is <= 0 we can hide it
	-- Use pcall to check <= 0 safely. If checking fails (secret), we assume it's positive/valid and continue.
	local isPositive = true
	local success, result = pcall(function() return incAmount <= 0 end)
	if( success and result ) then
		bar.total = nil
		bar:Hide()
		return
	end

	local health = UnitHealth(frame.unit)
	local maxHealth = UnitHealthMax(frame.unit)

	-- Check if health <= 0 safely
	success, result = pcall(function() return health <= 0 end)
	if( success and result ) then
		bar.total = nil
		bar:Hide()
		return
	end

	-- Check if maxHealth <= 0 safely
	success, result = pcall(function() return maxHealth <= 0 end)
	if( success and result ) then
		bar.total = nil
		bar:Hide()
		return
	end

	if( not bar.total ) then bar:Show() end
	bar.total = incAmount

	-- Get anchor mode setting
	local anchorMode = ShadowUF.db.profile.units[frame.unitType][self.frameKey].anchorMode or "healthBar"
	
	-- Frame Anchor Mode: Bar anchored to frame edge with reverse fill
	if( anchorMode == "frame" ) then
		self:PositionBarFrameMode(frame, bar, incAmount, maxHealth)
	else
		-- Health Bar Anchor Mode (default): Original behavior with cropper
		self:PositionBarHealthMode(frame, bar, incAmount, maxHealth)
	end
end

-- New Frame Anchor Mode: Bar anchored to frame edge, growing inward with reverse fill
function IncHeal:PositionBarFrameMode(frame, bar, incAmount, maxHealth)
	local frameSize = ShadowUF.db.profile.units[frame.unitType][self.frameKey].frameSize or 0.80
	-- frameSize is the "start position" from the left (0.90 = starts at 90%, so max coverage is 10%)
	-- Coverage = (1 - frameSize), e.g. 0.90 -> 10% coverage, 0.50 -> 50% coverage
	local coverage = 1 - frameSize
	
	-- Hide cropper if it exists (not used in this mode)
	if( frame[self.frameKey].cropper ) then
		frame[self.frameKey].cropper:Hide()
	end
	
	if( bar.background ) then bar.background:Hide() end
	
	-- Reparent to healthBar
	bar:SetParent(frame.healthBar)
	bar:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	bar:ClearAllPoints()
	
	-- Force reverse fill for this mode
	bar:SetReverseFill(true)
	
	local orientation = frame.healthBar:GetOrientation()
	
	if( orientation == "HORIZONTAL" ) then
		local barWidth = frame.healthBar:GetWidth() * coverage
		bar:SetWidth(barWidth)
		bar:SetHeight(frame.healthBar:GetHeight())
		
		-- Anchor to right edge of frame
		bar:SetPoint("RIGHT", frame.healthBar, "RIGHT", 0, 0)
		bar:SetPoint("TOP", frame.healthBar, "TOP", 0, 0)
		bar:SetPoint("BOTTOM", frame.healthBar, "BOTTOM", 0, 0)
	else -- VERTICAL
		local barHeight = frame.healthBar:GetHeight() * coverage
		bar:SetWidth(frame.healthBar:GetWidth())
		bar:SetHeight(barHeight)
		
		-- Anchor to top edge of frame
		bar:SetPoint("TOP", frame.healthBar, "TOP", 0, 0)
		bar:SetPoint("LEFT", frame.healthBar, "LEFT", 0, 0)
		bar:SetPoint("RIGHT", frame.healthBar, "RIGHT", 0, 0)
	end
	
	-- Calculate maxHealth for the bar proportional to coverage
	-- If the bar covers 10% of frame, it should represent 10% of maxHealth when full
	-- Use pcall for the calculation in case maxHealth is a "secret value" (hostile units)
	local success, barMaxHealth = pcall(function() return maxHealth * coverage end)
	if not success then
		-- Can't calculate, hide the bar for this unit
		bar.total = nil
		bar:Hide()
		return
	end
	
	-- Set Values
	bar:SetMinMaxValues(0, barMaxHealth)
	bar:SetValue(incAmount)
end

-- Original Health Bar Anchor Mode with cropper
function IncHeal:PositionBarHealthMode(frame, bar, incAmount, maxHealth)
	-- Visual Anchoring + Cropper
	-- Implement Cap (Overlay/Overflow size) support
	bar:ClearAllPoints()
	
	-- Restore original reverse fill setting
	bar:SetReverseFill(frame.healthBar:GetReverseFill())
	
	local cap = ShadowUF.db.profile.units[frame.unitType][self.frameKey].cap or 1.30
	local healthTexture = frame.healthBar:GetStatusBarTexture()
	if( not healthTexture ) then 
		bar:Hide()
		return 
	end
	
	if( bar.background ) then bar.background:Hide() end
	
	if( not frame[self.frameKey].cropper ) then
		local cropper = CreateFrame("Frame", nil, frame.healthBar)
		cropper:SetClipsChildren(true)
		frame[self.frameKey].cropper = cropper
	end
	
	local cropper = frame[self.frameKey].cropper
	cropper:Show()
	cropper:SetFrameLevel(frame.topFrameLevel + 5 - self.frameLevelMod)
	cropper:ClearAllPoints()

	
	local frameSize = 0
	if( frame.healthBar:GetOrientation() == "HORIZONTAL" ) then
		frameSize = frame.healthBar:GetWidth()
		-- Start Anchor
		if( bar.reverseFill ) then
			cropper:SetPoint("RIGHT", healthTexture, "LEFT", 0, 0)
		else
			cropper:SetPoint("LEFT", healthTexture, "RIGHT", 0, 0)
		end
		
		-- End Anchor: Limit relative to Frame Edge
		local maxOffset = frameSize * (cap - 1)
		
		if( bar.reverseFill ) then
			cropper:SetPoint("LEFT", frame.healthBar, "LEFT", -maxOffset, 0)
		else
			cropper:SetPoint("RIGHT", frame.healthBar, "RIGHT", maxOffset, 0)
		end
		
		-- Align Height
		cropper:SetHeight(frame.healthBar:GetHeight())
		cropper:SetPoint("TOP", frame.healthBar, "TOP", 0, 0)
		
	else -- VERTICAL
		frameSize = frame.healthBar:GetHeight()
		-- Start Anchor
		if( bar.reverseFill ) then
			cropper:SetPoint("BOTTOM", healthTexture, "TOP", 0, 0)
		else
			cropper:SetPoint("TOP", healthTexture, "BOTTOM", 0, 0)
		end
		
		-- End Anchor
		local maxOffset = frameSize * (cap - 1)
		
		if( bar.reverseFill ) then
			cropper:SetPoint("TOP", frame.healthBar, "TOP", 0, maxOffset)
		else
			cropper:SetPoint("BOTTOM", frame.healthBar, "BOTTOM", 0, -maxOffset)
		end
		
		-- Align Width
		cropper:SetWidth(frame.healthBar:GetWidth())
		cropper:SetPoint("LEFT", frame.healthBar, "LEFT", 0, 0)
	end
	
	-- Setup Bar inside Cropper
	bar:SetParent(cropper)
	bar:ClearAllPoints()
	
	-- Anchor Bar Start to Cropper Start
	if( frame.healthBar:GetOrientation() == "HORIZONTAL" ) then
		bar:SetWidth(frameSize) -- Render at 1:1 Scale
		if( bar.reverseFill ) then
			bar:SetPoint("RIGHT", cropper, "RIGHT", 0, 0)
		else
			bar:SetPoint("LEFT", cropper, "LEFT", 0, 0)
		end
		-- Fix Thickness (Height)
		bar:SetPoint("TOP", cropper, "TOP", 0, 0)
		bar:SetPoint("BOTTOM", cropper, "BOTTOM", 0, 0)
	else
		bar:SetHeight(frameSize) -- Render at 1:1 Scale
		if( bar.reverseFill ) then
			bar:SetPoint("BOTTOM", cropper, "BOTTOM", 0, 0)
		else
			bar:SetPoint("TOP", cropper, "TOP", 0, 0)
		end
		-- Fix Thickness (Width)
		bar:SetPoint("LEFT", cropper, "LEFT", 0, 0)
		bar:SetPoint("RIGHT", cropper, "RIGHT", 0, 0)
	end
	
	-- Set Values
	pcall(bar.SetMinMaxValues, bar, 0, maxHealth)
	pcall(bar.SetValue, bar, incAmount)
end

function IncHeal:UpdateFrame(frame)
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	local amount = UnitGetIncomingHeals(frame.unit) or 0
	
	-- Safe check for > 0
	local isPositive = true
	local success, result = pcall(function() return amount <= 0 end)
	if( success and result ) then 
		isPositive = false 
	end

	if( isPositive and frame.visibility.healAbsorb ) then
		local absorbs = UnitGetTotalHealAbsorbs(frame.unit) or 0
		-- Safe Add
		pcall(function() amount = amount + absorbs end)
	end

	self:PositionBar(frame, amount)
end
