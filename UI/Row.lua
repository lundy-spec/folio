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
-- OnHeaderClick(categoryID, dropStorage) -- dropStorage (Q43's per-window
-- tag) says WHICH window/section's collapse state (Q53) to toggle.
Row.OnHeaderClick = nil

-- Set by Core/Init.lua. OnItemDragStart(itemRow) fires on drag start;
-- OnItemDragStop(itemRow, targetFrame) fires on release, targetFrame
-- being whatever GetMouseFoci() found under the cursor (nil if nothing).
Row.OnItemDragStart = nil
Row.OnItemDragStop = nil

-- Set by Core/Init.lua. Category-header-to-category-header reordering --
-- only fires for bare category headers (not Bags/Bank/Warband
-- sub-groups, whose order is fixed per S2). dropPosition is "before" or
-- "after" the target (reorder as a sibling) or "into" (nest as its
-- child), based on which third of the target row the cursor was over
-- when released -- see the drag-tracking below.
Row.OnHeaderDragStop = nil

-- Set by Core/Init.lua. Q40/Q41: shift-left-click an item row to pin/
-- unpin it -- the star-button version didn't render right and was
-- dropped in favor of this.
Row.OnItemPinToggle = nil

local INDENT = 12
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local HEADER_COLOR = { 1, 0.82, 0 }
local PLUS_TEXTURE = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS_TEXTURE = "Interface\\Buttons\\UI-MinusButton-Up"

-- True while any header/item drag is in progress -- the hover-tracked use
-- button (below) parks itself off-screen for the duration so it can't
-- interfere with GetMouseFoci()-based drop-target detection.
local dragInProgress = false

-- Shared across all rows -- only one row is ever hovered at a time. A
-- secure button, not the row itself, since C_Container.UseContainerItem
-- (right-click "use") is a protected function only invokable through
-- Blizzard's own secure-button click dispatch -- confirmed live (Q32):
-- calling it directly from a plain row's OnMouseUp threw WoW's standard
-- "action only available to the Blizzard UI" block, even from a genuine
-- mouse click. Repositioned over whichever item row is hovered so a real
-- right-click lands on it directly; SetPassThroughButtons lets
-- left-clicks/drags fall through untouched to the row underneath.
-- Deliberately never Show()/Hide()'d -- that's itself combat-restricted
-- once a secure button has attributes set -- parked off-screen via
-- SetPoint/SetSize instead, which isn't.
-- Q33: confirmed live -- positioning this ON TOP of the hovered row (so a
-- real right-click can land on it) makes IT the topmost frame at that
-- screen position, which makes WoW immediately fire the row's OnLeave
-- (having a covering frame steals "hovered" status regardless of
-- SetPassThroughButtons -- that only affects click routing, not
-- enter/leave). Naively parking the button again in that OnLeave just
-- re-uncovers the row, which re-fires OnEnter, which re-covers it again --
-- an infinite flutter, and worse, meant the button was rarely actually in
-- place at the moment a click landed. Fix: hover ownership hands off to
-- this button once it's in place -- the row's OnEnter shows the
-- tooltip/highlight and positions the button over itself, but its OnLeave
-- is a no-op for item rows; THIS button's OnLeave (fired when the cursor
-- truly leaves that screen area) is what hides them and parks it again.
local useButton
local hoveredItemRow

local function ShowItemHover(row)
	if hoveredItemRow and hoveredItemRow ~= row then
		hoveredItemRow.hoverHighlight:Hide()
	end
	hoveredItemRow = row
	row.hoverHighlight:Show()
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(row.itemLink)
	GameTooltip:Show()
end

-- Guarded by identity, not unconditional: this can fire slightly before
-- OR after the next row's OnEnter already reassigned hoveredItemRow
-- (both are consequences of the same cursor-position update when moving
-- directly from one item row to an adjacent one, and their relative
-- order isn't guaranteed) -- without the guard, firing after would wrongly
-- hide the row just shown instead of the one actually left.
local function HideItemHover(row)
	if hoveredItemRow ~= row then return end
	hoveredItemRow = nil
	row.hoverHighlight:Hide()
	GameTooltip:Hide()
end

local function ParkUseButton()
	if not useButton then return end
	if hoveredItemRow then
		HideItemHover(hoveredItemRow)
	end
	useButton:ClearAllPoints()
	useButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -1000, 1000)
	useButton:SetSize(1, 1)
end

