local menu = {}

local click_closureref = nil
local show_closureref = nil
local most_recent_menuitems = nil

function menu.show(show_fn)
  local wrapped_show_fn = function()
    most_recent_menuitems = show_fn()
    return most_recent_menuitems
  end

  local click_fn = function(i)
    local item = most_recent_menuitems[i]
    item.fn()
  end

  click_closureref, show_closureref = __api.menu_show(wrapped_show_fn, click_fn)
end

function menu.hide()
  __api.menu_hide(click_closureref, show_closureref)
end

return menu
