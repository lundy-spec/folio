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
local portraitMenuButton
local listView
local bagSpaceText

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
	-- edge just the frame's standard 12px inset -- the corner menu no
	-- longer has its own dedicated button next to this one (see
	-- AddPortraitMenuButton) to leave room for.
	searchBox:SetPoint("TOPLEFT", 64, -32)
	searchBox:SetPoint("TOPRIGHT", -12, -32)
	searchBox:SetAutoFocus(false)
	searchBox:HookScript("OnTextChanged", function(self)
		Folio.Actions.SetSearchText(self:GetText())
	end)
	return searchBox
end

-- Corner menu's actual content -- shared so both the trigger below and
-- (eventually) anything else that wants the same menu don't duplicate it.
local function ShowCornerMenu(anchor)
	MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
		rootDescription:CreateButton("New Category", function()
			Folio.Actions.ShowNewCategoryDialog()
		end)
		rootDescription:CreateButton("Options", function()
			Folio.UI.Options.Open()
		end)
	end)
end

-- Confirmed live: Blizzard's own Combined Backpack window has no separate
-- hamburger-style button at all -- clicking its portrait icon directly
-- opens the equivalent menu. Following that pattern instead of a
-- dedicated control next to the search box. Nothing in PortraitFrameTemplate
-- itself makes the portrait clickable (this is Blizzard's own ContainerFrame
-- adding its own overlay, not a template feature), so this does the same:
-- a plain transparent Button sized to the portrait's own container.
local function AddPortraitMenuButton(f)
	local button = CreateFrame("Button", nil, f)
	-- SetAllPoints(f.PortraitContainer) produced a 1x1px button -- confirmed
	-- live via /folio debug (rect came back essentially a single point at
	-- the frame's own top-left corner). PortraitContainer is apparently
	-- just a zero-size layout anchor, not the portrait's actual visible
	-- bounds. Sized/positioned explicitly instead, using the same overhang
	-- clearance AddSearchBox already had to account for (its own TOPLEFT
	-- starts at 64, -32 specifically to clear the portrait's circular art).
	button:SetSize(64, 64)
	button:SetPoint("TOPLEFT", f, "TOPLEFT", -8, 8)
	-- Same fix AddMenuButton needed before it (Q22): f.CloseButton sits at
	-- frame level 510 -- some other header-chrome element is elevated way
	-- above the frame's own base level to guarantee it's always
	-- clickable, and would otherwise swallow this button's clicks too.
	button:SetFrameLevel(f.CloseButton:GetFrameLevel() + 1)

	-- No highlight texture or hover tooltip -- confirmed live the
	-- highlight square could get stuck showing over the portrait art
	-- rather than only appearing on actual mouseover, and Blizzard's own
	-- Combined Backpack doesn't decorate its portrait on hover either.
	button:SetScript("OnClick", function(self)
		ShowCornerMenu(self)
	end)
	return button
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
	-- Smaller than the well's own 20px height (not a flush fit) so it
	-- reads as sitting inside a padded well rather than wedged edge-to-
	-- edge in it -- 12px leaves 4px of clearance top and bottom, matching
	-- the well's own 4px border inset (UI/CurrencyBar.lua).
	btn:SetSize(12, 12)
	-- Sits inside currencyBar's own well now (UI/CurrencyBar.lua's
	-- BackdropTemplate border), not the main frame's bare corner --
	-- confirmed live the previous flat 8px-from-frame-corner anchor
	-- landed partly outside/overlapping the well's left edge once that
	-- border existed. "LEFT" centers it on the bar's own height
	-- automatically; 5px clears the border's 4px inset with a hair of
	-- breathing room.
	btn:SetPoint("LEFT", currencyBar, "LEFT", 5, 0)
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

	-- Bag space (used/total slots), right next to the button that opens
	-- Blizzard's own bags -- SetBagSpace (Core/Init.lua's RefreshItems)
	-- keeps this current on every bag change. Parented to btn, not f --
	-- confirmed live it rendered behind currencyBar's own well backdrop
	-- otherwise: a FontString draws at its PARENT's frame level, and
	-- currencyBar sits above f's base level (btn itself already needed
	-- to go a level above currencyBar just to be clickable, right above
	-- this comment) -- being a direct child of f left it a level below
	-- that backdrop instead of above it.
	bagSpaceText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bagSpaceText:SetPoint("LEFT", btn, "RIGHT", 6, 0)

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
		-- UnitName should always resolve by PLAYER_LOGIN (this frame's
		-- only current creation point), but falls back to the plain
		-- title rather than ever showing a literal "nil's Folio". Forever
		-- added surnames -- UnitName now plausibly returns "Given Sur" as
		-- one space-separated string with no separate accessor for just
		-- the given name, so take everything up to the first space.
		local playerName = UnitName("player")
		if playerName then
			playerName = playerName:match("^(%S+)")
		end
		f:SetTitle(playerName and (playerName .. "'s Folio") or "Folio")
	end
	if f.TitleContainer and f.TitleContainer.TitleText then
		-- PortraitFrameTemplate's own title defaults to plain white --
		-- confirmed live against Blizzard's own Combined Backpack window
		-- (same template), whose title renders in this warm gold instead.
		-- Same value as UI/Row.lua's category header color, for the same
		-- reason: matching Blizzard's own UI language rather than an
		-- arbitrary pick. The FontString lives under TitleContainer, not
		-- directly on the frame -- confirmed live (a first attempt at
		-- f.TitleText errored, "attempt to index field 'TitleText' (a nil
		-- value)").
		f.TitleContainer.TitleText:SetTextColor(1, 0.82, 0, 1)
	end
	if f.SetPortraitToAsset then
		f:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_08")
	end
	if f.Bg then
		-- Confirmed live against Blizzard's own Combined Backpack window
		-- (same template): its body fill lets a bit of the scene behind
		-- it show through instead of sitting fully opaque like this did.
		-- Bg is the flat body-fill layer specifically (separate from the
		-- header/border art), so this doesn't touch either of those.
		-- 0.7 is a first pass, not a confirmed-live match -- tune from a
		-- screenshot.
		f.Bg:SetAlpha(0.7)
	end

	AddResizeGrip(f)
	local currencyBar = AddCurrencyBar(f)
	listView = AddListView(f, currencyBar)
	AddSearchBox(f)
	portraitMenuButton = AddPortraitMenuButton(f)
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