local function GetUseButton(parent)
	if not useButton then
		useButton = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
		useButton:RegisterForClicks("RightButtonUp", "RightButtonDown")
		useButton:SetPassThroughButtons("LeftButton")
		useButton:SetSize(1, 1)
		useButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -1000, 1000)
		useButton:SetScript("OnLeave", function(self)
			if self.hoveredRow then
				HideItemHover(self.hoveredRow)
				self.hoveredRow = nil
			end
			ParkUseButton()
		end)
	end
	return useButton
end

-- Called once, eagerly, at login (UI/ListView.lua) instead of lazily on
-- first hover -- SetPassThroughButtons is itself combat-restricted
-- (10.1.5+), so the button needs to exist before combat could plausibly
-- start.
function Row.EnsureUseButton(parent)
	GetUseButton(parent)
end

local function PositionUseButtonOver(row)
	if dragInProgress or row.entryKind ~= "item" or not row.itemLink then
		return
	end
	local btn = GetUseButton(row:GetParent())
	btn.hoveredRow = row
	btn:ClearAllPoints()
	btn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	btn:SetFrameLevel(row:GetFrameLevel() + 1)
	btn:SetAttribute("type2", "item")
	btn:SetAttribute("item2", row.itemLink)
end

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

-- Three-zone drop read, the standard nested-list convention (Explorer,
-- VS Code's tree, etc.): top third of the target row = "before" it,
-- bottom third = "after" it (both siblings, existing reorder behavior),
-- middle third = "into" it -- nest the dragged category as its child.
local function DropPositionRelativeTo(targetRow)
	local _, cursorY = GetCursorPosition()
	local scale = targetRow:GetEffectiveScale()
	if not scale or scale == 0 then return "before" end
	cursorY = cursorY / scale
	local top, bottom = targetRow:GetTop(), targetRow:GetBottom()
	if not top or not bottom then return "before" end
	local height = top - bottom
	if height <= 0 then return "before" end
	local fromTop = (top - cursorY) / height
	if fromTop < 1 / 3 then
		return "before"
	elseif fromTop > 2 / 3 then
		return "after"
	end
	return "into"
end

-- Item-row reordering only ever inserts before or after the target row --
-- unlike category headers, items can't nest, so this is a plain top-half/
-- bottom-half split rather than DropPositionRelativeTo's three zones.
local function ItemDropPositionRelativeTo(targetRow)
	local _, cursorY = GetCursorPosition()
	local scale = targetRow:GetEffectiveScale()
	if not scale or scale == 0 then return "before" end
	cursorY = cursorY / scale
	local top, bottom = targetRow:GetTop(), targetRow:GetBottom()
	if not top or not bottom then return "before" end
	return cursorY >= (top + bottom) / 2 and "before" or "after"
end

-- Dragging a category header out past the window's own edges deletes it
-- (Core/Init.lua decides, this just answers "is the cursor past the
-- frame's bounds"). Same cursor/effective-scale math as
-- DropPositionRelativeTo above.
local function IsCursorOutsideFrame(frame)
	if not frame then return false end
	local x, y = GetCursorPosition()
	local scale = frame:GetEffectiveScale()
	if not scale or scale == 0 then return false end
	x, y = x / scale, y / scale
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then return false end
	return x < left or x > right or y < bottom or y > top
end

-- Highlights whatever row is currently a valid drop target -- shared
-- between item drags (dragging onto a category/sub-group) and header
-- drags dropped in a target's middle third ("into", nesting it as a
-- child) -- a full-row block reads as "goes inside this" the same way
-- it already does for item drops, vs. the thin before/after line for
-- sibling reordering. Only one drag of either kind happens at a time.
local dropHighlight

local function GetDropHighlight(parent)
	if not dropHighlight then
		dropHighlight = parent:CreateTexture(nil, "BACKGROUND")
		dropHighlight:SetColorTexture(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3], 0.25)
		dropHighlight:Hide()
	end
	return dropHighlight
end

-- A category header row is only ~18px tall, same full-block problem
-- ResolveDropTarget (Core/Init.lua) already solves for item drops onto a
-- category: any row belonging to it -- an item inside it -- counts as a
-- hit on the category too, not just its own header line. Returns the
-- target category id, and (only for an actual header row) that row
-- itself, since only a real header row has a meaningful before/into/after
-- split -- an item row proxying for its category is always "into".
local function ResolveHeaderDropTarget(target)
	if not target then return nil end
	if target.entryKind == "header" and target.categoryID then
		return target.categoryID, target
	end
	if target.entryKind == "item" and target.itemCategoryID then
		return target.itemCategoryID, nil
	end
	return nil
end

