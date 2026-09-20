local _, Folio = ...

-- Blizzard's WowScrollBoxList + MinimalScrollBar per §6.1 — a 400-row
-- list only instantiates the handful of rows actually visible. Renders
-- whatever flattened row list Logic/Render.lua produces (category
-- headers, section labels, and items alike) via one shared row template
-- — see UI/Row.lua.
--
-- Q43: instance-returning factory, not a module-level singleton --
-- the bank drawer (UI/BankFrame.lua) needs its own independent
-- ScrollBox/pool alongside the main window's.

local ListView = {}
Folio.UI = Folio.UI or {}
Folio.UI.ListView = ListView

-- The shared secure "use" button (UI/Row.lua) only ever needs to exist
-- once, regardless of how many ListView instances end up hovering rows
-- into it -- EnsureUseButton is itself idempotent, but no need to call it
-- more than once either.
local useButtonEnsured = false

function ListView.Create(parent)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(Folio.UI.Row.HEIGHT)
	view:SetElementInitializer("BackdropTemplate", function(row, item)
		Folio.UI.Row.Initialize(row, item)
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	-- Experimenting with hiding the scrollbar entirely when the current
	-- row count fits without scrolling, rather than always reserving its
	-- space -- Blizzard's own ScrollBar mixin already has this exact
	-- toggle built in.
	scrollBar:SetHideIfUnscrollable(true)

	if not useButtonEnsured then
		useButtonEnsured = true
		-- Eagerly, once, at login -- not lazily on first item hover --
		-- since the shared secure "use" button's SetPassThroughButtons
		-- call is itself combat-restricted (10.1.5+); it needs to exist
		-- before combat could plausibly start.
		Folio.UI.Row.EnsureUseButton(scrollBox)
	end

	local instance = {
		scrollBox = scrollBox,
		scrollBar = scrollBar,
		view = view,
	}

	function instance:SetItems(items)
		local provider = CreateDataProvider()
		if #items > 0 then
			provider:InsertTable(items)
		end
		self.view:SetDataProvider(provider)
	end

	return instance
end

return ListView
