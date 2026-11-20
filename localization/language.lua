local _, ShadowUF = ...
local clientLocale = ShadowUF.L
local localizedTables = setmetatable({}, {__mode = "k"})

-- Keep L and all published label tables stable for consumers holding a reference.
ShadowUF.L = setmetatable({}, {__index = clientLocale})

function ShadowUF:LocalizedLabels(keys)
	local labels = {}
	for id, key in pairs(keys) do labels[id] = self.L[key] end
	localizedTables[labels] = keys
	return labels
end

function ShadowUF:SetDisplayLocale(locale)
	local dictionary = clientLocale
	if locale == "enUS" then dictionary = self.englishLocale end
	if locale == "ruRU" then dictionary = self.russianLocale end
	getmetatable(self.L).__index = dictionary
	for labels, keys in pairs(localizedTables) do
		for id, key in pairs(keys) do labels[id] = self.L[key] end
	end
	for _, module in pairs(self.modules) do
		if module.moduleNameKey then module.moduleName = self.L[module.moduleNameKey] end
	end
end
