local _, Folio = ...

-- §6.2 UI1: bounded height, always.
local MAX_HEIGHT_SCREEN_PCT = 0.6
-- §6.2 UI2: narrow enough to read as a list, wide enough for a full item name.
local MIN_WIDTH, MAX_WIDTH = 260, 500
local MIN_HEIGHT = 200

local Frame = {}
Folio.UI = Folio.UI or {}
Folio.UI.Frame = Frame

local frame

local function SavePosition(f)
	local point, _, relativePoint, x, y = f:GetPoint()
	local db = Folio.Config.db.frame
	db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
end

local function SaveSize(f)
	local db = Folio.Config.db.frame
	db.width, db.height = f:GetWidth(), f:GetHeight()
end

-- Placeholder rows only — real virtualized ListView lands in a later spike
-- (§12 step 9). This step is purely about proportions, anchoring, and resize
-- feel per §6.2's "build the frame shell and look at it."
local function AddPlaceholderRows(f)
	local rows = {
		"Consumables (12)",
		"  Flask of Alchemical Chaos  5",
		"  Healing Potion  20",
		"Crafting (31)",
		"Uncategorized (47)",
	}
	local prev
	for _, text in ipairs(rows) do
		local row = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		if prev then
			row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
		else
			row:SetPoint("TOPLEFT", 14, -64)
		end
		row:SetText(text)
		prev = row
	end
end

local function AddResizeGrip(f, maxHeight)
	local grip = CreateFrame("Button", nil, f)
	grip:SetPoint("BOTTOMRIGHT", -6, 6)
	grip:SetSize(16, 16)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		f:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		SaveSize(f)
	end)
end

function Frame.Create()
	if frame then return frame end

	local db = Folio.Config.db.frame
	local maxHeight = GetScreenHeight() * MAX_HEIGHT_SCREEN_PCT

	local f = CreateFrame("Frame", "FolioFrame", UIParent, "PortraitFrameTemplate")
	f:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
	f:SetSize(db.width, math.min(db.height, maxHeight))

	-- §6.2 UI3: resizable both axes, persisted independently.
	f:SetResizable(true)
	if f.SetResizeBounds then
		f:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, maxHeight)
	elseif f.SetMinResize then
		f:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		f:SetMaxResize(MAX_WIDTH, maxHeight)
	end

	-- §6.2 UI5: never let the frame wander mostly off-screen.
	f:SetClampedToScreen(true)

	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition(self)
	end)

	if f.SetTitle then
		f:SetTitle("Folio")
	end

	AddResizeGrip(f, maxHeight)
	AddPlaceholderRows(f)

	-- §6: register with the UI panel system so Escape closes it like any
	-- other Blizzard panel.
	table.insert(UISpecialFrames, "FolioFrame")

	f:Hide()
	frame = f
	return f
end

function Frame.Toggle()
	local f = Frame.Create()
	if f:IsShown() then
		f:Hide()
	else
		f:Show()
	end
end

return Frame
