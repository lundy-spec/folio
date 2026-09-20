local _, Folio = ...

-- §4.1/§6.3: fixed footer strip. Gold only for now, right-justified --
-- pinned-currency display is paused. Data/Currency.lua's seed/scan
-- machinery is untouched and already tested; it's just unused here
-- until that work resumes.

local CurrencyBar = {}
Folio.UI = Folio.UI or {}
Folio.UI.CurrencyBar = CurrencyBar

local BAR_HEIGHT = 20
local BORDER_INSET = 4

local bar, text

function CurrencyBar.Create(parent)
	if bar then return bar end

	bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	bar:SetHeight(BAR_HEIGHT)

	-- Confirmed live against Blizzard's own Combined Backpack window
	-- (same money-display row): its currency readout sits in a visible
	-- dark inset well with a thin rounded border, not a flat borderless
	-- rectangle floating on the panel background like this did. Reuses
	-- WoW's own long-standing tooltip backdrop art rather than hand-
	-- drawing a border -- tinted gold (same value used for the title/
	-- category-header text elsewhere) instead of its default light-gray,
	-- to match Folio's own accent color rather than Blizzard's.
	bar:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = BORDER_INSET, right = BORDER_INSET, top = BORDER_INSET, bottom = BORDER_INSET },
	})
	bar:SetBackdropColor(0, 0, 0, 0.6)
	bar:SetBackdropBorderColor(1, 0.82, 0, 1)

	-- No separate icon texture -- confirmed live this looked wrong
	-- doubled up: Core/API.lua's GetMoneyString already calls Blizzard's
	-- own GetMoneyString(money, true), which embeds a native round coin
	-- icon per nonzero denomination directly into the string. A hand-
	-- added square "pile of coins" icon next to that just clashed with
	-- Blizzard's own icons showing up in the text right next to it.
	text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Gold")
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return bar
end

function CurrencyBar.SetGold(entry)
	-- PLAYER_MONEY can fire before PLAYER_LOGIN has run Frame.Create()
	-- (and so Create() above) -- nothing to update yet.
	if not bar then return end
	text:SetText(entry.display or tostring(entry.quantity))
end

return CurrencyBar
