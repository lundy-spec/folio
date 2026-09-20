local _, Folio = ...

-- Q43: the bank drawer -- slides out to the LEFT, from behind the main
-- Folio window, showing bank storage only, while a banker is open.
--
-- Not independently movable or resizable -- it's an attached drawer,
-- always anchored relative to the main window's current position/size,
-- not a standalone panel the player positions on its own. No corner menu,
-- search box, or currency bar -- category management and search stay in
-- the main window; this is deliberately a narrower, secondary view. No
-- independent close button either (Q52) -- its lifecycle belongs to the
-- main window and to actually being at a banker, not to the player
-- managing it as its own panel.

local BankFrame = {}
Folio.UI = Folio.UI or {}
Folio.UI.BankFrame = BankFrame

-- How much shorter than the main window the drawer sits, how many pixels
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

-- Q44/Q45/Q46/Q47, all confirmed live: (1) Blizzard's own bank window sits
-- above the default ("MEDIUM") strata, so the drawer needs "HIGH" once
-- fully open to not end up covered by it. (2) An Alpha animation meant to
-- hide the brief hidden/behind-main start got stuck at alpha=0
-- permanently -- don't trust that animation type. (3) The SAME "don't
-- trust it to persist" lesson applies to the Translation itself too --
-- OnFinished explicitly re-anchors the frame to its true resting position
-- rather than trusting the animation to have left it there. (4) A
-- permanent "HIGH" strata then meant it rendered ON TOP of the main
-- window during the part of the slide where it's supposed to be hidden
-- BEHIND it -- "HIGH" and "hidden behind main" are contradictory as a
-- single static value. Strata switches dynamically instead: "LOW" (below
-- main's default "MEDIUM") while sliding out from behind or back in
-- behind it, "HIGH" (above Blizzard's bank window) only once actually
-- landed at rest.
local STRATA_HIDDEN = "LOW"
local STRATA_OPEN = "HIGH"

local frame, listView
local openAnimGroup, closeAnimGroup, openAnim, closeAnim

local function EnsureAnimations(f)
	if not openAnimGroup then
		openAnimGroup = f:CreateAnimationGroup()
		openAnim = openAnimGroup:CreateAnimation("Translation")
		openAnim:SetDuration(SLIDE_OUT_DURATION)
		openAnim:SetSmoothing("OUT")
		openAnimGroup:SetScript("OnFinished", function()
			f:ClearAllPoints()
			f:SetPoint("BOTTOMRIGHT", Folio.UI.Frame.Create(), "BOTTOMLEFT", OVERLAP, Y_OFFSET)
			f:SetFrameStrata(STRATA_OPEN)
		end)
	end
	if not closeAnimGroup then
		closeAnimGroup = f:CreateAnimationGroup()
		closeAnim = closeAnimGroup:CreateAnimation("Translation")
		closeAnim:SetDuration(SLIDE_IN_DURATION)
		closeAnim:SetSmoothing("IN")
		-- The actual :Hide() waits for the slide-in to finish, not called
		-- up front -- otherwise there'd be nothing left visible to
		-- animate. No need to also re-anchor here (unlike open, above) --
		-- position doesn't matter once hidden.
		closeAnimGroup:SetScript("OnFinished", function()
			f:Hide()
		end)
	end
end

-- Sized and anchored fresh on every Show() -- not persisted -- so it
-- always tracks the main window's CURRENT position/size instead of
-- drifting stale if that window was moved or resized while the drawer
-- was closed.
local function RepositionBehindMain(f)
	local mainFrame = Folio.UI.Frame.Create()
	local width, height = mainFrame:GetWidth(), mainFrame:GetHeight()
	f:SetSize(width, math.max(height - HEIGHT_INSET, MIN_HEIGHT))
	f:ClearAllPoints()
	-- Starting ("hidden") anchor: directly behind/overlapping the main
	-- frame, at the SAME Y_OFFSET the resting position uses -- the open
	-- Translation only moves it horizontally, so both ends need to
	-- already agree on the Y or OnFinished's re-anchor would visibly pop
	-- it up/down at the very end.
	f:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, Y_OFFSET)
end

function BankFrame.Create()
	if frame then return frame end

	local f = CreateFrame("Frame", "FolioBankFrame", UIParent, "PortraitFrameTemplate")
	-- Starts at the "hidden behind main" strata -- Show() switches to
	-- STRATA_OPEN only once it's actually landed.
	f:SetFrameStrata(STRATA_HIDDEN)
	f:SetTitle("Folio - Bank")
	-- PortraitFrameTemplate's own title defaults to plain white --
	-- confirmed live against Blizzard's own Combined Backpack window
	-- (same template), whose title renders in this warm gold instead. The
	-- title FontString lives under TitleContainer, not directly on the
	-- frame -- confirmed live (a first attempt at f.TitleText errored,
	-- "attempt to index field 'TitleText' (a nil value)").
	f.TitleContainer.TitleText:SetTextColor(1, 0.82, 0, 1)
	f:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_10")
	f.CloseButton:Hide()
	-- Same body-fill transparency as UI/Frame.lua, for the same reason
	-- (confirmed live against Blizzard's own Combined Backpack window) --
	-- 0.7 is a first pass, tune from a screenshot.
	f.Bg:SetAlpha(0.7)

	-- No native "drop shadow" primitive for an arbitrary frame -- a thin
	-- gradient strip along the near edge instead. SetGradient (not the
	-- older SetGradientAlpha, merged into it and removed in patch
	-- 10.0.0) takes ColorMixin objects via CreateColor.
	local shadow = f:CreateTexture(nil, "ARTWORK")
	shadow:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	shadow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	shadow:SetWidth(SHADOW_WIDTH)
	shadow:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.65))

	listView = Folio.UI.ListView.Create(f)
	-- y=-60, matching UI/Frame.lua's own list top offset, not a tighter
	-- one -- the portrait icon's circular overhang extends down into the
	-- content area regardless of window, confirmed live for the main
	-- window's search box (needed a 64px LEFT inset at y=-32 to clear
	-- it); staying below its full vertical extent here avoids needing to
	-- work out the equivalent horizontal clearance for a list instead.
	listView.scrollBox:SetPoint("TOPLEFT", 12, -60)
	listView.scrollBox:SetPoint("BOTTOMRIGHT", -(28 + OVERLAP), 12)
	listView.scrollBar:SetPoint("TOPLEFT", listView.scrollBox, "TOPRIGHT", 4, 0)
	listView.scrollBar:SetPoint("BOTTOMLEFT", listView.scrollBox, "BOTTOMRIGHT", 4, 0)

	f:Hide()
	frame = f
	return f
