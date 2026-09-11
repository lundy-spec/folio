local _, Folio = ...

-- Q43/Q54: the bank drawer -- slides out to the LEFT, from behind the
-- main Folio window, showing bank storage only (warband bank has its
-- own separate drawer, UI/WarbandFrame.lua, to the right). Thin wrapper
-- around the shared UI/DrawerFrame.lua factory -- see that file for the
-- actual window/animation implementation.

Folio.UI = Folio.UI or {}
Folio.UI.BankFrame = Folio.UI.DrawerFrame.New({
	name = "FolioBankFrame",
	title = "Folio - Bank",
	portraitIcon = "Interface\\Icons\\INV_Misc_Bag_10",
	side = "LEFT",
})

return Folio.UI.BankFrame
