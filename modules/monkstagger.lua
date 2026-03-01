local Stagger = {}
ShadowUF:RegisterModule(Stagger, "staggerBar", ShadowUF.L["Stagger bar"], true, "MONK", SPEC_MONK_BREWMASTER)

function Stagger:OnEnable(frame)
	frame.staggerBar = frame.staggerBar or ShadowUF.Units:CreateBar(frame)
	frame.staggerBar.timeElapsed = 0
	frame.staggerBar.parent = frame
	frame.staggerBar:SetScript("OnUpdate", function(f, elapsed)
		f.timeElapsed = f.timeElapsed + elapsed
		if( f.timeElapsed < 0.25 ) then return end
		f.timeElapsed = f.timeElapsed - 0.25

		Stagger:Update(f.parent)
	end)

	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateMinMax")
	frame:RegisterUpdateFunc(self, "UpdateMinMax")
end

function Stagger:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Stagger:OnLayoutApplied(frame)
	if( frame.staggerBar ) then
		frame.staggerBar.colorState = nil
	end
end

function Stagger:UpdateMinMax(frame)
	local ok, maxHealth = pcall(UnitHealthMax, frame.unit)
	if not ok then return end
	frame.staggerBar.maxHealth = maxHealth
	frame.staggerBar:SetMinMaxValues(0, maxHealth)

	self:Update(frame)
end

-- Arithmetic on stagger may fail when UnitStagger returns a secret (e.g. War Mode)
function Stagger.ComputeColorState(stagger, maxHealth)
	maxHealth = maxHealth or 1
	local percent = maxHealth > 0 and stagger / maxHealth or 0
	if percent >= STAGGER_STATES.RED.threshold then
		return "STAGGER_RED"
	elseif percent >= STAGGER_STATES.YELLOW.threshold then
		return "STAGGER_YELLOW"
	else
		return "STAGGER_GREEN"
	end
end

function Stagger:Update(frame)
	local stagger = UnitStagger(frame.unit)
	if not stagger then return end

	frame.staggerBar:SetValue(stagger)

	local ok, state = pcall(Stagger.ComputeColorState, stagger, frame.staggerBar.maxHealth)
	if ok and state and frame.staggerBar.colorState ~= state then
		frame.staggerBar.colorState = state
		local c = ShadowUF.db.profile.powerColors[state]
		frame:SetBarColor("staggerBar", c.r, c.g, c.b)
	end
end