local function ShowIntoHighlight(highlight, indicator, blockRow)
	indicator:Hide()
	highlight:ClearAllPoints()
	highlight:SetPoint("TOPLEFT", blockRow, "TOPLEFT", 0, 0)
	highlight:SetPoint("BOTTOMRIGHT", blockRow, "BOTTOMRIGHT", 0, 0)
	highlight:Show()
end

local function StartHeaderReorderTracking(row)
	row.dropPosition = nil
	row.dropCategoryID = nil
	row:SetScript("OnUpdate", function(self)
		local foci = GetMouseFoci and GetMouseFoci()
		local rawTarget = foci and foci[1]
		local indicator = GetDropIndicator(self:GetParent())
		local highlight = GetDropHighlight(self:GetParent())

		local categoryID, headerRow = ResolveHeaderDropTarget(rawTarget)

		if categoryID and categoryID ~= self.categoryID then
			self.dropCategoryID = categoryID
			if headerRow then
				local position = DropPositionRelativeTo(headerRow)
				self.dropPosition = position
				if position == "into" then
					ShowIntoHighlight(highlight, indicator, headerRow)
				else
					highlight:Hide()
					indicator:ClearAllPoints()
					if position == "before" then
						indicator:SetPoint("BOTTOMLEFT", headerRow, "TOPLEFT", 0, -1)
						indicator:SetPoint("BOTTOMRIGHT", headerRow, "TOPRIGHT", 0, -1)
					else
						indicator:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, 1)
						indicator:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, 1)
					end
					indicator:Show()
				end
			else
				-- Proxy hit (an item, or a sub-group header) -- always
				-- "into" the category it belongs to, highlighting
				-- whatever row was actually under the cursor.
				self.dropPosition = "into"
				ShowIntoHighlight(highlight, indicator, rawTarget)
			end
		else
			self.dropPosition = nil
			self.dropCategoryID = nil
			indicator:Hide()
			highlight:Hide()
		end
	end)
end

-- Returns the last tracked drop position and target category id, and
-- tears down the indicator/highlight.
local function StopHeaderReorderTracking(row)
	row:SetScript("OnUpdate", nil)
	if dropIndicator then
		dropIndicator:Hide()
	end
	if dropHighlight then
		dropHighlight:Hide()
	end
	local position, categoryID = row.dropPosition, row.dropCategoryID
	row.dropPosition = nil
	row.dropCategoryID = nil
	return position, categoryID
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

	row.dropPosition = nil

	row:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		ghost:ClearAllPoints()
		-- LEFT rather than CENTER: the ghost is full row-width, so
		-- centering it on the cursor left the icon floating well away
		-- from the actual cursor tip. Anchoring by LEFT puts the icon
		-- (and the name right after it) right at the cursor instead.
		ghost:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + 16, y / scale)

		local foci = GetMouseFoci and GetMouseFoci()
		local target = foci and foci[1]
		local indicator = GetDropIndicator(self:GetParent())
		local highlight = GetDropHighlight(self:GetParent())

		if not IsValidItemDropTarget(target) then
			self.dropPosition = nil
			indicator:Hide()
			highlight:Hide()
		elseif target.entryKind == "item" and target ~= self then
			-- Dropping on another item row reorders (an exact slot,
			-- before/after it -- same before/after convention as header
			-- reordering) rather than the vague "somewhere in this
			-- category" full-block highlight a header target gets.
			highlight:Hide()
			self.dropPosition = ItemDropPositionRelativeTo(target)
			indicator:ClearAllPoints()
			if self.dropPosition == "before" then
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
			highlight:ClearAllPoints()
			highlight:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
			highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
			highlight:Show()
		end
	end)
end

-- Returns the last tracked drop position (Q31: "before"/"after" a target
-- item row, nil for a header/sub-group drop or no valid target) and tears
-- down the indicator/highlight/ghost.
local function StopItemDropTracking(row)
	row:SetScript("OnUpdate", nil)
	if dropIndicator then
		dropIndicator:Hide()
	end
	if dropHighlight then
		dropHighlight:Hide()
	end
	if dragGhost then
		dragGhost:Hide()
	end
	local dropPosition = row.dropPosition
	row.dropPosition = nil
	return dropPosition
end

