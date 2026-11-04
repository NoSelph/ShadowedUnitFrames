local Combat = {}
ShadowUF:RegisterModule(Combat, "combatText", ShadowUF.L["Combat text"])

-- Size multipliers against the base font, the frame scale carries them so the string itself is never stretched
local flagScales = {CRITICAL = 1.5, CRUSHING = 1.5, GLANCING = 0.75}
local actionScales = {IMMUNE = 0.75, BLOCK = 0.75}
local zeroWoundScales = {ABSORB = 0.75, BLOCK = 0.75, RESIST = 0.75}

function Combat:OnEnable(frame)
	if( not frame.combatText ) then
		frame.combatText = CreateFrame("Frame", nil, frame.highFrame)
		frame.combatText:SetFrameStrata("HIGH")
		frame.combatText.feedbackText = frame.combatText:CreateFontString(nil, "ARTWORK")
		frame.combatText.feedbackText:SetPoint("CENTER", frame.combatText, "CENTER", 0, 0)
		frame.combatText:SetFrameLevel(frame.topFrameLevel)

		frame.combatText.feedbackStartTime = 0
		frame.combatText:SetScript("OnUpdate", CombatFeedback_OnUpdate)
		frame.combatText:SetHeight(1)
		frame.combatText:SetWidth(1)
	end

	frame:RegisterUnitEvent("UNIT_COMBAT", self, "Update")
end

function Combat:OnLayoutApplied(frame, config)
	ShadowUF.Layout:ToggleVisibility(frame.combatText, frame.visibility.combatText)
	if( frame.visibility.combatText ) then
		local font = ShadowUF.db.profile.font
		if( font.shadowEnabled and font.shadowColor and font.shadowX and font.shadowY ) then
			ShadowUF:SetFontAndShadow(frame.combatText.feedbackText, ShadowUF.Layout.mediaPath.font, font.size, "OUTLINE", font.shadowColor.r, font.shadowColor.g, font.shadowColor.b, font.shadowColor.a, font.shadowX, font.shadowY)
		else
			ShadowUF:SetFontAndShadow(frame.combatText.feedbackText, ShadowUF.Layout.mediaPath.font, font.size, "OUTLINE")
		end
		ShadowUF.Layout:AnchorFrame(frame, frame.combatText, config.combatText)
	end
end

function Combat:OnDisable(frame)
	frame:UnregisterAll(self)
end

-- The amount is secret, so nothing compares it and nothing measures the string built from it, size and color come from the plain action and flags
function Combat:Update(frame, event, unit, action, flags, amount, schoolMask)
	if( not frame.visibility.combatText ) then return end

	local text, scale = "", 1
	local r, g, b = 1, 1, 1
	if( action == "WOUND" ) then
		-- The zero damage words are only reachable while the amount is plain
		if( issecretvalue(amount) or amount ~= 0 ) then
			scale = flagScales[flags] or 1
			if( schoolMask ~= Enum.Damageclass.MaskPhysical ) then b = 0 end
			text = BreakUpLargeNumbers(amount)
			if( flags == "BLOCK_REDUCED" ) then text = COMBAT_TEXT_BLOCK_REDUCED:format(text) end
		elseif( zeroWoundScales[flags] ) then
			text, scale = CombatFeedbackText[flags], zeroWoundScales[flags]
		else
			text = CombatFeedbackText.MISS
		end
	elseif( action == "HEAL" ) then
		text, r, b = BreakUpLargeNumbers(amount), 0, 0
		if( flags == "CRITICAL" ) then scale = 1.5 end
	elseif( action == "ENERGIZE" ) then
		text, r, g, b = BreakUpLargeNumbers(amount), 0.41, 0.8, 0.94
		if( flags == "CRITICAL" ) then scale = 1.5 end
	else
		text, scale = CombatFeedbackText[action] or "", actionScales[action] or 1
	end

	local fontSize = ShadowUF.db.profile.font.size
	frame.combatText:SetScale((fontSize + 1) * scale / fontSize)
	frame.combatText.feedbackText:SetText(text)
	frame.combatText.feedbackText:SetTextColor(r, g, b)
	frame.combatText.feedbackText:SetAlpha(0)
	frame.combatText.feedbackText:Show()
	frame.combatText.feedbackStartTime = GetTime()
end
