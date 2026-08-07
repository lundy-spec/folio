local _, Folio = ...

-- Pooled row widget for the virtualized ListView. Built lazily on first
-- use (guarded by row.built) rather than via XML, since children survive
-- pool reuse — SetElementInitializer re-calls Row.Initialize on the same
-- physical frame as rows scroll in and out of view.
--
-- One pooled shape renders both category headers and items (§12 step 12)
-- rather than juggling two widget templates through the ScrollBox's
-- single element initializer — icon/toggle hidden and swapped as needed
-- per row.kind (see Logic/Render.lua for where that field comes from).

local Row = {}
Folio.UI = Folio.UI or {}
Folio.UI.Row = Row

-- §6.2 UI9: Compact density (text-forward, ~16px rows) ships as default.
Row.HEIGHT = 18

-- Set by Core/Init.lua so clicking a header can toggle collapse + refresh
-- without Row.lua needing to know about the tree/refresh machinery.
Row.OnHeaderClick = nil

-- Set by Core/Init.lua. OnItemDragStart(itemRow) fires on drag start;
-- OnItemDragStop(itemRow, targetFrame) fires on release, targetFrame
-- being whatever GetMouseFoci() found under the cursor (nil if nothing).
Row.OnItemDragStart = nil
Row.OnItemDragStop = nil

-- Set by Core/Init.lua. Category-header-to-category-header reordering --
-- only fires for bare category headers (not Bags/Bank/Warband
-- sub-groups, whose order is fixed per S2). dropPosition is "before" or
-- "after" the target, based on which half of the target row the cursor
-- was over when released -- see the drag-tracking below.
Row.OnHeaderDragStop = nil

local INDENT = 12
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local HEADER_COLOR = { 1, 0.82, 0 }
local SUBGROUP_COLOR = { 0.8, 0.8, 0.8 }
local PLUS_TEXTURE = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS_TEXTURE = "Interface\\Buttons\\UI-MinusButton-Up"

-- Shared across all rows -- only one header drag happens at a time.
local dropIndicator

local function GetDropIndicator(parent)
	if not dropIndicator then
		dropIndicator = parent:CreateTexture(nil, "OVERLAY")
		dropIndicator:SetColorTexture(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3], 0.9)
		dropIndicator:SetHeight(2)
		dropIndicator:Hide()
	end
	return dropIndicator
end

-- "before" if the cursor is over the target's upper half, "after" if the
-- lower half -- the standard list-reorder convention.
local function DropPositionRelativeTo(targetRow)
	local _, cursorY = GetCursorPosition()
	local scale = targetRow:GetEffectiveScale()
	if not scale or scale == 0 then return "before" end
	cursorY = cursorY / scale
	local top, bottom = targetRow:GetTop(), targetRow:GetBottom()
	if not top or not bottom then return "before" end
	return cursorY > (top + bottom) / 2 and "before" or "after"
end

local function StartHeaderReorderTracking(row)
	row.dropPosition = nil
	row:SetScript("OnUpdate", function(self)
		local foci = GetMouseFoci and GetMouseFoci()
		local target = foci and foci[1]
		local indicator = GetDropIndicator(self:GetParent())

		if target and target.entryKind == "header" and not target.subgroup and target ~= self then
			local position = DropPositionRelativeTo(target)
			self.dropPosition = position
			indicator:ClearAllPoints()
			if position == "before" then
				indicator:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, -1)
				indicator:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, -1)
			else
				indicator:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, 1)
				indicator:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, 1)
			end
			indicator:Show()
		else
			self.dropPosition = nil
			indicator:Hide()
		end
	end)
end

-- Returns the last tracked drop position and tears down the indicator.
local function StopHeaderReorderTracking(row)
	row:SetScript("OnUpdate", nil)
	if dropIndicator then
		dropIndicator:Hide()
	end
	local position = row.dropPosition
	row.dropPosition = nil
	return position
end

-- Highlights whatever row is currently a valid drop target while
-- dragging an item -- a header (category or sub-group) or another item
-- row, which ResolveDropTarget (Core/Init.lua) treats as a proxy for its
-- own category/sub-group, same full-block-counts-as-a-hit rule as the
-- hit-testing itself. Shared across all rows -- only one item drag
-- happens at a time.
local dropHighlight

local function GetDropHighlight(parent)
	if not dropHighlight then
		dropHighlight = parent:CreateTexture(nil, "BACKGROUND")
		dropHighlight:SetColorTexture(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3], 0.25)
		dropHighlight:Hide()
	end
	return dropHighlight
end

local function IsValidItemDropTarget(target)
	if not target then return false end
	if target.entryKind == "header" and target.categoryID then return true end
	if target.entryKind == "item" and target.itemCategoryID then return true end
	return false
end

