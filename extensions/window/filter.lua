--- === hs.window.filter ===
---
--- **WARNING**: EXPERIMENTAL MODULE. DO **NOT** USE IN PRODUCTION.
--- This module is *for testing purposes only*. It can undergo breaking API changes or *go away entirely* **at any point and without notice**.
--- (Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.freenode.net)
---
--- Filter windows by application, role, and/or title, and easily subscribe to events on these windows
---
--- Usage:
--- -- alter the default windowfilter
--- hs.window.filter.default:setAppFilter('My IDE',{allowTitles=1}) -- ignore no-title windows (e.g. autocomplete suggestions) in My IDE
---
--- -- set the exact scope of what you're interested in
--- wf_terminal = hs.window.filter.new{'Terminal','iTerm2'} -- all visible terminal windows
--- wf_timewaster = hs.window.filter.new(false):setAppFilter('Safari',{allowTitles='reddit'}) -- any Safari windows with "reddit" anywhere in the title
--- wf_bigwindows = hs.window.filter.new(function(w)return w:frame().w*w:frame().h>3000000 end) -- only very large windows
--- wf_notif = hs.window.filter.new{['Notification Center']={allowRoles='AXNotificationCenterAlert'}} -- notification center alerts
---
--- -- subscribe to events
--- wf_terminal:subscribe(hs.window.filter.windowFocused,some_fn) -- run a function whenever a terminal window is focused
--- wf_timewaster:notify(startAnnoyingMe,stopAnnoyingMe) -- fight procrastination :)



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
-- * There is the usual problem with spaces; it's usefully abstracted away from userspace via :setTrackSpaces,
--   but the implementation is inefficient as it relies on calling hs.window.allWindows() (which is slow)
--   on space changes.
-- * window(un)maximized could be implemented, or merged into window(un)fullscreened (but currently isn't either)
-- * Perhaps (seems doubtful, tho) the user should be allowed to provide his own root filter for better performance
--   (e.g. if they know all they cares about is Safari)

local pairs,ipairs,type,smatch,sformat,ssub = pairs,ipairs,type,string.match,string.format,string.sub
local next,tsort,tinsert,tremove,setmetatable = next,table.sort,table.insert,table.remove,setmetatable
local timer = require 'hs.timer'
local application,window = require'hs.application',hs.window
local appwatcher,uiwatcher = application.watcher, require'hs.uielement'.watcher
local logger = require'hs.logger'
local log = logger.new('wfilter')

local windowfilter={} -- module


--local SPECIAL_ID_DESKTOP=-1 -- finder desktop "window"
local SPECIAL_ID_INVALIDATE_CACHE=-100
--- hs.window.filter.ignoreAlways
--- Variable
--- A table of application names (as per `hs.application:name()`) that are always ignored by this module.
--- These are apps with no windows or any visible GUI, such as system services, background daemons and "helper" apps.
---
--- You can add an app to this table with `hs.window.filter.ignoreAlways['Background App Title'] = true`
---
--- Notes:
---  * As the name implies, even the empty, "allow all" windowfilter will ignore these apps.
---  * You don't *need* to keep this table up to date, since non GUI apps will simply never show up anywhere;
---    this table is just used as a "root" filter to gain a (very small) performance improvement.

do
  local SKIP_APPS_NO_PID = {
    -- ideally, keep this updated (used in the root filter)
    -- these will be shown as a warning in the console ("No accessibility access to app ...")
    'universalaccessd','sharingd','Safari Networking','iTunes Helper','Safari Web Content',
    'App Store Web Content', 'Safari Database Storage',
    'Google Chrome Helper','Spotify Helper',
  --  'Little Snitch Agent','Little Snitch Network Monitor', -- depends on security settings in Little Snitch
  }

  local SKIP_APPS_NO_WINDOWS = {
    -- ideally, keep this updated (used in the root filter)
    -- hs.window.filter._showCandidates() -- from the console
    'com.apple.internetaccounts', 'CoreServicesUIAgent', 'AirPlayUIAgent',
    'com.apple.security.pboxd',
    'SystemUIServer', 'Dock', 'com.apple.dock.extra', 'storeuid',
    'Folder Actions Dispatcher', 'Keychain Circle Notification', 'Wi-Fi',
    'Image Capture Extension', 'iCloud Photos', 'System Events',
    'Speech Synthesis Server', 'Dropbox Finder Integration', 'LaterAgent',
    'Karabiner_AXNotifier', 'Photos Agent', 'EscrowSecurityAlert',
    'Google Chrome Helper', 'com.apple.MailServiceAgent', 'Safari Web Content', 'Mail Web Content',
    'Safari Networking', 'nbagent','rcd',
    'Evernote Helper', 'BTTRelaunch',
  --'universalAccessAuthWarn', -- actual window "App.app would like to control this computer..."
  }
  windowfilter.ignoreAlways = {}
  for _,list in ipairs{SKIP_APPS_NO_PID,SKIP_APPS_NO_WINDOWS} do
    for _,appname in ipairs(list) do windowfilter.ignoreAlways[appname] = true end
  end

  local SKIP_APPS_TRANSIENT_WINDOWS = {
    --TODO keep this updated (used in the default filter)
    -- hs.window.filter._showCandidates() -- from the console
    'Spotlight', 'Notification Center', 'loginwindow', 'ScreenSaverEngine', 'PressAndHold',
    -- preferences etc
    'PopClip','Isolator', 'CheatSheet', 'CornerClickBG', 'Alfred 2', 'Moom', 'CursorSense Manager',
    -- menulets
    'Music Manager', 'Google Drive', 'Dropbox', '1Password mini', 'Colors for Hue', 'MacID',
    'CrashPlan menu bar', 'Flux', 'Jettison', 'Bartender', 'SystemPal', 'BetterSnapTool', 'Grandview', 'Radium',
  }

  windowfilter.ignoreInDefaultFilter = {}
  for _,appname in ipairs(SKIP_APPS_TRANSIENT_WINDOWS) do windowfilter.ignoreInDefaultFilter[appname] = true end
end

local apps

-- utility function for maintainers; shows (in the console) candidate apps that, if recognized as
-- "no GUI" or "transient window" apps, can be added to the relevant tables for the default windowfilter
function windowfilter._showCandidates()
  local running=application.runningApplications()
  local t={}
  for _,app in ipairs(running) do
    local appname = app:title()
    if appname and windowfilter.isGuiApp(appname) and #app:allWindows()==0
      and not windowfilter.ignoreInDefaultFilter[appname]
      and (not apps[appname] or not next(apps[appname].windows)) then
      t[#t+1]=appname
    end
  end
  print(require'hs.inspect'(t))
end


--- hs.window.filter.allowedWindowRoles
--- Variable
--- A table for window roles (as per `hs.window:subrole()`) that are allowed by default.
---
--- Set the desired window roles as *keys* in this table, like this: `hs.window.filter.allowedWindowRoles = {AXStandardWindow=true,AXDialog=true}`
---
--- Notes:
---  * You can have fine grained control of allowed window roles via the `setAppFilter`, `setDefaultFilter`, `setOverrideFilter` methods.
---  * If you know what you're doing you can override the allowed window roles globally by changing this variable, but this is discouraged.
windowfilter.allowedWindowRoles = {['AXStandardWindow']=true,['AXDialog']=true,['AXSystemDialog']=true}


local wf={} -- class
-- .apps = filters set
-- .events = subscribed events
-- .windows = current allowed windows

--- hs.window.filter:isWindowAllowed(window) -> bool
--- Method
--- Checks if a window is allowed by the windowfilter
---
--- Parameters:
---  * window - an `hs.window` object to check
---
--- Returns:
---  * `true` if the window is allowed by the windowfilter, `false` otherwise; `nil` if an invalid object was passed

local function matchTitle(titles,t)
  for _,title in ipairs(titles) do
    if smatch(t,title) then return true end
  end
end
local function allowWindow(app,props)
  if app.allowTitles then
    if type(app.allowTitles)=='number' then if #props.title<=app.allowTitles then return false end
    elseif not matchTitle(app.allowTitles,props.title) then return false end
  end
  if app.rejectTitles and matchTitle(app.rejectTitles,props.title) then return false end
  local approles = app.allowRoles or windowfilter.allowedWindowRoles
  if approles~='*' and not approles[props.role] then return false end
  if app.fullscreen~=nil and app.fullscreen~=props.fullscreen then return false end
  if app.visible~=nil and app.visible~=props.visible then return false end
  if app.focused~=nil and app.focused~=props.focused then return false end
  return true
end
--local shortRoles={AXStandardWindow='window',AXDialog='dialog',AXSystemDialog='sys dlg',AXFloatingWindow='float',AXUnknown='unknown',['']='no role'}
local props = {id=SPECIAL_ID_INVALIDATE_CACHE}-- cache window props for successive calls to isWindowAllowed
function wf:isWindowAllowed(window,appname,cache)
  if not window then return end
  local id=window.id and window:id()
  --this filters out non-windows, as well as AXScrollArea from Finder (i.e. the desktop)
  --which allegedly is a window, but without id
  if not id then return end
  if not cache or id~=props.id then
    props.role = window.subrole and window:subrole() or ''
    props.title = window:title() or ''
    props.fullscreen = window:isFullScreen() or false
    props.visible = window:isVisible() or false
    if props.visible and id and self.currentSpaceWindows then props.visible=self.currentSpaceWindows[id] end
    -- for the brave who ventured here: window:application:isFrontmost() lies to your face (for a few ms, at least)
    local frontapp = application.frontmostApplication()
    local frontwin = frontapp and frontapp:focusedWindow()
    props.focused = frontwin and frontwin:id()==id or false --FIXME problems when changing spaces
    props.appname = appname or window:application():title()
    props.id=id
  end
  local role,appname=--[[shortRoles[props.role] or--]]props.role,props.appname
  local app=self.apps.override
  if app==false then self.log.vf('reject %s (%s %d): override reject',appname,role,id)return false
  elseif app then
    local r=allowWindow(app,props)
    self.log.vf('%s %s (%s %d): override filter',r and 'allow' or 'reject',appname,role,id)
    return r
  end
  if self.spaceFilter and not self.currentSpaceWindows[id] then self.log.vf('reject %s (%s %d): not in current space',appname,role,id) return false
  elseif self.spaceFilter==false and self.currentSpaceWindows[id] then self.log.vf('reject %s (%s %d): in current space',appname,role,id) return false end

  if not windowfilter.isGuiApp(appname) then
    --if you see this in the log, add to .ignoreAlways
    self.log.wf('reject %s (%s %d): should be a non-GUI app!',appname,role,id) return false
  end
  app=self.apps[appname]
  if app==false then self.log.vf('reject %s (%s %d): app reject',appname,role,id) return false
  elseif app then
    local r=allowWindow(app,props)
    self.log.vf('%s %s (%s %d): app filter',r and 'allow' or 'reject',appname,role,id)
    return r
  end
  app=self.apps.default
  if app==false then self.log.vf('reject %s (%s %d): default reject',appname,role,id) return false
  elseif app then
    local r=allowWindow(app,props)
    self.log.vf('%s %s (%s %d): default filter',r and 'allow' or 'reject',appname,role,id)
    return r
  end
  self.log.vf('allow %s (%s %d) (no filter)',appname,role,id)
  return true
end

--- hs.window.filter:isAppAllowed(appname) -> bool
--- Method
--- Checks if an app is allowed by the windowfilter
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---
--- Returns:
---  * `false` if the app is rejected by the windowfilter; `true` otherwise

function wf:isAppAllowed(appname)
  return windowfilter.isGuiApp(appname) and self.apps[appname]~=false
end

--- hs.window.filter:rejectApp(appname) -> hs.window.filter
--- Method
--- Sets the windowfilter to outright reject any windows belonging to a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining

function wf:rejectApp(appname)
  return self:setAppFilter(appname,false)
end

--- hs.window.filter:allowApp(appname) -> hs.window.filter
--- Method
--- Sets the windowfilter to allow all visible windows belonging to a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function wf:allowApp(appname)
  return self:setAppFilter(appname,true)--nil,nil,windowfilter.allowedWindowRoles,nil,true)
end
--- hs.window.filter:setDefaultFilter(filter) -> hs.window.filter
--- Method
--- Set the default filtering rules to be used for apps without app-specific rules
---
--- Parameters:
---   * filter - see `hs.window.filter:setAppFilter`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function wf:setDefaultFilter(...)
  return self:setAppFilter('default',...)
end
--- hs.window.filter:setOverrideFilter(filter) -> hs.window.filter
--- Method
--- Set overriding filtering rules that will be applied for all apps before any app-specific rules
---
--- Parameters:
---   * filter - see `hs.window.filter:setAppFilter`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function wf:setOverrideFilter(...)
  return self:setAppFilter('override',...)
end

--- hs.window.filter:setAppFilter(appname, filter) -> hs.window.filter
--- Method
--- Sets the detailed filtering rules for the windows of a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---  * filter - if `false`, reject the app; if `true`, `nil`, or omitted, allow all visible windows for the app; otherwise
---    it must be a table describing the filtering rules for the app, via the following fields:
---    * allowTitles
---      * if a number, only allow windows whose title is at least as many characters long; e.g. pass `1` to filter windows with an empty title
---      * if a string or table of strings, only allow windows whose title matches (one of) the pattern(s) as per `string.match`
---      * if omitted, this rule is ignored
---    * rejectTitles
---      * if a string or table of strings, reject windows whose titles matches (one of) the pattern(s) as per `string.match`
---      * if omitted, this rule is ignored
---    * allowRoles
---      * if a string or table of strings, only allow these window roles as per `hs.window:subrole()`
---      * if the special string `'*'`, this rule is ignored (i.e. all window roles, including empty ones, are allowed)
---      * if omitted, use the default allowed roles (defined in `hs.window.filter.allowedWindowRoles`)
---    * fullscreen - if `true`, only allow fullscreen windows; if `false`, reject fullscreen windows; if `nil`, this rule is ignored
---    * visible - if `true`, only allow visible windows; if `false`, reject visible windows; if omitted, this rule is ignored
---    * focused - if `true`, only allow a window while focused; if `false`, reject the focused window; if omitted, this rule is ignored
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * Passing `focused=true` in `filter` will (naturally) result in the windowfilter ever allowing 1 window at most
---  * If you want to allow *all* windows for an app, including invisible ones, pass an empty table for `filter`
local activeFilters,refreshWindows

function wf:setAppFilter(appname,ft)
  if type(appname)~='string' then error('appname must be a string',2) end
  local logs
  if appname=='override' or appname=='default' then logs=sformat('setting %s filter: ',appname)
  else logs=sformat('setting filter for %s: ',appname) end

  if ft==false then
    logs=logs..'reject'
    self.apps[appname]=false
  else
    if ft==nil or ft==true then ft={visible=true} end -- shortcut
    if type(ft)~='table' then error('filter must be a table',2) end
    local app = {} -- always override

    for k,v in pairs(ft) do
      if k=='allowTitles' then
        if type(v)=='string' then v={v}
        elseif type(v)~='number' and type(v)~='table' then error('allowTitles must be a number, string or table',2) end
        logs=sformat('%s%s=%s, ',logs,k,type(v)=='table' and '{...}' or v)
        app.allowTitles=v
      elseif k=='rejectTitles' then
        if type(v)=='string' then v={v}
        elseif type(v)~='table' then error('rejectTitles must be a string or table',2) end
        logs=sformat('%s%s=%s, ',logs,k,type(v)=='table' and '{...}' or v)
        app.rejectTitles=v
      elseif k=='allowRoles' then
        local roles={}
        if v=='*' then roles=v
        elseif type(v)=='string' then roles={[v]=true}
        elseif type(v)=='table' then
          for rk,rv in pairs(v) do
            if type(rk)=='number' and type(rv)=='string' then roles[rv]=true
            elseif type(rk)=='string' and rv then roles[rk]=true
            else error('incorrect format for allowRoles table',2) end
          end
        else error('allowRoles must be a string or table',2) end
        logs=sformat('%s%s=%s, ',logs,k,type(v)=='table' and '{...}' or v)
        app.allowRoles=roles
      elseif k=='fullscreen' then
        app.fullscreen=v and true or nil logs=sformat('%s%s=%s, ',logs,k,ft.fullscreen)
      elseif k=='visible' then
        app.visible=v and true or nil  logs=sformat('%s%s=%s, ',logs,k,ft.visible)
      elseif k=='focused' then
        app.focused=v and true or nil logs=sformat('%s%s=%s',logs,k,ft.focused)
      else
        error('invalid key in filter table: '..tostring(k),2)
      end
    end
    self.apps[appname]=app
  end
  self.log.i(logs)
  if activeFilters[self] then refreshWindows(self) end
  return self
end

--- hs.window.filter:setFilters(filters) -> hs.window.filter object
--- Method
--- Sets multiple filtering rules
---
--- Parameters:
---  * filters - table, every element will set an application filter; these elements must:
---    - have a *key* of type string, denoting an application name as per `hs.application:name()`
---    - if the *value* is a boolean, the app will be allowed or rejected accordingly - see `hs.window.filter:allowApp()`
---      and `hs.window.filter:rejectApp()`
---    - if the *value* is a table, it must contain the accept/reject rules for the app *as key/value pairs*; valid keys
---      and values are described in `hs.window.filter:setAppFilter()`
---    - the *key* can be one of the special strings `"default"` and `"override"`, which will will set the default and override
---      filter respectively
---    - the *key* can be the special string `"trackSpaces"`; its value must be one of `"current"`, `"all"`, `"others"` or
---      `"no"`, and it will set Spaces tracking on the windowfilter accordingly - see `hs.window.filter:trackSpaces()`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * every filter definition in `filters` will overwrite the pre-existing one for the relevant application, if present;
---    this also applies to the special default and override filters, if included
function wf:setFilters(filters)
  local wasActive=activeFilters[self] activeFilters[self]=nil
  if type(filters)~='table' then error('filters must be a table',2) end
  for k,v in pairs(filters) do
    if type(k)=='number' then
      if type(v)=='string' then self:allowApp(v) -- {'appname'}
      else error('invalid filters table: integer key '..k..' needs a string value, got '..type(v)..' instead',2) end
    elseif type(k)=='string' then --{appname=...}
      if type(v)=='boolean' then if v then self:allowApp(k) else self:rejectApp(k) end --{appname=true/false}
      elseif type(v)=='string' then
        if k=='trackSpaces' then self:trackSpaces(v)
        else error('invalid filters table: key "'..k..'" needs a table value, got '..type(v)..' instead',2) end
    elseif type(v)=='table' then --{appname={arg1=val1,...}}
      if k=='trackSpaces' then error('invalid filters table: key "'..k..'" needs a string value, got '..type(v)..' instead',2)
      else self:setAppFilter(k,v) end
    else error('invalid filters table: key "'..k..'" needs a table value, got '..type(v)..' instead',2) end
    else error('invalid filters table: keys can be integer or string, got '..type(k)..' instead',2) end
  end
  activeFilters[self]=wasActive if activeFilters[self] then refreshWindows(self) end
  return self
end

--- hs.window.filter:getFilters() -> table
--- Method
--- Return a table with all the filtering rules defined for this windowfilter
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the filtering rules of this windowfilter; you can pass this table (optionally
---  after performing valid manipulations) to `hs.window.filter:setFilters()` and `hs.window.filter.new()`
function wf:getFilters() return self.apps end
--TODO getFilters


--TODO windowstartedmoving event?
--TODO windowstoppedmoving event? (needs eventtap on mouse, even then not fully reliable)

--TODO :setScreens / :setRegions
--TODO hs.windowsnap (or snapareas)
--[[
function wf:setScreens(screens)
  if not screens then self.screens=nil 
  else
    if type(screens)=='userdata' then screens={screens} end
    if type(screens)~='table' then error('screens must be a `hs.screen` object, or table of objects',2) end
    local s='setting screens: '
    for _,s in ipairs(screens) do
      if type(s)~='userdata' or not s.frame
    end
    self.screens=screens
  end
  if activeFilters[self] then refreshWindows(self) end
  return self  
end
--]]
--- hs.window.filter.new(fn[,logname[,loglevel]]) -> hs.window.filter object
--- Constructor
--- Creates a new hs.window.filter instance
---
--- Parameters:
---  * fn
---    - if `nil`, returns a copy of the default windowfilter, including any customizations you might have applied to it
---      so far; you can then further restrict or expand it
---    - if `true`, returns an empty windowfilter that allows every window
---    - if `false`, returns a windowfilter with a default rule to reject every window
---    - if a string or table of strings, returns a windowfilter that only allows visible windows of the specified apps
---      as per `hs.application:name()`
---    - if a table, you can fully define a windowfilter without having to call any methods after construction; the
---      table must be structured as per `hs.window.filter:setFilters()`; if not specified in the table, the
---      default filter in the new windowfilter will reject all windows
---    - otherwise it must be a function that accepts an `hs.window` object and returns `true` if the window is allowed
---      or `false` otherwise; this way you can define a fully custom windowfilter
---  * logname - (optional) name of the `hs.logger` instance for the new windowfilter; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new windowfilter
---
--- Returns:
---  * a new windowfilter instance

function windowfilter.new(fn,logname,loglevel)
  local mt=getmetatable(fn) if mt and mt.__index==wf then return fn end -- no copy-on-new
  local o = setmetatable({apps={},events={},windows={},pending={},log=logname and logger.new(logname,loglevel) or log},{__index=wf})
  if logname then o.setLogLevel=function(lvl)o.log.setLogLevel(lvl)return o end end
  if type(fn)=='function' then
    o.log.i('new windowfilter, custom function')
    o.isAppAllowed = function()return true end
    o.isWindowAllowed = function(self,w) return fn(w) end
    return o
  elseif type(fn)=='string' then fn={fn}
  end
  if fn==nil then
    o.log.i('new windowfilter, default windowfilter copy')
    for appname,filter in pairs(windowfilter.default.apps) do
      o.apps[appname]=filter
    end
    o.spaceFilter = windowfilter.default.spaceFilter
    o.currentSpaceWindows = windowfilter.default.currentSpaceWindows and {} or nil
    --TODO add regions and screens here
    return o
  elseif type(fn)=='table' then
    o.log.i('new windowfilter, reject all with exceptions')
    return o:setDefaultFilter(false):setFilters(fn)
  elseif fn==true then o.log.i('new empty windowfilter') return o
  elseif fn==false then o.log.i('new windowfilter, reject all') return o:setDefaultFilter(false)
  else error('fn must be nil, a boolean, a string or table of strings, or a function',2) end
end

--- hs.window.filter.copy(windowfilter[,logname[,loglevel]]) -> hs.window.filter object
--- Constructor
--- Returns a copy of an hs.window.filter object that you can further restrict or expand
---
--- Parameters:
---  * windowfilter - an `hs.window.filter` object to copy
---  * logname - (optional) name of the `hs.logger` instance for the new windowfilter; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new windowfilter
function windowfilter.copy(wf,logname,loglevel)
  local mt=getmetatable(fn) if not mt or mt.__index~=wf then error('windowfilter must be an hs.window.filter object',2) end
  return windowfilter.new(true,logname,loglevel):setFilters(wf:getFilters())
end

--- hs.window.filter.default
--- Constant
--- The default windowfilter; it filters apps whose windows are transient in nature so that you're unlikely (and often
--- unable) to do anything with them, such as launchers, menulets, preference pane apps, screensavers, etc. It also
--- filters nonstandard and invisible windows.
---
--- Notes:
---  * While you can customize the default windowfilter, it's usually advisable to make your customizations on a local copy via `mywf=hs.window.filter.new()`;
---    the default windowfilter can potentially be used in several Hammerspoon modules and changing it might have unintended consequences.
---    Common customizations:
---    * to exclude fullscreen windows: `nofs_wf=hs.window.filter.new():setOverrideFilter(nil,nil,nil,false)`
---    * to include invisible windows: `inv_wf=windowfilter.new():setDefaultFilter()`
---  * If you still want to alter the default windowfilter:
---    * you should probably apply your customizations at the top of your `init.lua`, or at any rate before instantiating any other windowfilter; this
---      way copies created via `hs.window.filter.new(nil,...)` will inherit your modifications
---    * to list the known exclusions: `hs.window.filter.setLogLevel('info')`; the console will log them upon instantiating the default windowfilter
---    * to add an exclusion: `hs.window.filter.default:rejectApp'Cool New Launcher'`
---    * to add an app-specific rule: `hs.window.filter.default:setAppFilter('My IDE',1)`; ignore tooltips/code completion (empty title) in My IDE
---    * to remove an exclusion (e.g. if you want to have access to Spotlight windows): `hs.window.filter.default:allowApp'Spotlight'`;
---      for specialized uses you can make a specific windowfilter with `myfilter=hs.window.filter.new'Spotlight'`

