local Cast = {}
local L = ShadowUF.L
local FADE_TIME = 0.30

ShadowUF:RegisterModule(Cast, "castBar", L["Cast bar"], true)

-- Fake units use polling since events don't fire for them
-- 12.0: Use durationObject to avoid secret value errors
local function monitorFakeCast(self)
	local unit = self.parent.unit
	local spell, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
	local isChannelled
	
	if( not spell ) then
		spell, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
		if spell then
			isChannelled = true
		end
	end

	-- No active cast detected - stop if we had one tracked
	if( not spell ) then
		local cast = self.parent.castBar.bar
		if( cast and cast.spellName ) then
			Cast:EventStopCast(self.parent, "UNIT_SPELLCAST_STOP", unit, cast.castID, cast.spellID)
		end
		
		-- Clean up monitor state
		self.durationObj = nil
		self.spellName = nil
		self.spellID = nil
		return
	end

	-- Get duration object
	local durationObj
	if (isChannelled) then
		if (UnitEmpoweredChannelDuration) then durationObj = UnitEmpoweredChannelDuration(unit) end
		if (not durationObj and UnitChannelDuration) then durationObj = UnitChannelDuration(unit) end
	else
		if (UnitCastingDuration) then durationObj = UnitCastingDuration(unit) end
	end
	
	-- New cast or cast changed
	if (durationObj and (not self.durationObj or self.durationObj ~= durationObj)) then
		self.durationObj = durationObj
		self.spellName = spell
		self.spellID = spellID
		Cast:UpdateCast(self.parent, unit, isChannelled, spell, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID, castID)
	end
end

local function createFakeCastMonitor(frame)
	if( not frame.castBar.monitor ) then
		frame.castBar.monitor = C_Timer.NewTicker(0.10, monitorFakeCast)
		frame.castBar.monitor.parent = frame
	end
end

local function cancelFakeCastMonitor(frame)
	if( frame.castBar and frame.castBar.monitor ) then
		frame.castBar.monitor:Cancel()
		frame.castBar.monitor = nil
	end
end

function Cast:OnEnable(frame)
	if( not frame.castBar ) then
		frame.castBar = CreateFrame("Frame", nil, frame)
		frame.castBar.bar = ShadowUF.Units:CreateBar(frame)
		frame.castBar.background = frame.castBar.bar.background
		frame.castBar.bar.parent = frame
		frame.castBar.bar.background = frame.castBar.background

		frame.castBar.icon = frame.castBar.bar:CreateTexture(nil, "ARTWORK")
		frame.castBar.bar.name = frame.castBar.bar:CreateFontString(nil, "ARTWORK")
		frame.castBar.bar.time = frame.castBar.bar:CreateFontString(nil, "ARTWORK")
	end

	if( ShadowUF.fakeUnits[frame.unitType] ) then
		createFakeCastMonitor(frame)
		frame:RegisterUpdateFunc(self, "UpdateFakeCast")
		return
	end

	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", self, "EventUpdateCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", self, "EventStopCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", self, "EventInterruptCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", self, "EventDelayCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", self, "EventCastSucceeded")

	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", self, "EventUpdateChannel")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", self, "EventStopCast")
	--frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", self, "EventInterruptCast")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", self, "EventDelayChannel")
	
	-- 12.0 Empowered Casts
	-- Treating them as channels (complex Start/Update/Stop flow)
	if( UnitEmpoweredChannelDuration ) then
		frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", self, "EventUpdateChannel")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", self, "EventStopCast")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", self, "EventDelayChannel")
	end

	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", self, "EventInterruptible")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", self, "EventUninterruptible")

	frame:RegisterUpdateFunc(self, "UpdateCurrentCast")
end