local function Build(row)
	-- Subtle hover feedback for both item and header rows -- one texture
	-- per pooled row (not shared like dropIndicator/dropHighlight above)
	-- since hover is purely local state, no cross-row tracking needed.
	-- Blizzard's own quest-log/achievement row-hover texture: an ADD-blend
	-- glow bar that fades at both ends on its own, rather than a flat
	-- rectangle with hard edges.
	row.hoverHighlight = row:CreateTexture(nil, "BACKGROUND")
	row.hoverHighlight:SetAllPoints()
	row.hoverHighlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	row.hoverHighlight:SetBlendMode("ADD")
	row.hoverHighlight:SetAlpha(0.4)
	row.hoverHighlight:Hide()

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(Row.HEIGHT - 4, Row.HEIGHT - 4)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.toggle = row:CreateTexture(nil, "ARTWORK")
	row.toggle:SetSize(Row.HEIGHT - 6, Row.HEIGHT - 6)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetJustifyH("LEFT")
	-- Truncate with "..." instead of wrapping to a second line -- always
	-- correct for a fixed-height row, but only ever mattered once the
	-- quality icon/count narrowed the available width enough for a long
	-- name to actually hit the limit.
	row.name:SetWordWrap(false)

	-- Item rows only: the real Blizzard crafting-quality icon (see
	-- CraftingQualityIcon below for why SetAtlas is pcall-guarded).
	row.qualityIcon = row:CreateTexture(nil, "OVERLAY")
	row.qualityIcon:SetSize(12, 12)

	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.count:SetJustifyH("LEFT")

	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		if self.entryKind ~= "item" or not self.itemLink then
			self.hoverHighlight:Show()
			return
		end
		ShowItemHover(self)
		PositionUseButtonOver(self)
	end)
	row:SetScript("OnLeave", function(self)
		-- Item rows hand hover off to the use-button overlay the moment it
		-- gets positioned on top (see PositionUseButtonOver/Q33 above) --
		-- THAT frame's OnLeave is what actually fires once the cursor
		-- leaves, not this one. For header rows nothing ever covers them,
		-- so this is still the real "mouse left" signal.
		if self.entryKind == "item" then return end
		self.hoverHighlight:Hide()
	end)
	row:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then return end
		-- Q40/Q41: shift-left-click an item row to pin/unpin it.
		if button == "LeftButton" and self.entryKind == "item" and IsShiftKeyDown() then
			if Row.OnItemPinToggle and self.itemID then
				Row.OnItemPinToggle(self.itemID)
			end
			return
		end
		if self.entryKind == "header" and self.categoryID and Row.OnHeaderClick then
			Row.OnHeaderClick(self.categoryID, self.dropStorage)
		end
	end)

	-- Drag an item onto a category header to recategorize or transfer it
	-- (Q43: which storage it transfers to comes from the header's own
	-- dropStorage, stamped per-window by Core/Init.lua). Drag a category
	-- header onto another to reorder them.
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function(self)
		if self.entryKind == "item" and Row.OnItemDragStart then
			dragInProgress = true
			ParkUseButton()
			Row.OnItemDragStart(self)
			StartItemDropTracking(self)
		elseif self.entryKind == "header" then
			dragInProgress = true
			ParkUseButton()
			StartHeaderReorderTracking(self)
		end
	end)
	row:SetScript("OnDragStop", function(self)
		dragInProgress = false
		local foci = GetMouseFoci and GetMouseFoci()
		local target = foci and foci[1]
		if self.entryKind == "item" and Row.OnItemDragStop then
			local dropPosition = StopItemDropTracking(self)
			Row.OnItemDragStop(self, target, dropPosition)
		elseif self.entryKind == "header" then
			local dropPosition, targetCategoryID = StopHeaderReorderTracking(self)
			if Row.OnHeaderDragStop then
				local droppedOutside = not target and IsCursorOutsideFrame(Folio.UI.Frame.Create())
				-- Resolved category id, not the raw row that was
				-- physically under the cursor (could be an item row
				-- proxying for it) -- Core/Init.lua just wants "which
				-- category", not which specific row.
				local resolvedTarget = targetCategoryID and { entryKind = "header", categoryID = targetCategoryID }
				Row.OnHeaderDragStop(self, resolvedTarget, dropPosition, droppedOutside)
			end
		end
	end)

	row.built = true
end

local function InitHeader(row, entry, indent)
	row.entryKind = "header"
	row.categoryID = entry.categoryID
	row.itemLink = nil
	-- Q43: which storage a drop on THIS row transfers an item to -- stamped
	-- by Core/Init.lua on every header row it builds for a given window
	-- (bags for the main window, bank/warband for the drawer's two
	-- sections), separate from the category tree itself (a category
	-- header means the same category regardless of which window it's
	-- rendered in).
	row.dropStorage = entry.dropStorage

	row.icon:Hide()

	row.toggle:Show()
	row.toggle:ClearAllPoints()
	row.toggle:SetPoint("LEFT", row, "LEFT", indent, 0)
	row.toggle:SetTexture(entry.collapsed and PLUS_TEXTURE or MINUS_TEXTURE)

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.name:SetText(entry.name .. " (" .. entry.count .. ")")
	row.name:SetTextColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])

	row.qualityIcon:Hide()
	row.count:Hide()
