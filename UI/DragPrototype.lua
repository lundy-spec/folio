-- Throwaway spike for Q17 (§4.3): feel out both candidate drag models
-- before locking the real ListView's event structure to either one.
-- Operates entirely on fake placeholder rows — no real item-movement API
-- calls — so there's no risk to actual inventory while testing feel.
-- Delete this file once Q17 is settled (§12 step 8).

local _, Folio = ...

local Proto = {}
Folio.UI = Folio.UI or {}
Folio.UI.DragPrototype = Proto

local ROW_HEIGHT = 18
local mode = "a" -- "a": drag=move, right-click=categorize · "b": drop target decides

local frame, modeButton, ghost
local categoryHeaders = {} -- name -> header frame
local subgroupHeaders = {} -- "Category/Sub" -> { frame, category, sub }

local ITEMS = {
	{ name = "Healing Potion", category = "Consumables", sub = "Bags" },
	{ name = "Mana Potion", category = "Consumables", sub = "Bags" },
	{ name = "Feast", category = "Consumables", sub = "Bank" },
	{ name = "Augment Rune", category = "Crafting", sub = "Bags" },
	{ name = "Weavercloth", category = "Crafting", sub = "Bank" },
}

local function Log(fmt, ...)
	print("|cff33ff99[dragtest]|r " .. string.format(fmt, ...))
end

local function FindDropTarget()
	for _, sub in pairs(subgroupHeaders) do
		if sub.frame:IsMouseOver() then
			return "subgroup", sub
		end
	end
	for name, header in pairs(categoryHeaders) do
		if header:IsMouseOver() then
			return "category", name
		end
	end
	return nil
end

local function HandleDrop(item, target, targetKind)
	if mode == "a" then
		if targetKind == "subgroup" then
			Log("MODE A: moved '%s' -> %s / %s", item.name, target.category, target.sub)
		else
			Log("MODE A: dropped on a category header -- no-op (drag only moves between subgroups in mode A)")
		end
	else -- mode b
		if targetKind == "category" then
			Log("MODE B: recategorized '%s' -> %s (metadata only, item stays put)", item.name, target)
		elseif target.category == item.category then
			Log("MODE B: transferred '%s' -> %s / %s (same category)", item.name, target.category, target.sub)
		else
			Log("MODE B: moved AND recategorized '%s' -> %s / %s", item.name, target.category, target.sub)
		end
	end
end

local function ShowCategoryMenu(owner, item)
	MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:CreateTitle("Move to category")
		for _, catName in ipairs({ "Consumables", "Crafting" }) do
			rootDescription:CreateButton(catName, function()
				Log("MODE A: right-click categorized '%s' -> %s", item.name, catName)
			end)
		end
	end)
end

local function CreateItemRow(parent, item, y)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -y)
	row:SetPoint("RIGHT", parent, "RIGHT", -8, 0)

	local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT")
	text:SetText(item.name)

	row:RegisterForDrag("LeftButton")

	row:SetScript("OnDragStart", function(self)
		ghost:SetText(item.name)
		ghost:Show()
		self:SetScript("OnUpdate", function()
			local x, cy = GetCursorPosition()
			local scale = UIParent:GetEffectiveScale()
			ghost:ClearAllPoints()
			ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 12, cy / scale + 12)
		end)
	end)

	row:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		ghost:Hide()
		local kind, target = FindDropTarget()
		if kind then
			HandleDrop(item, target, kind)
		else
			Log("dropped '%s' over empty space -- no-op", item.name)
		end
	end)

	row:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" and mode == "a" then
			ShowCategoryMenu(self, item)
		end
	end)

	return row
end

-- Drop-target hit boxes are invisible frames spanning a whole block (header
-- + every row under it), not just the thin header line — a drop anywhere
-- over a category's contents should count as hitting that category. Never
-- calls EnableMouse(true), so it doesn't intercept clicks/drags meant for
-- the row buttons layered inside it.
local function CreateHitBox(parent, startY, endY)
	local box = CreateFrame("Frame", nil, parent)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -startY)
	box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -startY)
	box:SetHeight(math.max(endY - startY, ROW_HEIGHT))
	return box
end

local function CreateSubgroupLabel(parent, subName, y)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -y)
	text:SetText(subName)
end

local function CreateCategoryLabel(parent, name, y)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
	text:SetText(name)
end

local function Build(parent)
	local byCategory, order = {}, {}
	for _, item in ipairs(ITEMS) do
		if not byCategory[item.category] then
			byCategory[item.category] = {}
			table.insert(order, item.category)
		end
		byCategory[item.category][item.sub] = byCategory[item.category][item.sub] or {}
		table.insert(byCategory[item.category][item.sub], item)
	end

	local y = 0
	for _, catName in ipairs(order) do
		local catStartY = y
		CreateCategoryLabel(parent, catName, y)
		y = y + ROW_HEIGHT
		for _, subName in ipairs({ "Bags", "Bank" }) do
			local rows = byCategory[catName][subName]
			if rows then
				local subStartY = y
				CreateSubgroupLabel(parent, subName, y)
				y = y + ROW_HEIGHT
				for _, item in ipairs(rows) do
					CreateItemRow(parent, item, y)
					y = y + ROW_HEIGHT
				end
				subgroupHeaders[catName .. "/" .. subName] = {
					frame = CreateHitBox(parent, subStartY, y),
					category = catName,
					sub = subName,
				}
			end
		end
		categoryHeaders[catName] = CreateHitBox(parent, catStartY, y)
	end
end

function Proto.Create()
	if frame then return frame end

	local f = CreateFrame("Frame", "FolioDragPrototype", UIParent, "PortraitFrameTemplate")
	f:SetSize(300, 320)
	f:SetPoint("LEFT", UIParent, "LEFT", 60, 0)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.SetTitle then
		f:SetTitle("Drag Test")
	end

	modeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	modeButton:SetSize(160, 22)
	modeButton:SetPoint("TOPLEFT", 12, -30)
	modeButton:SetText("Mode: A (drag=move)")
	modeButton:SetScript("OnClick", function()
		mode = (mode == "a") and "b" or "a"
		modeButton:SetText(mode == "a" and "Mode: A (drag=move)" or "Mode: B (drop decides)")
		Log("switched to mode %s", mode)
	end)

	ghost = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	ghost:Hide()

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", 8, -60)
	body:SetPoint("RIGHT", -8, 0)
	body:SetPoint("BOTTOM", 0, 8)

	Build(body)

	table.insert(UISpecialFrames, "FolioDragPrototype")
	f:Hide()
	frame = f
	return f
end

function Proto.Toggle()
	local f = Proto.Create()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end

return Proto
