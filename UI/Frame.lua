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
local menuButton
local listView

-- Set by Core/Init.lua. Q52: fires whenever this window is hidden, by
-- ANY means -- its own close button, /folio, or Escape (UISpecialFrames)
-- -- so the bank drawer closes right along with it regardless of how
-- Folio itself got closed.
Frame.OnClosed = nil

local function SavePosition(f)
	local point, _, relativePoint, x, y = f:GetPoint()
	local db = Folio.Config.db.frame
	db.point, db.relativePoint, db.x, db.y = point, relativePoint, x, y
end

local function SaveSize(f)
	local db = Folio.Config.db.frame
	db.width, db.height = f:GetWidth(), f:GetHeight()
end

-- §6.3: fixed footer strip, pinned currencies only, above the resize grip.
local function AddCurrencyBar(f)
	local bar = Folio.UI.CurrencyBar.Create(f)
	bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
	bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 8)
	return bar
end

-- §12 step 9: real virtualized ListView, no categories yet (those land
-- in step 12). Anchored TOPLEFT/BOTTOMRIGHT so it resizes with the frame.
-- Top edge sits below the search row (Q39) instead of directly under the
-- title bar.
local function AddListView(f, currencyBar)
	local lv = Folio.UI.ListView.Create(f)
	lv.scrollBox:SetPoint("TOPLEFT", 12, -60)
	lv.scrollBox:SetPoint("BOTTOMRIGHT", currencyBar, "TOPRIGHT", 0, 4)
	lv.scrollBar:SetPoint("TOPLEFT", lv.scrollBox, "TOPRIGHT", 4, 0)
	lv.scrollBar:SetPoint("BOTTOMLEFT", lv.scrollBox, "BOTTOMRIGHT", 4, 0)
	return lv
end

-- Q39: matches Blizzard's own bag search (screenshot-confirmed against
-- the "Combined Backpack" window) -- SearchBoxTemplate directly, not a
-- hand-rolled EditBox, gets the magnifying-glass icon, grey "Search"
-- placeholder, and clear ("X") button for free, all wired by Blizzard's
-- own mixin. HookScript (not SetScript) for OnTextChanged so Folio's
-- filter logic runs ALONGSIDE the template's own instructions/
-- clear-button handling instead of replacing it.
local function AddSearchBox(f)
	local searchBox = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	-- Left edge cleared past the portrait icon's circular overhang
	-- (PortraitFrameTemplate) -- confirmed live: at the same 12px inset
	-- everything else in the frame uses, the portrait covered the
	-- magnifying glass and most of the "Search" placeholder text. Right
	-- edge leaves room for the corner menu button, anchored off of this
	-- box itself (see AddMenuButton) rather than a fixed inset.
	searchBox:SetPoint("TOPLEFT", 64, -32)
	searchBox:SetPoint("TOPRIGHT", -32, -32)
	searchBox:SetAutoFocus(false)
	searchBox:HookScript("OnTextChanged", function(self)
		Folio.Actions.SetSearchText(self:GetText())
	end)
	return searchBox
end