end

local function InitItem(row, entry, indent)
	row.entryKind = "item"
	row.categoryID = nil
	row.dropStorage = nil
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

	local color = ITEM_QUALITY_COLORS[entry.quality or 1] or { r = 1, g = 1, b = 1 }

	-- Built left-to-right so the quality icon and count sit immediately
	-- after the item name, instead of pinned to the row's own right edge
	-- (Q30: right-pinning left a large, unintentional gap after short
	-- names -- the cluster should hug the text, not the row).
	--
	-- row.name is first width-clamped to whatever space remains once the
	-- count/icon are reserved (so a too-long name still truncates with
	-- "..." rather than overrunning the row), then shrunk down to its
	-- actual rendered width whenever that's narrower than the clamp --
	-- otherwise the FontString's frame would stay at the clamp's full
	-- width for short names, and anchoring the icon/count to its RIGHT
	-- point would reproduce the exact "far right" gap this is fixing.
	local hasCount = (entry.count or 1) > 1
	if hasCount then
		row.count:SetText("(" .. entry.count .. ")")
		row.count:SetTextColor(color.r, color.g, color.b)
	end

	-- The real Blizzard icon for this item's specific tier (whichever
	-- visual convention its expansion actually uses -- Scanner.lua
	-- already resolved that via Core/API.lua). pcall-guarded: if
	-- SetAtlas ever throws on an unexpected atlas string, that must not
	-- abort the rest of this row's initialization.
	local iconOK = entry.craftingQualityIcon
		and pcall(row.qualityIcon.SetAtlas, row.qualityIcon, entry.craftingQualityIcon)

	local iconSize = Row.HEIGHT - 4
	local nameLeftOffset = indent + iconSize + 4
	-- row:GetWidth() should already be resolved by the ScrollBox's layout
	-- by the time an element's initializer runs, but 220 (this window's
	-- observed default content width) is a safe fallback if it's ever 0.
	local rowWidth = row:GetWidth()
	local availableWidth = (rowWidth > 0 and rowWidth or 220) - nameLeftOffset - 4

	local reserved = 0
	if iconOK then
		reserved = reserved + 12 + 4
	end
	if hasCount then
		reserved = reserved + row.count:GetStringWidth() + 4
	end
	local maxNameWidth = math.max(availableWidth - reserved, 20)

	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetText(entry.name or ("Item " .. tostring(entry.itemID)))
	row.name:SetTextColor(color.r, color.g, color.b)
	row.name:SetWidth(maxNameWidth)
	local actualNameWidth = row.name:GetStringWidth()
	if actualNameWidth > 0 and actualNameWidth < maxNameWidth then
		row.name:SetWidth(actualNameWidth)
	end

	local trailingAnchor = row.name
	row.qualityIcon:ClearAllPoints()
	if iconOK then
		row.qualityIcon:SetSize(12, 12)
		row.qualityIcon:SetPoint("LEFT", trailingAnchor, "RIGHT", 4, 0)
		row.qualityIcon:Show()
		trailingAnchor = row.qualityIcon
	else
		row.qualityIcon:Hide()
	end

	row.count:ClearAllPoints()
	if hasCount then
		row.count:SetPoint("LEFT", trailingAnchor, "RIGHT", 4, 0)
		row.count:Show()
	else
		row.count:Hide()
	end
end

function Row.Initialize(row, entry)
	if not row.built then
		Build(row)
	end

	local indent = 4 + (entry.depth or 0) * INDENT
	-- pcall-wrapped so a bug in any Init* function can never leave a row
	-- silently blank (Q29: a real anchor bug did exactly that -- a
	-- collapsed-to-zero-width FontString isn't a Lua error, so this
	-- alone wouldn't have caught it, but it's a cheap, permanent safety
	-- net against whatever the next one is) -- falls back to visible
	-- (red) text and surfaces the real error instead.
	local ok, err = pcall(function()
		if entry.kind == "header" then
			InitHeader(row, entry, indent)
		else
			InitItem(row, entry, indent)
		end
	end)
	if not ok then
		if not Row.lastInitError or Row.lastInitError ~= err then
			Row.lastInitError = err
			print("|cffff3333Folio row init error|r", err)
		end
		row.name:SetText(entry.name or ("Item " .. tostring(entry.itemID or "?")))
		row.name:SetTextColor(1, 0.2, 0.2)
	end
end

return Row
