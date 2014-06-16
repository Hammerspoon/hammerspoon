local menu = {}

function menu.show(fn)
  __api.menu_show(fn)
end

function menu.hide()
  __api.menu_hide()
end

return menu
