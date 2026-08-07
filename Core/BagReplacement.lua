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
end

-- F8: "must degrade gracefully when off" -- restores Blizzard's original
-- bag behavior exactly as it was before Enable() ran.
function BagReplacement.Disable()
	for name in pairs(REPLACEMENTS) do
		if originals[name] then
			_G[name] = originals[name]
		end
	end
end

return BagReplacement
