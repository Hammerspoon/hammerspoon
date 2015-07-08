--- === hs.windowfilter ===
---
--- Filter windows by application, role, and/or title, and easily subscribe to events on these windows

-- The pure filtering part alone should fulfill a lot of use cases
-- * The root and default filters should be quite handy for users; the user is able to customize both, but ideally
--   there should be ongoing maintenance on the list by the core maintainers
-- * Maybe an additional filter could be added for window geometry (e.g. minimum width/heigth/area)

-- The 'active' part abstracts hs.application.watcher and hs.uielement.watcher into a simple and coherent API
-- for users who are interested in window events. Additionally, a lot of effort is spent on cleaning up
-- the mess coming from osx events:
--   * reduntant events are never fired more than once
--   * related events are fired in the correct order (e.g. the previous window is unfocused before the
--     current one is focused)
--   * 'missing' events are filled in (e.g. a focused window that gets destroyed for any reason emits unfocused first)
--   * coherency is maintained (e.g. closing System Preferences with cmd-w has the same result as with cmd-q)
-- A further :notify() method is provided for use cases with highly specific filters.
--
--TODO * There is the usual problem with spaces (being investigated)
-- * window(un)maximized could be implemented, or merged into window(un)fullscreened (but currently isn't either)
-- * Perhaps (seems doubtful, tho) the user should be allowed to provide his own root filter for better performance
--   (e.g. if they know all they cares about is Safari)

local pairs,ipairs,type,smatch,sformat,ssub = pairs,ipairs,type,string.match,string.format,string.sub
local next,tsort,tinsert,setmetatable = next,table.sort,table.insert,setmetatable
local timer = require 'hs.timer'
local application,window = require'hs.application',require'hs.window'
local appwatcher,uiwatcher = application.watcher, require'hs.uielement'.watcher
local logger = require'hs.logger'
local log = logger.new('wfilter')

local windowfilter={} -- module

--- hs.windowfilter.ignoreAlways
--- Variable
--- A table of application names (as per `hs.application:title()`) that are always ignored by this module.
--- These are apps with no windows or any visible GUI, such as system services, background daemons and "helper" apps.
---
--- You can add an app to this table with `hs.windowfilter.ignoreAlways['Background App Title'] = true`
---
--- Notes:
---  * As the name implies, even the empty, "allow all" windowfilter will ignore these apps.
---  * You don't *need* to keep this table up to date, since non GUI apps will simply never show up anywhere;
---    this table is just used as a "root" filter to gain a (very small) performance improvement.

do
  local SKIP_APPS_NO_PID = {
    -- ideally, keep this updated (used in the root filter)
    'universalaccessd','sharingd','Safari Networking','iTunes Helper','Safari Web Content',
    'App Store Web Content', 'Safari Database Storage',
    'Google Chrome Helper','Spotify Helper','Karabiner_AXNotifier',
  --  'Little Snitch Agent','Little Snitch Network Monitor', -- depends on security settings in Little Snitch
  }

  local SKIP_APPS_NO_WINDOWS = {
    -- ideally, keep this updated (used in the root filter)
    'com.apple.internetaccounts', 'CoreServicesUIAgent', 'AirPlayUIAgent',
    'SystemUIServer', 'Dock', 'com.apple.dock.extra', 'storeuid',
    'Folder Actions Dispatcher', 'Keychain Circle Notification', 'Wi-Fi',
    'Image Capture Extensions', 'iCloud Photos', 'System Events',
    'Speech Synthesis Server', 'Dropbox Finder Integration', 'LaterAgent',
    'Karabiner_AXNotifier', 'Photos Agent', 'EscrowSecurityAlert',
    'Google Chrome Helper', 'com.apple.MailServiceAgent', 'Safari Web Content',
    'Safari Networking', 'nbagent',
  }
  windowfilter.ignoreAlways = {}
  for _,list in ipairs{SKIP_APPS_NO_PID,SKIP_APPS_NO_WINDOWS} do
    for _,appname in ipairs(list) do
      windowfilter.ignoreAlways[appname] = true
    end
  end
end

local SKIP_APPS_TRANSIENT_WINDOWS = {
  --TODO keep this updated (used in the default filter)
  'Spotlight', 'Notification Center', 'loginwindow', 'ScreenSaverEngine',
  -- preferences etc
  'PopClip','Isolator', 'CheatSheet', 'CornerClickBG', 'Alfred 2', 'Moom', 'CursorSense Manager',
  -- menulets
  'Music Manager', 'Google Drive', 'Dropbox', '1Password mini', 'Colors for Hue', 'MacID',
  'CrashPlan menu bar', 'Flux', 'Jettison', 'Bartender', 'SystemPal', 'BetterSnapTool', 'Grandview', 'Radium',
}

--- hs.windowfilter.allowedWindowRoles
--- Variable
--- A list of window roles (as per `hs.window:subrole()`) that are allowed by default.
---
--- Notes:
---  * You can have fine grained control of allowed window roles via the `setAppFilter`, `setDefaultFilter`, `setOverrideFilter` methods.
---  * If you know what you're doing you can override the allowed window roles globally by changing this variable, but this is discouraged.
windowfilter.allowedWindowRoles = {'AXStandardWindow','AXDialog','AXSystemDialog'}


local wf={} -- class
-- .apps = filters set
-- .events = subscribed events
-- .windows = current allowed windows

--- hs.windowfilter:isWindowAllowed(window) -> bool
--- Method
--- Checks if a window is allowed by the windowfilter
---
--- Parameters:
---  * window - a `hs.window` object to check
---
--- Returns:
---  * - `true` if the window is allowed by the windowfilter; `false` otherwise

function wf:isWindowAllowed(window,appname)
  local function matchTitle(titles,t)
    for _,title in ipairs(titles) do
      if smatch(t,title) then return true end
    end
  end
  local function allowWindow(app,role,title,fullscreen,visible)
    if app.titles then
      if type(app.titles)=='number' then if #title<=app.titles then return false end
      elseif not matchTitle(app.titles,title) then return false end
    end
    if app.rtitles and matchTitle(app.rtitles,title) then return false end
    if app.roles and not app.roles[role] then return false end
    if app.fullscreen~=nil and app.fullscreen~=fullscreen then return false end
    if app.visible~=nil and app.visible~=visible then return false end
    return true
  end
  local role = window.subrole and window:subrole() or ''
  local title = window:title() or ''
  local fullscreen = window:isFullScreen() or false
  local visible = window:isVisible() or false
  local app=self.apps[true]
  if app==false then self.log.vf('%s rejected: override reject',role)return false
  elseif app then
    local r=allowWindow(app,role,title,fullscreen,visible)
    self.log.vf('%s %s: override filter',role,r and 'allowed' or 'rejected')
    return r
  end
  appname = appname or window:application():title()
  if not windowfilter.isGuiApp(appname) then
    --this would need fixing .ignoreAlways
    self.log.wf('%s (%s) rejected: should be a non-GUI app!',role,appname) return false
  end
  app=self.apps[appname]
  if app==false then self.log.vf('%s (%s) rejected: app reject',role,appname) return false
  elseif app then
    local r=allowWindow(app,role,title,fullscreen,visible)
    self.log.vf('%s (%s) %s: app filter',role,appname,r and 'allowed' or 'rejected')
    return r
  end
  app=self.apps[false]
  if app==false then self.log.vf('%s (%s) rejected: default reject',role,appname) return false
  elseif app then
    local r=allowWindow(app,role,title,fullscreen,visible)
    self.log.vf('%s (%s) %s: default filter',role,appname,r and 'allowed' or 'rejected')
    return r
  end
  self.log.vf('%s (%s) allowed (no rules)',role,appname)
  return true
end

--- hs.windowfilter:isAppAllowed(appname) -> bool
--- Method
--- Checks if an app is allowed by the windowfilter
---
--- Parameters:
---  * appname - app name as per `hs.application:title()`
---
--- Returns:
---  * `false` if the app is rejected by the windowfilter; `true` otherwise

function wf:isAppAllowed(appname)
  return windowfilter.isGuiApp(appname) and self.apps[appname]~=false
end

--- hs.windowfilter:rejectApp(appname) -> hs.windowfilter
--- Method
--- Sets the windowfilter to outright reject any windows belonging to a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:title()`
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining

function wf:rejectApp(appname)
  return self:setAppFilter(appname,false)
end

--- hs.windowfilter:allowApp(appname) -> hs.windowfilter
--- Method
--- Sets the windowfilter to allow all visible windows belonging to a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:title()`
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
function wf:allowApp(appname)
  return self:setAppFilter(appname,nil,nil,windowfilter.allowedWindowRoles,nil,true)
end
--- hs.windowfilter:setDefaultFilter(allowTitles, rejectTitles, allowRoles, fullscreen, visible) -> hs.windowfilter
--- Method
--- Set the default filtering rules to be used for apps without app-specific rules
---
--- Parameters:
---   allowTitles, rejectTitles, allowRoles, fullscreen, visible - see `hs.windowfilter:setAppFilter`
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
function wf:setDefaultFilter(...)
  return self:setAppFilter(false,...)
end
--- hs.windowfilter:setOverrideFilter(allowTitles, rejectTitles, allowRoles, fullscreen, visible) -> hs.windowfilter
--- Method
--- Set overriding filtering rules that will be applied for all apps before any app-specific rules
---
--- Parameters:
---   allowTitles, rejectTitles, allowRoles, fullscreen, visible - see `hs.windowfilter:setAppFilter`
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
function wf:setOverrideFilter(...)
  return self:setAppFilter(true,...)
end

--- hs.windowfilter:setAppFilter(appname, allowTitles, rejectTitles, allowRoles, fullscreen, visible) -> hs.windowfilter
--- Method
--- Sets the detailed filtering rules for the windows of a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:title()`
---  * allowTitles
---    * if a number, only allow windows whose title is at least as many characters long; e.g. pass `1` to filter windows with an empty title
---    * if a string or table of strings, only allow windows whose title matches (one of) the pattern(s) as per `string.match`
---    * if `nil`, this rule is ignored
---  * rejectTitles
---    * if a string or table of strings, reject windows whose titles matches (one of) the pattern(s) as per `string.match`
---    * if `nil`, this rule is ignored
---  * allowRoles
---    * if a string or table of strings, only allow these window roles as per `hs.window:subrole()`
---    * if the special string '*', this rule is ignored (i.e. all window roles, including empty ones, are allowed)
---    * if `nil`, use the default allowed roles (defined in `hs.window.allowedWindowRoles`)
---  * fullscreen - if `true`, only allow fullscreen windows; if `false`, reject fullscreen windows; if `nil`, this rule is ignored
---  * visible - if `true`, only allow visible windows; if `false`, reject visible windows; if `nil`, this rule is ignored
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
local activeFilters,refreshWindows
function wf:setAppFilter(appname,allowTitles,rejectTitles,allowRoles,fullscreen,visible)
  if type(appname)~='string' and type(appname)~='boolean' then error('appname must be a string or boolean',2) end
  local logs
  if type(appname)=='boolean' then logs=sformat('setting %s filter: ',appname==true and 'override' or 'default')
  else logs=sformat('setting filter for %s: ',appname) end

  if allowTitles==false then
    logs=logs..'reject'
    self.apps[appname]=false
  else
    local app = --[[self.apps[appname] or--]] {} -- always override
    if allowTitles~=nil then
      local titles=allowTitles
      if type(allowTitles)=='string' then titles={allowTitles}
      elseif type(allowTitles)~='number' and type(allowTitles)~='table' then error('allowTitles must be a number, string or table',2) end
      logs=sformat('%sallowTitles=%s, ',logs,type(allowTitles)=='table' and '{...}' or allowTitles)
      app.titles=titles
    end
    if rejectTitles~=nil then
      local rtitles=rejectTitles
      if type(rejectTitles)=='string' then rtitles={rejectTitles}
      elseif type(rejectTitles)~='table' then error('rejectTitles must be a string or table',2) end
      logs=sformat('%srejectTitles=%s, ',logs,type(rejectTitles)=='table' and '{...}' or rejectTitles)
      app.rtitles=rtitles
    end
    if allowRoles~='*' then
      local roles={}
      if allowRoles==nil then allowRoles=hs.windowfilter.allowedWindowRoles end
      if type(allowRoles)=='string' then roles={[allowRoles]=true}
      elseif type(allowRoles)=='table' then
        for _,r in ipairs(allowRoles) do roles[r]=true end
      else error('allowRoles must be a string or table',2) end
      logs=sformat('%sallowRoles=%s, ',logs,type(allowRoles)=='table' and '{...}' or allowRoles)
      app.roles=roles
    end
    if fullscreen~=nil then app.fullscreen=fullscreen end
    if visible~=nil then app.visible=visible end
    self.apps[appname]=app
  end
  self.log.d(logs)
  if activeFilters[self] then refreshWindows(self) end
  return self
end

--- hs.windowfilter.new(fn,logname,loglevel) -> hs.windowfilter
--- Function
--- Creates a new hs.windowfilter instance
---
--- Parameters:
---  * fn - if `nil`, returns a copy of the default windowfilter; you can then further restrict or expand it
---       - if `true`, returns an empty windowfilter that allows every window
---       - if `false`, returns a windowfilter with a default rule to reject every window
--        - if a string or table of strings, returns a copy of the default windowfilter that only allows the specified apps
---       - otherwise it must be a function that accepts an `hs.window` object and returns `true` if the window is allowed or `false` otherwise; this way you can define a fully custom windowfilter
---
---  * logname - (optional) name of the `hs.logger` instance for the new windowfilter; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new windowfilter
--- Returns:
---  * a new windowfilter instance

function windowfilter.new(fn,logname,loglevel)
  local o = setmetatable({apps={},events={},windows={},log=logname and logger.new(logname,loglevel) or log},{__index=wf})
  if type(fn)=='function' then
    o.log.i('new windowfilter, custom function')
    o.isAppAllowed = function()return true end
    o.isWindowAllowed = function(self,w) return fn(w) end
    return o
  elseif type(fn)=='string' then fn={fn}
  end
  local isTable=type(fn)=='table'
  if fn==nil or isTable then
    --    for appname in pairs(windowfilter.ignoreAlways) do
    --      o:rejectApp(appname)
    --    end
    for _,appname in ipairs(SKIP_APPS_TRANSIENT_WINDOWS) do
      o:rejectApp(appname)
    end
    if not isTable then
      o.log.i('new windowfilter, default windowfilter copy')
      --[[      for _,appname in ipairs(APPS_ALLOW_NONSTANDARD_WINDOWS) do
        o:setAppFilter(appname,nil,nil,ALLOWED_NONSTANDARD_WINDOW_ROLES)
      end
      for _,appname in ipairs(APPS_SKIP_NO_TITLE) do
        o:setAppFilter(appname,1)
      end
--]]
      o:setAppFilter('Hammerspoon',{'Preferences','Console'})
      --      local fs,vis=false,true
      --      if includeFullscreen then fs=nil end
      --      if includeInvisible then vis=nil end
      o:setDefaultFilter(nil,nil,nil,nil,true)
    else
      o.log.i('new windowfilter, reject all with exceptions')
      for _,app in ipairs(fn) do
        --        log.i('allow '..app)
        --        o:setAppFilter(app,nil,nil,ALLOWED_NONSTANDARD_WINDOW_ROLES,nil,true)
        o:allowApp(app)
      end
      o:setDefaultFilter(false)
    end
    return o
  elseif fn==true then o.log.i('new empty windowfilter') return o
  elseif fn==false then o.log.i('new windowfilter, reject all') o:setDefaultFilter(false)  return o
  else error('fn must be nil, a boolean, a string or table of strings, or a function',2) end
end


--- hs.windowfilter.default
--- Constant
--- The default windowfilter; it filters apps whose windows are transient in nature so that you're unlikely
--- (and often unable) to do anything with them, such as launchers, menulets, preference pane apps, screensavers, etc.
--- It also filters nonstandard and invisible windows.
---
--- Notes:
---  * While you can customize the default windowfilter, it's usually advisable to make your customizations on a local copy via `mywf=hs.windowfilter.new()`;
--     the default windowfilter can potentially be used in several Hammerspoon modules and changing it might have unintended consequences.
--     Common customizations:
---    * to exclude fullscreen windows: `nofs_wf=hs.windowfilter.new():setOverrideFilter(nil,nil,nil,false)`
---    * to include invisible windows: `inv_wf=windowfilter.new():setDefaultFilter()`
---  * If you still want to alter the default windowfilter:
---    * to list the known exclusions: `hs.windowfilter.setLogLevel('debug')`; the console will log them upon instantiating the default windowfilter
---    * to add an exclusion: `hs.windowfilter.default:rejectApp'Cool New Launcher'`
---    * to remove an exclusion (e.g. if you want to have access to Spotlight windows): `hs.windowfilter.default:allowApp'Spotlight'`;
---      for specialized uses you can make a specific windowfilter with `myfilter=hs.windowfilter.new'Spotlight'`

--- hs.windowfilter.isGuiApp(appname) -> bool
--- Function
--- Checks whether an app is a known non-GUI app, as per `hs.windowfilter.ignoreAlways`
---
--- Parameters:
---  * appname - name of the app to check as per `hs.application:title()`
---
--- Returns:
---  * `false` if the app is a known non-GUI (or not accessible) app; `true` otherwise

windowfilter.isGuiApp = function(appname)
  if not appname then return true
  elseif windowfilter.ignoreAlways[appname] then return false
  elseif ssub(appname,1,12)=='QTKitServer-' then return false
  else return true end
end


-- event watcher (formerly windowwatcher)

local events={windowCreated=true, windowDestroyed=true, windowMoved=true,
  windowMinimized=true, windowUnminimized=true,
  windowFullscreened=true, windowUnfullscreened=true,
  --TODO perhaps windowMaximized? (compare win:frame to win:screen:frame) - or include it in windowFullscreened
  windowHidden=true, windowShown=true, windowFocused=true, windowUnfocused=true,
  windowTitleChanged=true,
}
for k in pairs(events) do windowfilter[k]=k end -- expose events
--- hs.windowfilter.windowCreated
--- Constant
--- Event for `hs.windowfilter:subscribe`: a new window was created

--- hs.windowfilter.windowDestroyed
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window was destroyed

--- hs.windowfilter.windowMoved
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window was moved or resized, including toggling fullscreen/maximize

--- hs.windowfilter.windowMinimized
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window was minimized

--- hs.windowfilter.windowUnminimized
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window was unminimized

--- hs.windowfilter.windowFullscreened
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window was expanded to full screen

--- hs.windowfilter.windowUnfullscreened
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window was reverted back from full screen

--- hs.windowfilter.windowHidden
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window is no longer visible due to it being minimized, closed, or its application being hidden (e.g. via cmd-h) or closed

--- hs.windowfilter.windowShown
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window has became visible (after being hidden, or when created)

--- hs.windowfilter.windowFocused
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window received focus

--- hs.windowfilter.windowUnfocused
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window lost focus

--- hs.windowfilter.windowTitleChanged
--- Constant
--- Event for `hs.windowfilter:subscribe`: a window's title changed

activeFilters = {} -- active wf instances
local apps = {} -- all GUI apps
local global = {} -- global state

local Window={} -- class

function Window:emitEvent(event)
  local logged, notified
  for wf in pairs(activeFilters) do
    if self:setFilter(wf,event==windowfilter.windowDestroyed) and wf.notifyfn then
      -- filter status changed, call notifyfn if present
      if not notified then wf.log.df('Notifying windows changed') if wf.log==log then notified=true end end
      wf.notifyfn(wf:getWindows(),event)
    end
    if wf.windows[self] then
      -- window is currently allowed, call subscribers if any
      local fns = wf.events[event]
      if fns then
        if not logged then wf.log.df('Emitting %s %d (%s)',event,self.id,self.app.name) if wf.log==log then logged=true end end
        for fn in pairs(fns) do
          fn(self.window,self.app.name)
        end
      end
    end
  end
end

function Window:focused()
  if global.focused==self then return log.df('Window %d (%s) already focused',self.id,self.app.name) end
  global.focused=self
  self.app.focused=self
  self.time=timer.secondsSinceEpoch()
  self:emitEvent(windowfilter.windowFocused)
end

function Window:unfocused()
  if global.focused~=self then return log.vf('Window %d (%s) already unfocused',self.id,self.app.name) end
  global.focused=nil
  self.app.focused=nil
  self:emitEvent(windowfilter.windowUnfocused)
end

function Window:setFilter(wf, forceremove) -- returns true if filtering status changes
  local wasAllowed,isAllowed = wf.windows[self]
  if not forceremove then isAllowed = wf:isWindowAllowed(self.window,self.app.name) or nil end
  wf.windows[self] = isAllowed
  return wasAllowed ~= isAllowed
end

function Window.new(win,id,app,watcher)
  local o = setmetatable({app=app,window=win,id=id,watcher=watcher,time=timer.secondsSinceEpoch()},{__index=Window})
  if not win:isVisible() then o.isHidden = true end
  if win:isMinimized() then o.isMinimized = true end
  o.isFullscreen = win:isFullScreen()
  app.windows[id]=o
  o:emitEvent(windowfilter.windowCreated)
  if not o.isHidden and not o.isMinimized then o:emitEvent(windowfilter.windowShown) end
end

function Window:destroyed()
  if self.movedDelayed then self.movedDelayed:stop() self.movedDelayed=nil end
  if self.titleDelayed then self.titleDelayed:stop() self.titleDelayed=nil end
  self.watcher:stop()
  self.app.windows[self.id]=nil
  self:unfocused()
  if not self.isHidden then self:emitEvent(windowfilter.windowHidden) end
  self:emitEvent(windowfilter.windowDestroyed)
end
local WINDOWMOVED_DELAY=0.5
function Window:moved()
  if self.movedDelayed then self.movedDelayed:stop() self.movedDelayed=nil end
  self.movedDelayed=timer.doAfter(WINDOWMOVED_DELAY,function()self:doMoved()end)
end

function Window:doMoved()
  self:emitEvent(windowfilter.windowMoved)
  local fs = self.window:isFullScreen()
  local oldfs = self.isFullscreen or false
  if self.isFullscreen~=fs then
    self.isFullscreen=fs
    self:emitEvent(fs and windowfilter.windowFullscreened or windowfilter.windowUnfullscreened)
  end
end
local TITLECHANGED_DELAY=0.5
function Window:titleChanged()
  if self.titleDelayed then self.titleDelayed:stop() self.titleDelayed=nil end
  self.titleDelayed=timer.doAfter(TITLECHANGED_DELAY,function()self:doTitleChanged()end)
end
function Window:doTitleChanged()
  self:emitEvent(windowfilter.windowTitleChanged)
end
function Window:hidden()
  if self.isHidden then return log.df('Window %d (%s) already hidden',self.id,self.app.name) end
  self:unfocused()
  self.isHidden = true
  self:emitEvent(windowfilter.windowHidden)
end
function Window:shown()
  if not self.isHidden then return log.df('Window %d (%s) already shown',self.id,self.app.name) end
  self.isHidden = nil
  self:emitEvent(windowfilter.windowShown)
end
function Window:minimized()
  if self.isMinimized then return log.df('Window %d (%s) already minimized',self.id,self.app.name) end
  self.isMinimized=true
  self:emitEvent(windowfilter.windowMinimized)
  self:hidden()
end
function Window:unminimized()
  if not self.isMinimized then log.df('Window %d (%s) already unminimized',self.id,self.app.name) end
  self.isMinimized=nil
  self:shown()
  self:emitEvent(windowfilter.windowUnminimized)
end

local appWindowEvent

local App={} -- class

function App:getFocused()
  if self.focused then return end
  local fw=self.app:focusedWindow()
  local fwid=fw and fw.id and fw:id()
  if not fwid then
    fw=self.app:mainWindow()
    fwid=fw and fw.id and fw:id()
  end
  if fwid then
    log.vf('Window %d is focused for app %s',fwid,self.name)
    if not self.windows[fwid] then
      -- windows on a different space aren't picked up by :allWindows() at first refresh
      log.df('Focused window %d (%s) was not registered',fwid,self.name)
      appWindowEvent(fw,uiwatcher.windowCreated,nil,self.name)
    end
    if not self.windows[fwid] then
      log.wf('Focused window %d (%s) is STILL not registered',fwid,self.name)
    else
      self.focused = self.windows[fwid]
    end
  end
end

function App.new(app,appname,watcher)
  local o = setmetatable({app=app,name=appname,watcher=watcher,windows={}},{__index=App})
  if app:isHidden() then o.isHidden=true end
  --FIXME add here any reliable spaces 'fix' (if found), to fetch windows across spaces
  log.f('New app %s registered',appname)
  apps[appname] = o
  o:getWindows()
end

function App:getWindows()
  local windows=self.app:allWindows()
  if #windows>0 then log.df('Found %d windows for app %s',#windows,self.name) end
  for _,win in ipairs(windows) do
    appWindowEvent(win,uiwatcher.windowCreated,nil,self.name)
  end
  self:getFocused()
  if self.app:isFrontmost() then
    log.df('App %s is the frontmost app',self.name)
    if global.active then global.active:deactivated() end
    global.active = self
    if self.focused then
      self.focused:focused()
      log.df('Window %d is the focused window',self.focused.id)
    end
  end
end

function App:activated()
  local prevactive=global.active
  if self==prevactive then return log.df('App %s already active; skipping',self.name) end
  if prevactive then prevactive:deactivated() end
  log.vf('App %s activated',self.name)
  global.active=self
  self:getFocused()
  if not self.focused then return log.df('App %s does not (yet) have a focused window',self.name) end
  self.focused:focused()
end
function App:deactivated()
  if self~=global.active then return end
  log.vf('App %s deactivated',self.name)
  global.active=nil
  if global.focused~=self.focused then log.e('Focused app/window inconsistency') end
  if self.focused then self.focused:unfocused() end
end
function App:focusChanged(id,win)
  if not id then return log.wf('Cannot process focus changed for app %s - no window id',self.name) end
  if self.focused and self.focused.id==id then return log.df('Window %d (%s) already focused, skipping',id,self.name) end
  local active=global.active
  if not self.windows[id] then
    appWindowEvent(win,uiwatcher.windowCreated,nil,self.name)
  end
  log.vf('App %s focus changed',self.name)
  if self==active then self:deactivated() end
  self.focused = self.windows[id]
  if self==active then self:activated() end
end
function App:hidden()
  if self.isHidden then return log.df('App %s already hidden, skipping',self.name) end
  for id,window in pairs(self.windows) do
    window:hidden()
  end
  log.vf('App %s hidden',self.name)
  self.isHidden=true
end
function App:shown()
  if not self.isHidden then return log.df('App %s already visible, skipping',self.name) end
  for id,window in pairs(self.windows) do
    window:shown()
  end
  log.vf('App %s shown',self.name)
  self.isHidden=nil
end
function App:destroyed()
  log.f('App %s deregistered',self.name)
  self.watcher:stop()
  for id,window in pairs(self.windows) do
    window:destroyed()
  end
  apps[self.name]=nil
end

local function windowEvent(win,event,_,appname,retry)
  log.vf('Received %s for %s',event,appname)
  local id=win and win.id and win:id()
  local app=apps[appname]
  if not id and app then
    for _,window in pairs(app.windows) do
      if window.window==win then id=window.id break end
    end
  end
  if not id then return log.ef('%s: %s cannot be processed',appname,event) end
  if not app then return log.ef('App %s is not registered!',appname) end
  local window = app.windows[id]
  if not window then return log.ef('Window %d (%s) is not registered!',id,appname) end
  if event==uiwatcher.elementDestroyed then
    window:destroyed()
  elseif event==uiwatcher.windowMoved or event==uiwatcher.windowResized then
    window:moved()
  elseif event==uiwatcher.windowMinimized then
    window:minimized()
  elseif event==uiwatcher.windowUnminimized then
    window:unminimized()
  elseif event==uiwatcher.titleChanged then
    window:titleChanged()
  end
end


local RETRY_DELAY,MAX_RETRIES = 0.2,3
local windowWatcherDelayed={}

appWindowEvent=function(win,event,_,appname,retry)
  log.vf('Received %s for %s',event,appname)
  local id = win and win.id and win:id()
  if event==uiwatcher.windowCreated then
    if windowWatcherDelayed[win] then windowWatcherDelayed[win]:stop() windowWatcherDelayed[win]=nil end
    retry=(retry or 0)+1
    if not id then
      if retry>MAX_RETRIES then log.wf('%s: %s has no id',appname,win.subrole and win:subrole() or (win.role and win:role()) or 'window')
      else
        windowWatcherDelayed[win]=timer.doAfter(retry*RETRY_DELAY,function()appWindowEvent(win,event,_,appname,retry)end) end
      return
    end
    if apps[appname].windows[id] then return log.df('%s: window %d already registered',appname,id) end
    local watcher=win:newWatcher(windowEvent,appname)
    if not watcher._element.pid then
      log.wf('%s: %s has no watcher pid',appname,win.subrole and win:subrole() or (win.role and win:role()))
      -- old workaround for the 'missing pid' bug
      --      if retry>MAX_RETRIES then log.df('%s: %s has no watcher pid',appname,win.subrole and win:subrole() or (win.role and win:role()) or 'window')
      --      else
      --        windowWatcherDelayed[win]=timer.doAfter(retry*RETRY_DELAY,function()appWindowEvent(win,event,_,appname,retry)end) end
      --      return
    end
    Window.new(win,id,apps[appname],watcher)
    watcher:start({uiwatcher.elementDestroyed,uiwatcher.windowMoved,uiwatcher.windowResized
      ,uiwatcher.windowMinimized,uiwatcher.windowUnminimized,uiwatcher.titleChanged})
  elseif event==uiwatcher.focusedWindowChanged then
    local app=apps[appname]
    if not app then return log.ef('App %s is not registered!',appname) end
    app:focusChanged(id,win)
  end
end

local function startAppWatcher(app,appname)
  if not app or not appname then log.e('Called startAppWatcher with no app') return end
  if apps[appname] then log.df('App %s already registered',appname) return end
  if app:kind()<0 or not windowfilter.isGuiApp(appname) then log.df('App %s has no GUI',appname) return end
  local watcher = app:newWatcher(appWindowEvent,appname)
  watcher:start({uiwatcher.windowCreated,uiwatcher.focusedWindowChanged})
  App.new(app,appname,watcher)
  if not watcher._element.pid then
    log.f('No accessibility access to app %s (no watcher pid)',(appname or '[???]'))
  end
end

--[[
-- old workaround for the 'missing pid' bug
local appWatcherDelayed={}
local function startAppWatcher(app,appname,retry,takeiteasy)
  if not app or not appname then log.e('Called startAppWatcher with no app') return end
  if apps[appname] then return not takeiteasy and log.df('App %s already registered',appname) end
  if app:kind()<0 or not isGuiApp(appname) then log.df('App %s has no GUI',appname) return end
  local watcher = app:newWatcher(appWindowEvent,appname)
  if watcher._element.pid then
    watcher:start({uiwatcher.windowCreated,uiwatcher.focusedWindowChanged})
    App.new(app,appname,watcher)
  else
    retry=(retry or 0)+1
    if retry>5 then return not takeiteasy and log.wf('STILL no accessibility pid for app %s, giving up',(appname or '[???]')) end
    log.df('No accessibility pid for app %s',(appname or '[???]'))
    appWatcherDelayed[appname]=delayed.doAfter(appWatcherDelayed[appname],0.2*retry,startAppWatcher,app,appname,retry)
  end
end
--]]
local function appEvent(appname,event,app,retry)
  local sevent={[0]='launching','launched','terminated','hidden','unhidden','activated','deactivated'}
  log.vf('Received app %s for %s',sevent[event],appname)
  if not appname then return end
  if event==appwatcher.launched then return startAppWatcher(app,appname)
  elseif event==appwatcher.launching then return end
  local appo=apps[appname]
  if event==appwatcher.activated then
    if appo then return appo:activated() end
    retry = (retry or 0)+1
    if retry==1 then
      log.vf('First attempt at registering app %s',appname)
      startAppWatcher(app,appname,5,true)
    end
    if retry>5 then return log.df('App %s still is not registered!',appname) end
    timer.doAfter(0.1*retry,function()appEvent(appname,event,app,retry)end)
    return
  end
  if not appo then return log.ef('App %s is not registered!',appname) end
  if event==appwatcher.terminated then return appo:destroyed()
  elseif event==appwatcher.deactivated then return appo:deactivated()
  elseif event==appwatcher.hidden then return appo:hidden()
  elseif event==appwatcher.unhidden then return appo:shown() end
end


local function startGlobalWatcher()
  if global.watcher then return end
  global.watcher = appwatcher.new(appEvent)
  local runningApps = application.runningApplications()
  log.f('Registering %d running apps',#runningApps)
  for _,app in ipairs(runningApps) do
    startAppWatcher(app,app:title())
  end
  global.watcher:start()
end

local function stopGlobalWatcher()
  if not global.watcher then return end
  for _,active in pairs(activeFilters) do
    if active then return end
  end
  local totalApps = 0
  for _,app in pairs(apps) do
    for _,window in pairs(app.windows) do
      window.watcher:stop()
    end
    app.watcher:stop()
    totalApps=totalApps+1
  end
  global.watcher:stop()
  apps,global={},{}
  log.f('Unregistered %d apps',totalApps)
end


local function subscribe(self,event,fns)
  if not events[event] then error('invalid event: '..event,3) end
  for _,fn in ipairs(fns) do
    if type(fn)~='function' then error('fn must be a function or table of functions',3) end
    if not self.events[event] then self.events[event]={} end
    self.events[event][fn]=true
    self.log.df('Added callback for event %s',event)
  end
end

local function unsubscribe(self,fn)
  for event in pairs(events) do
    if self.events[event] and self.events[event][fn] then
      self.log.df('Removed callback for event %s',event)
      self.events[event][fn]=nil
      if not next(self.events[event]) then
        self.log.df('No more callbacks for event %s',event)
        self.events[event]=nil
      end
    end
  end
  return self
end

local function unsubscribeEvent(self,event)
  if not events[event] then error('invalid event: '..event,3) end
  if self.events[event] then self.log.df('Removed all callbacks for event %s',event) end
  self.events[event]=nil
  return self
end


refreshWindows=function(wf)
  -- whenever a wf is edited, refresh the windows to reflect the new filter
  wf.log.v('Refreshing windows')
  for _,app in pairs(apps) do
    for _,window in pairs(app.windows) do
      window:setFilter(wf)
    end
  end
end

local function start(wf)
  if activeFilters[wf]==true then return end
  startGlobalWatcher()
  activeFilters[wf]=true
  return refreshWindows(wf)
end

-- keeps the wf in active mode even without subscriptions; used internally by other modules that rely on :getWindows
-- but do not necessarily :subscribe
-- (not documented as the passive vs active distinction should be abstracted away in the user api)
-- more detail: i noticed that even having to call startGlobalWatcher->getWindows->stopGlobalWatcher is
-- *way* faster than hs.window.allWindows(); even so, better to have a way to avoid the overhead if we know
-- we'll call :getWindows often enough
function wf:keepActive()
  start(self)
end


local function getWindowObjects(wf)
  local t={}
  for w in pairs(wf.windows) do
    t[#t+1] = w
  end
  tsort(t,function(a,b)return a.time>b.time end)
  return t
end

--- hs.windowfilter:getWindows() -> table
--- Method
--- Gets the current windows allowed by this windowfilter, ordered by most recently focused
---
--- Parameters:
---  * None
---
--- Returns:
---  * a list of `hs.window` objects

--TODO allow to pass in a list of candidate windows?
function wf:getWindows()
  local wasActive=activeFilters[self]
  start(self)
  local t={}
  local o=getWindowObjects(self)
  for i,w in ipairs(o) do
    t[i]=w.window
  end
  if not wasActive then self:pause() end
  return t
end

--- hs.windowfilter:notify(fn) -> hs.windowfilter
--- Method
--- Notify a callback whenever the list of allowed windows change
---
--- Parameters:
---  * fn - a function that should accept a list of windows (as per `hs.windowfilter:getWindows()`) as its single parameter; it will be called when:
---    * an allowed window is created or destroyed, and therefore added or removed from the list of allowed windows
---    * a previously allowed window is now filtered or vice versa (e.g. in consequence of a title change)
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
---
--- Notes:
---  * If `fn` is `nil`, notifications for this windowfilter will stop.
function wf:notify(fn)
  if fn~=nil and type(fn)~='function' then error('fn must be a function or nil',2) end
  self.notifyfn = fn
  if fn then start(self) elseif not next(self.events) then self:pause() end
  return self
end

--- hs.windowfilter:subscribe(event,fn,immediate) -> hs.windowfilter
--- Method
--- Subscribe to one or more events on the allowed windows
---
--- Parameters:
---  * event - string or table of strings, the event(s) to subscribe to (see the `hs.windowfilter` constants)
---  * fn - function or table of functions - the callback(s) to add for the event(s); each will be passed two parameters:
---          * a `hs.window` object referring to the event's window
---          * a string containing the application name (`window:application():title()`) for convenience
---  * immediate - if `true`, call all the callbacks immediately for windows that satisfy the event(s) criteria
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
---
--- Notes:
---  * Passing tables means that *all* the `fn`s will be called when *any* of the `event`s fires,
---    so it's *not* a shortcut for subscribing distinct callbacks to distinct events; use chained `:subscribe` calls for that.
---  * Use caution with `immediate`: if for example you're subscribing to `hs.windowfilter.windowUnfocused`,
---    `fn`(s) will be called for *all* the windows except the currently focused one.
---  * If the windowfilter was paused with `hs.windowfilter:pause()`, calling this will resume it.
function wf:subscribe(event,fn,immediate)
  start(self)
  if type(fn)=='function' then fn={fn} end
  if type(fn)~='table' then error('fn must be a function or table of functions',2) end
  if type(event)=='string' then event={event} end
  if type(event)~='table' then error('event must be a string or a table of strings',2) end
  for _,e in ipairs(event) do
    subscribe(self,e,fn)
  end
  if immediate then
    -- get windows
    local windows = getWindowObjects(self)
    local hev={}
    for _,e in ipairs(event) do hev[e]=true end
    for _,f in ipairs(fn) do
      for _,win in ipairs(windows) do
        if hev[windowfilter.windowCreated]
          or hev[windowfilter.windowMoved]
          or hev[windowfilter.windowTitleChanged]
          or (hev[windowfilter.windowShown] and not win.isHidden)
          or (hev[windowfilter.windowHidden] and win.isHidden)
          or (hev[windowfilter.windowMinimized] and win.isMinimized)
          or (hev[windowfilter.windowUnminimized] and not win.isMinimized)
          or (hev[windowfilter.windowFullscreened] and win.isFullscreen)
          or (hev[windowfilter.windowUnfullscreened] and not win.isFullscreen)
          or (hev[windowfilter.windowFocused] and global.focused==win)
          or (hev[windowfilter.windowUnfocused] and global.focused~=win)
        then f(win.window,win.app.name) end
      end
    end
  end
  return self
end

--- hs.windowfilter:unsubscribe(fn) -> hs.windowfilter
--- Method
--- Removes one or more event subscriptions
---
--- Parameters:
---  * fn - it can be:
---    * a function or table of functions: the callback(s) to remove
---    * a string or table of strings: the event(s) to unsubscribe (*all* callbacks will be removed from these)
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
---
--- Notes:
---  * If calling this on the default (or any other shared use) windowfilter, do not pass events, as that would remove
---    *all* the callbacks for the events including ones subscribed elsewhere that you might not be aware of. Instead keep
---    references to your functions and pass in those.
function wf:unsubscribe(fn)
  if type(fn)=='string' or type(fn)=='function' then fn={fn} end--return unsubscribe(self,fn)
  if type(fn)~='table' then error('fn must be a function, string, or a table of functions or strings',2) end
  for _,e in ipairs(fn) do
    if type(e)=='string' then unsubscribeEvent(self,e)
    elseif type(e)=='function' then unsubscribe(self,e)
    else error('fn must be a function, string, or a table of functions or strings',2) end
  end
  if not next(self.events) then return self:unsubscribeAll() end
  return self
end

--- hs.windowfilter:unsubscribeAll() -> hs.windowfilter
--- Method
--- Removes all event subscriptions
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
---
--- Notes:
---  * You should not use this on the default windowfilter or other shared windowfilters
function wf:unsubscribeAll()
  self.events={}
  self:pause()
  return self
end



--- hs.windowfilter:resume() -> hs.windowfilter
--- Method
--- Resumes the windowfilter event subscriptions
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
function wf:resume()
  if activeFilters[self]==true then self.log.i('instance already running, ignoring')
  else start(self) end
  return self
end

--- hs.windowfilter:pause() -> hs.windowfilter
--- Method
--- Stops the windowfilter event subscriptions; no more event callbacks will be triggered, but the subscriptions remain intact for a subsequent call to `hs.windowfilter:resume()`
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.windowfilter` object for method chaining
function wf:pause()
  activeFilters[self]=nil
  stopGlobalWatcher()
  return self
end


function wf:delete()
  activeFilters[self]=nil
  self.events={}
  stopGlobalWatcher()
end

--FIXME spaces
local spacesDone = {}
function windowfilter.switchedToSpace(space,cb)
  if spacesDone[space] then log.v('Switched to space #'..space) return cb and cb() end
  timer.doAfter(0.5,function()
    if spacesDone[space] then log.v('Switched to space #'..space) return cb and cb() end
    log.f('Entered space #%d, refreshing all windows',space)
    for _,app in pairs(apps) do
      app:getWindows()
    end
    spacesDone[space] = true
    return cb and cb()
  end)
end


local defaultwf
function windowfilter.setLogLevel(lvl)
  log.setLogLevel(lvl)
  if defaultwf then defaultwf.log.setLogLevel(lvl) end
end

local rawget=rawget
return setmetatable(windowfilter,{
  __index=function(t,k)
    if k=='default' then
      if not defaultwf then defaultwf=windowfilter.new(nil,'wflt-def') log.i('default windowfilter instantiated') end
      return defaultwf
    else return rawget(t,k) end
  end,
})

