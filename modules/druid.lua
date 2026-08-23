local Druid = {}
ShadowUF:RegisterModule(Druid, "druidBar", ShadowUF.L["Druid mana bar"], true, "DRUID")

function Druid:OnEnable(frame)
	frame.druidBar = frame.druidBar or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "PowerChanged")

	frame:RegisterUpdateFunc(self, "PowerChanged")
	frame:RegisterUpdateFunc(self, "Update")
end

function Druid:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Druid:OnLayoutApplied(frame)
	if( not frame.visibility.druidBar ) then return end

	local color = ShadowUF.db.profile.powerColors.MANA
	frame:SetBarColor("druidBar", color.r, color.g, color.b)
end

function Druid:PowerChanged(frame)
	local ok, pt = pcall(UnitPowerType, frame.unitSUF)
	if not ok then return end
	local visible = pt ~= Enum.PowerType.Mana and not frame.inVehicle
	local type = visible and "RegisterUnitEvent" or "UnregisterSingleEvent"

	frame[type](frame, "UNIT_POWER_FREQUENT", self, "Update")
	frame[type](frame, "UNIT_MAXPOWER", self, "Update")
	ShadowUF.Layout:SetBarVisibility(frame, "druidBar", visible)

	if( visible ) then self:Update(frame) end
end

function Druid:Update(frame, event, unit, powerType)
	if( powerType and powerType ~= "MANA" ) then return end
	local okMax, max = pcall(UnitPowerMax, frame.unitSUF, Enum.PowerType.Mana)
	local okPow, pow = pcall(UnitPower, frame.unitSUF, Enum.PowerType.Mana)
	if not okMax or not okPow then return end
	frame.druidBar:SetMinMaxValues(0, max)
	frame.druidBar:SetValue(UnitIsDeadOrGhost(frame.unitSUF) and 0 or not UnitIsConnected(frame.unitSUF) and 0 or pow)
end