function Cast:OnLayoutApplied(frame, config)
	if( not frame.visibility.castBar ) then return end

	-- Set textures
	frame.castBar.bar:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	frame.castBar.bar:SetStatusBarColor(0, 0, 0, 0)
	frame.castBar.bar:GetStatusBarTexture():SetHorizTile(false)
	frame.castBar.background:SetVertexColor(0, 0, 0, 0)
	frame.castBar.background:SetHorizTile(false)
	
	-- Create overlay StatusBar for non-interruptible casts (animates with cast)
	if (not frame.castBar.uninterruptibleOverlay) then
		frame.castBar.uninterruptibleOverlay = CreateFrame("StatusBar", nil, frame.castBar.bar)
		frame.castBar.uninterruptibleOverlay:SetAlpha(0)
	end
	frame.castBar.uninterruptibleOverlay:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	local c = ShadowUF.db.profile.castColors.uninterruptible or {r = 0.6, g = 0.6, b = 0.6}
	frame.castBar.uninterruptibleOverlay:SetStatusBarColor(c.r, c.g, c.b, 1)
	frame.castBar.uninterruptibleOverlay:SetAllPoints(frame.castBar.bar)
	frame.castBar.uninterruptibleOverlay:SetMinMaxValues(0, 1)
	frame.castBar.uninterruptibleOverlay:SetValue(0)

	-- Setup fill
	frame.castBar.bar:SetOrientation(config.castBar.vertical and "VERTICAL" or "HORIZONTAL")
	frame.castBar.bar:SetReverseFill(config.castBar.reverse and true or false)
	frame.castBar.uninterruptibleOverlay:SetOrientation(config.castBar.vertical and "VERTICAL" or "HORIZONTAL")
	frame.castBar.uninterruptibleOverlay:SetReverseFill(config.castBar.reverse and true or false)

	-- Setup the main bar + icon
	frame.castBar.bar:ClearAllPoints()
	frame.castBar.bar:SetHeight(frame.castBar:GetHeight())
	frame.castBar.bar:SetValue(0)
	frame.castBar.bar:SetMinMaxValues(0, 1)

	-- Use the entire bars width and show the icon
	if( config.castBar.icon == "HIDE" ) then
		frame.castBar.bar:SetWidth(frame.castBar:GetWidth())
		frame.castBar.bar:SetAllPoints(frame.castBar)
		frame.castBar.icon:Hide()
	-- Shift the bar to the side and show an icon
	else
		frame.castBar.bar:SetWidth(frame.castBar:GetWidth() - frame.castBar:GetHeight())
		frame.castBar.icon:ClearAllPoints()
		frame.castBar.icon:SetWidth(frame.castBar:GetHeight())
		frame.castBar.icon:SetHeight(frame.castBar:GetHeight())
		frame.castBar.icon:Show()

		if( config.castBar.icon == "LEFT" ) then
			frame.castBar.bar:SetPoint("TOPLEFT", frame.castBar, "TOPLEFT", frame.castBar:GetHeight() + 1, 0)
			frame.castBar.icon:SetPoint("TOPRIGHT", frame.castBar.bar, "TOPLEFT", -1, 0)
		else
			frame.castBar.bar:SetPoint("TOPLEFT", frame.castBar, "TOPLEFT", 1, 0)
			frame.castBar.icon:SetPoint("TOPLEFT", frame.castBar.bar, "TOPRIGHT", 0, 0)
		end
	end

	-- Set the font at the very least, so it doesn't error when we set text on it even if it isn't being shown
	ShadowUF.Layout:ToggleVisibility(frame.castBar.bar.name, config.castBar.name.enabled)
	if( config.castBar.name.enabled ) then
		frame.castBar.bar.name:SetParent(frame.highFrame)
		frame.castBar.bar.name:SetWidth(frame.castBar.bar:GetWidth() * 0.75)
		frame.castBar.bar.name:SetHeight(ShadowUF.db.profile.font.size + 1)
		frame.castBar.bar.name:SetJustifyH(ShadowUF.Layout:GetJustify(config.castBar.name))

		ShadowUF.Layout:AnchorFrame(frame.castBar.bar, frame.castBar.bar.name, config.castBar.name)
		ShadowUF.Layout:SetupFontString(frame.castBar.bar.name, config.castBar.name.size)
	end

	ShadowUF.Layout:ToggleVisibility(frame.castBar.bar.time, config.castBar.time.enabled)
	if( config.castBar.time.enabled ) then
		frame.castBar.bar.time:SetParent(frame.highFrame)
		frame.castBar.bar.time:SetWidth(frame.castBar.bar:GetWidth() * 0.25)
		frame.castBar.bar.time:SetHeight(ShadowUF.db.profile.font.size + 1)
		frame.castBar.bar.time:SetJustifyH(ShadowUF.Layout:GetJustify(config.castBar.time))

		ShadowUF.Layout:AnchorFrame(frame.castBar.bar, frame.castBar.bar.time, config.castBar.time)
		ShadowUF.Layout:SetupFontString(frame.castBar.bar.time, config.castBar.time.size)
	end

	-- So we don't have to check the entire thing in an OnUpdate
	frame.castBar.bar.time.enabled = config.castBar.time.enabled

	if( config.castBar.autoHide and not UnitCastingInfo(frame.unit) and not UnitChannelInfo(frame.unit) ) then
		ShadowUF.Layout:SetBarVisibility(frame, "castBar", false)
	end
