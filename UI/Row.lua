local _, Folio = ...

-- Pooled row widget for the virtualized ListView. Built lazily on first
-- use (guarded by row.built) rather than via XML, since children survive
-- pool reuse — SetElementInitializer re-calls Row.Initialize on the same
-- physical frame as rows scroll in and out of view.
--
-- One pooled shape renders both category headers and items (§12 step 12)
-- rather than juggling two widget templates through the ScrollBox's
-- single element initializer — icon hidden and text styled differently
-- per row.kind (see Logic/Render.lua for where that field comes from).

local Row = {}
Folio.UI = Folio.UI or {}
Folio.UI.Row = Row

-- §6.2 UI9: Compact density (text-forward, ~16px rows) ships as default.
Row.HEIGHT = 18

-- Set by Core/Init.lua so clicking a header can toggle collapse + refresh
-- without Row.lua needing to know about the tree/refresh machinery.
Row.OnHeaderClick = nil

local INDENT = 12
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local HEADER_COLOR = { 1, 0.82, 0 }
local SUBGROUP_COLOR = { 0.8, 0.8, 0.8 }

local function Build(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(Row.HEIGHT - 4, Row.HEIGHT - 4)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.count:SetPoint("RIGHT", -4, 0)
	row.count:SetJustifyH("RIGHT")

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetJustifyH("LEFT")

	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if self.entryKind ~= "item" or not self.itemLink then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.itemLink)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row:SetScript("OnMouseUp", function(self)
		if self.entryKind == "header" and self.categoryID and Row.OnHeaderClick then
			Row.OnHeaderClick(self.categoryID, self.subgroup)
		end
	end)

	row.built = true
end

local function InitHeader(row, entry, indent)
	row.entryKind = "header"
	row.categoryID = entry.categoryID
	row.subgroup = entry.subgroup
	row.itemLink = nil

	row.icon:Hide()

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row, "LEFT", indent, 0)
	row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
	row.name:SetText((entry.collapsed and "> " or "v ") .. entry.name)

	-- §4.3 sub-group headers (Bags/Bank/Warband) read as a lighter,
	-- secondary level under the gold category header.
	local color = entry.subgroup and SUBGROUP_COLOR or HEADER_COLOR
	row.name:SetTextColor(color[1], color[2], color[3])

	row.count:SetText("(" .. entry.count .. ")")
end

local function InitItem(row, entry, indent)
	row.entryKind = "item"
	row.categoryID = nil
	row.subgroup = nil
	row.itemLink = entry.itemLink

	row.icon:Show()
	row.icon:ClearAllPoints()
	row.icon:SetPoint("LEFT", row, "LEFT", indent, 0)
	row.icon:SetTexture(entry.icon or FALLBACK_ICON)

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
	row.name:SetText(entry.name or ("Item " .. tostring(entry.itemID)))

	local color = ITEM_QUALITY_COLORS[entry.quality or 1]
	if color then
		row.name:SetTextColor(color.r, color.g, color.b)
	else
		row.name:SetTextColor(1, 1, 1)
	end

	row.count:SetText((entry.count or 1) > 1 and tostring(entry.count) or "")
end

function Row.Initialize(row, entry)
	if not row.built then
		Build(row)
	end

	local indent = 4 + (entry.depth or 0) * INDENT
	if entry.kind == "header" then
		InitHeader(row, entry, indent)
	else
		InitItem(row, entry, indent)
	end
end

return Row