-- Corner menu: the actual template Blizzard uses for a small icon-only
-- menu-trigger button (Blizzard_Menu/MenuTemplates.xml,
-- WowStyle2IconButtonTemplate) rather than a hand-rolled backdrop -- same
-- family as the close button's own template, which is why that one
-- looks native for free. Its mixin handles its own hover/pressed/
-- disabled background art; `normalAtlas`/`disabledAtlas` are properties
-- the consumer is expected to set for the icon layer (no default),
-- refreshed via a manual OnButtonStateChanged() call since OnLoad
-- already ran once, with nothing set, by the time CreateFrame returns.
-- Sits to the right of the search box (Q39), same row.
local function AddMenuButton(f, searchBox)
	local menu = CreateFrame("Button", nil, f, "WowStyle2IconButtonTemplate")
	-- The mixin re-applies its background/icon atlases at their native
	-- size on every hover/click (UseAtlasSize), which would just undo a
	-- plain SetSize the next time it's moused over -- SetScale shrinks
	-- everything as a rendering transform instead, so it isn't fighting
	-- that logic. Close button is ~24x24 at full scale; this reads as a
	-- clearly secondary, smaller control next to it.
	menu:SetScale(0.75)
	menu:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	-- Debug (Q22) found the real bug behind three earlier invisible
	-- attempts: f.CloseButton sits at frame level 510 -- some other
	-- header-chrome element in the template is elevated way above the
	-- frame's own base level to guarantee it's always clickable, and was
	-- painting over this button the whole time. IsVisible() doesn't
	-- account for that (it only reflects the show/hide chain, not draw
	-- order), which is why every earlier diagnostic looked clean.
	-- Anchoring off the close button's own level instead of the frame's
	-- clears whatever that element is.
	menu:SetFrameLevel(f.CloseButton:GetFrameLevel() + 1)

	-- Keep the template's own background chrome (dark bordered square,
	-- already confirmed to look right) but skip its Icon layer -- no
	-- native Blizzard hamburger-menu asset exists (three stacked lines is
	-- a web/mobile convention, not part of Blizzard's own UI language),
	-- so this draws one by hand instead: three flat bars, same
	-- SetColorTexture technique already used for the drag/hover
	-- indicators elsewhere in UI/Row.lua.
	menu.normalAtlas = "common-dropdown-c-button-hover-arrow"
	menu.disabledAtlas = "common-dropdown-c-button-hover-arrow"
	menu:OnButtonStateChanged()
	menu.Icon:Hide()

	for i = -1, 1 do
		local bar = menu:CreateTexture(nil, "OVERLAY")
		bar:SetSize(9, 2)
		bar:SetPoint("CENTER", 0, i * 4)
		bar:SetColorTexture(1, 0.82, 0, 1)
	end

	menu:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, rootDescription)
			rootDescription:CreateButton("New Category", function()
				Folio.Actions.ShowNewCategoryDialog()
			end)
			rootDescription:CreateButton("Options", function()
				Folio.UI.Options.Open()
			end)
		end)
	end)
	return menu
end

