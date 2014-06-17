local menu = {}

local __click_closureref = nil
local __show_closureref = nil

function menu.show(click_fn, show_fn)
  __click_closureref, __show_closureref = __api.menu_show(click_fn, show_fn)
end

function menu.hide()
  __api.menu_hide(__click_closureref, __show_closureref)
end

return menu
