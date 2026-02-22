local IncAbsorb = setmetatable({["frameKey"] = "incAbsorb", ["colorKey"] = "incAbsorb", ["frameLevelMod"] = 3}, {__index = ShadowUF.IncHeal})
ShadowUF:RegisterModule(IncAbsorb, "incAbsorb", ShadowUF.L["Incoming absorbs"])

function IncAbsorb:OnEnable(frame)
	frame.incAbsorb = frame.incAbsorb or ShadowUF.Units:CreateBar(frame)

	-- Ensure shared calculator exists
	if( not frame.healCalc ) then
		frame.healCalc = CreateUnitHealPredictionCalculator()
		frame.healCalc:SetHealAbsorbMode(1)
	end

	-- All prediction events
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")

	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

-- OnLayoutApplied inherited from IncHeal

function IncAbsorb:UpdateFrame(frame)
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	if( not self:PopulateCalculator(frame) ) then
		frame[self.frameKey].total = nil
		frame[self.frameKey]:Hide()
		return
	end

	local calc = frame.healCalc
	local amount = calc:GetTotalDamageAbsorbs()
	local maxHealth = calc:GetMaximumHealth()

	-- Stack incoming heals + heal absorbs for visual layering
	if( not calc:HasSecretValues() ) then
		if( frame.visibility.incHeal ) then
			amount = amount + calc:GetTotalIncomingHeals()
		end
		if( frame.visibility.healAbsorb ) then
			amount = amount + calc:GetTotalHealAbsorbs()
		end
	end

	self:PositionBar(frame, amount, maxHealth)
end