--- hs.window.filter.isGuiApp(appname) -> bool
--- Function
--- Checks whether an app is a known non-GUI app, as per `hs.window.filter.ignoreAlways`
---
--- Parameters:
---  * appname - name of the app to check as per `hs.application:name()`
---
--- Returns:
---  * `false` if the app is a known non-GUI (or not accessible) app; `true` otherwise

windowfilter.isGuiApp = function(appname)
  if not appname then return true
  elseif windowfilter.ignoreAlways[appname] then return false
  elseif ssub(appname,1,12)=='QTKitServer-' then return false
    --  elseif appname=='Hammerspoon' then return false
  else return true end
end


-- event watcher (formerly windowwatcher)

--FIXME events: 1. fire when relevant (i.e. windowHidden for visible=true)
-- 2. getWindows must return CURRENT situation (i.e. no hidden window for visible=true)

local events={windowCreated=true, windowDestroyed=true, windowMoved=true,
  windowMinimized=true, windowUnminimized=true,
  windowFullscreened=true, windowUnfullscreened=true,
  --TODO perhaps windowMaximized? (compare win:frame to win:screen:frame) - or include it in windowFullscreened
  --TODO windowInCurrentSpace, windowNotInCurrentSpace
  windowInCurrentSpace=true,WindowNotInCurrentSpace=true,
  windowHidden=true, windowShown=true, windowFocused=true, windowUnfocused=true,
  windowTitleChanged=true,
}
for k in pairs(events) do windowfilter[k]=k end -- expose events
--- hs.window.filter.windowCreated
--- Constant
--- Event for `hs.window.filter:subscribe()`: a new window was created