end

function Cast:OnDisable(frame, unit)
	frame:UnregisterAll(self)

	if( frame.castBar ) then
		cancelFakeCastMonitor(frame)

		frame.castBar.bar.name:Hide()
		frame.castBar.bar.time:Hide()
		frame.castBar.bar:Hide()
	end
end

-- Easy coloring
local function setBarColor(self, r, g, b)
	self.parent:SetBlockColor(self, "castBar", r, g, b)
end

-- Cast OnUpdates
local function fadeOnUpdate(self, elapsed)
	self.fadeElapsed = self.fadeElapsed - elapsed

	if( self.fadeElapsed <= 0 ) then
		self.fadeElapsed = nil
		self.name:Hide()
		self.time:Hide()
		self:Hide()

		local frame = self:GetParent()
		if( ShadowUF.db.profile.units[frame.unitType].castBar.autoHide ) then
			ShadowUF.Layout:SetBarVisibility(frame, "castBar", false)
		end
	else
		local alpha = self.fadeElapsed / self.fadeStart
		self:SetAlpha(alpha)
		self.time:SetAlpha(alpha)
		self.name:SetAlpha(alpha)
	end
end

local function castOnUpdate(self, elapsed)
	if( self.usingDurationObject ) then
		if( self.time.enabled ) then
			local remaining = self.durationObject:GetRemainingDuration()
			self.time:SetFormattedText("%.1f", remaining)
		end
		return
	end

	local time = GetTime()
	self.elapsed = self.elapsed + (time - self.lastUpdate)
	self.lastUpdate = time
	self:SetValue(self.elapsed)

	if( self.elapsed <= 0 ) then
		self.elapsed = 0
	end

	if( self.time.enabled ) then
		local timeLeft = self.endSeconds - self.elapsed
		if( timeLeft <= 0 ) then
			self.time:SetText("0.0")
		elseif( self.pushback == 0 ) then
			self.time:SetFormattedText("%.1f", timeLeft)
		else
			self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, timeLeft)
		end
	end

	-- Cast finished, do a quick fade
	if( self.elapsed >= self.endSeconds ) then
		setBarColor(self, ShadowUF.db.profile.castColors.finished.r, ShadowUF.db.profile.castColors.finished.g, ShadowUF.db.profile.castColors.finished.b)

		self.spellName = nil
		self.fadeElapsed = FADE_TIME
		self.fadeStart = FADE_TIME
		self:SetScript("OnUpdate", fadeOnUpdate)
	end
end

local function channelOnUpdate(self, elapsed)
	if( self.usingDurationObject ) then
		if( self.time.enabled ) then
			local remaining = self.durationObject:GetRemainingDuration()
			self.time:SetFormattedText("%.1f", remaining)
		end
		return
	end

	local time = GetTime()
	self.elapsed = self.elapsed - (time - self.lastUpdate)
	self.lastUpdate = time
	self:SetValue(self.elapsed)

	if( self.elapsed <= 0 ) then
		self.elapsed = 0
	end

	if( self.time.enabled ) then
		if( self.elapsed <= 0 ) then
			self.time:SetText("0.0")
		elseif( self.pushback == 0 ) then
			self.time:SetFormattedText("%.1f", self.elapsed)
		else
			self.time:SetFormattedText("|cffff0000%.1f|r %.1f", self.pushback, self.elapsed)
		end
	end

	-- Channel finished, do a quick fade
	if( self.elapsed <= 0 ) then
		setBarColor(self, ShadowUF.db.profile.castColors.finished.r, ShadowUF.db.profile.castColors.finished.g, ShadowUF.db.profile.castColors.finished.b)

		self.spellName = nil
		self.fadeElapsed = FADE_TIME
		self.fadeStart = FADE_TIME
		self:SetScript("OnUpdate", fadeOnUpdate)
	end