end

function BankFrame.SetItems(rows)
	if not listView then return end
	listView:SetItems(rows)
end

-- Idempotent -- safe to call on every RefreshItems() while still open
-- (Core/Init.lua does exactly that); only actually plays the slide-out
-- the first time, when actually transitioning from hidden to shown, not
-- on every subsequent content refresh.
function BankFrame.Show()
	local f = BankFrame.Create()
	if f:IsShown() then return end

	RepositionBehindMain(f)
	EnsureAnimations(f)
	-- Behind main for the slide-out itself -- openAnimGroup's OnFinished
	-- switches to STRATA_OPEN once it's actually landed.
	f:SetFrameStrata(STRATA_HIDDEN)

	-- Distance from the fully-hidden position (near edge at main's edge)
	-- to the resting position (near edge OVERLAP px past it).
	local slideDistance = f:GetWidth() - OVERLAP
	openAnim:SetOffset(-slideDistance, 0)
	closeAnim:SetOffset(slideDistance, 0)

	f:Show()
	openAnimGroup:Play()
end

function BankFrame.Hide()
	if not frame or not frame:IsShown() then return end
	-- Drops back below main for the slide-in, same reasoning as Show()'s
	-- STRATA_HIDDEN -- it should visually tuck back UNDER the main window
	-- as it retreats, not slide back in on top of it.
	frame:SetFrameStrata(STRATA_HIDDEN)
	closeAnimGroup:Play()
end

-- On-demand diagnostic (`/folio bankdebug`) -- kept permanently rather
-- than stripped once root-caused, since strata/position drift is exactly
-- the kind of thing that's silent until it visibly breaks again.
function BankFrame.Debug()
	if not frame then
		print("|cff33ff99Folio debug|r bank frame not created yet")
		return
	end
	print("|cff33ff99Folio debug|r bank frame shown=", frame:IsShown(),
		"alpha=", frame:GetAlpha(), "strata=", frame:GetFrameStrata(), "level=", frame:GetFrameLevel())
	print("|cff33ff99Folio debug|r bank frame rect =",
		frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom())
end

return BankFrame