--- hs.window.filter.windowDestroyed
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was destroyed

--- hs.window.filter.windowMoved
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was moved or resized, including toggling fullscreen/maximize

--- hs.window.filter.windowMinimized
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was minimized

--- hs.window.filter.windowUnminimized
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was unminimized

--- hs.window.filter.windowFullscreened
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was expanded to full screen

--- hs.window.filter.windowUnfullscreened
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was reverted back from full screen

-- hs.window.filter.windowInCurrentSpace
-- Constant
--TODO Event for `hs.window.filter:subscribe()`:

-- hs.window.filter.windowNotInCurrentSpace
-- Constant
--TODO Event for `hs.window.filter:subscribe()`:

--- hs.window.filter.windowHidden
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window is no longer visible due to it being minimized, closed,
--- its application being hidden (e.g. via cmd-h) or closed, or in a different Mission Control Space (only for
--- windowfilters with `:trackSpaces(true)`)

--- hs.window.filter.windowShown
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window has became visible (after being hidden, or when created)

--- hs.window.filter.windowFocused
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window received focus

--- hs.window.filter.windowUnfocused
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window lost focus

--- hs.window.filter.windowTitleChanged
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window's title changed

activeFilters = {} -- active wf instances
apps = {} -- all GUI apps
local pendingApps = {} -- apps resisting being watched
local global = {} -- global state