-- WoW's native cursor-follows-item only shows the bare icon (that's
-- just what PickupContainerItem gives you) -- this ghost shows the full
-- row (icon + name) instead, so it's clear what's actually being moved.
local dragGhost

local function GetDragGhost(parent)
	if not dragGhost then
		dragGhost = CreateFrame("Frame", nil, parent)
		dragGhost:SetFrameStrata("TOOLTIP")

		dragGhost.icon = dragGhost:CreateTexture(nil, "ARTWORK")
		dragGhost.icon:SetSize(Row.HEIGHT - 4, Row.HEIGHT - 4)
		dragGhost.icon:SetPoint("LEFT")

		dragGhost.name = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		dragGhost.name:SetPoint("LEFT", dragGhost.icon, "RIGHT", 4, 0)
		dragGhost.name:SetJustifyH("LEFT")

		dragGhost:Hide()
	end
	return dragGhost
end

local function StartItemDropTracking(row)
	local ghost = GetDragGhost(row:GetParent())
	ghost:SetSize(row:GetWidth(), Row.HEIGHT)
	ghost.icon:SetTexture(row.icon:GetTexture())
	ghost.name:SetText(row.name:GetText())
	ghost.name:SetTextColor(row.name:GetTextColor())
	ghost:Show()

	row:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		ghost:ClearAllPoints()
		ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 16, y / scale)

		local foci = GetMouseFoci and GetMouseFoci()
		local target = foci and foci[1]
		local highlight = GetDropHighlight(self:GetParent())

		if IsValidItemDropTarget(target) then
			highlight:ClearAllPoints()
			highlight:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
			highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
			highlight:Show()
		else
			highlight:Hide()
		end
	end)
end

local function StopItemDropTracking(row)
	row:SetScript("OnUpdate", nil)
	if dropHighlight then
		dropHighlight:Hide()
	end
	if dragGhost then
		dragGhost:Hide()
	end
end

local function Build(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(Row.HEIGHT - 4, Row.HEIGHT - 4)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.toggle = row:CreateTexture(nil, "ARTWORK")
	row.toggle:SetSize(Row.HEIGHT - 6, Row.HEIGHT - 6)

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

	-- §4.3: drag an item onto a category/sub-group header to recategorize
	-- or transfer it. Drag a bare category header onto another to
	-- reorder them (sub-group headers are excluded -- their order is
	-- fixed per S2, a drag destination has to stay unambiguous).
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function(self)
		if self.entryKind == "item" and Row.OnItemDragStart then
			Row.OnItemDragStart(self)
			StartItemDropTracking(self)
		elseif self.entryKind == "header" and not self.subgroup then
			StartHeaderReorderTracking(self)
		end
	end)
	row:SetScript("OnDragStop", function(self)
		local foci = GetMouseFoci and GetMouseFoci()
		local target = foci and foci[1]
		if self.entryKind == "item" and Row.OnItemDragStop then
			StopItemDropTracking(self)
			Row.OnItemDragStop(self, target)
		elseif self.entryKind == "header" and not self.subgroup then
			local dropPosition = StopHeaderReorderTracking(self)
			if Row.OnHeaderDragStop then
				Row.OnHeaderDragStop(self, target, dropPosition)
			end
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

	row.toggle:Show()
	row.toggle:ClearAllPoints()
	row.toggle:SetPoint("LEFT", row, "LEFT", indent, 0)
	row.toggle:SetTexture(entry.collapsed and PLUS_TEXTURE or MINUS_TEXTURE)

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.name:SetText(entry.name .. " (" .. entry.count .. ")")

	-- §4.3 sub-group headers (Bags/Bank/Warband) read as a lighter,
	-- secondary level under the gold category header.
	local color = entry.subgroup and SUBGROUP_COLOR or HEADER_COLOR
	row.name:SetTextColor(color[1], color[2], color[3])
end

local function InitItem(row, entry, indent)
	row.entryKind = "item"
	row.categoryID = nil
	row.subgroup = nil
	row.itemLink = entry.itemLink
	row.itemID = entry.itemID
	row.itemBag = entry.bag
	row.itemSlot = entry.slot
	row.itemStorage = entry.storage
	row.itemCategoryID = entry.categoryID

	row.toggle:Hide()

	row.icon:Show()
	row.icon:ClearAllPoints()
	row.icon:SetPoint("LEFT", row, "LEFT", indent, 0)
	row.icon:SetTexture(entry.icon or FALLBACK_ICON)

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)

	local displayName = entry.name or ("Item " .. tostring(entry.itemID))
	if (entry.count or 1) > 1 then
		displayName = displayName .. " (" .. entry.count .. ")"
	end
	row.name:SetText(displayName)

	local color = ITEM_QUALITY_COLORS[entry.quality or 1]
	if color then
		row.name:SetTextColor(color.r, color.g, color.b)
	else
		row.name:SetTextColor(1, 1, 1)
	end
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
