local _, Folio = ...

-- §4.1/§6.3: fixed footer strip. Gold only for now, right-justified --
-- pinned-currency display is paused. Data/Currency.lua's seed/scan
-- machinery is untouched and already tested; it's just unused here
-- until that work resumes.

local CurrencyBar = {}
Folio.UI = Folio.UI or {}
Folio.UI.CurrencyBar = CurrencyBar

local ICON_SIZE = 16
local GOLD_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local bar, icon, text

function CurrencyBar.Create(parent)
	if bar then return bar end

	bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(ICON_SIZE)

	text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("RIGHT", bar, "RIGHT", 0, 0)

	icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("RIGHT", text, "LEFT", -2, 0)
	icon:SetTexture(GOLD_ICON)

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