local Window={} -- class

function Window:setFilter(wf, forceremove,cache) -- returns true if filtering status changes
  local wasAllowed,isAllowed = wf.windows[self]
  if not forceremove then isAllowed = wf:isWindowAllowed(self.window,self.app.name,cache) or nil end
  wf.windows[self] = isAllowed
  return wasAllowed ~= isAllowed
end

function Window:filterEmitEvent(wf,event,inserted,logged,notified,cache)
  if self:setFilter(wf,event==windowfilter.windowDestroyed,cache) and wf.notifyfn then
    -- filter status changed, call notifyfn if present
    if not notified then wf.log.d('Notifying windows changed') if wf.log==log then notified=true end end
    wf.notifyfn(wf:getWindows(),event)
    -- if this is an 'inserted' event, keep around the window until all the events are exhausted
    if inserted and not wf.windows[self] then wf.pending[self]=true end
  end
  if wf.windows[self] or wf.pending[self] then
    -- window is currently allowed, call subscribers if any
    local fns = wf.events[event]
    if fns then
      if not logged then wf.log.df('Emitting %s %d (%s)',event,self.id,self.app.name) if wf.log==log then logged=true end end
      for fn in pairs(fns) do
        fn(self.window,self.app.name,event)
      end
    end
    -- clear the window if this is the last event in the chain
    if not inserted then wf.pending[self]=nil end
  end
  return logged,notified
end
function Window:emitEvent(event,inserted)
  log.vf('%s (%s) => %s%s',self.app.name,self.id,event,inserted and ' (inserted)' or '')
  local logged, notified
  for wf in pairs(activeFilters) do
    logged,notified = self:filterEmitEvent(wf,event,inserted,logged,notified,true)
  end
  props.id=SPECIAL_ID_INVALIDATE_CACHE
end


