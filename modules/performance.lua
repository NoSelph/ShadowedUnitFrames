local Performance = {}
ShadowUF.Performance = Performance

-- Rate definitions: {default, min, max}
local RATES = {
	rangeCheck       = {default = 0.50, min = 0.20, max = 2.00},
	tagMonitorFast   = {default = 0.25, min = 0.10, max = 1.00},
	tagMonitorNormal = {default = 0.50, min = 0.25, max = 2.00},
	tagMonitorSlow   = {default = 1.00, min = 0.50, max = 3.00},
	fakeCastMonitor  = {default = 0.10, min = 0.05, max = 0.50},
	combatIndicator  = {default = 1.00, min = 0.50, max = 3.00},
}

function Performance:GetRate(key)
	local db = ShadowUF.db and ShadowUF.db.profile.performance
	if db and db[key] then
		local def = RATES[key]
		if def then
			return math.max(def.min, math.min(def.max, db[key]))
		end
		return db[key]
	end
	return RATES[key] and RATES[key].default or 0.5
end

function Performance:GetRateDefinition(key)
	return RATES[key]
end

function Performance:GetAllRateKeys()
	return {"rangeCheck", "tagMonitorFast", "tagMonitorNormal", "tagMonitorSlow",
			"fakeCastMonitor", "combatIndicator"}
end

local callbacks = {}

function Performance:RegisterCallback(key, func)
	callbacks[key] = callbacks[key] or {}
	table.insert(callbacks[key], func)
end

function Performance:FireCallback(key)
	local rate = self:GetRate(key)
	if callbacks[key] then
		for _, func in ipairs(callbacks[key]) do
			func(rate)
		end
	end
end
