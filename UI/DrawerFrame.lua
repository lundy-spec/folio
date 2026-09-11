local _, Folio = ...

-- Q54: shared factory behind the bank drawer (UI/BankFrame.lua) and the
-- warband drawer (UI/WarbandFrame.lua) -- a second/third, similarly-
-- formatted window that slides out from behind the main Folio window,
-- one to the left, one to the right (config.side). Extracted once a
-- second real usage (warband) needed the exact same animation/
-- positioning/strata logic mirrored, rather than duplicating it.
--
-- Not independently movable or resizable -- each instance is an attached
-- drawer, always anchored relative to the main window's current
-- position/size, not a standalone panel a player positions on its own.
-- No corner menu, search box, or currency bar -- category management and
-- search stay in the main window; these are deliberately narrower,
-- secondary views. No independent close button either (Q52) -- a
-- drawer's lifecycle belongs to the main window and to actually being at
-- a banker, not to the player managing it as its own panel.

local DrawerFrame = {}
Folio.UI = Folio.UI or {}
Folio.UI.DrawerFrame = DrawerFrame

-- How much shorter than the main window a drawer sits, how many pixels
-- of its near edge tuck in BEHIND the main window's edge once fully open
-- (Q48 -- reads as "emerging from behind" rather than sitting flush
-- beside it), how far above main's own bottom edge it rests (Q50), and
-- the slide timings -- all purely aesthetic guesses, not verifiable
-- without seeing it live.
local HEIGHT_INSET = 100
local MIN_HEIGHT = 150
local OVERLAP = 16
local Y_OFFSET = 30
local SLIDE_OUT_DURATION = 0.25
local SLIDE_IN_DURATION = 0.2
local SHADOW_WIDTH = 20