function Window.new(win,id,app,watcher)
  --FIXED hackity hack below; if it survives extensive testing (all windows ever returned by a wf will have it),
  -- the id "caching" should be moved to the hs.window userdata itself
  --  local w = setmetatable({id=function()return id end},{__index=function(_,k)return function(self,...)return win[k](win,...)end end})
  -- hackity hack removed, turns out it was just for :snapshot (see gh#413)
  local o = setmetatable({app=app,window=win,id=id,watcher=watcher,time=timer.secondsSinceEpoch()},{__index=Window})
  if not win:isVisible() then o.isHidden = true end
  if win:isMinimized() then o.isMinimized = true end
  o.isFullscreen = win:isFullScreen()
  --  o.currentFrame = win:frame()
  app.windows[id]=o
  -- deal with trackSpaces
  for wf in pairs(activeFilters) do
    if wf.currentSpaceWindows then -- this filter cares about spaces
      o.inCurrentSpace={}
      --FIXME ideally check app.app:allWindows() to determine if it's in the current space
      --however doing that indiscriminately for every window is expensive, so for now
      o.inCurrentSpace[wf]=true -- assume true at start
      wf.currentSpaceWindows[o.id]=true
    end
  end



  o:emitEvent(windowfilter.windowCreated)
  if o.isMinimized then o:emitEvent(windowfilter.windowMinimized,true)
  elseif o.isHidden then o:emitEvent(windowfilter.windowHidden,true)
  else
    o:emitEvent(windowfilter.windowShown,true)
    local loggedspace,notifiedspace
    for wf in pairs(activeFilters) do
      if wf.currentSpaceWindows then
        loggedspace,notifiedspace= o:filterEmitEvent(wf,windowfilter.windowInCurrentSpace,true,loggedspace,notifiedspace)
      end
    end
  end
end

function Window:shown(inserted)
  if not self.isHidden then return log.df('%s (%d) already shown',self.app.name,self.id) end
  self.isHidden = nil
  self:emitEvent(windowfilter.windowShown,inserted)
end

function Window:unminimized()
  if not self.isMinimized then log.df('%s (%d) already unminimized',self.app.name,self.id) end
  self.isMinimized=nil
  self:emitEvent(windowfilter.windowUnminimized)
  self:shown(true)
end

function Window:focused(inserted)
  if global.focused==self then return log.df('%s (%d) already focused',self.app.name,self.id) end
  global.focused=self
  self.app.focused=self
  self.time=timer.secondsSinceEpoch()
  self:emitEvent(windowfilter.windowFocused,inserted) --TODO check this
end

local WINDOWMOVED_DELAY=0.5
function Window:moved()
  if self.movedDelayed then self.movedDelayed:stop() self.movedDelayed=nil end
  self.movedDelayed=timer.doAfter(WINDOWMOVED_DELAY,function()self:doMoved()end)
end
function Window:doMoved()
  local fs = self.window:isFullScreen()
  local oldfs = self.isFullscreen or false
  if self.isFullscreen~=fs then
    self.isFullscreen=fs
    self:emitEvent(fs and windowfilter.windowFullscreened or windowfilter.windowUnfullscreened,true)
  end
  self:emitEvent(windowfilter.windowMoved)
end

local TITLECHANGED_DELAY=0.5
function Window:titleChanged()
  if self.titleDelayed then self.titleDelayed:stop() self.titleDelayed=nil end
  self.titleDelayed=timer.doAfter(TITLECHANGED_DELAY,function()self:doTitleChanged()end)
end
function Window:doTitleChanged()
  self:emitEvent(windowfilter.windowTitleChanged)
end

function Window:unfocused(inserted)
  if global.focused~=self then return log.vf('%s (%d) already unfocused',self.app.name,self.id) end
  global.focused=nil
  self.app.focused=nil
  self:emitEvent(windowfilter.windowUnfocused,inserted)
end

function Window:minimized()
  if self.isMinimized then return log.df('%s (%d) already minimized',self.app.name,self.id) end
  self:hidden(true)
  self.isMinimized=true
  self:emitEvent(windowfilter.windowMinimized)
end

function Window:hidden(inserted)
  if self.isHidden then return log.df('%s (%d) already hidden',self.app.name,self.id) end
  if global.focused==self then self:unfocused(true) end
  self.isHidden = true
  self:emitEvent(windowfilter.windowHidden,inserted)
end

function Window:destroyed()
  if self.movedDelayed then self.movedDelayed:stop() self.movedDelayed=nil end
  if self.titleDelayed then self.titleDelayed:stop() self.titleDelayed=nil end
  self.watcher:stop()
  self.app.windows[self.id]=nil
  if not self.isHidden then self:hidden(true) end
  self:emitEvent(windowfilter.windowDestroyed)
  self.window=nil
end

function Window:spaceChanged()
  local loggedvis,loggedspace,notifiedvis,notifiedspace
  for wf in pairs(activeFilters) do
    if wf.currentSpaceWindows then -- this filter cares about spaces
      if not self.inCurrentSpace then self.inCurrentSpace={} end
      if self.inCurrentSpace[wf]==nil then self.inCurrentSpace[wf]=true end -- assume true at start
      local prev = self.inCurrentSpace[wf]
      local now = wf.currentSpaceWindows[self.id] and true or false
      if prev~=now then
        log.df('%s (%d) %s in current space',self.app.name,self.id,now and 'is' or 'not')
        if now then
          loggedvis,notifiedvis = self:filterEmitEvent(wf,windowfilter.windowShown,nil,loggedvis,notifiedvis)
          loggedspace,notifiedspace = self:filterEmitEvent(wf,windowfilter.windowInCurrentSpace,true,loggedspace,notifiedspace)
        else
          loggedspace,notifiedspace = self:filterEmitEvent(wf,windowfilter.windowNotInCurrentSpace,true,loggedspace,notifiedspace)
          loggedvis,notifiedvis = self:filterEmitEvent(wf,windowfilter.windowHidden,nil,loggedvis,notifiedvis)
        end
        self.inCurrentSpace[wf]=now
      end
    end
  end
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
    log.vf('%s (%d) is main/focused',self.name,fwid)
    if not self.windows[fwid] then
      -- windows on a different space aren't picked up by :allWindows() at first refresh
      log.df('%s (%d) was not registered',self.name,fwid)
      appWindowEvent(fw,uiwatcher.windowCreated,nil,self.name)
    end
    if not self.windows[fwid] then
      log.wf('%s (%d) is STILL not registered',self.name,fwid)
    else
      self.focused = self.windows[fwid]
    end
  end
end

function App.new(app,appname,watcher)
  local o = setmetatable({app=app,name=appname,watcher=watcher,windows={}},{__index=App})
  if app:isHidden() then o.isHidden=true end
  -- TODO if a way is found to fecth *all* windows across spaces, add it here
  -- and remove .switchedToSpace, .forceRefreshOnSpaceChange
  log.f('New app %s registered',appname)
  apps[appname] = o
  o:getWindows()
end

-- events aren't "inserted" across apps (param name notwithsanding) so an active app should NOT :deactivate
-- another app, otherwise the latter's :unfocused will have a broken "inserted" chain with nothing to close it
function App:getWindows()
  local windows=self.app:allWindows()
  if self.name=='Finder' then --filter out the desktop here
    for i=#windows,1,-1 do if windows[i]:role()~='AXWindow' then tremove(windows,i) break end end
  end
  if #windows>0 then log.df('Found %d windows for app %s',#windows,self.name) end
  for _,win in ipairs(windows) do
    appWindowEvent(win,uiwatcher.windowCreated,nil,self.name)
  end
  self:getFocused()
  if self.app:isFrontmost() then
    log.df('App %s is the frontmost app',self.name)
    if global.active then global.active:deactivated() end --see comment above
    global.active = self
    if self.focused then
      self.focused:focused(true)
      log.df('Window %d is the focused window',self.focused.id)
    end
  end
end

function App:activated()
  local prevactive=global.active
  if self==prevactive then return log.df('App %s already active; skipping',self.name) end
  if prevactive then prevactive:deactivated() end --see comment above
  log.vf('App %s activated',self.name)
  global.active=self
  self:getFocused()
  if not self.focused then return log.df('App %s does not (yet) have a focused window',self.name) end
  self.focused:focused()
end
function App:deactivated(inserted) --as per comment above, only THIS app should call :deactivated(true)
  if self~=global.active then return end
  log.vf('App %s deactivated',self.name)
  global.active=nil
  if global.focused~=self.focused then log.e('Focused app/window inconsistency') end
  if self.focused then self.focused:unfocused(inserted) end
end
function App:focusChanged(id,win)
  if self.focused and self.focused.id==id then return log.df('%s (%d) already focused, skipping',self.name,id) end
  local active=global.active
  log.vf('App %s focus changed',self.name)
  if self==active then self:deactivated(--[[true--]]) end
  if not id then
    if self.name~='Finder' then log.wf('Cannot process focus changed for app %s - %s has no window id',self.name,win:role()) end
    self.focused=nil
  else
    if not self.windows[id] then
      log.wf('%s (%d) is not registered yet',self.name,id)
      appWindowEvent(win,uiwatcher.windowCreated,nil,self.name)
    end
    self.focused = self.windows[id]
  end
  if self==active then self:activated() end
end
function App:hidden(inserted)
  if self.isHidden then return log.df('App %s already hidden, skipping',self.name) end
  --  self:deactivated(true)
  for id,window in pairs(self.windows) do
    window:hidden(inserted)
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
  --  self:hidden(true)
  for id,window in pairs(self.windows) do
    window:destroyed()
  end
  apps[self.name]=nil
end

local function windowEvent(win,event,_,appname,retry)
  local id=win and win.id and win:id()
  local app=apps[appname]
  if not id and app then
    for _,window in pairs(app.windows) do
      if window.window==win then id=window.id break end
    end
  end
  log.vf('%s (%s) <= %s (window event)',appname,id or '?',event)
  if not id then return log.ef('%s: %s cannot be processed',appname,event) end
  if not app then return log.ef('App %s is not registered!',appname) end
  local window = app.windows[id]
  if not window then return log.ef('%s (&d) is not registered!',appname,id) end
  if event==uiwatcher.elementDestroyed then
    window:destroyed()
  elseif event==uiwatcher.windowMoved or event==uiwatcher.windowResized then
    --    local frame=win:frame()
    --    if window.currentFrame~=frame then
    --      window.currentFrame=frame
    window:moved()
    --    end
  elseif event==uiwatcher.windowMinimized then
    window:minimized()
  elseif event==uiwatcher.windowUnminimized then
    window:unminimized()
  elseif event==uiwatcher.titleChanged then
    window:titleChanged()
  end
end


local RETRY_DELAY,MAX_RETRIES = 0.2,5
local windowWatcherDelayed={}

appWindowEvent=function(win,event,_,appname,retry)
  if not win:isWindow() then return end
  local role=win.subrole and win:subrole()
  if appname=='Hammerspoon' and (not role or role=='AXUnknown') then return end
  --  hs.assert(role,'(315) '..event..' '..win:role(),win)
  local id = win.id and win:id()
  log.vf('%s (%s) <= %s (appwindow event)',appname,id or '?',event)
  if event==uiwatcher.windowCreated then
    if windowWatcherDelayed[win] then windowWatcherDelayed[win]:stop() windowWatcherDelayed[win]=nil end
    retry=(retry or 0)+1
    if not id then
      if retry>MAX_RETRIES then log.wf('%s: %s has no id',appname,role or (win.role and win:role()) or 'window')
      else windowWatcherDelayed[win]=timer.doAfter(retry*RETRY_DELAY,function()appWindowEvent(win,event,_,appname,retry)end) end
      return
    end
    if apps[appname].windows[id] then return log.df('%s (%d) already registered',appname,id) end
    local watcher=win:newWatcher(windowEvent,appname)
    if not watcher._element.pid then
      log.wf('%s: %s has no watcher pid',appname,role or (win.role and win:role()))
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

--[[
local function startAppWatcher(app,appname)
  if not app or not appname then log.e('Called startAppWatcher with no app') return end
  if apps[appname] then log.df('App %s already registered',appname) return end
  if app:kind()<0 or not windowfilter.isGuiApp(appname) then log.df('App %s has no GUI',appname) return end
  local watcher = app:newWatcher(appWindowEvent,appname)
  watcher:start({uiwatcher.windowCreated,uiwatcher.focusedWindowChanged})
  App.new(app,appname,watcher)
  if not watcher._element.pid then
    log.wf('No accessibility access to app %s (no watcher pid)',(appname or '[???]'))
  end
end
--]]

-- old workaround for the 'missing pid' bug
-- reinstated because occasionally apps take a while to be watchable after launching
local function startAppWatcher(app,appname,retry,nologging)
  if not app or not appname then log.e('Called startAppWatcher with no app') return end
  if apps[appname] then return not nologging and log.df('App %s already registered',appname) end
  if app:kind()<0 or not windowfilter.isGuiApp(appname) then log.df('App %s has no GUI',appname) return end
  retry=(retry or 0)+1
  if retry>1 and not pendingApps[appname] then return end --given up before anything could even happen

  local watcher = app:newWatcher(appWindowEvent,appname)
  if watcher._element.pid then
    pendingApps[appname]=nil --done
    watcher:start({uiwatcher.windowCreated,uiwatcher.focusedWindowChanged})
    App.new(app,appname,watcher)
  else
    if retry>5 then
      pendingApps[appname]=nil --give up
      return log[nologging and 'df' or 'wf']('No accessibility access to app %s (no watcher pid)',appname)
    end
    timer.doAfter(RETRY_DELAY*MAX_RETRIES,function()startAppWatcher(app,appname,retry,nologging)end)
    pendingApps[appname]=true
  end
end


local function appEvent(appname,event,app,retry)
  local sevent={[0]='launching','launched','terminated','hidden','unhidden','activated','deactivated'}
  log.vf('%s <= %s (app event)',appname,sevent[event])
  if not appname then return end
  if event==appwatcher.launched then return startAppWatcher(app,appname)
  elseif event==appwatcher.launching then return end
  local appo=apps[appname]
  if event==appwatcher.activated then
    if appo then return appo:activated()
    else return startAppWatcher(app,appname,0,true) end
    --[[
    retry = (retry or 0)+1
    if retry==1 then
      log.vf('First attempt at registering app %s',appname)
      startAppWatcher(app,appname,5,true)
    end
    if retry>5 then return log.df('App %s still is not registered!',appname) end
    timer.doAfter(0.1*retry,function()appEvent(appname,event,app,retry)end)
    return
    --]]
  elseif event==appwatcher.terminated then pendingApps[appname]=nil end
  if not appo then return log.ef('App %s is not registered!',appname) end
  if event==appwatcher.terminated then return appo:destroyed()
  elseif event==appwatcher.deactivated then return appo:deactivated()
  elseif event==appwatcher.hidden then return appo:hidden()
  elseif event==appwatcher.unhidden then return appo:shown() end
end


local function getAllWindows()
  for _,app in pairs(apps) do
    app:getWindows()
  end
end

local trackSpacesFilters = {}
local function refreshTrackSpacesFilters()
  if not next(trackSpacesFilters) then return end
  local spacewins = {}
  if global.watcher then
    for _,app in pairs(apps) do
      for _,w in ipairs(app.app:visibleWindows()) do
        local id=w:id()
        if id then spacewins[id]=true end
      end
    end
  else
    for _,w in ipairs(window.visibleWindows()) do
      local id=w:id()
      if id then spacewins[id]=true end
    end
  end
  for wf in pairs(trackSpacesFilters) do
    wf.log.i("Space changed, updating filter")
    if wf.currentSpaceWindows then wf.currentSpaceWindows = spacewins end
  end
  for _,app in pairs(apps) do
    for _,win in pairs(app.windows) do
      win:spaceChanged()
    end
  end
end

-- matrix for trackSpaces
--              |visible=         nil                      |             true             |     false    |
-- |currentSpace|------------------------------------------|------------------------------|--------------|
-- |     nil    |all                                       |visible in ANY space          |min and hidden|
-- |    true    |visible in CURRENT space,min and hidden   |visible in CURRENT space      |min and hidden|
-- |    false   |visible in OTHER space only,min and hidden|visible in OTHER space only   |min and hidden|

--- hs.window.filter:trackSpaces(track) -> hs.window.filter
--- Method
--- Sets whether the windowfilter should be aware of different Mission Control Spaces
---
--- Parameters:
---  * track - string, it can have the following values:
---    - `"no"` (or `false`): this is the default behaviour for all windowfilters; this windowfilter will not track Space changes
---    - `"all": this windowfilter will track Space changes; when the user switches to a different Space, windows
---      that only existed in the previous Space will emit an `hs.window.filter.windowHidden` event, and similarly windows in the current
---      space will emit an `hs.window.filter.windowShown` event. Windows that carry over (i.e. for apps that have "Assign To"->"All Desktops",
---      and when you manually drag a window to another Space) won't emit either event. Minimized and hidden windows are also
---      considered to belong to all Spaces.
---      This is reflected in the visibility rules for this windowfilter: for example if it's set to only allow visible windows
---      (which is the default behaviour), windows that only exist in a given Space will be filtered out or allowed again when
---      the user switches (respectively) away from or back to that Space.
---    - `"current"` (or `true`): like "all", but regardless of this windowfilter's visiblity rules, it will only allow
---      windows in the current Space. In practice: for app filters that only allow visible windows, "current" behaves like "all";
---      for app filters that have no visibility rule set, "current" will exclude windows that are visible in other Spaces but not
---      the current one (but still include minimized and hidden windows as they belong to all Spaces).
---    - `"others"`: like "current", this windowfilter will track Space changes, but this windowfilter will only allow windows in any Space other than the current one (you need to
---      set the visibility rules to allow invisible windows, or no windows will ever be allowed)
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * Spaces-aware windowfilters might experience a (sometimes significant) delay after every Space switch, since
---    (due to OS X limitations) they must re-query for the list of all windows in the current Space every time.
function wf:trackSpaces(track)
  if track=='no' or not track then
    self.currentSpaceWindows = nil
    self.spaceFilter = nil
    trackSpacesFilters[self] = nil
  else
    self.currentSpaceWindows = {}
    trackSpacesFilters[self] = true
    if track=='all' then self.spaceFilter = nil
    elseif track=='others' then self.spaceFilter = false
    elseif track=='current' or track==true then self.spaceFilter = true
    else error('invalid parameter to trackSpaces',2) end
  end
  refreshTrackSpacesFilters()
  if activeFilters[self] then refreshWindows(self) end
  --  windowfilter.forceRefreshOnSpaceChange=next(trackSpacesFilters) and true
  return self
end

local spacesDone = {}
--- hs.window.filter.switchedToSpace(space)
--- Function
--- Callback to inform all windowfilters that the user initiated a switch to a (numbered) Mission Control Space.
---
--- See `hs.window.filter.forceRefreshOnSpaceChange` for an overview of Spaces limitations in Hammerspoon. If you
--- often (or always) change Space via the "numbered" Mission Control keyboard shortcuts (by default, `ctrl-1` etc.), you
--- can call this function from your `init.lua` when intercepting these shortcuts; for example:
--- ```
--- hs.hotkey.bind({'ctrl','1',nil,function()hs.window.filter.switchedToSpace(1)end)
--- hs.hotkey.bind({'ctrl','2',nil,function()hs.window.filter.switchedToSpace(2)end)
--- -- etc.
--- ```
--- Using this callback results in slightly better performance than setting `forceRefreshOnSpaceChange` to `true`, since
--- already visited Spaces are remembered and no refreshing is necessary when switching back to those.
---
--- Parameters:
---  * space - the Space number the user is switching to
---
--- Returns:
---- * None
---
--- Notes:
---  * Only use this function if "Displays have separate Spaces" and "Automatically rearrange Spaces" are
----   OFF in System Preferences>Mission Control
---  * Calling this function will set `hs.window.filter.forceRefreshOnSpaceChange` to `false`
function windowfilter.switchedToSpace(space,cb)
  windowfilter.forceRefreshOnSpaceChange = nil
  --  if spacesDone[space] then log.v('Switched to space #'..space) return cb and cb() end
  timer.doAfter(0.5,function()
    if not spacesDone[space] and next(activeFilters) then
      log.f('Entered space #%d, refreshing all windows',space)
      getAllWindows()
      spacesDone[space] = true
    else log.i('Switched to space #'..space) end
    refreshTrackSpacesFilters()
    return cb and cb()
  end)
end


--- hs.window.filter.forceRefreshOnSpaceChange
--- Variable
--- Tells the windowfilters whether to refresh all windows when the user switches to a different Mission Control Space.
---
--- Due to OS X limitations Hammerspoon cannot directly query for windows in Spaces other than the current one;
--- therefore when a windowfilter is initially instantiated, it doesn't know about many of these windows.
---
--- If this variable is set to `true`, windowfilters will re-query applications for all their windows whenever a Space change
--- by the user is detected, therefore any existing windows in that Space that were not yet being tracked will become known at that point;
--- if `false` (the default) this won't happen, but the windowfilters will *eventually* learn about these windows
--- anyway, as soon as they're interacted with.
---
--- If you need your windowfilters to become aware of all windows as soon as possible, you can set this to `true`,
--- but you'll incur a modest performance penalty on every Space change. If possible, use the `hs.window.filter.switchedToSpace()`
--- callback instead.
windowfilter.forceRefreshOnSpaceChange = false
local function spaceChanged()
  if windowfilter.forceRefreshOnSpaceChange and next(activeFilters) then
    log.i('Space changed, refreshing all windows')
    getAllWindows()
  end
  refreshTrackSpacesFilters()
end
local spacesWatcher = require'hs.spaces'.watcher.new(spaceChanged)
spacesWatcher:start()

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
  --  spacesWatcher:stop()
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


local function subscribe(self,map)
  for event,fns in pairs(map) do
    if not events[event] then error('invalid event: '..event,3) end
    for _,fn in pairs(fns) do
      if type(fn)~='function' then error('fn must be a function or table of functions',3) end
      if not self.events[event] then self.events[event]={} end
      self.events[event][fn]=true
      self.log.df('Added callback for event %s',event)
    end
  end
end

local function unsubscribe(self,event,fn)
  if self.events[event] and self.events[event][fn] then
    self.log.df('Removed callback for event %s',event)
    self.events[event][fn]=nil
    if not next(self.events[event]) then
      self.log.df('No more callbacks for event %s',event)
      self.events[event]=nil
    end
  end
  return self
end
local function unsubscribeCallback(self,fn)
  for event in pairs(events) do
    unsubscribe(self,event,fn)
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
      if wf.currentSpaceWindows then window:spaceChanged() end
      window:setFilter(wf)
    end
  end
end

local function start(wf)
  if activeFilters[wf]==true then return end
  wf.windows={}
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
  start(self) return self
end

-- make sure startGlobalWatcher is running during a batch operation
local batches={}
function windowfilter.startBatchOperation()
  local id=require'hs.host'.uuid()
  batches[id]=true
  startGlobalWatcher()
  return id
end
function windowfilter.stopBatchOperation(id)
  batches[id]=nil
  if not next(batches) then stopGlobalWatcher() end
end


local function getWindowObjects(wf)
  local t={}
  for w in pairs(wf.windows) do
    t[#t+1] = w
  end
  tsort(t,function(a,b)return a.time>b.time end)
  return t
end

--- hs.window.filter:getWindows() -> table
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

--- hs.window.filter:notify(fn[, fnEmpty][, immediate]) -> hs.window.filter
--- Method
--- Notify a callback whenever the list of allowed windows change
---
--- Parameters:
---  * fn - a callback function that will be called when:
---    * an allowed window is created or destroyed, and therefore added or removed from the list of allowed windows
---    * a previously allowed window is now filtered or vice versa (e.g. in consequence of a title change)
---    It will be passed 2 parameters:
---    * a list of the `hs.window` objects currently (i.e. *after* the change took place) allowed by this
---      windowfilter (as per `hs.window.filter:getWindows()`)
---    * a string containing the (first) event that caused the change (see the `hs.window.filter` constants)
---  * fnEmpty - (optional) if provided, when this windowfilter becomes empty (i.e. `:getWindows()` returns
---    an empty list) call this function (with no arguments) instead of `fn`, otherwise, always call `fn`
---  * immediate - (optional) if `true`, also call `fn` (or `fnEmpty`) immediately
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * If `fn` is nil, notifications for this windowfilter will stop.
function wf:notify(fn,fnEmpty,immediate)
  if fn~=nil and type(fn)~='function' then error('fn must be a function or nil',2) end
  if fnEmpty and type(fnEmpty)~='function' then fnEmpty=nil immediate=true end
  if fnEmpty~=nil and type(fnEmpty)~='function' then error('fnEmpty must be a function or nil',2) end
  self.notifyfn = fnEmpty and function(wins)if #wins>0 then return fn(wins) else return fnEmpty()end end or fn
  if fn then start(self) elseif not next(self.events) then self:pause() end
  if fn and immediate then self.notifyfn(self:getWindows()) end
  return self
end

--- hs.window.filter:subscribe(event, fn[, immediate]) -> hs.window.filter
--- Method
--- Subscribe to one or more events on the allowed windows
---
--- Parameters:
---  * event - string or list of strings, the event(s) to subscribe to (see the `hs.window.filter` constants);
---    alternatively, this can be a map `{event1=fn1,event2=fn2,...}`: fnN will be subscribed to eventN, and the parameter `fn` will be ignored
---  * fn - function or list of functions, the callback(s) to add for the event(s); each will be passed 3 parameters
---    * a `hs.window` object referring to the event's window
---    * a string containing the application name (`window:application():title()`) for convenience
---    * a string containing the event that caused the callback (i.e. the event, or one of the events, you subscribed to)
---  * immediate - (optional) if `true`, also call all the callbacks immediately for windows that satisfy the event(s) criteria
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * Passing lists means that *all* the `fn`s will be called when *any* of the `event`s fires,
---    so it's *not* a shortcut for subscribing distinct callbacks to distinct events; use a map
---    or chained `:subscribe` calls for that.
---  * Use caution with `immediate`: if for example you're subscribing to `hs.window.filter.windowUnfocused`,
---    `fn`(s) will be called for *all* the windows except the currently focused one.
---  * If the windowfilter was paused with `hs.window.filter:pause()`, calling this will resume it.
function wf:subscribe(event,fn,immediate)
  if type(event)=='string' then event={event} end
  if type(event)~='table' then error('event must be a string, a list of strings, or a map',2) end
  if type(fn)=='function' then fn={fn}
  elseif type(fn)=='boolean' then immediate=fn fn=nil end
  if fn and type(fn)~='table' then error('fn must be a function or list of functions',2) end
  local map,k,v={},next(event)
  if type(k)=='string' and type(v)=='function' then map=event
  else
    if not fn then error('missing parameter fn',2) end
    for _,ev in ipairs(event) do map[ev]=fn end
  end
  for _,e in pairs(event) do
    subscribe(self,map)
  end
  start(self)
  if immediate then
    local windows = getWindowObjects(self)
    for _,win in ipairs(windows) do
      for ev,fns in pairs(map) do
        if ev==windowfilter.windowCreated
          or ev==windowfilter.windowMoved
          or ev==windowfilter.windowTitleChanged
          or (ev==windowfilter.windowShown and not win.isHidden)
          or (ev==windowfilter.windowHidden and win.isHidden)
          or (ev==windowfilter.windowMinimized and win.isMinimized)
          or (ev==windowfilter.windowUnminimized and not win.isMinimized)
          or (ev==windowfilter.windowFullscreened and win.isFullscreen)
          or (ev==windowfilter.windowUnfullscreened and not win.isFullscreen)
          or (ev==windowfilter.windowFocused and global.focused==win)
          or (ev==windowfilter.windowUnfocused and global.focused~=win)
        then for _,fn in ipairs(fns) do
          fn(win.window,win.app.name,ev) end
        end
      end
    end
  end
  return self
end

--- hs.window.filter:unsubscribe([event][, fn]) -> hs.window.filter
--- Method
--- Removes one or more event subscriptions
---
--- Parameters:
---  * event - string or list of strings, the event(s) to unsubscribe; if omitted, `fn`(s) will be unsubscribed from all events;
---    alternatively, this can be a map `{event1=fn1,event2=fn2,...}`: fnN will be unsubscribed from eventN, and the parameter `fn` will be ignored
---  * fn - function or list of functions, the callback(s) to remove; if omitted, all callbacks will be unsubscribed from `event`(s)
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * You must pass at least one of `event` or `fn`
---  * If calling this on the default (or any other shared use) windowfilter, do not pass events, as that would remove
---    *all* the callbacks for the events including ones subscribed elsewhere that you might not be aware of. You should
---    instead keep references to your functions and pass in those.
function wf:unsubscribe(events,fns)
  if not events and not fns then error('you must pass at least one of event or fn',2) end
  local tevents,tfns=type(events),type(fns)
  if events==nil then tevents=nil end
  if fns==nil then tfns=nil end
  if tfns=='function' then fns={fns} tfns='lfn' end --?+fn
  if tevents=='function' then fns={events} tfns='lfn' tevents=nil --omitted+fn
  elseif tevents=='string' then events={events} tevents='ls' end --event+?
  if tevents=='table' then
    local k,v=next(events)
    if type(k)=='function' and v==true then fns=events tfns='sfn' tevents=nil --omitted+set of fns
    elseif type(k)=='string' then --set of events, or map
      if type(v)=='function' then tevents='map' tfns=nil --map+ignored
      elseif v==true then tevents='ss' --set of events+?
      else error('invalid event parameter',2) end
    elseif type(k)=='number' then --list of events or functions
      if type(v)=='function' then fns=events tfns='lfn' tevents=nil --omitted+list of fns
      elseif type(v)=='string' then tevents='ls' --list of events+?
      else error('invalid event parameter',2) end
    else error('invalid event parameter',2) end
  end
  if tfns=='table' then
    local k,v=next(fns)
    if type(k)=='function' and v==true then tfns='sfn' --?+set of fns
    elseif type(k)=='number' and type(v)=='function' then tfns='lfn' --?+list of fns
    else error('invalid fn parameter',2) end
  end
  if tevents==nil then --all events
    events=self.events tevents='ss'
  end
  if tevents=='ss' then --make list
    local l={} for k in pairs(events) do l[#l+1]=k end events=l tevents='ls'
  end
  if tfns=='sfn' then --make list
    local l={} for k in pairs(fns) do l[#l+1]=k end fns=l tfns='lfn'
  end

  if tevents=='map' then
    for ev,fn in pairs(events) do unsubscribe(self,ev,fn) end
  else
    if tevents~='ls' then error('invalid event parameter',2)
    elseif tfns~=nil and tfns~='lfn' then error('invalid fn parameter',2) end

    for _,ev in ipairs(events) do
      if not tfns then unsubscribeEvent(self,ev)
      else for _,fn in ipairs(fns) do unsubscribe(self,ev,fn) end end
    end
  end
  if not next(self.events) then return self:unsubscribeAll() end
  return self
end

--- hs.window.filter:unsubscribeAll() -> hs.window.filter
--- Method
--- Removes all event subscriptions
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * You should not use this on the default windowfilter or other shared windowfilters
function wf:unsubscribeAll()
  self.events={}
  self:pause()
  return self
end


--- hs.window.filter:resume() -> hs.window.filter
--- Method
--- Resumes the windowfilter event subscriptions
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function wf:resume()
  if activeFilters[self]==true then self.log.i('instance already running, ignoring')
  else start(self) end
  return self
end

--- hs.window.filter:pause() -> hs.window.filter
--- Method
--- Stops the windowfilter event subscriptions; no more event callbacks will be triggered, but the subscriptions remain intact for a subsequent call to `hs.window.filter:resume()`
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
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

local defaultwf, loglevel
function windowfilter.setLogLevel(lvl)
  log.setLogLevel(lvl) loglevel=lvl
  if defaultwf then defaultwf.setLogLevel(lvl) end
  return windowfilter
end

local function makeDefault()
  if not defaultwf then
    defaultwf = windowfilter.new(true,'wflt-def')
    if loglevel then defaultwf.setLogLevel(loglevel) end
    for appname in pairs(windowfilter.ignoreInDefaultFilter) do
      defaultwf:rejectApp(appname)
    end
    --    defaultwf:setAppFilter('Hammerspoon',{'Preferences','Console'})
    defaultwf:rejectApp'Hammerspoon'
    defaultwf:setDefaultFilter(nil,nil,nil,nil,true)
    defaultwf.log.i('default windowfilter instantiated')
  end
  return defaultwf
end


-- utilities

--- hs.window.filter:windowsToEast(window, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all visible windows allowed by this windowfilter that lie to the east a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    eastward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned east (i.e. right) of the window, in ascending order of distance
---
--- Notes:
---  * This is a convenience wrapper that returns `hs.window.windowsToEast(window,self:getWindows(),...)`

--- hs.window.filter:windowsToWest(window, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all visible windows allowed by this windowfilter that lie to the west a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    westward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned west (i.e. left) of the window, in ascending order of distance
---
--- Notes:
---  * This is a convenience wrapper that returns `hs.window.windowsToWest(window,self:getWindows(),...)`

--- hs.window.filter:windowsToNorth(window, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all visible windows allowed by this windowfilter that lie to the north a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    northward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned north (i.e. up) of the window, in ascending order of distance
---
--- Notes:
---  * This is a convenience wrapper that returns `hs.window.windowsToNorth(window,self:getWindows(),...)`

--- hs.window.filter:windowsToSouth(window, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all visible windows allowed by this windowfilter that lie to the south a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    southward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned south (i.e. down) of the window, in ascending order of distance
---
--- Notes:
---  * This is a convenience wrapper that returns `hs.window.windowsToSouth(window,self:getWindows(),...)`

--- hs.window.filter:focusWindowEast(window, frontmost, strict)
--- Method
--- Focuses the nearest window to the east of a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window in this windowfilter
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    eastward axis
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.focusWindowEast(window,self:getWindows(),...)`
---  * You'll likely want to add `:trackSpaces(true)` to the windowfilter used for this method call.

--- hs.window.filter:focusWindowWest(window, frontmost, strict)
--- Method
--- Focuses the nearest window to the west of a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window in this windowfilter
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    westward axis
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.focusWindowWest(window,self:getWindows(),...)`
---  * You'll likely want to add `:trackSpaces(true)` to the windowfilter used for this method call.

--- hs.window.filter:focusWindowSouth(window, frontmost, strict)
--- Method
--- Focuses the nearest window to the north of a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window in this windowfilter
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    northward axis
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.focusWindowSouth(window,self:getWindows(),...)`
---  * You'll likely want to add `:trackSpaces(true)` to the windowfilter used for this method call.

--- hs.window.filter:focusWindowNorth(window, frontmost, strict)
--- Method
--- Focuses the nearest window to the south of a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window in this windowfilter
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    southward axis
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.focusWindowNorth(window,self:getWindows(),...)`
---  * You'll likely want to add `:trackSpaces(true)` to the windowfilter used for this method call.
for _,dir in ipairs{'East','North','West','South'}do
  wf['windowsTo'..dir]=function(self,win,...)
    return window['windowsTo'..dir](win,self:getWindows(),...)
  end
  wf['focusWindow'..dir]=function(self,win,...)
    if window['focusWindow'..dir](win,self:getWindows(),...) then self.log.i('Focused window '..dir:lower()) end
  end
end


local rawget=rawget
return setmetatable(windowfilter,{
  __index=function(t,k) return k=='default' and makeDefault() or rawget(t,k) end,
  __call=function(t,...) return windowfilter.new(...):getWindows() end
})

