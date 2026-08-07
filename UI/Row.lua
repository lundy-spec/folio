local _, Folio = ...

-- Pooled row widget for the virtualized ListView. Built lazily on first
-- use (guarded by row.built) rather than via XML, since children survive
-- pool reuse — SetElementInitializer re-calls Row.Initialize on the same
-- physical frame as rows scroll in and out of view.

local Row = {}
Folio.UI = Folio.UI or {}
Folio.UI.Row = Row

-- §6.2 UI9: Compact density (text-forward, ~16px rows) ships as default.
Row.HEIGHT = 18

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Build(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(Row.HEIGHT - 4, Row.HEIGHT - 4)
	row.icon:SetPoint("LEFT", 4, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.count:SetPoint("RIGHT", -4, 0)
	row.count:SetJustifyH("RIGHT")

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
	row.name:SetJustifyH("LEFT")

	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if not self.itemLink then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.itemLink)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row.built = true
end

function Row.Initialize(row, item)
	if not row.built then
		Build(row)
	end

	row.itemLink = item.itemLink
	row.icon:SetTexture(item.icon or FALLBACK_ICON)
	row.name:SetText(item.name or ("Item " .. tostring(item.itemID)))

	local color = ITEM_QUALITY_COLORS[item.quality or 1]
	if color then
		row.name:SetTextColor(color.r, color.g, color.b)
	else
		row.name:SetTextColor(1, 1, 1)
	end

	row.count:SetText((item.count or 1) > 1 and tostring(item.count) or "")
end

return Row
