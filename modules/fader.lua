local Fader = {}
local powerDepletes = {[Enum.PowerType.Mana] = true, [Enum.PowerType.Energy] = true, [Enum.PowerType.Focus] = true}
ShadowUF:RegisterModule(Fader, "fader", ShadowUF.L["Combat fader"])

local canCurve = C_CurveUtil and C_CurveUtil.CreateCurve and C_CurveUtil.EvaluateColorValueFromBoolean and UnitHealthPercent and true or false

local function newCurve()
	local curve = C_CurveUtil.CreateCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	return curve
end

local function setCurve(curve, low, full)
	curve:ClearPoints()
	curve:AddPoint(0, low)
	curve:AddPoint(1, full)
end

local function healthValue(frame, curve, fallback)
	local ok, value = pcall(UnitHealthPercent, frame.unitSUF, true, curve)
	if( ok and value ) then return value end
	return fallback
end

-- With the health curves on, the idle fade lives in each curve's full-health point sliding toward the inactive alpha while the wounded point stays put, so a wounded unit never fades and a full one fades on schedule
-- Range writes join through the stored range state, the plain or secret boolean picks between the in-range and out-of-range curves natively
local function applyHealthAlpha(frame)
	local fader = frame.fader
	local config = ShadowUF.db.profile.units[frame.unitType].fader
	local progress, inactive = fader.progress, config.inactiveAlpha
	if( frame.rangeSet ) then
		local inAlpha, oorAlpha = frame.rangeInAlpha, frame.rangeOorAlpha
		if( fader.builtProgress ~= progress or fader.builtIn ~= inAlpha or fader.builtOOR ~= oorAlpha ) then
			setCurve(fader.curveIn, inAlpha, inAlpha + (inactive - inAlpha) * progress)
			setCurve(fader.curveOOR, oorAlpha, oorAlpha + (inactive - oorAlpha) * progress)
			fader.builtProgress, fader.builtIn, fader.builtOOR = progress, inAlpha, oorAlpha
		end
		frame:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(frame.rangeInRange, healthValue(frame, fader.curveIn, inAlpha), healthValue(frame, fader.curveOOR, oorAlpha)))
	else
		local combat = config.combatAlpha
		if( fader.builtProgress ~= progress or fader.builtIn ~= combat or fader.builtOOR ~= nil ) then
			setCurve(fader.curve, combat, combat + (inactive - combat) * progress)
			fader.builtProgress, fader.builtIn, fader.builtOOR = progress, combat, nil
		end
		frame:SetAlpha(healthValue(frame, fader.curve, combat))
	end
end