end

-- Helper to sanitize secret values
local function safeCastID(id)
	if (_G.issecretvalue and _G.issecretvalue(id)) then
		return "secret_cast"
	end
	return id
end

function Cast:UpdateCurrentCast(frame)
	if( UnitCastingInfo(frame.unit) ) then
		local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID, _, _, castBarID = UnitCastingInfo(frame.unit)
		castID = castBarID or castID
		self:UpdateCast(frame, frame.unit, false, name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, castID)
	elseif( UnitChannelInfo(frame.unit) ) then
		local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, _, castBarID = UnitChannelInfo(frame.unit)
		castID = castBarID or spellID
		self:UpdateCast(frame, frame.unit, true, name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, castID)
	else
		if( ShadowUF.db.profile.units[frame.unitType].castBar.autoHide ) then
			ShadowUF.Layout:SetBarVisibility(frame, "castBar", false)
		end

		setBarColor(frame.castBar.bar, 0, 0, 0)

		frame.castBar.bar.spellName = nil
		frame.castBar.bar.name:Hide()
		frame.castBar.bar.time:Hide()
		frame.castBar.bar:Hide()
	end
end

-- Cast updated/changed
function Cast:EventUpdateCast(frame)
	local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(frame.unit)
	self:UpdateCast(frame, frame.unit, false, name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, castID)
end

function Cast:EventDelayCast(frame)
	local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(frame.unit)
	self:UpdateDelay(frame, name, text, texture, startTime, endTime)
end

-- Channel updated/changed
function Cast:EventUpdateChannel(frame)
	local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(frame.unit)
	self:UpdateCast(frame, frame.unit, true, name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID)
end

function Cast:EventDelayChannel(frame)
	local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(frame.unit)
	self:UpdateDelay(frame, name, text, texture, startTime, endTime)
end

-- Helper to check if any event arg matches our stored castID
function Cast:DoCastsMatch(storedID, ...)
	if (not storedID) then return false end
	local numArgs = select("#", ...)
	for i = 1, numArgs do
		local arg = select(i, ...)
		
		if (_G.issecretvalue and _G.issecretvalue(arg)) then
			-- Arg is secret. Match only if storedID is the sanitized "secret_cast"
			if (storedID == "secret_cast") then return true end
		else
			-- Arg is safe. Compare directly.
			if (arg == storedID) then return true end
		end
	end
	return false
end

-- Cast finished
function Cast:EventStopCast(frame, event, unit, castID, spellID, ...)
	local cast = frame.castBar.bar
	-- Check for match in legacy args or extra args (castBarID)
	local match = self:DoCastsMatch(cast.castID, castID, spellID, ...)
	
	if( event == "UNIT_SPELLCAST_CHANNEL_STOP" and not castID ) then 
		-- Channel Stop sometimes lacks ID, verify spellID (Sanitize secrets)
		if (safeCastID(cast.spellID) == safeCastID(spellID)) then match = true end
	end
	
	if( not match or ( event == "UNIT_SPELLCAST_FAILED" and cast.isChannelled ) ) then return end

	if( cast.time.enabled ) then
		cast.time:SetText("0.0")
	end

	--setBarColor(cast, ShadowUF.db.profile.castColors.interrupted.r, ShadowUF.db.profile.castColors.interrupted.g, ShadowUF.db.profile.castColors.interrupted.b)
	if( ShadowUF.db.profile.units[frame.unitType].castBar.autoHide ) then
		ShadowUF.Layout:SetBarVisibility(frame, "castBar", true)
	end
	
	if( cast.usingDurationObject ) then
		cast.usingDurationObject = nil
	end
	
	cast.spellName = nil
	cast.spellID = nil
	cast.castID = nil
	cast.fadeElapsed = FADE_TIME
	cast.fadeStart = FADE_TIME
	cast:SetScript("OnUpdate", fadeOnUpdate)
	cast:SetMinMaxValues(0, 1)
	cast:SetValue(1)
	cast:Show()
