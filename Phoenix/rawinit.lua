-- set both require-paths
local thisdir = ...
package.path = os.getenv("HOME") .. "/.phoenix/?.lua;" .. package.path -- user configs
package.path = thisdir .. "/?.lua;" .. package.path                    -- built-in configs

local alert = require("alert")

-- load user's config
local ok, err = pcall(function()
    local phoenix = require("phoenix")
    phoenix.reload()
end)

-- report err in user's config
if not ok then alert.show(err, 5) end






-- test bed
local ok, err = pcall(function()
    -- local util = require("util")
    -- print(util.reduce({2, 3, 4}, function(a, b) return a + b end))

    -- local window = require("window")
    -- local screen = require("screen")
    -- local hotkey = require("hotkey")
    -- hotkey.bind({"cmd", "shift"}, "d", function()
    --     local win = window.focusedwindow()
    --     local f = win:frame()
    --     f.x = f.x + 40
    --     f.y = f.y + 40
    --     f.w = f.w - 80
    --     f.h = f.h - 80
    --     win:setframe(f)
    -- end)

    -- for _, win in pairs(window.visiblewindows()) do
    --   print("[" .. win:title() .. "]")

    --   if win:title() == "sdegutis" then
    --     win:focus()
    --   end
    -- end

    local menu = require("menu")
    local i = 0
    menu.show(function()
        i = i + 1
        return {
          {title = "number "..tostring(i), fn = function() print("got a") end, checked = true},
          {title = "hello", fn = function() print("got b") end},
          {title = "-", fn = function() print("got c") end},
          {title = "world", fn = function() print("got d") end},
        }
    end)

end)
if not ok then alert.show(err, 5) end















-- local application = require("application")

-- for i, app in pairs(application.running_applications()) do
--   print(app)
--   print(app.pid)
--   print(app:title())
-- end


-- local hotkey = require("hotkey")
-- local pathwatcher = require("pathwatcher")

-- local m = nil

-- hotkey.new({"cmd", "shift"}, "a", function()
--     m = pathwatcher.new("/Users/sdegutis/projects/phoenix/Phoenix", function()
--                           print("here!")
--     end)
-- end):enable()

-- hotkey.new({"cmd", "shift"}, "b", function()
--     m:start()
-- end):enable()

-- hotkey.new({"cmd", "shift"}, "c", function()
--     m:stop()
-- end):enable()

-- print("ready")



-- -- print(__api)
-- -- print(__api.app_running_apps)

-- -- for k, v in pairs(__api.app_running_apps()) do
-- --    print(k, __api.app_title(v))
-- -- end

__api.menu_icon_show()

-- -- lol = __api.path_watcher_start("/Users/sdegutis/projects/phoenix", function()
-- --                             print(lol)
-- --                             __api.path_watcher_stop(lol)
-- --                                                              end)



-- -- __api.alert_show("hi!", 1)



-- for k, pid in pairs(__api.app_running_apps()) do
--    local x = __api.app_get_windows(pid)
--    print(__api.app_title(pid))
--    for k, v in pairs(x) do
--       print(k, v)
--    end
-- end

-- collectgarbage()



-- __api.hotkey_setup(function(uid)
--                       local w = __api.window_get_focused_window()
--                       print(__api.window_role(w))
--                    end)
-- __api.hotkey_register(true, true, true, false, "s")


-- print("done")

-- -- local x, y = __api.mouse_get()

-- -- __api.hotkey_setup(function(uid)
-- --                       __api.mouse_set(x, y)
-- --                       print("got: " .. tostring(uid))
-- --                    end)

-- -- local uid, carbonkey = __api.hotkey_register(true, true, true, false, "s")

-- -- print(uid, carbonkey)
