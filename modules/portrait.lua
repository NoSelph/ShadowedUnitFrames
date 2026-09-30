local Portrait = {}
ShadowUF:RegisterModule(Portrait, "portrait", ShadowUF.L["Portrait"])

-- If the camera isn't reset OnShow, it'll show the entire character instead of just the head, odd I know
local function resetCamera(self)
	self:SetPortraitZoom(1)
end

local function resetGUID(self)
	self.guid = nil
	self._nextSecretUpdate = nil
end

-- Crops the square portrait image to fill the area without stretching, the ratio is cached at layout time because sizes read back secret once the bars anchoring the portrait carry secret values
local function applyCover(frame, texture)
	local ratio = frame.portrait.coverRatio
	if( not ratio ) then
		texture:SetTexCoord(0.10, 0.90, 0.10, 0.90)
	elseif( ratio >= 1 ) then
		local half = 0.40 / ratio
		texture:SetTexCoord(0.10, 0.90, 0.50 - half, 0.50 + half)
	else
		local half = 0.40 * ratio
		texture:SetTexCoord(0.50 - half, 0.50 + half, 0.10, 0.90)
	end
end

function Portrait:OnEnable(frame)
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self, "UpdateFunc")
	frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", self, "Update")

	frame:RegisterUpdateFunc(self, "UpdateFunc")
end

function Portrait:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Portrait:OnPreLayoutApply(frame, config)
	if( not frame.visibility.portrait ) then return end

	if( config.portrait.type == "3D" ) then
		if( not frame.portraitModel ) then
			frame.portraitModel = CreateFrame("PlayerModel", nil, frame)
			frame.portraitModel:SetScript("OnShow", resetCamera)
			frame.portraitModel:SetScript("OnHide", resetGUID)
			frame.portraitModel.parent = frame

			-- 2D fallback texture for instanced content where SetUnit is blocked
			frame.portraitModel.fallbackTexture = frame.portraitModel:CreateTexture(nil, "ARTWORK")
			frame.portraitModel.fallbackTexture:SetAllPoints(frame.portraitModel)
			frame.portraitModel.fallbackTexture:Hide()
		end

		frame.portrait = frame.portraitModel
		frame.portrait:Show()

		ShadowUF.Layout:ToggleVisibility(frame.portraitTexture, false)
	else
		frame.portraitTexture = frame.portraitTexture or frame:CreateTexture(nil, "ARTWORK")
		frame.portrait = frame.portraitTexture
		frame.portrait:Show()

		ShadowUF.Layout:ToggleVisibility(frame.portraitModel, false)
	end
end

function Portrait:OnLayoutWidgets(frame)
	if( not frame.visibility.portrait or not frame.portrait ) then return end

	local width, height = frame.portrait:GetSize()
	if( issecretvalue(width) or issecretvalue(height) or width <= 0 or height <= 0 ) then
		frame.portrait.coverRatio = nil
	else
		frame.portrait.coverRatio = width / height
	end

	local type = ShadowUF.db.profile.units[frame.unitType].portrait.type
	if( type == "2D" ) then
		applyCover(frame, frame.portrait)
	elseif( type == "3D" ) then
		applyCover(frame, frame.portraitModel.fallbackTexture)
	end
end

function Portrait:UpdateFunc(frame)
	-- Portrait models can't be updated unless the GUID changed or else you have the animation jumping around
	if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "3D" ) then
		local okG, guid = pcall(UnitGUID, frame.unitOwner)
		if not okG then guid = nil end
		local prev = frame.portrait.guid

		-- Only compare when it is safe (not secret + caller can access the value).
		local canCompare = false
		
		-- Use Blizzard globals for secret checks if available
		if (_G.canaccessvalue and _G.issecretvalue) then
			canCompare = guid ~= nil and prev ~= nil and 
						canaccessvalue(guid) and canaccessvalue(prev) and 
						(not issecretvalue(guid)) and (not issecretvalue(prev))
		else
			-- Fallback: basic type check (if globals missing)
			canCompare = type(guid) == "string" and type(prev) == "string"
		end

		if canCompare then
			if prev ~= guid then
				self:Update(frame)
			end
		else
			-- If we cannot compare (secret/tainted), do a throttled update so we do not jitter every frame (credits Xinux_vg).
			local now = GetTime()
			if not frame.portrait._nextSecretUpdate or now >= frame.portrait._nextSecretUpdate then
				self:Update(frame)
				frame.portrait._nextSecretUpdate = now + 0.50
			end
		end

		-- Storing secrets is allowed; we just do not compare them unless safe.
		frame.portrait.guid = guid
	else
		self:Update(frame)
	end
end

function Portrait:Update(frame, event)
	local type = ShadowUF.db.profile.units[frame.unitType].portrait.type
	-- Use class thingy
	if( type == "class" ) then
		local classToken = frame:UnitClassToken()
		if( classToken ) then
			local classIconAtlas = GetClassAtlas(classToken)
			if( classIconAtlas ) then
				frame.portrait:SetAtlas(classIconAtlas)
			else
				frame.portrait:SetTexture("")
			end
		else
			frame.portrait:SetTexture("")
		end
	-- Use 2D character image
	elseif( type == "2D" ) then
		applyCover(frame, frame.portrait)
		SetPortraitTexture(frame.portrait, frame.unitOwner)
	-- Using 3D portrait, but the players not in range so swap to question mark
	elseif( not UnitIsVisible(frame.unitOwner) or not UnitIsConnected(frame.unitOwner) ) then
		frame.portrait:ClearModel()
		frame.portrait:SetModelScale(5.5)
		frame.portrait:SetPosition(0, 0, -0.8)
		frame.portrait:SetModel("Interface\\Buttons\\talktomequestionmark.m2")
		frame.portraitModel.fallbackTexture:Hide()

	-- Use animated 3D portrait, with 2D fallback when unit identity is secret
	else
		local guid = UnitGUID(frame.unitOwner)
		if( guid and issecretvalue(guid) ) then
			-- Unit identity is classified — SetUnit won't work, fallback to 2D
			frame.portrait:ClearModel()
			local fb = frame.portraitModel.fallbackTexture
			applyCover(frame, fb)
			SetPortraitTexture(fb, frame.unitOwner)
			fb:Show()
		else
			frame.portraitModel.fallbackTexture:Hide()
			frame.portrait:ClearModel()
			frame.portrait:SetUnit(frame.unitOwner)
			frame.portrait:SetPortraitZoom(1)
			frame.portrait:SetPosition(0, 0, 0)
			frame.portrait:Show()
		end
	end
end