end

-- Cast interrupted
function Cast:EventInterruptCast(frame, event, unit, castID, spellID, ...)
	local cast = frame.castBar.bar
	local match = self:DoCastsMatch(cast.castID, castID, spellID, ...)
	
	if( not match ) then return end

	setBarColor(cast, ShadowUF.db.profile.castColors.interrupted.r, ShadowUF.db.profile.castColors.interrupted.g, ShadowUF.db.profile.castColors.interrupted.b)
	if( ShadowUF.db.profile.units[frame.unitType].castBar.autoHide ) then
		ShadowUF.Layout:SetBarVisibility(frame, "castBar", true)
	end

	if( ShadowUF.db.profile.units[frame.unitType].castBar.name.enabled ) then
		cast.name:SetText(L["Interrupted"])
	end

	if( cast.usingDurationObject ) then
		cast.usingDurationObject = nil
	end
	
	cast.spellID = nil
	cast.fadeElapsed = FADE_TIME + 0.20
	cast.fadeStart = cast.fadeElapsed
	cast:SetScript("OnUpdate", fadeOnUpdate)
	cast:SetMinMaxValues(0, 1)
	cast:SetValue(1)
	cast:Show()
end

-- Cast succeeded
function Cast:EventCastSucceeded(frame, event, unit, castID, spellID, ...)
	local cast = frame.castBar.bar
	local match = self:DoCastsMatch(cast.castID, castID, spellID, ...)
	
	if( not cast.isChannelled and match ) then
		setBarColor(cast, ShadowUF.db.profile.castColors.finished.r, ShadowUF.db.profile.castColors.finished.g, ShadowUF.db.profile.castColors.finished.b)
	end
end

-- Interruptible status changed
function Cast:EventInterruptible(frame)
	local cast = frame.castBar.bar
	if( cast.isChannelled ) then
		setBarColor(cast, ShadowUF.db.profile.castColors.channel.r, ShadowUF.db.profile.castColors.channel.g, ShadowUF.db.profile.castColors.channel.b)
	else
		setBarColor(cast, ShadowUF.db.profile.castColors.cast.r, ShadowUF.db.profile.castColors.cast.g, ShadowUF.db.profile.castColors.cast.b)
	end
end

function Cast:EventUninterruptible(frame)
	setBarColor(frame.castBar.bar, ShadowUF.db.profile.castColors.uninterruptible.r, ShadowUF.db.profile.castColors.uninterruptible.g, ShadowUF.db.profile.castColors.uninterruptible.b)
end

function Cast:UpdateDelay(frame, spell, displayName, icon, startTime, endTime)
	if( not spell or not frame.castBar.bar.startTime ) then return end
	local cast = frame.castBar.bar
	
	if( cast.usingDurationObject ) then return end

	startTime = startTime / 1000
	endTime = endTime / 1000

	-- For a channel, delay is a negative value so using plus is fine here
	local delay = startTime - cast.startTime
	if( not cast.isChannelled ) then
		cast.endSeconds = cast.endSeconds + delay
		cast:SetMinMaxValues(0, cast.endSeconds)
	else
		cast.elapsed = cast.elapsed + delay
	end

	cast.pushback = cast.pushback + delay
	cast.lastUpdate = GetTime()
	cast.startTime = startTime
	cast.endTime = endTime
end

