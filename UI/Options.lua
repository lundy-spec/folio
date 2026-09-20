local _, Folio = ...

-- Canvas-layout Settings panel (Patch 10.0+ API). No declarative widget
-- helpers exist for canvas layouts (those are vertical-layout only), so
-- this hand-builds frames the same way UI/Frame.lua and UI/Row.lua do.
local Options = {}
Folio.UI = Folio.UI or {}
Folio.UI.Options = Options

local category

local function AddTitle(f)
	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Folio")
	return title
end

local function AddBagReplacementCheckbox(f, anchor)
	local check = CreateFrame("CheckButton", nil, f, "ChatConfigCheckButtonTemplate")
	check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -16)
	check.Text:SetText("Replace default bags (B opens Folio)")
	check:SetScript("OnClick", function(self)
		if self:GetChecked() ~= Folio.Config.db.bagReplacementEnabled then
			Folio.Actions.ToggleBagReplacement()
		end
	end)
	f:SetScript("OnShow", function()
		check:SetChecked(Folio.Config.db.bagReplacementEnabled)
	end)
	return check
end

local function AddBagSpacePercentCheckbox(f, anchor)
	local check = CreateFrame("CheckButton", nil, f, "ChatConfigCheckButtonTemplate")
	check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
	check.Text:SetText("Show bag space as a percentage")
	check:SetScript("OnClick", function(self)
		if self:GetChecked() ~= Folio.Config.db.showBagSpaceAsPercent then
			Folio.Actions.ToggleBagSpaceAsPercent()
		end
	end)
	f:HookScript("OnShow", function()
		check:SetChecked(Folio.Config.db.showBagSpaceAsPercent)
	end)
	return check
end

local function MakeButton(f, text, width)
	local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	btn:SetSize(width, 22)
	btn:SetText(text)
	return btn
end

local function AddCollapseButtons(f, anchor)
	local collapseBtn = MakeButton(f, "Collapse All", 130)
	collapseBtn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -16)
	collapseBtn:SetScript("OnClick", function()
		Folio.Actions.SetAllCollapsed(true)
	end)

	local expandBtn = MakeButton(f, "Expand All", 130)
	expandBtn:SetPoint("LEFT", collapseBtn, "RIGHT", 8, 0)
	expandBtn:SetScript("OnClick", function()
		Folio.Actions.SetAllCollapsed(false)
	end)

	return collapseBtn
end

StaticPopupDialogs["FOLIO_RESET_CATEGORIES"] = {
	text = "Reset all Folio categories to defaults?\nThis deletes every category you've created and clears manual item sorting. This cannot be undone.",
	button1 = "Reset",
	button2 = "Cancel",
	OnAccept = function()
		Folio.Actions.ResetCategories()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function AddResetButton(f, anchor)
	local btn = MakeButton(f, "Reset Categories to Defaults", 220)
	btn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -20)
	btn:SetScript("OnClick", function()
		StaticPopup_Show("FOLIO_RESET_CATEGORIES")
	end)
	return btn
end

function Options.Create()
	if category then return category end

	local f = CreateFrame("Frame")
	f.name = "Folio"

	local title = AddTitle(f)
	local check = AddBagReplacementCheckbox(f, title)
	local percentCheck = AddBagSpacePercentCheckbox(f, check)
	local collapseBtn = AddCollapseButtons(f, percentCheck)
	AddResetButton(f, collapseBtn)

	category = Settings.RegisterCanvasLayoutCategory(f, f.name)
	Settings.RegisterAddOnCategory(category)

	return category
end

-- Confirmed live: passing the addon's own name string as the category id
-- (a previously-common idiom, and what this used to do via a hand-set
-- category.ID) now fails -- OpenSettingsPanel validates its argument as a
-- real integer and rejects a string with "outside of expected range".
-- category:GetID() is the actual id Blizzard assigned on registration.
function Options.Open()
	Settings.OpenToCategory(Options.Create():GetID())
end

return Options
