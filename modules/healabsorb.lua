local HealAbsorb = setmetatable({["frameKey"] = "healAbsorb", ["colorKey"] = "healAbsorb", ["frameLevelMod"] = 1}, {__index = ShadowUF.IncHeal})
ShadowUF:RegisterModule(HealAbsorb, "healAbsorb", ShadowUF.L["Healing absorb"])

function HealAbsorb:OnEnable(frame)
	frame.healAbsorb = frame.healAbsorb or ShadowUF.Units:CreateBar(frame)

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

function HealAbsorb:UpdateFrame(frame)
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	if( not self:PopulateCalculator(frame) ) then
		frame[self.frameKey].total = nil
		frame[self.frameKey]:Hide()
		return
	end

	local calc = frame.healCalc
	local amount = calc:GetTotalHealAbsorbs()
	local maxHealth = calc:GetMaximumHealth()

	self:PositionBar(frame, amount, maxHealth)
end
