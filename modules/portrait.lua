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

-- A live PlayerModel portrait fights with Blizzard's own model windows, but only where the two actually
-- overlap on screen, so the test is per portrait and geometric. A character sheet parked away from the
-- unit frames costs nothing, and in a raid only the portraits genuinely underneath the window go dark.
-- Extending this is just a matter of adding the frame's global name.
-- BarberShopFrame is the odd one out: it is set to all points of the screen, so it covers every portrait
-- by definition and effectively suppresses the lot. That is the right answer for a full screen scene.
local CONFLICTING_FRAMES = {"CharacterFrame", "DressUpFrame", "InspectFrame", "TransmogFrame", "CollectionsJournal", "BarberShopFrame"}

-- Both the windows and the unit frames are draggable and neither move fires an event, so the overlap is
-- re-tested on a slow timer, and only for as long as one of the windows is actually up
local CONFLICT_POLL = 0.25

-- Only frames currently drawing a 3D portrait, kept up to date by OnPreLayoutApply/OnDisable
local active3DFrames = {}
local suppressedFrames = {}
local hookedFrames = {}
local conflictVisible = false

-- Screen space rect, so two frames on different effective scales can be compared at all. Deliberately
-- not gated on visibility: a suppressed portrait is hidden and still has to be measured to know when it
-- is clear again, and a hidden frame keeps reporting the rect it was last laid out at.
local function getScreenRect(region)
	local left, bottom, width, height = region:GetRect()
	if( not left or not width or width <= 0 or height <= 0 ) then return end

	local scale = region:GetEffectiveScale()
	return left * scale, bottom * scale, (left + width) * scale, (bottom + height) * scale
end

-- Measured once per pass and compared against every portrait, rather than re-measured per portrait, which
-- in a full raid is the difference between four rects and a hundred and sixty. Slots are reused.
local conflictRects = {}

local function collectConflictRects()
	local count = 0

	for _, name in ipairs(CONFLICTING_FRAMES) do
		local conflict = _G[name]
		if( conflict and conflict:IsVisible() ) then
			local left, bottom, right, top = getScreenRect(conflict)
			if( left ) then
				count = count + 1

				local rect = conflictRects[count]
				if( not rect ) then
					rect = {}
					conflictRects[count] = rect
				end

				rect[1], rect[2], rect[3], rect[4] = left, bottom, right, top
			end
		end
	end

	return count
end

local function isPortraitCovered(model, count)
	local left, bottom, right, top = getScreenRect(model)
	if( not left ) then return false end

	for i = 1, count do
		local rect = conflictRects[i]
		if( left < rect[3] and rect[1] < right and bottom < rect[4] and rect[2] < top ) then
			return true
		end
	end

	return false
end

-- Forward declared, the poller below calls it and it starts and stops the poller in turn
local applyConflictState

local poller
local function ensurePoller()
	if( poller ) then return poller end

	poller = CreateFrame("Frame")
	poller:Hide()

	local elapsed = 0
	poller:SetScript("OnUpdate", function(self, delta)
		elapsed = elapsed + delta
		if( elapsed < CONFLICT_POLL ) then return end

		elapsed = 0
		applyConflictState()
	end)

	return poller
end

-- Single entry point for the hooks, the load on demand path and the poller, so the state is always
-- derived from what is on screen rather than from which script happened to fire
function applyConflictState()
	local count = collectConflictRects()
	conflictVisible = count > 0

	for frame in pairs(active3DFrames) do
		local model = frame.portraitModel
		if( model ) then
			local covered = conflictVisible and isPortraitCovered(model, count)

			if( covered and not suppressedFrames[frame] ) then
				suppressedFrames[frame] = true
				model:ClearModel()
				-- OnHide runs resetGUID, so the restore below always sees a changed GUID and rebuilds
				model:Hide()
			elseif( not covered and suppressedFrames[frame] ) then
				suppressedFrames[frame] = nil

				if( frame.visibility.portrait ) then
					model:Show()
					Portrait:Update(frame)
				end
			end
		end
	end

	if( conflictVisible ) then
		ensurePoller():Show()
	elseif( poller ) then
		poller:Hide()
	end
end

-- A layout pass moves the portrait after OnPreLayoutApply has run, so measuring from there reads the old
-- position. This defers to the end of the frame instead, and coalesces a whole raid worth of calls.
local syncQueued
local function queueConflictUpdate()
	if( syncQueued ) then return end

	syncQueued = true
	C_Timer.After(0, function()
		syncQueued = nil
		applyConflictState()
	end)
end

-- InspectFrame and TransmogFrame are load on demand, so the ones that don't exist yet are picked up on
-- ADDON_LOADED. Blizzard shows those right after loading them and may well beat the hook to it, hence
-- the resync afterwards instead of trusting OnShow to have fired.
local function hookConflictFrames()
	local pending
	for _, name in ipairs(CONFLICTING_FRAMES) do
		if( not hookedFrames[name] ) then
			local conflict = _G[name]
			if( conflict ) then
				hookedFrames[name] = true
				conflict:HookScript("OnShow", applyConflictState)
				conflict:HookScript("OnHide", applyConflictState)
			else
				pending = true
			end
		end
	end

	return pending
end

local watcher
local function installWatchers()
	if( watcher ) then return end

	watcher = CreateFrame("Frame")
	if( hookConflictFrames() ) then
		watcher:RegisterEvent("ADDON_LOADED")
		watcher:SetScript("OnEvent", function(self)
			if( not hookConflictFrames() ) then self:UnregisterAllEvents() end
			applyConflictState()
		end)
	end

	-- A reload with one of them still open would otherwise start out of sync
	applyConflictState()
end

function Portrait:OnEnable(frame)
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", self, "UpdateFunc")
	frame:RegisterUnitEvent("UNIT_MODEL_CHANGED", self, "Update")

	frame:RegisterUpdateFunc(self, "UpdateFunc")

	installWatchers()
end

function Portrait:OnDisable(frame)
	active3DFrames[frame] = nil
	suppressedFrames[frame] = nil
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
		active3DFrames[frame] = true

		-- Stay hidden while something covers it, applyConflictState brings it back on its own
		if( not suppressedFrames[frame] ) then
			frame.portrait:Show()
		end

		-- The layout may have moved this portrait under an open window, or out from under one
		if( conflictVisible ) then queueConflictUpdate() end

		ShadowUF.Layout:ToggleVisibility(frame.portraitTexture, false)
	else
		active3DFrames[frame] = nil
		suppressedFrames[frame] = nil

		frame.portraitTexture = frame.portraitTexture or frame:CreateTexture(nil, "ARTWORK")
		frame.portrait = frame.portraitTexture
		frame.portrait:Show()

		ShadowUF.Layout:ToggleVisibility(frame.portraitModel, false)
	end
end

function Portrait:UpdateFunc(frame)
	-- Portrait models can't be updated unless the GUID changed or else you have the animation jumping around
	if( ShadowUF.db.profile.units[frame.unitType].portrait.type == "3D" ) then
		-- No model work at all while this portrait is covered, not even the GUID bookkeeping
		if( suppressedFrames[frame] ) then return end

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

	-- Never touch the model while a window covers it, this also catches the event driven updates
	if( type == "3D" and suppressedFrames[frame] ) then return end

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
		frame.portrait:SetTexCoord(0.10, 0.90, 0.10, 0.90)
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
			fb:SetTexCoord(0.10, 0.90, 0.10, 0.90)
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