-- Q44/Q45/Q46/Q47, all confirmed live on the original (bank-only) drawer:
-- (1) Blizzard's own bank window sits above the default ("MEDIUM")
-- strata, so a drawer needs "HIGH" once fully open to not end up covered
-- by it. (2) An Alpha animation meant to hide the brief hidden/
-- behind-main start got stuck at alpha=0 permanently -- don't trust that
-- animation type. (3) The SAME "don't trust it to persist" lesson
-- applies to the Translation itself too -- OnFinished explicitly
-- re-anchors the frame to its true resting position rather than trusting
-- the animation to have left it there. (4) A permanent "HIGH" strata
-- then meant it rendered ON TOP of the main window during the part of
-- the slide where it's supposed to be hidden BEHIND it -- "HIGH" and
-- "hidden behind main" are contradictory as a single static value.
-- Strata switches dynamically instead: "LOW" (below main's default
-- "MEDIUM") while sliding out from behind or back in behind it, "HIGH"
-- (above Blizzard's bank window) only once actually landed at rest.
local STRATA_HIDDEN = "LOW"
local STRATA_OPEN = "HIGH"

-- config = { name, title, portraitIcon, side = "LEFT" | "RIGHT" }
-- Returns an instance with Create/SetItems/Show/Hide -- everything about
-- WHICH storage/rows it displays is the caller's concern (Core/Init.lua);
-- this is purely the window shell.
function DrawerFrame.New(config)
	local self = {}

	local frame, listView
	local openAnimGroup, closeAnimGroup, openAnim, closeAnim

	-- Mirrors every side-dependent value once, up front, instead of
	-- branching on config.side throughout the rest of this instance.
	local isRight = config.side == "RIGHT"
	-- Which of the DRAWER's own corners is used for each anchor step,
	-- and which of MAIN's corner both of them reference.
	local hiddenPoint = isRight and "BOTTOMRIGHT" or "BOTTOMLEFT"
	local restPoint = isRight and "BOTTOMLEFT" or "BOTTOMRIGHT"
	local mainPoint = isRight and "BOTTOMRIGHT" or "BOTTOMLEFT"
	-- Resting anchor's x-offset direction (tuck INTO main) and the
	-- Translation's slide direction -- opposite signs for the two sides.
	local overlapSign = isRight and -1 or 1
	local slideSign = isRight and 1 or -1
	-- Shadow lives on the edge nearest main -- left edge for a
	-- right-side drawer, right edge for a left-side one -- darkest right
	-- at that edge, fading to transparent moving into the drawer's own
	-- visible content.
	local shadowPoint = isRight and "LEFT" or "RIGHT"
	local shadowFromAlpha = isRight and 0.65 or 0
	local shadowToAlpha = isRight and 0 or 0.65
	-- Content inset: whichever side sits in the OVERLAP zone needs the
	-- extra padding so the list/scrollbar clears it (Q49).
	local leftInset = isRight and (12 + OVERLAP) or 12
	local rightInset = isRight and -28 or -(28 + OVERLAP)

	local function EnsureAnimations(f)
		if not openAnimGroup then
			openAnimGroup = f:CreateAnimationGroup()
			openAnim = openAnimGroup:CreateAnimation("Translation")
			openAnim:SetDuration(SLIDE_OUT_DURATION)
			openAnim:SetSmoothing("OUT")
			openAnimGroup:SetScript("OnFinished", function()
				f:ClearAllPoints()
				f:SetPoint(restPoint, Folio.UI.Frame.Create(), mainPoint, overlapSign * OVERLAP, Y_OFFSET)
				f:SetFrameStrata(STRATA_OPEN)
			end)
		end
		if not closeAnimGroup then
			closeAnimGroup = f:CreateAnimationGroup()
			closeAnim = closeAnimGroup:CreateAnimation("Translation")
			closeAnim:SetDuration(SLIDE_IN_DURATION)
			closeAnim:SetSmoothing("IN")
			-- The actual :Hide() waits for the slide-in to finish, not
			-- called up front -- otherwise there'd be nothing left visible
			-- to animate. No need to also re-anchor here (unlike open,
			-- above) -- position doesn't matter once hidden.
			closeAnimGroup:SetScript("OnFinished", function()
				f:Hide()
			end)
		end
	end

	-- Sized and anchored fresh on every Show() -- not persisted -- so it
	-- always tracks the main window's CURRENT position/size instead of
	-- drifting stale if that window was moved or resized while the
	-- drawer was closed.
	local function RepositionBehindMain(f)
		local mainFrame = Folio.UI.Frame.Create()
		local width, height = mainFrame:GetWidth(), mainFrame:GetHeight()
		f:SetSize(width, math.max(height - HEIGHT_INSET, MIN_HEIGHT))
		f:ClearAllPoints()
		-- Starting ("hidden") anchor: directly behind/overlapping the
		-- main frame, at the SAME Y_OFFSET the resting position uses --
		-- the open Translation only moves it horizontally, so both ends
		-- need to already agree on the Y or OnFinished's re-anchor would
		-- visibly pop it up/down at the very end.
		f:SetPoint(hiddenPoint, mainFrame, mainPoint, 0, Y_OFFSET)
	end

	function self.Create()
		if frame then return frame end

		local f = CreateFrame("Frame", config.name, UIParent, "PortraitFrameTemplate")
		-- Starts at the "hidden behind main" strata -- Show() switches to
		-- STRATA_OPEN only once it's actually landed.
		f:SetFrameStrata(STRATA_HIDDEN)

		if f.SetTitle then
			f:SetTitle(config.title)
		end
		if f.SetPortraitToAsset then
			f:SetPortraitToAsset(config.portraitIcon)
		end
		if f.CloseButton then
			f.CloseButton:Hide()
		end

		-- No native "drop shadow" primitive for an arbitrary frame -- a
		-- thin gradient strip along the near edge instead. SetGradient
		-- (not the older SetGradientAlpha, merged into it and removed in
		-- patch 10.0.0) takes ColorMixin objects via CreateColor.
		local shadow = f:CreateTexture(nil, "ARTWORK")
		shadow:SetPoint("TOP" .. shadowPoint, f, "TOP" .. shadowPoint, 0, 0)
		shadow:SetPoint("BOTTOM" .. shadowPoint, f, "BOTTOM" .. shadowPoint, 0, 0)
		shadow:SetWidth(SHADOW_WIDTH)
		shadow:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, shadowFromAlpha), CreateColor(0, 0, 0, shadowToAlpha))

		listView = Folio.UI.ListView.Create(f)
		-- y=-60, matching UI/Frame.lua's own list top offset, not a
		-- tighter one -- the portrait icon's circular overhang extends
		-- down into the content area regardless of window, confirmed
		-- live for the main window's search box (needed a 64px LEFT
		-- inset at y=-32 to clear it); staying below its full vertical
		-- extent here avoids needing to work out the equivalent
		-- horizontal clearance for a list instead.
		listView.scrollBox:SetPoint("TOPLEFT", leftInset, -60)
		listView.scrollBox:SetPoint("BOTTOMRIGHT", rightInset, 12)
		listView.scrollBar:SetPoint("TOPLEFT", listView.scrollBox, "TOPRIGHT", 4, 0)
		listView.scrollBar:SetPoint("BOTTOMLEFT", listView.scrollBox, "BOTTOMRIGHT", 4, 0)

		f:Hide()
		frame = f
		return f
	end

	function self.SetItems(rows)
		if not listView then return end
		listView:SetItems(rows)
	end

	-- Idempotent -- safe to call on every RefreshItems() while still
	-- open (Core/Init.lua does exactly that); only actually plays the
	-- slide-out the first time, when actually transitioning from hidden
	-- to shown, not on every subsequent content refresh.
	function self.Show()
		local f = self.Create()
		if f:IsShown() then return end

		RepositionBehindMain(f)
		EnsureAnimations(f)
		-- Behind main for the slide-out itself -- openAnimGroup's
		-- OnFinished switches to STRATA_OPEN once it's actually landed.
		f:SetFrameStrata(STRATA_HIDDEN)

		-- Distance from the fully-hidden position (near edge at main's
		-- edge) to the resting position (near edge OVERLAP px past it).
		local slideDistance = f:GetWidth() - OVERLAP
		openAnim:SetOffset(slideSign * slideDistance, 0)
		closeAnim:SetOffset(-slideSign * slideDistance, 0)

		f:Show()
		openAnimGroup:Play()
	end

	function self.Hide()
		if not frame or not frame:IsShown() then return end
		-- Drops back below main for the slide-in, same reasoning as
		-- Show()'s STRATA_HIDDEN -- it should visually tuck back UNDER
		-- the main window as it retreats, not slide back in on top of it.
		frame:SetFrameStrata(STRATA_HIDDEN)
		closeAnimGroup:Play()
	end

	-- On-demand diagnostic (Q44/Q45's `/folio bankdebug`, carried forward
	-- for both drawers once this became a shared factory) -- kept
	-- permanently rather than stripped once root-caused, since strata/
	-- alpha/position drift is exactly the kind of thing that's silent
	-- until it visibly breaks again.
	function self.Debug()
		if not frame then
			print("|cff33ff99Folio debug|r " .. config.name .. " not created yet")
			return
		end
		print("|cff33ff99Folio debug|r " .. config.name .. " shown=", frame:IsShown(),
			"alpha=", frame:GetAlpha(), "strata=", frame:GetFrameStrata(), "level=", frame:GetFrameLevel())
		print("|cff33ff99Folio debug|r " .. config.name .. " rect =",
			frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom())
	end

	return self
end

return DrawerFrame
