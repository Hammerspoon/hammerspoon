local menu = {}

local __closureref = nil

function menu.show(fn)
  __closureref = __api.menu_show(fn)
end

function menu.hide()
  __api.menu_hide(__closureref)
end

return menu
