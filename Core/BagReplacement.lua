local _, Folio = ...

-- F8: replaces Blizzard's default bag toggle (the B keybind, the main
-- bar's bag buttons, and any macro that calls these) with Folio's own
-- window. Overriding the global functions rather than calling through to
-- Blizzard's OpenAllBags/ToggleAllBags avoids a documented taint issue
-- where calling those directly leaves items unusable until reload
-- (forum-confirmed, patch 10.0+) -- Folio's replacements never invoke
-- Blizzard's originals at all, so that code path is simply never run.

local BagReplacement = {}
Folio.BagReplacement = BagReplacement

local originals = {}

local function ReplacementToggle()
	Folio.UI.Frame.Toggle()
end

-- Confirmed live: SetOverrideBindingClick isn't fully suppressing the
-- underlying "B" binding dispatch on this client -- pressing B fires
-- BOTH the override-click below AND, separately, whatever ToggleBackpack
-- currently points to (a Forever-beta-specific divergence from
-- documented behavior). Keeping Folio's replacement functions active
-- only OUT of combat, and swapping back to Blizzard's REAL originals for
-- the duration of combat (PLAYER_REGEN_DISABLED/ENABLED, below), means
-- that stray dispatch calls a real, untainted Blizzard function instead
-- of erroring -- Folio's own window still opens via the independent
-- override-click path regardless of what these globals currently point
-- to, since toggleButton's OnClick calls ReplacementToggle directly,
-- never through _G lookup.
local toggleButton = CreateFrame("Button", "FolioBagToggleOverrideButton", UIParent)
toggleButton:Hide()
-- Confirmed live: registering both AnyUp and AnyDown fires OnClick TWICE
-- per single key press (once on press, once on release) -- toggling
-- Folio's window open then immediately shut again, looking like nothing
-- happened. Just AnyUp fires once, on release, like a normal click.
toggleButton:RegisterForClicks("AnyUp")
toggleButton:SetScript("OnClick", ReplacementToggle)

-- SetOverrideBindingClick/ClearOverrideBindings are themselves protected
-- -- only safe to call outside combat. Enable/Disable's current callers
-- (PLAYER_LOGIN, the Options checkbox) only run out of combat in
-- practice, but this guards the rare case of the checkbox somehow being
-- clicked mid-fight: the override binding just won't update until the
-- next out-of-combat Enable()/Disable() call (e.g. next login) rather
-- than erroring.
local function SetBagKeybindOverride(enabled)
	if InCombatLockdown() then return end
	ClearOverrideBindings(toggleButton)
	if enabled then
		for _, key in ipairs({ GetBindingKey("TOGGLEBACKPACK") }) do
			SetOverrideBindingClick(toggleButton, false, key, "FolioBagToggleOverrideButton")
		end
	end
end

local function ReplacementShow()
	Folio.UI.Frame.Create():Show()
end

local function ReplacementHide()
	local f = Folio.UI.Frame.Create()
	if f:IsShown() then
		f:Hide()
	end
end

-- ToggleBackpack/ToggleBag/ToggleAllBags: the keybind and bag-slot
-- buttons all funnel through one of these.
-- OpenBackpack/OpenAllBags, CloseBackpack/CloseAllBags: called by a
-- handful of other paths (e.g. looting flows) that open/close explicitly
-- rather than toggling.
local REPLACEMENTS = {
	ToggleBackpack = ReplacementToggle,
	ToggleBag = ReplacementToggle,
	ToggleAllBags = ReplacementToggle,
	OpenBackpack = ReplacementShow,
	OpenAllBags = ReplacementShow,
	CloseBackpack = ReplacementHide,
	CloseAllBags = ReplacementHide,
}

local function ApplyReplacements()
	for name, replacement in pairs(REPLACEMENTS) do
		if originals[name] == nil then
			originals[name] = _G[name]
		end
		_G[name] = replacement
	end
end

local function RestoreOriginals()
	for name in pairs(REPLACEMENTS) do
		if originals[name] then
			_G[name] = originals[name]
		end
	end
end

function BagReplacement.Enable()
	ApplyReplacements()
	SetBagKeybindOverride(true)
end

-- F8: "must degrade gracefully when off" -- restores Blizzard's original
-- bag behavior exactly as it was before Enable() ran.
function BagReplacement.Disable()
	RestoreOriginals()
	SetBagKeybindOverride(false)
end

-- Core/Init.lua's PLAYER_REGEN_DISABLED/ENABLED handlers -- see the
-- comment above toggleButton for why this exists. Only acts while the
-- feature is actually turned on; a no-op otherwise.
function BagReplacement.EnterCombat()
	if Folio.Config.db.bagReplacementEnabled then
		RestoreOriginals()
	end
end

function BagReplacement.ExitCombat()
	if Folio.Config.db.bagReplacementEnabled then
		ApplyReplacements()
	end
end

return BagReplacement
