local Combat = {}
ShadowUF:RegisterModule(Combat, "combatText", ShadowUF.L["Combat text"])

function Combat:OnEnable(frame)
	if( not frame.combatText ) then
		frame.combatText = CreateFrame("Frame", nil, frame.highFrame)
		frame.combatText:SetFrameStrata("HIGH")
		frame.combatText.feedbackText = frame.combatText:CreateFontString(nil, "ARTWORK")
		frame.combatText.feedbackText:SetPoint("CENTER", frame.combatText, "CENTER", 0, 0)
		frame.combatText:SetFrameLevel(frame.topFrameLevel)

		frame.combatText.feedbackStartTime = 0
		frame.combatText.feedbackFontHeight = ShadowUF.db.profile.font.size + 1
		frame.combatText:SetScript("OnUpdate", CombatFeedback_OnUpdate)
		frame.combatText:SetHeight(1)
		frame.combatText:SetWidth(1)
	end

	frame:RegisterUnitEvent("UNIT_COMBAT", self, "Update")
end

function Combat:OnLayoutApplied(frame, config)
	-- Update feedback text
	ShadowUF.Layout:ToggleVisibility(frame.combatText, frame.visibility.combatText)
	if( frame.visibility.combatText ) then
		frame.combatText.feedbackFontHeight = ShadowUF.db.profile.font.size + 1
		frame.combatText.fontPath = ShadowUF.Layout.mediaPath.font

		ShadowUF.Layout:SetupFontString(frame.combatText.feedbackText, 1)
		ShadowUF.Layout:AnchorFrame(frame, frame.combatText, config.combatText)
	end
end

function Combat:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Combat:Update(frame, event, unit, type, ...)
	-- Blizzard's CombatFeedback errors on a nil font height (the layout only sets it when combat text is visible)
	if( not frame.visibility.combatText or not frame.combatText.feedbackFontHeight ) then return end
	CombatFeedback_OnCombatEvent(frame.combatText, type, ...)
	if( type == "IMMUNE" ) then
		frame.combatText.feedbackText:SetTextHeight(frame.combatText.feedbackFontHeight * 0.75)
	end

	-- Increasing the font size will make the text look pixelated, however scaling it up will make it look smooth and awesome
	local scale = frame.combatText.feedbackText:GetStringHeight() / ShadowUF.db.profile.font.size
	if( scale > 0 ) then
		frame.combatText:SetScale(scale)
		local cf = ShadowUF.db.profile.font
		local cr, cg, cb, ca = frame.combatText.feedbackText:GetTextColor()
		if( cf.shadowEnabled and cf.shadowColor and cf.shadowX and cf.shadowY ) then
			ShadowUF:SetFontAndShadow(frame.combatText.feedbackText, frame.combatText.fontPath, cf.size, "OUTLINE", cf.shadowColor.r, cf.shadowColor.g, cf.shadowColor.b, cf.shadowColor.a, cf.shadowX, cf.shadowY)
		else
			ShadowUF:SetFontAndShadow(frame.combatText.feedbackText, frame.combatText.fontPath, cf.size, "OUTLINE")
		end
		if( cr ) then frame.combatText.feedbackText:SetTextColor(cr, cg, cb, ca) end
	end
end