local function faderUpdate(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	local frame = self.parent
	local done = self.timeElapsed >= self.fadeTime
	local fraction = done and 1 or self.timeElapsed / self.fadeTime
	if( self.healthAware ) then
		self.progress = self.progressStart + (self.progressEnd - self.progressStart) * fraction
		applyHealthAlpha(frame)
	else
		frame:SetAlpha(self.alphaStart + (self.alphaEnd - self.alphaStart) * fraction)
	end

	if( done ) then
		self:Hide()
		if( self.fadeType == "in" and not self.healthAware ) then
			frame:DisableRangeAlpha(false)
		end
	end
end

local function startFading(frame, fadeType, speedy)
	local fader = frame.fader
	if( fader.fadeType == fadeType ) then return false end
	local config = ShadowUF.db.profile.units[frame.unitType].fader
	fader.fadeType = fadeType
	fader.fadeTime = speedy and 0.15 or fadeType == "in" and 0.25 or 0.75
	fader.timeElapsed = 0
	if( fader.healthAware ) then
		fader.progressStart = fader.progress
		fader.progressEnd = fadeType == "in" and 0 or 1
	else
		if( fadeType == "out" ) then
			frame:DisableRangeAlpha(true)
		end
		-- GetAlpha reads secret once the range module used SetAlphaFromBoolean, the previous fade target is the best approximation then
		if( frame.HasSecretAspect and frame:HasSecretAspect(Enum.SecretAspect.Alpha) ) then
			fader.alphaStart = fader.alphaEnd or 1.0
		else
			fader.alphaStart = frame:GetAlpha()
		end
		fader.alphaEnd = fadeType == "in" and config.combatAlpha or config.inactiveAlpha
	end
	fader:Show()
	return true
end

local function powerValues(unit)
	return UnitPowerType(unit), UnitPower(unit), UnitPowerMax(unit)
end

-- Power only counts while it reads plain, a secret reading never triggers the fade
local function powerNotFull(unit)
	local ok, powerType, power, maxPower = pcall(powerValues, unit)
	if( not ok or not powerDepletes[powerType] or issecretvalue(power) or issecretvalue(maxPower) ) then return false end
	return power ~= maxPower
end

local function configure(frame)
	local fader = frame.fader
	fader.healthAware = canCurve and ShadowUF.db.profile.units[frame.unitType].fader.healthAware or false
	fader.routeRange = fader.healthAware
	fader.builtProgress = nil
	if( fader.healthAware and not fader.curve ) then
		fader.curve, fader.curveIn, fader.curveOOR = newCurve(), newCurve(), newCurve()
	end
end

-- Range writes land here while the health curves own the alpha, a running fade picks the new state up on its next tick
function Fader:ApplyRange(frame)
	if( not frame.fader:IsShown() ) then
		applyHealthAlpha(frame)
	end
end

function Fader:OnEnable(frame)
	local fader = frame.fader
	if( not fader ) then
		fader = CreateFrame("Frame", nil, frame)
		fader.parent = frame
		fader:SetScript("OnUpdate", faderUpdate)
		fader:Hide()
		frame.fader = fader
	end
	fader.active = true
	fader.fadeType = nil
	fader.progress = 0
	configure(frame)

	frame:RegisterNormalEvent("PLAYER_REGEN_ENABLED", self, "Update")
	frame:RegisterNormalEvent("PLAYER_REGEN_DISABLED", self, "Update")
	frame:RegisterUpdateFunc(self, "Update")

	if( InCombatLockdown() ) then
		Fader:PLAYER_REGEN_DISABLED(frame, "PLAYER_REGEN_DISABLED")
	else
		Fader:PLAYER_REGEN_ENABLED(frame, "PLAYER_REGEN_ENABLED")
	end
end

function Fader:OnLayoutApplied(frame)
	if( frame.visibility.fader ) then
		frame.fader.fadeType = nil
		configure(frame)
		frame:DisableRangeAlpha(false)
	end
end

function Fader:OnDisable(frame)
	frame:UnregisterAll(self)
	if( frame.fader ) then
		frame.fader.active = false
		frame.fader.routeRange = false
		frame.fader.fadeType = nil
		frame.fader:Hide()
	end
	frame:SetAlpha(1.0)
	frame:DisableRangeAlpha(false)
end

-- While we're in combat, we don't care about the other events so we might as well unregister them
function Fader:PLAYER_REGEN_ENABLED(frame, event)
	self:Update(frame, event)
	frame:RegisterNormalEvent("PLAYER_TARGET_CHANGED", self, "Update")
	frame:RegisterNormalEvent("UNIT_SPELLCAST_CHANNEL_START", self, "CastStart")
	frame:RegisterNormalEvent("UNIT_SPELLCAST_CHANNEL_STOP", self, "CastStop")
	frame:RegisterNormalEvent("UNIT_SPELLCAST_START", self, "CastStart")
	frame:RegisterNormalEvent("UNIT_SPELLCAST_STOP", self, "CastStop")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "Update")
	frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "Update")
end

function Fader:PLAYER_REGEN_DISABLED(frame, event)
	self:Update(frame, event)
	frame:UnregisterSingleEvent("PLAYER_TARGET_CHANGED", self)
	frame:UnregisterSingleEvent("UNIT_SPELLCAST_CHANNEL_START", self)
	frame:UnregisterSingleEvent("UNIT_SPELLCAST_CHANNEL_STOP", self)
	frame:UnregisterSingleEvent("UNIT_SPELLCAST_START", self)
	frame:UnregisterSingleEvent("UNIT_SPELLCAST_STOP", self)
	frame:UnregisterSingleEvent("UNIT_HEALTH", self)
	frame:UnregisterSingleEvent("UNIT_POWER_FREQUENT", self)
	frame:UnregisterSingleEvent("UNIT_MAXHEALTH", self)
	frame:UnregisterSingleEvent("UNIT_MAXPOWER", self)
end

local activeCastID
function Fader:CastStart(frame, event, unit, id)
	if( unit ~= "player" or activeCastID == id ) then return end
	activeCastID = id

	frame.fader.playerCasting = true
	self:Update(frame)
end

function Fader:CastStop(frame, event, unit, id)
	if( unit ~= "player" or activeCastID ~= id ) then return end
	activeCastID = nil

	frame.fader.playerCasting = nil
	self:Update(frame)
end

function Fader:Update(frame, event)
	local fader = frame.fader
	local started
	if( InCombatLockdown() or event == "PLAYER_REGEN_DISABLED" ) then
		started = startFading(frame, "in")
	elseif( fader.playerCasting ) then
		started = startFading(frame, "in", true)
	elseif( ( frame.unitType == "player" and UnitExists("target") ) or powerNotFull(frame.unitSUF) ) then
		started = startFading(frame, "in")
	else
		started = startFading(frame, "out")
	end

	-- Settled with the curves on, a health change still needs a fresh evaluation
	if( not started and fader.healthAware and not fader:IsShown() ) then
		applyHealthAlpha(frame)
	end
end