-- Q36/Q38: a plain button whose OnClick (or a dropdown-menu entry, tried
-- and reverted -- see Core/Init.lua's ArmBlizzardBagsPeek) calls Folio's
-- own Lua to open Blizzard's bags doesn't work -- the OpenAllBags/
-- ToggleAllBags taint bug (Core/BagReplacement.lua's header) is confirmed
-- even from a bare `/run OpenAllBags()` console command, so it's not
-- about how or where an addon calls it -- any insecure Lua call taints
-- the item buttons (or, as seen live, can corrupt the container frame's
-- own layout -- only the reagent bag rendered instead of the full
-- combined window) until /reload. The only safe trigger is BLIZZARD's own
-- OnClick script on BLIZZARD's own button making the call, with zero
-- addon Lua frames in that specific call -- exactly what a secure
-- "type=click, clickbutton=<frame>" forward gives you, but ONLY when the
-- real hardware click lands directly on THIS button. A dropdown menu item
-- doesn't qualify (the click lands on the menu's own row, which calls
-- back into addon Lua normally -- same taint problem as calling it
-- outright) -- that's why this is a real, always-visible button, not a
-- menu entry.
local function AddShowBagsButton(f, currencyBar)
	local btn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
	btn:SetSize(14, 14)
	-- Tucked directly into the frame's own bottom-left corner (not
	-- centered on currencyBar's row) with a flat 8px inset on both axes,
	-- rather than following currencyBar's own (12, 8) padding.
	btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
	-- currencyBar spans the ENTIRE footer width (BOTTOMLEFT to BOTTOMRIGHT
	-- of the main frame, per AddCurrencyBar) and is itself mouse-enabled
	-- with its own OnEnter/tooltip -- geometrically this button sits
	-- inside that hit area, and without an explicit level bump the
	-- sibling frame created first (currencyBar) won every hit test,
	-- confirmed live (hovering showed currencyBar's "Gold" tooltip
	-- instead of this button's own).
	btn:SetFrameLevel(currencyBar:GetFrameLevel() + 1)
	btn:SetNormalTexture("Interface\\Icons\\INV_Misc_Bag_08")
	btn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	btn:RegisterForClicks("AnyUp", "AnyDown")
	btn:SetAttribute("type", "click")
	btn:SetAttribute("clickbutton", MainMenuBarBackpackButton)

	-- Ordinary insecure PreClick -- not part of the secure dispatch, runs
	-- and fully completes before the engine performs the actual forward,
	-- so it's safe to touch normal addon state here (the global-function
	-- swap in Core/BagReplacement.lua is just a plain table write, never a
	-- protected call itself). Without this, MainMenuBarBackpackButton's
	-- own OnClick would read _G.ToggleBackpack -- which, while replacement
	-- is on, IS Folio's own override -- and the forwarded click would just
	-- reopen Folio instead of Blizzard's bags.
	btn:SetScript("PreClick", function()
		Folio.Actions.ArmBlizzardBagsPeek()
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Toggle Blizzard Bags")
		GameTooltip:AddLine("Opens Blizzard's bags alongside Folio -- switches back once you close them.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return btn
end

local function AddResizeGrip(f)
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

	-- Q48: one tier above the bank drawer's own open-state "HIGH" strata
	-- (UI/BankFrame.lua) -- the drawer now deliberately overlaps this
	-- window's left edge by a few pixels so it reads as tucked in BEHIND
	-- it, which only works if this window renders on top in that overlap.
	f:SetFrameStrata("DIALOG")

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
	if f.SetPortraitToAsset then
		f:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_08")
	end

	AddResizeGrip(f)
	local currencyBar = AddCurrencyBar(f)
	listView = AddListView(f, currencyBar)
	local searchBox = AddSearchBox(f)
	menuButton = AddMenuButton(f, searchBox)
	AddShowBagsButton(f, currencyBar)

	-- §6: register with the UI panel system so Escape closes it like any
	-- other Blizzard panel.
	table.insert(UISpecialFrames, "FolioFrame")

	f:HookScript("OnHide", function()
		if Frame.OnClosed then
			Frame.OnClosed()
		end
	end)

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

function Frame.SetItems(rows)
	if not listView then return end
	listView:SetItems(rows)
end

-- TEMP DEBUG (Q22): the corner menu button hasn't shown up in three
-- attempts, with no Lua error and no print output either at PLAYER_LOGIN
-- time -- on-demand via /folio debug instead, so there's no scrollback/
-- login-spam to lose it in, and it can be re-run freely.
function Frame.Debug()
	local f = Frame.Create()
	print("|cff33ff99Folio debug|r screen =", GetScreenWidth(), GetScreenHeight())
	print("|cff33ff99Folio debug|r frame rect =", f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom(),
		"scale=", f:GetEffectiveScale(), "strata=", f:GetFrameStrata(), "level=", f:GetFrameLevel())
	print("|cff33ff99Folio debug|r f.CloseButton rect =",
		f.CloseButton:GetLeft(), f.CloseButton:GetRight(), f.CloseButton:GetTop(), f.CloseButton:GetBottom(),
		"level=", f.CloseButton:GetFrameLevel())
	if menuButton then
		print("|cff33ff99Folio debug|r menuButton rect =",
			menuButton:GetLeft(), menuButton:GetRight(), menuButton:GetTop(), menuButton:GetBottom(),
			"scale=", menuButton:GetEffectiveScale(), "strata=", menuButton:GetFrameStrata(),
			"level=", menuButton:GetFrameLevel(), "alpha=", menuButton:GetAlpha(),
			"shown=", menuButton:IsShown(), "visible=", menuButton:IsVisible())
	end
end

return Frame