-- Update the actual bar
function Cast:UpdateCast(frame, unit, channelled, spell, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID, castID)
	if( not spell ) then return end
	local cast = frame.castBar.bar
	if( ShadowUF.db.profile.units[frame.unitType].castBar.autoHide ) then
		ShadowUF.Layout:SetBarVisibility(frame, "castBar", true)
	end

	-- Set casted spell
	if( ShadowUF.db.profile.units[frame.unitType].castBar.name.enabled ) then
		cast.name:SetText(spell)
		cast.name:SetAlpha(ShadowUF.db.profile.bars.alpha)
		cast.name:Show()
	end

	-- Show cast time
	if( cast.time.enabled ) then
		cast.time:SetAlpha(1)
		cast.time:Show()
	end

	-- Set spell icon
	if( ShadowUF.db.profile.units[frame.unitType].castBar.icon ~= "HIDE" ) then
		frame.castBar.icon:SetTexture(icon)
		frame.castBar.icon:Show()
	end

	-- BigWigs Spell Name Override
	local isSecretID = _G.issecretvalue and _G.issecretvalue(spellID)
	if (not isSecretID and BigWigsAPI and BigWigsAPI.GetSpellRename and ShadowUF.db.profile.bossmodSpellRename and spellID) then
		spell = BigWigsAPI.GetSpellRename(spellID) or spell
	end

	-- Setup cast info
	cast.isChannelled = channelled
	cast.usingDurationObject = nil
	
	
	-- Check if time values are secret
	local hasSecretTimes = _G.issecretvalue and (_G.issecretvalue(startTime) or _G.issecretvalue(endTime))
	
	if (hasSecretTimes) then
		local durationObj
		if (channelled) then
			if (UnitEmpoweredChannelDuration) then durationObj = UnitEmpoweredChannelDuration(frame.unit) end
			if (not durationObj and UnitChannelDuration) then durationObj = UnitChannelDuration(frame.unit) end
		else
			if (UnitCastingDuration) then durationObj = UnitCastingDuration(frame.unit) end
		end
		
		if (durationObj and type(durationObj) == "userdata") then
			cast.usingDurationObject = true
			cast.durationObject = durationObj
			
			if (cast.SetTimerDuration) then
				local direction = channelled and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
				cast:SetMinMaxValues(0, 1)
				cast:SetTimerDuration(durationObj, Enum.StatusBarInterpolation.Immediate, direction)
			end
			
			-- For fake values
			cast.startTime = GetTime()
			cast.endTime = cast.startTime + 1
			cast.endSeconds = 1
			cast.elapsed = 0
		end
	else
		-- Non-secret values
		local startSeconds = startTime / 1000
		local endSeconds = endTime / 1000
	
		cast.startTime = startSeconds
		cast.endTime = endSeconds
		cast.endSeconds = cast.endTime - cast.startTime
		cast.elapsed = cast.isChannelled and cast.endSeconds or 0
		cast.durationObject = nil
		
		cast:SetMinMaxValues(0, cast.endSeconds)
		cast:SetValue(cast.elapsed)
	end
	
	cast.spellName = spell
	cast.spellID = spellID
	cast.castID = safeCastID(channelled and spellID or castID)
	cast.pushback = 0
	cast.lastUpdate = cast.startTime
	
	cast:SetAlpha(ShadowUF.db.profile.bars.alpha)
	cast:Show()

	if( cast.isChannelled ) then
		cast:SetScript("OnUpdate", channelOnUpdate)
	else
		cast:SetScript("OnUpdate", castOnUpdate)
	end
	
	-- Uninterruptible overlay (handles secret values and animates with bar)
	local overlay = frame.castBar.uninterruptibleOverlay
	if (overlay) then
		-- Animate overlay same as main bar
		if (cast.usingDurationObject and cast.durationObject) then
			if (overlay.SetTimerDuration) then
				local direction = channelled and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
				overlay:SetMinMaxValues(0, 1)
				overlay:SetTimerDuration(cast.durationObject, Enum.StatusBarInterpolation.Immediate, direction)
			end
		else
			overlay:SetMinMaxValues(0, cast.endSeconds)
			overlay:SetValue(cast.elapsed)
		end
		-- Show/hide based on notInterruptible (handles secret values)
		if (overlay.SetAlphaFromBoolean) then
			overlay:SetAlphaFromBoolean(notInterruptible, 1, 0)
		end
	end
	
	-- Always use cast/channel color, overlay handles the non-interruptible visual
	if( cast.isChannelled ) then
		setBarColor(cast, ShadowUF.db.profile.castColors.channel.r, ShadowUF.db.profile.castColors.channel.g, ShadowUF.db.profile.castColors.channel.b)
	else
		setBarColor(cast, ShadowUF.db.profile.castColors.cast.r, ShadowUF.db.profile.castColors.cast.g, ShadowUF.db.profile.castColors.cast.b)
	end
end

-- Trigger checks on fake cast
function Cast:UpdateFakeCast(f)
	local monitor = f.castBar.monitor
	monitor.durationObj = nil
	monitor.spellName = nil
	monitor.spellID = nil
	monitorFakeCast(monitor)
end
