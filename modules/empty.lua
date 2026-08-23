local Empty = {}
local fallbackColor
local issecretvalue = _G.issecretvalue
ShadowUF:RegisterModule(Empty, "emptyBar", ShadowUF.L["Empty bar"], true)

function Empty:OnEnable(frame)
	frame.emptyBar = frame.emptyBar or ShadowUF.Units:CreateBar(frame)
	frame.emptyBar:SetMinMaxValues(0, 1)
	frame.emptyBar:SetValue(0)

	fallbackColor = fallbackColor or {r = 0, g = 0, b = 0}
end

function Empty:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Empty:OnLayoutApplied(frame)
	if( frame.visibility.emptyBar ) then
		local color = frame.emptyBar.background.overrideColor or fallbackColor
		frame.emptyBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)

		if( ShadowUF.db.profile.units[frame.unitType].emptyBar.reactionType or ShadowUF.db.profile.units[frame.unitType].emptyBar.class ) then
			frame:RegisterUnitEvent("UNIT_FACTION", self, "UpdateColor")
			frame:RegisterUpdateFunc(self, "UpdateColor")
		else
			self:OnDisable(frame)
		end
	end
end

function Empty:UpdateColor(frame)
	local color
	local reactionType = ShadowUF.db.profile.units[frame.unitType].emptyBar.reactionType

	if( ( reactionType == "npc" or reactionType == "both" ) and not UnitPlayerControlled(frame.unitSUF) and UnitIsTapDenied(frame.unitSUF) and UnitCanAttack("player", frame.unitSUF) ) then
		color = ShadowUF.db.profile.healthColors.tapped
	elseif( not UnitPlayerOrPetInRaid(frame.unitSUF) and not UnitPlayerOrPetInParty(frame.unitSUF) and ( ( ( reactionType == "player" or reactionType == "both" ) and UnitIsPlayer(frame.unitSUF) and not UnitIsFriend(frame.unitSUF, "player") ) or ( ( reactionType == "npc" or reactionType == "both" ) and not UnitIsPlayer(frame.unitSUF) ) ) ) then
		if( not UnitIsFriend(frame.unitSUF, "player") and UnitPlayerControlled(frame.unitSUF) ) then
			if( UnitCanAttack("player", frame.unitSUF) ) then
				color = ShadowUF.db.profile.healthColors.hostile
			else
				color = ShadowUF.db.profile.healthColors.enemyUnattack
			end
		elseif( UnitReaction(frame.unitSUF, "player") ) then
			local reaction = UnitReaction(frame.unitSUF, "player")
			if( reaction > 4 ) then
				color = ShadowUF.db.profile.healthColors.friendly
			elseif( reaction == 4 ) then
				color = ShadowUF.db.profile.healthColors.neutral
			elseif( reaction < 4 ) then
				color = ShadowUF.db.profile.healthColors.hostile
			end
		end
	elseif( ShadowUF.db.profile.units[frame.unitType].emptyBar.class and ( UnitIsPlayer(frame.unitSUF) or UnitCreatureFamily(frame.unitSUF) or UnitPlayerOrPetInRaid(frame.unitSUF) or UnitPlayerOrPetInParty(frame.unitSUF) ) ) then
		local class = UnitCreatureFamily(frame.unitSUF) or frame:UnitClassToken()
		if class and not (issecretvalue and issecretvalue(class)) then
			color = ShadowUF.db.profile.classColors[class]
		end
	end

	color = color or frame.emptyBar.background.overrideColor or fallbackColor
	frame.emptyBar.background:SetVertexColor(color.r, color.g, color.b, ShadowUF.db.profile.bars.alpha)
end

