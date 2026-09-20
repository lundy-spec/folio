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

-- Confirmed live: pressing B in combat did nothing and printed WoW's
-- classic taint error, "Interface action failed because of an AddOn".
-- Overriding the ToggleBackpack GLOBAL below is plain insecure Lua --
-- fine out of combat, but the B key's own binding dispatch treats
-- calling a replaced global as tainted, and combat lockdown blocks
-- tainted calls to what it treats as a protected keybind action.
--
-- SetOverrideBindingClick sidesteps this the same way the Show Bags
-- button (UI/Frame.lua) already does for OpenAllBags: it makes the KEY
-- PRESS ITSELF perform a real click on a button -- even one whose
-- OnClick just runs plain addon Lua -- which WoW's security model
-- treats as genuine user interaction rather than an addon-initiated
-- call, regardless of combat state. The button doesn't need to be
-- shown; it only ever exists as a click target for the key.
local toggleButton = CreateFrame("Button", "FolioBagToggleOverrideButton", UIParent)
toggleButton:Hide()
toggleButton:RegisterForClicks("AnyUp", "AnyDown")
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

function BagReplacement.Enable()
	for name, replacement in pairs(REPLACEMENTS) do
		if originals[name] == nil then
			originals[name] = _G[name]
		end
		_G[name] = replacement
	end
	SetBagKeybindOverride(true)
end

-- F8: "must degrade gracefully when off" -- restores Blizzard's original
-- bag behavior exactly as it was before Enable() ran.
function BagReplacement.Disable()
	for name in pairs(REPLACEMENTS) do
		if originals[name] then
			_G[name] = originals[name]
		end
	end
	SetBagKeybindOverride(false)
end

return BagReplacement