-- §Options: percent display is a formatting choice only -- the low-space
-- warning color below is keyed off the real used-space fraction either
-- way, not whatever's currently shown. Confirmed live: a flat "10 free
-- slots" threshold triggered way earlier than intended on a 32-slot bag
-- (net 69% used) -- scales with bag size instead, at 90% full, so a
-- 20-slot bag and 32-slot bag both warn at the same fullness.
local LOW_SPACE_PERCENT = 0.9
local LOW_SPACE_COLOR = { 1, 0.15, 0.15 }
local NORMAL_COLOR = { 1, 1, 1 }

function Frame.SetBagSpace(used, total)
	if not bagSpaceText then return end
	local usedPercent = total > 0 and (used / total) or 0
	if Folio.Config.db.showBagSpaceAsPercent then
		bagSpaceText:SetText(math.floor(usedPercent * 100 + 0.5) .. "%")
	else
		bagSpaceText:SetText(("%d/%d"):format(used, total))
	end
	local color = usedPercent >= LOW_SPACE_PERCENT and LOW_SPACE_COLOR or NORMAL_COLOR
	bagSpaceText:SetTextColor(color[1], color[2], color[3])
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
	if portraitMenuButton then
		print("|cff33ff99Folio debug|r portraitMenuButton rect =",
			portraitMenuButton:GetLeft(), portraitMenuButton:GetRight(),
			portraitMenuButton:GetTop(), portraitMenuButton:GetBottom(),
			"scale=", portraitMenuButton:GetEffectiveScale(), "strata=", portraitMenuButton:GetFrameStrata(),
			"level=", portraitMenuButton:GetFrameLevel(), "alpha=", portraitMenuButton:GetAlpha(),
			"shown=", portraitMenuButton:IsShown(), "visible=", portraitMenuButton:IsVisible())
	end
end

return Frame
