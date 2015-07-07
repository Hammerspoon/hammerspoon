--- === hs.windowtracker ===
---
--- Track all windows on the screen. windowtracker abstracts away applications and treats all
--- windows the same, subscribing to all events on all windows.
---
--- You can watch for the following events:
--- * hs.windowtracker.windowCreated: A window was created.
--- * hs.windowtracker.windowDestroyed: A window was destroyed.
--- * hs.windowtracker.mainWindowChanged: The main window was changed. This is usually the same as
---   the focused window (except for helper dialog boxes like file pickers, which are not reported
---   by this event). Note that switching applications triggers this event, unlike the OS X
---   accessibility API.
--- * hs.windowtracker.windowMoved: A window was moved.
--- * hs.windowtracker.windowResized: A window was resized.
--- * hs.windowtracker.windowMinimized: A window was minimized.
--- * hs.windowtracker.windowUnminimized: A window was unminimized.
---
--- Note that Hammerspoon windows (the console) are ignored by windowtracker. This is because the
--- console pops after an error, which can cause infinite exception loops, rendering the computer
--- unusable.

local windowtracker = {}

windowtracker.windowCreated     = hs.uielement.watcher.windowCreated
windowtracker.windowDestroyed   = hs.uielement.watcher.elementDestroyed
windowtracker.mainWindowChanged = hs.uielement.watcher.mainWindowChanged
windowtracker.windowCreated     = hs.uielement.watcher.windowCreated
windowtracker.windowMoved       = hs.uielement.watcher.windowMoved
windowtracker.windowResized     = hs.uielement.watcher.windowResized
windowtracker.windowMinimized   = hs.uielement.watcher.windowMinimized
windowtracker.windowUnminimized = hs.uielement.watcher.windowUnminimized

--- hs.windowtracker.new(watchEvents, handler) -> windowtracker
--- Constructor
--- Creates a new tracker for the given events.
---
--- handler receives two arguments: the window object and the event name.
function windowtracker.new(watchEvents, handler)
  obj = {
    appsWatcher    = nil,
    watchers       = {},
    handler        = handler,
    watchEvents    = watchEvents,
    winWatchEvents = {},
    started        = false
  }

  -- Decide which events will be watched on new windows. Exclude events that are watched on the app.
  local nonWindowEvents = {windowtracker.windowCreated, windowtracker.mainWindowChanged}
  for i, event in pairs(watchEvents) do
    if not hs.fnutils.contains(nonWindowEvents, event) then table.insert(obj.winWatchEvents, event) end
  end
  if not hs.fnutils.contains(obj.winWatchEvents, windowtracker.windowDestroyed) then
    table.insert(obj.winWatchEvents, windowtracker.windowDestroyed)  -- always watch this event
  end

  setmetatable(obj, windowtracker)
  return obj
end

--- hs.windowtracker:start()
--- Method
--- Starts tracking all windows.
function windowtracker:start()
  if self.started then return end

  self.appsWatcher = hs.application.watcher.new(function(...) self:_handleGlobalAppEvent(...) end)
  self.appsWatcher:start()

  -- Watch any apps that already exist
  local apps = hs.application.runningApplications()
  for i = 1, #apps do
    if apps[i]:title() ~= "Hammerspoon" then
      self:_watchApp(apps[i], true)
    end
  end

  self.started = true
end

--- hs.windowtracker:stop()
--- Method
--- Stops tracking all windows.
---
--- The handler will not be called after this method, unless start() is called again.
function windowtracker:stop()
  if not self.started then return end

  self.appsWatcher:stop()
  for pid, appWatchers in pairs(self.watchers) do
    for watcherId, watcher in pairs(appWatchers) do
      watcher:stop()
    end
  end
  self.watchers = {}

  self.started = false
end

function windowtracker:_handleGlobalAppEvent(name, event, app)
  if     event == hs.application.watcher.launched then
    self:_watchApp(app)
  elseif event == hs.application.watcher.terminated then
    self.watchers[app:pid()] = nil
  end
end

function windowtracker:_watchApp(app, starting)
  if not app:isApplication() then return end
  if self.watchers[app:pid()] then return end

  local watcher = app:newWatcher(function(...) self:_handleAppEvent(...) end)
  self.watchers[app:pid()] = {app=watcher}

  if hs.fnutils.contains(self.watchEvents, windowtracker.mainWindowChanged) then
    watcher:start({
      windowtracker.windowCreated,
      windowtracker.mainWindowChanged,
      hs.uielement.watcher.applicationActivated})
  else
    watcher:start({windowtracker.windowCreated})
  end

  -- Watch any windows that already exist
  for i, window in pairs(app:allWindows()) do
    self:_watchWindow(window, starting)
  end
  local wins = app:allWindows()
end

function windowtracker:_handleAppEvent(element, event)
  if     event == windowtracker.windowCreated then
    local isNew = self:_watchWindow(element)

    -- Track event if wanted.
    if isNew and hs.fnutils.contains(self.watchEvents, windowtracker.windowCreated) then
      self.handler(element, windowtracker.windowCreated)
    end
  elseif event == windowtracker.mainWindowChanged and element:isWindow()
         and element:application() == hs.application.frontmostApplication() then
    self.handler(element, windowtracker.mainWindowChanged)
  elseif event == hs.uielement.watcher.applicationActivated then
    -- Generate a mainWindowChanged event since the application changed.
    self.handler(element:mainWindow(), windowtracker.mainWindowChanged)
  end
end

function windowtracker:_watchWindow(win, starting)
  if not win:isWindow() or not win:isStandard() then return end

  -- Ensure we don't track a window twice.
  local appWindows = self.watchers[win:application():pid()]
  if not appWindows[win:id()] then
    local watcher = win:newWatcher(function(...) self:_handleWindowEvent(...) end)
    appWindows[win:id()] = watcher

    watcher:start(self.winWatchEvents)
    return true
  end

  return false
end

function windowtracker:_handleWindowEvent(win, event, watcher)
  if win ~= watcher:element() then return end
  if event == windowtracker.windowDestroyed then
    self.watchers[win:pid()][win:id()] = nil
  end
  if hs.fnutils.contains(self.watchEvents, event) then
    self.handler(watcher:element(), event)
  end
end

windowtracker.__index = windowtracker

return windowtracker
