local _, Folio = ...

-- §4.1/§6.3: fixed footer strip, pinned currencies only. No expandable
-- in-frame list (Q10/Q11) -- depth lives in tooltips (CUR4).

local CurrencyBar = {}
Folio.UI = Folio.UI or {}
Folio.UI.CurrencyBar = CurrencyBar

local ICON_SIZE = 16
local GOLD_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local bar
local pips = {}

local function AcquirePip(index)
	local pip = pips[index]
	if not pip then
		pip = CreateFrame("Frame", nil, bar)
		pip.icon = pip:CreateTexture(nil, "ARTWORK")
		pip.icon:SetSize(ICON_SIZE, ICON_SIZE)
		pip.icon:SetPoint("LEFT")
		pip.text = pip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		pip.text:SetPoint("LEFT", pip.icon, "RIGHT", 2, 0)
		pip:SetHeight(ICON_SIZE)
		pip:EnableMouse(true)
		pips[index] = pip
	end
	pip:Show()
	return pip
end

local function SetPipTooltip(pip, entry)
	pip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if entry.kind == "currency" and entry.currencyID then
			GameTooltip:SetCurrencyByID(entry.currencyID, entry.quantity)
		else
			GameTooltip:SetText(entry.name or "Gold")
			GameTooltip:AddLine(entry.display or tostring(entry.quantity), 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	pip:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function CurrencyBar.Create(parent)
	if bar then return bar end
	bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(ICON_SIZE)
	return bar
end

-- Temporary, for /folio debug -- not part of the public module surface.
function CurrencyBar.DebugGetBar()
	return bar
end

-- entries: gold first (if present), then pinned currencies -- CUR3, the
-- unified entry model means both render through the same code path.
function CurrencyBar.SetEntries(entries)
	local x = 0
	for i, entry in ipairs(entries) do
		local pip = AcquirePip(i)
		pip:ClearAllPoints()
		pip:SetPoint("LEFT", bar, "LEFT", x, 0)

		if entry.kind == "money" then
			pip.icon:SetTexture(GOLD_ICON)
			pip.text:SetText(entry.display or tostring(entry.quantity))
		else
			pip.icon:SetTexture(entry.icon or FALLBACK_ICON)
			pip.text:SetText(tostring(entry.quantity or 0))
		end

		pip:SetWidth(ICON_SIZE + 4 + pip.text:GetStringWidth())
		SetPipTooltip(pip, entry)

		x = x + pip:GetWidth() + 12
	end

	for i = #entries + 1, #pips do
		pips[i]:Hide()
	end
end

return CurrencyBar
