local _, Folio = ...

-- Q54: the warband drawer -- slides out to the RIGHT, from behind the
-- main Folio window, showing warband bank storage only (personal bank
-- has its own separate drawer, UI/BankFrame.lua, to the left). Thin
-- wrapper around the shared UI/DrawerFrame.lua factory -- see that file
-- for the actual window/animation implementation.

Folio.UI = Folio.UI or {}
Folio.UI.WarbandFrame = Folio.UI.DrawerFrame.New({
	name = "FolioWarbandFrame",
	title = "Folio - Warband",
	portraitIcon = "Interface\\Icons\\INV_Misc_Bag_09",
	side = "RIGHT",
})

return Folio.UI.WarbandFrame
