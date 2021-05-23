--- === hs.window.filter ===
---
--- Filter windows by application, title, location on screen and more, and easily subscribe to events on these windows
---
--- Warning: this module is still somewhat experimental.
--- Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.libera.chat.
---
--- Windowfilters monitor all windows as they're created, closed, moved etc., and select some (or none) among these windows
--- according to specific filtering rules. These filtering rules are app-specific, i.e. they start off by selecting all windows
--- belonging to a certain application (but you can also define *default* and *override* filters - see `:setAppFilter()`,
--- `:setDefaultFilter()`, `:setOverrideFilter()`) and they can allow or reject windows based on:
---   * visibility, focused and/or fullscreen status
---   * title length or patterns in the title
---   * position on screen (inside or outside a certain region or screen)
---   * accessibility role (standard window, dialog, etc.)
---   * whether they're in the current Mission Control Space or not
---
--- The filtering happens automatically in the background; windowfilters then:
---   * generate a dynamic list of the windows that currently satisfy the filtering rules (see `:getWindows()`)
---   * sanitize and expose all pertinent events on these windows (see `:subscribe()` and the module constants with all the events)
---
--- A *default windowfilter* (not to be confused with the default filter *within* a windowfilter) is provided as convenience;
--- it excludes some known apps and windows that are transient in nature, therefore unlikely to be "interesting" for e.g. window management.
--- `hs.window.filter.new()` (with no arguments) returns a copy of the default windowfilter that you can further tailor
--- to your needs - see `hs.window.filter.default` and `hs.window.filter.new()` for more information.
---
--- Usage examples:
--- ```
--- local wf=hs.window.filter
---
--- -- alter the default windowfilter
--- wf.default:setAppFilter('My IDE',{allowTitles=1}) -- ignore no-title windows (e.g. transient autocomplete suggestions) in My IDE
---
--- -- set the exact scope of what you're interested in - see hs.window.filter:setAppFilter()
--- wf_terminal = wf.new{'Terminal','iTerm2'} -- all visible terminal windows
--- wf_timewaster = wf.new(false):setAppFilter('Safari',{allowTitles='reddit'}) -- any Safari windows with "reddit" anywhere in the title
--- wf_leftscreen = wf.new{override={visible=true,fullscreen=false,allowScreens='-1,0',currentSpace=true}}
--- -- all visible and non-fullscreen windows that are on the screen to the left of the primary screen in the current Space
--- wf_editors_righthalf = wf.new{'TextEdit','Sublime Text','BBEdit'}:setRegions(hs.screen.primaryScreen():fromUnitRect'0.5,0/1,1')
--- -- text editor windows that are on the right half of the primary screen
--- wf_bigwindows = wf.new(function(w)return w:frame().area>3000000 end) -- only very large windows
--- wf_notif = wf.new{['Notification Center']={allowRoles='AXNotificationCenterAlert'}} -- notification center alerts
---
--- -- subscribe to events
--- wf_terminal:subscribe(wf.windowFocused,some_fn) -- run a function whenever a terminal window is focused
--- wf_timewaster:subscribe(wf.hasWindow,startAnnoyingMe):subscribe(wf.hasNoWindows,stopAnnoyingMe) -- fight procrastination :)
--- ```


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
-- * There is the usual problem with spaces; it's usefully abstracted away from userspace via .currentSpace field in filters,
--   but the implementation is inefficient as it relies on calling hs.window.allWindows() (which can be slow)
--   on space changes.
-- * window(un)maximized could be implemented, or merged into window(un)fullscreened (but currently isn't either)

local pairs,ipairs,type,smatch,sformat,ssub = pairs,ipairs,type,string.match,string.format,string.sub
local next,tsort,setmetatable,pcall = next,table.sort,setmetatable,pcall
local timer,geometry,screen = require'hs.timer',require'hs.geometry',require'hs.screen'
local application,window = require'hs.application',hs.window
local appwatcher,uiwatcher = application.watcher,require'hs.uielement'.watcher
local axuielement, fnutils = require("hs.axuielement"), require("hs.fnutils")
local logger = require'hs.logger'
local log = logger.new('wfilter')
local DISTANT_FUTURE=315360000 -- 10 years (roughly)

local windowMT = hs.getObjectMetatable("hs.window")

local windowfilter={} -- module
local WF={} -- class
-- instance fields:
-- .filters = filters set
-- .events = subscribed events
-- .windows = current allowed windows
-- .pending = windows that must still emit more events in an event chain - cleared when the last event of the chain has been emitted


local global = {} -- global state (focused app, focused window, appwatchers running or not)
local activeInstances = {} -- active wf instances (i.e. with subscriptions or :keepActive)
local spacesInstances = {} -- wf instances that also need to be "active" because they care about Spaces
local screensInstances = {} -- wf instances that care about screens (needn't be active, but must screen.watcher)
local applicationInstances = {} -- wf instances that care about the active application
local applicationActiveInstances = {} -- wf instances above that are also active
local pendingApps = {} -- apps (hopefully temporarily) resisting being watched (hs.application)
local apps = {} -- all GUI apps (class App) containing all windows (class Window)
local App,Window={},{} -- classes
local preexistingWindowFocused,preexistingWindowCreated={},{} -- used to 'bootstrap' fields .focused/.created and preserve relative ordering in :getWindows

--- hs.window.filter.ignoreAlways
--- Variable
--- A table of application names (as per `hs.application:name()`) that are always ignored by this module.
--- These are apps with no windows or any visible GUI, such as system services, background daemons and "helper" apps.
---
--- You can add an app to this table with `hs.window.filter.ignoreAlways['Background App Title'] = true`
---
--- Notes:
---  * As the name implies, even the empty, "allow all" windowfilter will ignore these apps.
---  * You don't *need* to keep this table up to date, since non GUI apps will simply never show up anywhere; this table is just used as a "root" filter to gain a (very small) performance improvement.

do
  local SKIP_APPS_NO_PID = {
    -- ideally, keep this updated (used in the root filter)
    -- these will be shown as a warning in the console ("No accessibility access to app ...")
    'universalaccessd','sharingd','Safari Networking', 'Spotlight Networking', 'iTunes Helper','Safari Web Content',
    'App Store Web Content', 'Safari Database Storage',
    'Google Chrome Helper','Spotify Helper',
    'Todoist Networking', 'Safari Storage', 'Todoist Database Storage', 'AAM Updates Notifier', 'Slack Helper',
  --  'Little Snitch Agent','Little Snitch Network Monitor', -- depends on security settings in Little Snitch
  }

  local SKIP_APPS_NO_WINDOWS = {
    -- ideally, keep this updated (used in the root filter)
    -- hs.window.filter._showCandidates() -- from the console
    'com.apple.internetaccounts', 'CoreServicesUIAgent', 'AirPlayUIAgent',
    'com.apple.security.pboxd', 'PowerChime',
    'SystemUIServer', 'Dock', 'com.apple.dock.extra', 'storeuid',
    'Folder Actions Dispatcher', 'Keychain Circle Notification', 'Wi-Fi',
    'Image Capture Extension', 'iCloud Photos', 'System Events',
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
    'MenuMetersApp',
  }

  windowfilter.ignoreInDefaultFilter = {}
  for _,appname in ipairs(SKIP_APPS_TRANSIENT_WINDOWS) do windowfilter.ignoreInDefaultFilter[appname] = true end
end


-- utility function for maintainers; shows (in the console) candidate apps that, if recognized as
-- "no GUI" or "transient window" apps, can be added to the relevant tables for the default windowfilter
function windowfilter._showCandidates()
  local running=application.runningApplications()
  local t={}
  for _,app in ipairs(running) do
    local appname = app:name()
    if appname and windowfilter.isGuiApp(appname) and #app:allWindows()==0
      and not windowfilter.ignoreInDefaultFilter[appname] and app:kind()>=0
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



--- hs.window.filter:isWindowAllowed(window) -> boolean
--- Method
--- Checks if a window is allowed by the windowfilter
---
--- Parameters:
---  * window - an `hs.window` object to check
---
--- Returns:
---  * `true` if the window is allowed by the windowfilter, `false` otherwise; `nil` if an invalid object was passed

local function matchTitles(titles,t)
  for _,title in ipairs(titles) do
    if smatch(t,title) then return true end
  end
end
local function matchRegions(regions,frame) -- if more than half the window is inside, or if more than half the region is covered
  for _,region in ipairs(regions) do
    local area=frame:intersect(region).area
    if area>0 and (area>frame.area*0.5 or area>region.area*0.5) then return true end
end
end

local function checkWindowAllowed(filter,win)
  if filter.visible~=nil and filter.visible~=win.isVisible then return false,'visible' end
  if filter.currentSpace~=nil and filter.currentSpace~=win.isInCurrentSpace then return false,'currentSpace' end
  if filter.allowTitles then
    if type(filter.allowTitles)=='number' then if #win.title<=filter.allowTitles then return false,'allowTitles' end
    elseif not matchTitles(filter.allowTitles,win.title) then return false,'allowTitles' end
  end
  if filter.rejectTitles and matchTitles(filter.rejectTitles,win.title) then return false,'rejectTitles' end
  if filter.fullscreen~=nil and filter.fullscreen~=win.isFullscreen then return false,'fullscreen' end
  if filter.focused~=nil and filter.focused~=(win==global.focused) then return false,'focused' end
  if filter.activeApplication~=nil and filter.activeApplication~=(global.active==win.app) then return false,'activeApplication' end
  if win.isVisible then --min and hidden disregard regions and screens
    if filter.allowRegions and not matchRegions(filter.allowRegions,win.frame) then return false,'allowRegions' end
    if filter.rejectRegions and matchRegions(filter.allowRegions,win.frame) then return false,'rejectRegions' end
    if filter.allowScreens and not filter._allowedScreens[win.screen] then return false,'allowScreens' end
    if filter.rejectScreens and filter._rejectedScreens[win.screen] then return false,'rejectScreens' end
  end
  if filter.hasTitlebar~=nil and win.hasTitlebar~=filter.hasTitlebar then return false,'hasTitlebar' end
  local approles = filter.allowRoles or windowfilter.allowedWindowRoles
  if approles~='*' and not approles[win.role] then return false,'allowRoles' end
  return true,''
end

local shortRoles={AXStandardWindow='wnd',AXDialog='dlg',AXSystemDialog='sys dlg',AXFloatingWindow='float',
  AXNotificationCenterBanner='notif',AXUnknown='unknown',['']='no role'}

local function isWindowAllowed(self,win)
  local role,appname,id=shortRoles[win.role] or win.role,win.app.name,win.id
  local filter=self.filters.override
  if filter==false then self.log.vf('REJECT %s (%s %d): override filter reject',appname,role,id) return false
  elseif filter then
    local r,cause=checkWindowAllowed(filter,win)
    if not r then
      self.log.vf('REJECT %s (%s %d): override filter [%s]',appname,role,id,cause)
      return r
    end
  end
  if not windowfilter.isGuiApp(appname) then
    --if you see this in the log, add to .ignoreAlways
    self.log.wf('REJECT %s (%s %d): should be a non-GUI app!',appname,role,id) return false
  end
  filter=self.filters[appname]
  if filter==false then self.log.vf('REJECT %s (%s %d): app filter reject',appname,role,id) return false
  elseif filter then
    local r,cause=checkWindowAllowed(filter,win)
    self.log.vf('%s %s (%s %d): app filter [%s]',r and 'ALLOW' or 'REJECT',appname,role,id,cause)
    return r
  end
  filter=self.filters.default
  if filter==false then self.log.vf('REJECT %s (%s %d): default filter reject',appname,role,id) return false
  elseif filter then
    local r,cause=checkWindowAllowed(filter,win)
    self.log.vf('%s %s (%s %d): default filter [%s]',r and 'ALLOW' or 'REJECT',appname,role,id,cause)
    return r
  end
  self.log.vf('ALLOW %s (%s %d) (no filter)',appname,role,id)
  return true
end

function WF:isWindowAllowed(theWindow)
  if not theWindow then return end
  local id=theWindow.id and theWindow:id()
  --this filters out non-windows, as well as AXScrollArea from Finder (i.e. the desktop)
  --which allegedly is a window, but without id
  if not id then return end
  if activeInstances[self] then return self.windows[id] and true or false end
  local appname,win=theWindow:application():name()
  if apps[appname] then
    for wid,w in pairs(apps[appname].windows) do
      if wid==id then win=w break end
    end
  end
  if not win then
    --    hs.assert(not global.watcher,'window not being tracked')
    self.log.d('window is not being tracked')
    win=Window.new(theWindow,id) --fixme
    win.app={} win.app.name=appname
    if self.trackSpacesFilters then
      win.isInCurrentSpace=false
      if not win.isVisible then win.isInCurrentSpace=true
      else
        local allwins=theWindow:application():visibleWindows()
        for _,w in ipairs(allwins) do
          if w:id()==id then win.isInCurrentSpace=true break end
        end
      end
    end
    if not global.watcher then
      --temporarily fill in the necessary data
      local frontapp = application.frontmostApplication()
      local frontwin = frontapp and frontapp:focusedWindow()
      if frontwin and frontwin:id()==id then global.focused=win else global.focused=nil end
      if frontapp:pid()==theWindow:application():pid() then global.active=win.app else global.active=nil end
    end
  end
  return isWindowAllowed(self,win)
end

--- hs.window.filter:isAppAllowed(appname) -> boolean
--- Method
--- Checks if an app is allowed by the windowfilter
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---
--- Returns:
---  * `false` if the app is rejected by the windowfilter; `true` otherwise

function WF:isAppAllowed(appname)
  return windowfilter.isGuiApp(appname) and self.filters[appname]~=false
end

--- hs.window.filter:rejectApp(appname) -> hs.window.filter object
--- Method
--- Sets the windowfilter to outright reject any windows belonging to a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * this is just a convenience wrapper for `windowfilter:setAppFilter(appname,false)`
function WF:rejectApp(appname)
  return self:setAppFilter(appname,false)
end

--- hs.window.filter:allowApp(appname) -> hs.window.filter object
--- Method
--- Sets the windowfilter to allow all visible windows belonging to a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * this is just a convenience wrapper for `windowfilter:setAppFilter(appname,{visible=true})`
function WF:allowApp(appname)
  return self:setAppFilter(appname,true)--nil,nil,windowfilter.allowedWindowRoles,nil,true)
end
--- hs.window.filter:setDefaultFilter(filter) -> hs.window.filter object
--- Method
--- Set the default filtering rules to be used for apps without app-specific rules
---
--- Parameters:
---  * filter - see `hs.window.filter:setAppFilter`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function WF:setDefaultFilter(...)
  return self:setAppFilter('default',...)
end
--- hs.window.filter:setOverrideFilter(filter) -> hs.window.filter object
--- Method
--- Set overriding filtering rules that will be applied for all apps before any app-specific rules
---
--- Parameters:
---  * filter - see `hs.window.filter:setAppFilter`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function WF:setOverrideFilter(...)
  return self:setAppFilter('override',...)
end
--- hs.window.filter:setCurrentSpace(val) -> hs.window.filter object
--- Method
--- Sets whether the windowfilter should only allow (or reject) windows in the current Mission Control Space
---
--- Parameters:
---  * val - boolean; if `true`, only allow windows in the current Mission Control Space, plus minimized and hidden windows;
---    if `false`, reject them; if `nil`, ignore Mission Control Spaces
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * This is just a convenience wrapper for setting the `currentSpace` field in the `override` filter (other
---    fields will be left untouched); per-app filters will maintain their `currentSpace` field, if present, as is
---  * Spaces-aware windowfilters might experience a (sometimes significant) delay after every Space switch, since
---    (due to OS X limitations) they must re-query for the list of all windows in the current Space every time.
function WF:setCurrentSpace(val)
  local nf=self.filters.override or {}
  if nf~=false then nf.currentSpace=val end
  return self:setOverrideFilter(nf)
end

--- hs.window.filter:setRegions(regions) -> hs.window.filter object
--- Method
--- Sets the allowed screen regions for this windowfilter
---
--- Parameters:
---  * regions - an `hs.geometry` rect or constructor argument, or a list of them, indicating the allowed region(s) for this windowfilter
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * This is just a convenience wrapper for setting the `allowRegions` field in the `override` filter (other fields will be left untouched); per-app filters will maintain their `allowRegions` and `rejectRegions` fields, if present
function WF:setRegions(val)
  local nf=self.filters.override or {}
  if nf~=false then nf.allowRegions=val end
  return self:setOverrideFilter(nf)
end

--- hs.window.filter:setScreens(screens) -> hs.window.filter object
--- Method
--- Sets the allowed screens for this windowfilter
---
--- Parameters:
---  * regions - a valid argument for `hs.screen.find()`, or a list of them, indicating the allowed screen(s) for this windowfilter
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * This is just a convenience wrapper for setting the `allowScreens` field in the `override` filter (other
---    fields will be left untouched); per-app filters will maintain their `allowScreens` and `rejectScreens` fields, if present
function WF:setScreens(val)
  local nf=self.filters.override or {}
  if nf~=false then nf.allowScreens=val end
  return self:setOverrideFilter(nf)
end

--- hs.window.filter:setAppFilter(appname, filter) -> hs.window.filter object
--- Method
--- Sets the detailed filtering rules for the windows of a specific app
---
--- Parameters:
---  * appname - app name as per `hs.application:name()`
---  * filter - if `false`, reject the app; if `true`, `nil`, or omitted, allow all visible windows (in any Space) for the app; otherwise it must be a table describing the filtering rules for the app, via the following fields:
---    * visible - if `true`, only allow visible windows (in any Space); if `false`, reject visible windows; if omitted, this rule is ignored
---    * currentSpace - if `true`, only allow windows in the current Mission Control Space (minimized and hidden windows are included, as they're considered to belong to all Spaces); if `false`, reject windows in the current Space (including all minimized and hidden windows); if omitted, this rule is ignored
---    * fullscreen - if `true`, only allow fullscreen windows; if `false`, reject fullscreen windows; if omitted, this rule is ignored
---    * hasTitlebar - if `true`, only allow windows with titlebar; if `false`, reject window with titlebar; if omitted, this rule is ignored
---    * focused - if `true`, only allow a window while focused; if `false`, reject the focused window; if omitted, this rule is ignored
---    * activeApplication - only allow any of this app's windows while it is (if `true`) or it's not (if `false`) the active application; if omitted, this rule is ignored
---    * allowTitles
---      * if a number, only allow windows whose title is at least as many characters long; e.g. pass `1` to filter windows with an empty title
---      * if a string or table of strings, only allow windows whose title matches (one of) the pattern(s) as per `string.match`
---      * if omitted, this rule is ignored
---    * rejectTitles - if a string or table of strings, reject windows whose titles matches (one of) the pattern(s) as per `string.match`; if omitted, this rule is ignored
---    * allowRegions - an `hs.geometry` rect or constructor argument, or a list of them, designating (a) screen "region(s)" in absolute coordinates: only allow windows that "cover" at least 50% of (one of) the region(s), and/or windows that have at least 50% of their surface inside (one of) the region(s); if omitted, this rule is ignored
---    * rejectRegions - an `hs.geometry` rect or constructor argument, or a list of them, designating (a) screen "region(s)" in absolute coordinates: reject windows that "cover" at least 50% of (one of) the region(s), and/or windows that have at least 50% of their surface inside (one of) the region(s); if omitted, this rule is ignored
---    * allowScreens - a valid argument for `hs.screen.find()`, or a list of them, indicating one (or more) screen(s): only allow windows that (mostly) lie on (one of) the screen(s); if omitted, this rule is ignored
---    * rejectScreens - a valid argument for `hs.screen.find()`, or a list of them, indicating one (or more) screen(s): reject windows that (mostly) lie on (one of) the screen(s); if omitted, this rule is ignored
---    * allowRoles
---      * if a string or table of strings, only allow these window roles as per `hs.window:subrole()`
---      * if the special string `'*'`, this rule is ignored (i.e. all window roles, including empty ones, are allowed)
---      * if omitted, use the default allowed roles (defined in `hs.window.filter.allowedWindowRoles`)
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * Passing `focused=true` in `filter` will (naturally) result in the windowfilter ever allowing 1 window at most
---  * If you want to allow *all* windows for an app, including invisible ones, pass an empty table for `filter`
---  * Spaces-aware windowfilters might experience a (sometimes significant) delay after every Space switch, since (due to OS X limitations) they must re-query for the list of all windows in the current Space every time.
---  * If System Preferences>Mission Control>Displays have separate Spaces is *on*, the *current Space* is defined as the union of all the Spaces that are currently visible
---  * This table explains the effects of different combinations of `visible` and `currentSpace`, showing which windows will be allowed:
--- ```
---              |visible=         nil                      |             true             |     false    |
--- |currentSpace|------------------------------------------|------------------------------|--------------|
--- |     nil    |all                                       |visible in ANY space          |min and hidden|
--- |    true    |visible in CURRENT space+min and hidden   |visible in CURRENT space      |min and hidden|
--- |    false   |visible in OTHER space only+min and hidden|visible in OTHER space only   |none          |
--- ```
local refreshWindows,checkTrackSpacesFilters,checkScreensFilters,checkActiveApplicationFilters
local function getListOfStrings(l)
  if type(l)~='table' then return end
  local r={}
  for _,v in ipairs(l) do if type(v)=='string' then r[#r+1]=v else return end end
  return r
end
local function getListOfRects(l)
  local ok,res=nil,pcall(geometry.new,l)
  if ok and geometry.type(res)=='rect' then l={res} end
  if type(l)~='table' then return end
  local r={}
  for _,v in ipairs(l) do
    ok,res=pcall(geometry.new,v)
    if ok and geometry.type(res)=='rect' then r[#r+1]=v else return end
  end
  return r
end

local function getListOfScreens(l)
  if type(l)=='number' or type(l)=='string' then l={l}
  elseif type(l)=='table' then
    local ok,res=pcall(geometry.new,l)
    if ok and (geometry.type(res)=='rect' or geometry.type(res)=='size') then l={res} end
  end
  if type(l)~='table' then return end
  local r={}
  for _,v in ipairs(l) do
    if type(v)=='number' or type(v)=='string' then r[#r+1]=v
    elseif type(v)=='table' then
      local ok,res=pcall(geometry.new,v)
      if ok and (geometry.type(res)=='rect' or geometry.type(res)=='size') then r[#r+1]=res end
    end
  end
  return r
end

--TODO add size/aspect filters?
function WF:setAppFilter(appname,ft,batch)
  if type(appname)~='string' then error('appname must be a string',2) end
  local logs
  if appname=='override' or appname=='default' then logs=sformat('setting %s filter: ',appname)
  else logs=sformat('setting filter for %s: ',appname) end

  if ft==false then
    logs=logs..'reject'
    self.filters[appname]=false
  else
    if ft==nil or ft==true then ft={visible=true} end -- shortcut
    if type(ft)~='table' then error('filter must be a table',2) end
    local filter = {} -- always override

    for k,v in pairs(ft) do
      if k=='allowTitles' then
        local r
        if type(v)=='string' then r={v}
        elseif type(v)=='number' then r=v
        else r=getListOfStrings(v) end
        if not r then error('allowTitles must be a number, string or list of strings',2) end
        if type(r)=='table' then
          local first=r[1] if #r>1 then first=first..',...' end
          logs=sformat('%s%s={%s}, ',logs,k,first)
        else logs=sformat('%s%s=%s, ',logs,k,r) end
        filter.allowTitles=r
      elseif k=='rejectTitles' then
        local r
        if type(v)=='string' then r={v}
        else r=getListOfStrings(v) end
        if not r then error('rejectTitles must be a number, string or list of strings',2) end
        local first=r[1] if #r>1 then first=first..',...' end
        logs=sformat('%s%s={%s}, ',logs,k,first)
        filter.rejectTitles=r
      elseif k=='allowRoles' then
        local r={}
        if v=='*' then r=v
        elseif type(v)=='string' then r={[v]=true}
        elseif type(v)=='table' then
          for rk,rv in pairs(v) do
            if type(rk)=='number' and type(rv)=='string' then r[rv]=true
            elseif type(rk)=='string' and rv then r[rk]=true
            else error('incorrect format for allowRoles table',2) end
          end
        else error('allowRoles must be a string or a list or set of strings',2) end
        if type(r)=='table' then
          local first=next(r) if next(r,first) then first=first..',...' end
          logs=sformat('%s%s={%s}, ',logs,k,first)
        else logs=sformat('%s%s=%s, ',logs,k,v) end
        filter.allowRoles=r
      elseif k=='visible' or k=='fullscreen' or k=='focused' or k=='currentSpace' or k=='activeApplication' or k=='hasTitlebar' then
        if type(v)~='boolean' then error(k..' must be a boolean',2) end
        filter[k]=v logs=sformat('%s%s=%s, ',logs,k,ft[k])
      elseif k=='allowRegions' or k=='rejectRegions' then
        local r=getListOfRects(v)
        if not r then error(k..' must be an hs.geometry object or constructor, or a list of them',2) end
        local first=r[1].string if #r>1 then first=first..',...' end
        logs=sformat('%s%s={%s}, ',logs,k,first)
        filter[k]=r
      elseif k=='allowScreens' or k=='rejectScreens' then
        local r=getListOfScreens(v)
        if not r then error(k..' must be a valid argument for hs.screen.find, or a list of them',2) end
        local first=r[1] if #r>1 then first=first..',...' end
        logs=sformat('%s%s={%s}, ',logs,k,first)
        filter[k]=r
        self.screensFilters=42 --make sure to always re-applyScreenFilters()
      else
        error('invalid key in filter table: '..tostring(k),2)
      end
    end
    self.filters[appname]=filter
  end
  self.log.i(logs)
  if not batch then
    checkTrackSpacesFilters(self) checkScreensFilters(self) checkActiveApplicationFilters(self)
    if activeInstances[self] or spacesInstances[self] then return refreshWindows(self) end
  end
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
---    - the key can be one of the special strings `"default"` and `"override"`, which will will set the default and override
---      filter respectively
---    - the key can be the special string `"sortOrder"`; the value must be one of the `sortBy...` constants as per
---      `hs.window.filter:setSortOrder()`
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * every filter definition in `filters` will overwrite the pre-existing one for the relevant application, if present;
---    this also applies to the special default and override filters, if included
function WF:setFilters(filters)
  if type(filters)~='table' then error('filters must be a table',2) end
  for k,v in pairs(filters) do
    if type(k)=='number' then
      if type(v)=='string' then self:allowApp(v) -- {'appname'}
      else error('invalid filters table: integer key '..k..' needs a string value, got '..type(v)..' instead',2) end
    elseif type(k)=='string' then --{appname=...}
      if k=='sortOrder' then self:setSortOrder(v)
      elseif type(v)=='boolean' then if v then self:allowApp(k) else self:rejectApp(k) end --{appname=true/false}
      elseif type(v)=='table' then self:setAppFilter(k,v,true) --{appname={arg1=val1,...}}
      else error('invalid filters table: key "'..k..'" needs a table value, got '..type(v)..' instead',2) end
    else error('invalid filters table: keys can be integer or string, got '..type(k)..' instead',2) end
  end
  checkTrackSpacesFilters(self) checkScreensFilters(self) checkActiveApplicationFilters(self)
  if activeInstances[self] or spacesInstances[self] then return refreshWindows(self) end
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
function WF:getFilters()
  local r={}
  for appname,flt in pairs(self.filters) do
    if type(flt)~='table' then r[appname]=flt
    else r[appname]={}
      for k,v in pairs(flt) do
        if k:sub(1,1)~='_' then r[appname][k]=v end
      end
    end
  end
  return r
end

--TODO windowstarted/stoppedmoving event? (needs eventtap on mouse and keyboard mods, and hooking up with animations in hs.window,
-- and even then not fully reliable)

local getmetatable,tostring,gsub=getmetatable,tostring,string.gsub
local function __tostring(self) return sformat('hs.window.filter: %s (%s)',self.logname or '...',self.__address) end
function windowfilter.iswf(t)
  local mt=getmetatable(t) return mt and mt.__index==WF or false
end
--- hs.window.filter.new(fn[,logname[,loglevel]]) -> hs.window.filter object
--- Constructor
--- Creates a new hs.window.filter instance
---
--- Parameters:
---  * fn
---    * if `nil`, returns a copy of the default windowfilter, including any customizations you might have applied to it
---      so far; you can then further restrict or expand it
---    * if `true`, returns an empty windowfilter that allows every window
---    * if `false`, returns a windowfilter with a default rule to reject every window
---    * if a string or table of strings, returns a windowfilter that only allows visible windows of the specified apps
---      as per `hs.application:name()`
---    * if a table, you can fully define a windowfilter without having to call any methods after construction; the
---      table must be structured as per `hs.window.filter:setFilters()`; if not specified in the table, the
---      default filter in the new windowfilter will reject all windows
---    * otherwise it must be a function that accepts an `hs.window` object and returns `true` if the window is allowed
---      or `false` otherwise; this way you can define a fully custom windowfilter
---  * logname - (optional) name of the `hs.logger` instance for the new windowfilter; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new windowfilter
---
--- Returns:
---  * a new windowfilter instance
function windowfilter.new(fn,logname,loglevel,isCopy)
  local mt=getmetatable(fn) if mt and mt.__index==WF then return fn end -- no copy-on-new
  if fn==nil then
    log.i('copy default windowfilter')
    return windowfilter.copy(windowfilter.default,logname,loglevel)
  end
  local o={filters={},events={},windows={},pending={},
    log=logname and logger.new(logname,loglevel or log.level) or log,logname=logname,loglevel=loglevel or log.level}
  o.__address=gsub(tostring(o),'table: ','')
  setmetatable(o,{__index=WF,__tostring=__tostring,__gc=WF.delete})
  o.setLogLevel=o.log.setLogLevel o.getLogLevel=o.log.getLogLevel
  if type(fn)=='function' then
    o.log.i('new',o,'- custom function')
    o.isAppAllowed = function()return true end
    o.isWindowAllowed = function(_,w) return fn(w) end
    o.customFilter=true
    return o
  elseif type(fn)=='string' then fn={fn}
  end
  if type(fn)=='table' then
    o.log.i('new',o,'- reject all with exceptions')
    return o:setDefaultFilter(false):setFilters(fn)
  elseif fn==true then
    if isCopy then o.log.i('new',o,'- copy of',isCopy)
    else o.log.i('new',o,'- empty') end
    return o
  elseif fn==false then o.log.i('new',o,'- reject all') return o:setDefaultFilter(false)
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
---
--- Returns:
---  * An `hs.window.filter` object
function windowfilter.copy(wf,logname,loglevel)
  local mt=getmetatable(wf) if not mt or mt.__index~=WF then error('windowfilter must be an hs.window.filter object',2) end
  local self=windowfilter.new(true,logname,loglevel,wf)
  local lvl=self.getLogLevel() self.setLogLevel('warning') self:setFilters(wf:getFilters()) self.setLogLevel(lvl)
  return self
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
---    * to exclude fullscreen windows: `nofs_wf=hs.window.filter.new():setOverrideFilter{fullscreen=false}`
---    * to include invisible windows: `inv_wf=windowfilter.new():setDefaultFilter{}`
---  * If you still want to alter the default windowfilter:
---    * you should probably apply your customizations at the top of your `init.lua`, or at any rate before instantiating any other windowfilter; this
---      way copies created via `hs.window.filter.new(nil,...)` will inherit your modifications
---    * to list the known exclusions: `hs.inspect(hs.window.filter.default:getFilters())` from the console
---    * to add an exclusion: `hs.window.filter.default:rejectApp'Cool New Launcher'`
---    * to add an app-specific rule: `hs.window.filter.default:setAppFilter('My IDE',1)`; ignore tooltips/code completion (empty title) in My IDE
---    * to remove an exclusion (e.g. if you want to have access to Spotlight windows): `hs.window.filter.default:allowApp'Spotlight'`;
---      for specialized uses you can make a specific windowfilter with `myfilter=hs.window.filter.new'Spotlight'`

--- hs.window.filter.defaultCurrentSpace
--- Constant
--- A copy of the default windowfilter (see `hs.window.filter.default`) that only allows windows in the current
--- Mission Control Space
---
--- Notes:
---  * This windowfilter will inherit customizations to the default windowfilter if they're performed *before* referencing this

--- hs.window.filter.isGuiApp(appname) -> boolean
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
local nullEvent='null event'

local events={windowCreated=true, windowDestroyed=true, windowMoved=true,
  windowMinimized=true, windowUnminimized=true,
  windowHidden=true, windowUnhidden=true,
  windowVisible=true, windowNotVisible=true,
  windowInCurrentSpace=true,windowNotInCurrentSpace=true,
  windowOnScreen=true,windowNotOnScreen=true,
  windowFullscreened=true, windowUnfullscreened=true,
  --TODO perhaps windowMaximized? (compare win:frame to win:screen:frame) - or include it in windowFullscreened
  windowFocused=true, windowUnfocused=true,
  windowTitleChanged=true,

  windowAllowed=true,windowRejected=true,

  hasWindow=true,hasNoWindows=true,
  windowsChanged=true,
}

local trackSpacesEvents={
  windowInCurrentSpace=true,WindowNotInCurrentSpace=true,
  windowOnScreen=true,windowNotOnScreen=true,
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

--- hs.window.filter.windowFullscreened
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was expanded to fullscreen

--- hs.window.filter.windowUnfullscreened
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was reverted back from fullscreen

--- hs.window.filter.windowMinimized
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was minimized

--- hs.window.filter.windowUnminimized
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was unminimized

--- hs.window.filter.windowUnhidden
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was unhidden (its app was unhidden, e.g. via `cmd-h`)

--- hs.window.filter.windowHidden
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window was hidden (its app was hidden, e.g. via `cmd-h`)

--- hs.window.filter.windowVisible
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window became "visible" (in *any* Mission Control Space, as per `hs.window:isVisible()`)
--- after having been hidden or minimized, or if it was just created

--- hs.window.filter.windowNotVisible
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window is no longer "visible" (in *any* Mission Control Space, as per `hs.window:isVisible()`)
--- because it was minimized or closed, or its application was hidden (e.g. via `cmd-h`) or closed

--- hs.window.filter.windowInCurrentSpace
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window is now in the current Mission Control Space, due to
--- a Space switch or because it was hidden or minimized (hidden and minimized windows belong to all Spaces)

--- hs.window.filter.windowNotInCurrentSpace
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window that used to be in the current Mission Control Space isn't anymore,
--- due to a Space switch or because it was unhidden or unminimized onto another Space

--- hs.window.filter.windowOnScreen
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window became *actually* visible on screen (i.e. it's "visible" as per `hs.window:isVisible()`
--- *and* in the current Mission Control Space) after having been not visible, or when created

--- hs.window.filter.windowNotOnScreen
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window is no longer *actually* visible on any screen because it was minimized, closed,
--- its application was hidden (e.g. via cmd-h) or closed, or because it's not in the current Mission Control Space anymore

--- hs.window.filter.windowFocused
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window received focus

--- hs.window.filter.windowUnfocused
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window lost focus

--- hs.window.filter.windowTitleChanged
--- Constant
--- Event for `hs.window.filter:subscribe()`: a window's title changed

--- hs.window.filter.windowAllowed
--- Constant
--- Pseudo-event for `hs.window.filter:subscribe()`: a previously rejected window (or a newly created one) is now allowed
---
--- Notes:
---  * this pseudo-event will be emitted *before* the *actual* event(s) (e.g. `windowCreated`) that caused the window to be allowed

--- hs.window.filter.windowRejected
--- Constant
--- Pseudo-event for `hs.window.filter:subscribe()`: a previously allowed window (or a window that's been destroyed) is now rejected
---
--- Notes:
---  * this pseudo-event will be emitted *after* the *actual* event(s) (e.g. `windowDestroyed`) that caused the window to be rejected

--- hs.window.filter.hasWindow
--- Constant
--- Pseudo-event for `hs.window.filter:subscribe()`: the windowfilter now allows one window
---
--- Notes:
---  * callbacks for this event will receive (as the first argument) the window that is now allowed
---  * this pseudo-event won't trigger again until after the windowfilter reverts to rejecting all windows
---  * this pseudo-event will be emitted *after* the *actual* event(s) (e.g. `windowCreated`) that caused a window to be allowed

--- hs.window.filter.hasNoWindows
--- Constant
--- Pseudo-event for `hs.window.filter:subscribe()`: the windowfilter now rejects all windows
---
--- Notes:
---  * callbacks for this event will receive (as the first argument) the last window that was allowed (and is now rejected)
---  * this pseudo-event won't trigger again until after the windowfilter allows at least one window
---  * this pseudo-event will be emitted *after* the *actual* event(s) (e.g. `windowDestroyed`) that caused the window to be rejected

--- hs.window.filter.windowsChanged
--- Constant
--- Pseudo-event for `hs.window.filter:subscribe()`: the list of allowed windows (as per `windowfilter:getWindows()`) has changed
---
--- Notes:
---  * callbacks for this event will receive (as the first argument) either a random window among the currently allowed ones,
---    or nil if the windowfilter is rejecting all windows
---  * similarly, the second argument passed to callbacks (window's app name) will be nil if the windowfilter is rejecting all windows
---  * this pseudo-event will be emitted *after* the *actual* event(s) that caused the list of allowed windows to change

-- Window class

function Window:setFilter(wf,forceremove) -- returns true if filtering status changes
  local wasAllowed,isAllowed = wf.windows[self]
  if not forceremove then
    if wf.customFilter then isAllowed = wf:isWindowAllowed(self.window) or nil
    else isAllowed = isWindowAllowed(wf,self) or nil end
  end
  wf.windows[self] = isAllowed
  return wasAllowed ~= isAllowed
end

local function emit(win,wf,event,logged)
  local fns=wf.events[event]
  if fns then
    if not logged then wf.log.df('emitting %s %d (%s)',event,win.id,win.app.name) if wf.log==log then logged=true end end
    for fn in pairs(fns) do fn(win.window,win.app.name,event) end
  end
  return logged
end
local noWindow={app={}} -- emit nil,nil to windowsChanged if no allowed windows
function Window:filterEmitEvent(wf,event,_,logged,notified)
  local filteringStatusChanged=self:setFilter(wf,event==windowfilter.windowDestroyed)
  local isAllowed=wf.windows[self]
  if filteringStatusChanged then
    if isAllowed then
      emit(self,wf,windowfilter.windowAllowed) -- emit pseudo-event allowed
    else
      wf.pending[self]=true -- wait for endchain
    end
    --[[
    if wf.notifyfn then -- call notifyfn if present
      if not notified then wf.log.d('Notifying windows changed') if wf.log==log then notified=true end end
      wf.notifyfn(wf:getWindows(),event)
    end
    --]]
    -- if this is an 'inserted' event, keep around the window until all the events are exhausted
    --    if inserted and not isAllowed then wf.pending[self]=true end
  end
  --  wf.log.f('EVENT %s inserted %s statusChanged %s isallowed %s ispending %s',event,inserted,filteringStatusChanged,wf.windows[self],wf.pending[self])
  if isAllowed or wf.pending[self] then
    -- window is currently allowed, call subscribers if any
    logged=emit(self,wf,event,logged)
    --    if not inserted then  -- clear the window if this is the last event in the chain
    --      if wf.pending[self] then emit(self,wf,windowfilter.windowRejected) end
    --      wf.pending[self]=nil
    --    end
  end
  if filteringStatusChanged and isAllowed and not wf.hasWindow then
    wf.hasWindow=true
    emit(self,wf,windowfilter.hasWindow) -- emit pseudo-event
  end
  if filteringStatusChanged then
    -- emit windowsChanged on a random allowed window
    emit(next(wf.windows) or noWindow,wf,windowfilter.windowsChanged,true)
  end
  return logged,notified
end

function Window:emitEndChain()
  for wf in pairs(activeInstances) do
    if wf.pending[self] then
      emit(self,wf,windowfilter.windowRejected)
      if wf.hasWindow then
        emit(self,wf,windowfilter.hasNoWindows) -- emit pseudo-event
        wf.hasWindow=nil
      end
      wf.pending[self]=nil
    end
  end
end

function Window:emitEvent(event,inserted)
  log.vf('%s (%s) => %s%s',self.app.name,self.id,event,inserted and ' (inserted)' or '')
  local logged, notified
  for wf in pairs(activeInstances) do
    logged,notified = self:filterEmitEvent(wf,event,inserted,logged,notified)
  end
end


function Window.new(win,id,app,watcher)
  --FIXED hackity hack below; if it survives extensive testing (all windows ever returned by a wf will have it),
  -- the id "caching" should be moved to the hs.window userdata itself
  --  local w = setmetatable({id=function()return id end},{__index=function(_,k)return function(self,...)return win[k](win,...)end end})
  -- hackity hack removed, turns out it was just for :snapshot (see gh#413)
  local o = setmetatable({app=app,window=win,id=id,watcher=watcher,frame=win:frame(),screen=win:screen():id(),
    isMinimized=win:isMinimized(),isVisible=win:isVisible(),isFullscreen=win:isFullScreen(),hasTitlebar=(nil~=win:zoomButtonRect()),
    role=win:subrole(),title=win:title()}
  ,{__index=Window})
  o.isHidden = not o.isVisible and not o.isMinimized
  --  hs.assert(o.isHidden==win:application():isHidden(),'isHidden',o)
  return o
end

function Window.created(win,id,app,watcher)
  local self=Window.new(win,id,app,watcher)
  self.timeFocused=preexistingWindowFocused[id] or 0
  self.timeCreated=preexistingWindowCreated[id] or timer.secondsSinceEpoch()
  preexistingWindowFocused[id]=nil preexistingWindowCreated[id]=nil
  app.windows[id]=self
  self:emitEvent(windowfilter.windowCreated)
  if self.isVisible then
    self:emitEvent(windowfilter.windowVisible,true)
    if next(spacesInstances) then app:getCurrentSpaceAppWindows(true) end
    --FIXME inefficient, all app windows cycled every time
  else
    if self.isMinimized then self:emitEvent(windowfilter.windowMinimized,true) end
    if self.isHidden then self:emitEvent(windowfilter.windowHidden,true) end
    self:emitEvent(windowfilter.windowInCurrentSpace,true)
  end
  self:emitEndChain()
end

function Window:unhidden()
  if not self.isHidden then return log.vf('%s (%d) already unhidden',self.app.name,self.id) end
  self.isHidden=false
  self:emitEvent(windowfilter.windowUnhidden)
  if not self.isMinimzed then self:visible(true) end
  self:emitEndChain()
end

function Window:unminimized()
  if not self.isMinimized then return log.vf('%s (%d) already unminimized',self.app.name,self.id) end
  self.isMinimized=false
  self:emitEvent(windowfilter.windowUnminimized)
  if not self.isHidden then self:visible(true) end
  self:emitEndChain()
end

function Window:visible(inserted)
  if self.isVisible then return log.vf('%s (%d) already visible',self.app.name,self.id) end
  self.role=self.window:subrole()
  self.isVisible=true
  self:emitEvent(windowfilter.windowVisible,inserted)
  if next(spacesInstances) then self.app:getCurrentSpaceAppWindows(true) end
  if self.inCurrentSpace then self:onScreen(true) end
  if not inserted then self:emitEndChain() end
end

function Window:inCurrentSpace(inserted)
  if self.isInCurrentSpace then return log.vf('%s (%d) already in current space',self.app.name,self.id) end
  self.isInCurrentSpace=true
  self:emitEvent(windowfilter.windowInCurrentSpace,inserted)
  if self.isVisible then self:onScreen(true) end
  if not inserted then self:emitEndChain() end
end

function Window:onScreen(inserted)
  if self.isOnScreen then return log.vf('%s (%d) already on screen',self.app.name,self.id) end
  self.isOnScreen=true
  self:emitEvent(windowfilter.windowOnScreen,inserted)
  if not inserted then self:emitEndChain() end
end

function Window:focused(inserted)
  if global.focused==self then return log.vf('%s (%d) already focused',self.app.name,self.id) end
  global.focused=self
  self.app.focused=self
  self.timeFocused=timer.secondsSinceEpoch()
  self:emitEvent(windowfilter.windowFocused,inserted) --TODO check this
  if not inserted then self:emitEndChain() end
end

function Window:unfocused(inserted)
  if global.focused~=self then return log.vf('%s (%d) already unfocused',self.app.name,self.id) end
  global.focused=nil
  self.app.focused=nil
  self:emitEvent(windowfilter.windowUnfocused,inserted)
  if not inserted then self:emitEndChain() end
end

function Window:notOnScreen(inserted)
  if not self.isOnScreen then return log.vf('%s (%d) already not on screen',self.app.name,self.id) end
  self.isOnScreen=false
  self:emitEvent(windowfilter.windowNotOnScreen,inserted)
  if not inserted then self:emitEndChain() end
end

function Window:notInCurrentSpace(inserted)
  if not self.isInCurrentSpace then return log.vf('%s (%d) already not in current space',self.app.name,self.id) end
  self:notOnScreen(true)
  self.isInCurrentSpace=false
  self:emitEvent(windowfilter.windowNotInCurrentSpace,inserted)
  if not inserted then self:emitEndChain() end
end

function Window:notVisible(inserted,skipSpace)
  if not self.isVisible then return log.vf('%s (%d) already not visible',self.app.name,self.id) end
  if global.focused==self then self:unfocused(true) end
  self.role=self.window:subrole()
  self.isVisible=false
  self:notOnScreen(true)
  if not skipSpace then self:inCurrentSpace(true) end
  self:emitEvent(windowfilter.windowNotVisible,inserted)
  if not inserted then self:emitEndChain() end
end

function Window:minimized()
  if self.isMinimized then return log.vf('%s (%d) already minimized',self.app.name,self.id) end
  self:notVisible(true)
  self.isMinimized=true
  self:emitEvent(windowfilter.windowMinimized)
  self:emitEndChain()
end

function Window:hidden()
  if self.isHidden then return log.vf('%s (%d) already hidden',self.app.name,self.id) end
  self:notVisible(true)
  self.isHidden=true
  self:emitEvent(windowfilter.windowHidden)
  self:emitEndChain()
end


local WINDOWMOVED_DELAY=0.5
function Window:moved()
  if self.movedDelayed then self.movedDelayed:setNextTrigger(WINDOWMOVED_DELAY)
  else self.movedDelayed=timer.doAfter(WINDOWMOVED_DELAY,function()self:doMoved()end) end
end
function Window:doMoved()
  self.frame=self.window:frame() self.screen=self.window:screen():id()
  self.movedDelayed=nil
  local fs = self.window:isFullScreen()
  --local oldfs = self.isFullscreen or false
  if self.isFullscreen~=fs then
    self.isFullscreen=fs
    self:emitEvent(fs and windowfilter.windowFullscreened or windowfilter.windowUnfullscreened,true)
  end
  self:emitEvent(windowfilter.windowMoved)
  self:emitEndChain()
end

local TITLECHANGED_DELAY=0.5
function Window:titleChanged()
  if self.titleDelayed then self.titleDelayed:setNextTrigger(TITLECHANGED_DELAY)
  else self.titleDelayed=timer.doAfter(TITLECHANGED_DELAY,function()self:doTitleChanged()end) end
end
function Window:doTitleChanged()
  self.title=self.window:title()
  self.titleDelayed=nil
  self:emitEvent(windowfilter.windowTitleChanged)
  self:emitEndChain()
end

function Window:destroyed()
  if self.movedDelayed then self.movedDelayed:stop() self.movedDelayed=nil end
  if self.titleDelayed then self.titleDelayed:stop() self.titleDelayed=nil end
  self.watcher:stop()
  self.app.windows[self.id]=nil
  if self.isVisible then self:notVisible(true,true) end
  if next(spacesInstances) then self:notInCurrentSpace(true) end
  self:emitEvent(windowfilter.windowDestroyed)
  self:emitEndChain()
  self.window=nil
end


local appWindowEvent
-- App class

function App:getFocused()
  if self.focused then return end
  local fw=self.app:focusedWindow()
  local fwid=fw and fw.id and fw:id()
  if not fwid then
    fw=self.app:mainWindow() or self.app:allWindows()[1]
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
  log.f('new app %s registered',appname)
  apps[appname] = o
  o:getAppWindows()
end

-- events aren't "inserted" across apps (param name notwithsanding) so an active app should NOT :deactivate
-- another app, otherwise the latter's :unfocused will have a broken "inserted" chain with nothing to close it
function App:getAppWindows()
  self:getCurrentSpaceAppWindows()
  self:getFocused()
  if self.app:isFrontmost() then
    log.df('app %s is the frontmost app',self.name)
    if global.active then global.active:deactivated() end --see comment above
    global.active = self
    if self.focused then
      self.focused:focused(true)
      log.df('window %d is the focused window',self.focused.id)
    end
  end
end

function App:getCurrentSpaceAppWindows(inserted)
  local gone={}
  if next(spacesInstances) then
    for _,win in pairs(self.windows) do
      if win.isVisible and win.isInCurrentSpace then
        gone[win.id]=win
      end
    end
  end
  local allWindows=self.app:allWindows()
  --[[ no need, desktop is filtered in hs.window now
  if self.name=='Finder' then --filter out the desktop here
    for i=#allWindows,1,-1 do if allWindows[i]:role()~='AXWindow' then tremove(allWindows,i) break end end
  end
  --]]
  if #allWindows>0 then log.df('found %d windows for app %s',#allWindows,self.name) end
  local arrived={}
  for _,win in ipairs(allWindows) do
    local id=win:id()
    if id then
      if not self.windows[id] then appWindowEvent(win,uiwatcher.windowCreated,nil,self.name) end
      gone[id]=nil
      arrived[id]=self.windows[id]
    end
  end
  for _,win in pairs(gone) do win:notInCurrentSpace(inserted) end
  for _,win in pairs(arrived) do win:inCurrentSpace(inserted) end
end

function App:activated()
  local prevactive=global.active
  if self==prevactive then return log.df('app %s already active; skipping',self.name) end
  if prevactive then prevactive:deactivated() end --see comment above
  log.vf('app %s activated',self.name)
  global.active=self
  for wf in pairs(applicationActiveInstances) do
    for _,win in pairs(self.windows) do
      win:filterEmitEvent(wf,nullEvent) -- force allowing all app's windows if filter's activeApplication=true
    end
  end
  self:getFocused()
  if not self.focused then return log.df('app %s does not (yet) have a focused window',self.name) end
  self.focused:focused()
end
function App:deactivated(inserted) --as per comment above, only THIS app should call :deactivated(true)
  if self~=global.active then return end
  if global.focused~=self.focused then log.e('focused app/window inconsistency') end
  if self.focused then self.focused:unfocused(inserted) end
  log.vf('app %s deactivated',self.name)
  global.active=nil
  for wf in pairs(applicationActiveInstances) do
    for _,win in pairs(self.windows) do
      win:filterEmitEvent(wf,nullEvent) -- force rejecting all app's windows if filter's activeApplication=true
      win:emitEndChain()
    end
  end
end
function App:focusChanged(id,win)
  if self.focused and self.focused.id==id then return log.df('%s (%d) already focused, skipping',self.name,id) end
  local active=global.active
  log.vf('app %s focus changed',self.name)
  --  if self==active then self:deactivated(--[[true--]]nil,true) end
  if not id then
    if self.name~='Finder' then log.wf('cannot process focus changed for app %s - %s has no window id',self.name,win:role()) end
    if self==active and self.focused then self.focused:unfocused() end
    self.focused=nil
  else
    if not self.windows[id] then
      log.df('%s (%d) is not registered yet',self.name,id)
      appWindowEvent(win,uiwatcher.windowCreated,nil,self.name)
    end
    if self==active then
      if not self.windows[id] then log.wf('cannot process focus changed for app %s - %s (%d) not registered',self.name,win:role(),id)
      else self.windows[id]:focused() end
    end
    self.focused = self.windows[id]
  end
  --  if self==active then self:activated(true) end
end
function App:hidden()
  if self.isHidden then return log.df('app %s already hidden, skipping',self.name) end
  --  self:deactivated(true)
  for _,win in pairs(self.windows) do
    win:hidden()
  end
  log.vf('app %s hidden',self.name)
  self.isHidden=true
end
function App:unhidden()
  if not self.isHidden then return log.df('app %s already unhidden, skipping',self.name) end
  for _,win in pairs(self.windows) do
    win:unhidden()
  end
  log.vf('app %s unhidden',self.name)
  self.isHidden=false
  if next(spacesInstances) then self:getCurrentSpaceAppWindows(true) end
end
function App:destroyed()
  log.f('app %s deregistered',self.name)
  self.watcher:stop()
  for _,win in pairs(self.windows) do
    win:destroyed()
  end
  apps[self.name]=nil
end

local function windowEvent(event,appname,id)
  local app=apps[appname]
  log.vf('%s (%s) <= %s (window event)',appname,id or '?',event)
  if not id then return log.df('%s: %s cannot be processed',appname,event) end
  if not app then return log.df('app %s is not registered!',appname) end
  local w = app.windows[id]
  if not w then return log.df('%s (&d) is not registered!',appname,id) end
  if event==uiwatcher.elementDestroyed then
    w:destroyed()
  elseif event==uiwatcher.windowMoved or event==uiwatcher.windowResized then
    w:moved()
  elseif event==uiwatcher.windowMinimized then
    w:minimized()
  elseif event==uiwatcher.windowUnminimized then
    w:unminimized()
  elseif event==uiwatcher.titleChanged then
    w:titleChanged()
  end
end


local RETRY_DELAY,MAX_RETRIES = 0.2,5
local windowWatcherDelayed={}

appWindowEvent=function(win,event,_,appname,retry)
  if not win:isWindow() then return end
  local role=win.subrole and win:subrole()
  if appname=='Hammerspoon' and (not role or role=='AXUnknown') then return end
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
    local watcher=win:newWatcher(function(_,watcherEvent)
      windowEvent(watcherEvent,appname,id)
    end, appname)
-- pretty sure this is a NOP now since pid capture is no longer delayed
--     if not watcher:pid() then
--       log.wf('%s: %s has no watcher pid',appname,role or (win.role and win:role()))
--       if retry>MAX_RETRIES then log.df('%s: %s has no watcher pid',appname,win.subrole and win:subrole() or (win.role and win:role()) or 'window')
--       else
--         windowWatcherDelayed[win]=timer.doAfter(retry*RETRY_DELAY,function()appWindowEvent(win,event,_,appname,retry)end) end
--       return
--     end
    Window.created(win,id,apps[appname],watcher)
    watcher:start({uiwatcher.elementDestroyed,uiwatcher.windowMoved,uiwatcher.windowResized
      ,uiwatcher.windowMinimized,uiwatcher.windowUnminimized,uiwatcher.titleChanged})
  elseif event==uiwatcher.focusedWindowChanged then
    local app=apps[appname]
    if not app then return log.df('app %s is not registered!',appname) end
    app:focusChanged(id,win)
  end
end

local function startAppWatcher(app,appname,retry,nologging,force)
  if not app or not appname then log.e('called startAppWatcher with no app') return end
  if apps[appname] then return not nologging and log.df('app %s already registered',appname) end
  if app:kind()<0 or not windowfilter.isGuiApp(appname) then log.df('app %s has no GUI',appname) return end
  if not fnutils.contains(axuielement.applicationElement(app):attributeNames() or {}, "AXFocusedWindow") then
      log.df('app %s has no AXFocusedWindow element',appname)
      return
  end
  retry=(retry or 0)+1

  if app:focusedWindow() or force then
    pendingApps[appname]=nil --done
    local watcher = app:newWatcher(appWindowEvent,appname)
    watcher:start({uiwatcher.windowCreated,uiwatcher.focusedWindowChanged})
    App.new(app,appname,watcher)
  else
    -- apps that start with an open window will often fail to be detected by the watcher if we
    -- start it too early, so we try `app:focusedWindow()` MAX_RETRIES times before giving up
    pendingApps[appname] = timer.doAfter(retry*RETRY_DELAY,function()
        startAppWatcher(app,appname,retry,nologging, retry > MAX_RETRIES)
    end)
  end
end


local function appEvent(appname,event,app)
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
  if not appo then return log.df('app %s is not registered!',appname) end
  if event==appwatcher.terminated then return appo:destroyed()
  elseif event==appwatcher.deactivated then return appo:deactivated()
  elseif event==appwatcher.hidden then return appo:hidden()
  elseif event==appwatcher.unhidden then return appo:unhidden() end
end

local function getCurrentSpaceWindows()
  for _,app in pairs(apps) do
    app:getCurrentSpaceAppWindows()
  end
end


local spacesDone = {}
--- hs.window.filter.switchedToSpace(space)
--- Function
--- Callback to inform all windowfilters that the user initiated a switch to a (numbered) Mission Control Space.
---
--- Parameters:
---  * space - the Space number the user is switching to
---
--- Returns:
--- * None
---
--- Notes:
---  * Only use this function if "Displays have separate Spaces" and "Automatically rearrange Spaces" are OFF in System Preferences>Mission Control
---  * Calling this function will set `hs.window.filter.forceRefreshOnSpaceChange` to `false`
---  * If you defined one or more Spaces-aware windowfilters (i.e. when the `currentSpace` field of a filter is present), windows need refreshing at every space change anyway, so using this callback will not result in improved performance
---  * See `hs.window.filter.forceRefreshOnSpaceChange` for an overview of Spaces limitations in Hammerspoon. If you often (or always) change Space via the "numbered" Mission Control keyboard shortcuts (by default, `ctrl-1` etc.), you can call this function from your `init.lua` when intercepting these shortcuts; for example:
---  ```
---  hs.hotkey.bind('ctrl','1',nil,function()hs.window.filter.switchedToSpace(1)end)
---  hs.hotkey.bind('ctrl','2',nil,function()hs.window.filter.switchedToSpace(2)end)
---  -- etc.
---  ```
--- * Using this callback results in slightly better performance than setting `forceRefreshOnSpaceChange` to `true`, since already visited Spaces are remembered and no refreshing is necessary when switching back to those.

local pendingSpace
local function spaceChanged()
  if not pendingSpace then return end
  if not spacesDone[pendingSpace] or next(spacesInstances) or (windowfilter.forceRefreshOnSpaceChange and next(activeInstances)) then
    log.d('space changed, refreshing all windows')
    getCurrentSpaceWindows()
    if pendingSpace~=-1 then spacesDone[pendingSpace] = true end
  end
  pendingSpace=nil
end
local spaceDelayed=timer.new(DISTANT_FUTURE,spaceChanged):start()
function windowfilter.switchedToSpace(space)
  windowfilter.forceRefreshOnSpaceChange = nil
  pendingSpace=space
  spaceDelayed:setNextTrigger(0.5)
end

--- hs.window.filter.forceRefreshOnSpaceChange
--- Variable
--- Tells all windowfilters whether to refresh all windows when the user switches to a different Mission Control Space.
---
--- Due to OS X limitations Hammerspoon cannot directly query for windows in Spaces other than the current one;
--- therefore when a windowfilter is initially instantiated, it doesn't know about many of these windows.
---
--- If this variable is set to `true`, windowfilters will re-query applications for all their windows whenever a Space change
--- by the user is detected, therefore any existing windows in that Space that were not yet being tracked will become known at that point;
--- if `false` (the default) this won't happen, but the windowfilters will *eventually* learn about these windows
--- anyway, as soon as they're interacted with.
---
--- If you need your windowfilters to become aware of windows across all Spaces as soon as possible, you can set this to `true`,
--- but you'll incur a modest performance penalty on every Space change. If possible, use the `hs.window.filter.switchedToSpace()`
--- callback instead.
---
--- Notes:
---  * If you defined one or more Spaces-aware windowfilters (i.e. when the `currentSpace` field of a filter is present), windows need refreshing at every space change anyway, so this variable is ignored
windowfilter.forceRefreshOnSpaceChange = false

local spacesWatcher = require'hs.spaces'.watcher.new(function()pendingSpace=pendingSpace or -1 spaceChanged()end)
spacesWatcher:start()

local function startGlobalWatcher()
  if global.watcher then return end
  local ids,time=window._orderedwinids(),timer.secondsSinceEpoch()
  preexistingWindowFocused,preexistingWindowCreated={},{}
  for i,id in ipairs(ids) do
    preexistingWindowFocused[id]=time-i
    preexistingWindowCreated[id]=time+id-999999
  end
  global.watcher = appwatcher.new(appEvent)
  global.inStartGlobalWatcher = true
  local runningApps = application.runningApplications()
  log.f('registering %d running apps',#runningApps)
  for _,app in ipairs(runningApps) do
    startAppWatcher(app,app:name())
  end
  global.watcher:start()
  global.inStartGlobalWatcher = nil

end

local function stopGlobalWatcher()
  if not global.watcher then return end
  if next(activeInstances) or next(spacesInstances) then return end

  local totalApps = 0
  for _,app in pairs(apps) do
    for _,w in pairs(app.windows) do
      w.watcher:stop()
    end
    app.watcher:stop()
    totalApps=totalApps+1
  end
  global.watcher:stop()
  apps,global={},{}
  log.f('unregistered %d apps',totalApps)
end

local screenCache,screenWatcher={}
--local allowScreenSetFilters,rejectScreenSetFilters={},{}
local function getCachedScreenID(scrhint)
  if not screenCache[scrhint] then
    local s=screen.find(scrhint)
    local sid=s and s:id() or -1
    if sid==-1 then log.df('screen not found for hint %s',scrhint)
    else log.vf('screen id for hint %s: %d',scrhint,sid) end
    screenCache[scrhint]=sid
  end
  return screenCache[scrhint]
end
local function applyScreenFilters(self)
  self.log.d('finding screens for screen-aware filters')
  for _,flt in pairs(self.filters) do
    if type(flt)=='table' then
      if flt.allowScreens then
        flt._allowedScreens={}
        for _,scrhint in ipairs(flt.allowScreens) do flt._allowedScreens[getCachedScreenID(scrhint)]=true end
      end
      if flt.rejectScreens then
        flt._rejectedScreens={}
        for _,scrhint in ipairs(flt.rejectScreens) do flt._rejectedScreens[getCachedScreenID(scrhint)]=true end
      end
    end
  end
  refreshWindows(self)
end

local function screensChanged()
  screenCache={}
  log.i('screens changed, refreshing screens-aware windowfilters')
  for wf in pairs(screensInstances) do applyScreenFilters(wf) end
end

local function startScreenWatcher()
  if screenWatcher then return end
  screenWatcher=screen.watcher.new(screensChanged):start()
  log.i('screen watcher started')
  screensChanged()
end

local function stopScreenWatcher()
  if not screenWatcher then return end
  if next(screensInstances) then return end
  screenWatcher:stop() screenWatcher=nil
  log.i('screen watcher stopped')
end

checkScreensFilters=function(self)
  local prev,now=self.screensFilters
  for _,flt in pairs(self.filters) do if type(flt)=='table' and (flt.allowScreens or flt.rejectScreens) then now=true break end end
  if prev~=now then
    self.log.df('%s screens-aware filters',now and 'added' or 'no more')
    self.screensFilters=now
    screensInstances[self]=now
    if now then if not screenWatcher then startScreenWatcher() else applyScreenFilters(self) end
    else stopScreenWatcher() end
  end
end

checkTrackSpacesFilters=function(self)
  local prev,now=self.trackSpacesFilters
  for _,flt in pairs(self.filters) do if type(flt)=='table' and flt.currentSpace~=nil then now=true break end end
  if prev~=now then
    self.log.df('%s Spaces-aware filters',now and 'added' or 'no more')
    self.trackSpacesFilters=now
    spacesInstances[self]=(now or self.trackSpacesSubscriptions) and true or nil
    if now then startGlobalWatcher() else stopGlobalWatcher() end
  end
end

checkActiveApplicationFilters=function(self)
  local prev,now=self.activeApplicationFilters
  for _,flt in pairs(self.filters) do if type(flt)=='table' and flt.activeApplication~=nil then now=true break end end
  if prev~=now then
    self.log.df('%s active application-aware filters',now and 'added' or 'no more')
    self.activeApplicationFilters=now
    applicationInstances[self]=now
  end
end

local function checkTrackSpacesSubscriptions(self)
  local prev,now=self.trackSpacesSubscriptions
  for ev in pairs(trackSpacesEvents) do if self.events[ev] then now=true break end end
  if prev~=now then
    self.log.df('%s Spaces-aware subscriptions',now and 'added' or 'no more')
    self.trackSpacesSubscriptions=now
    spacesInstances[self]=(now or self.trackSpacesFilters) and true or nil
    if now then startGlobalWatcher() else stopGlobalWatcher() end
  end
end

local function subscribe(self,map)
  --  hs.assert(next(map),'empty map')
  for event,fns in pairs(map) do
    if not events[event] then error('invalid event: '..event,3) end
    if type(fns)~='table' then error('fn must be a function or table of functions',3) end
    for _,fn in pairs(fns) do
      if type(fn)~='function' then error('fn must be a function or table of functions',3) end
      if not self.events[event] then self.events[event]={} end
      if not self.events[event][fn] then
        self.events[event][fn]=true
        self.log.df('added callback for event %s',event)
      end
    end
  end
end

local function unsubscribe(self,event,fn)
  if self.events[event] and self.events[event][fn] then
    self.log.df('removed callback for event %s',event)
    self.events[event][fn]=nil
    if not next(self.events[event]) then
      self.log.df('no more callbacks for event %s',event)
      self.events[event]=nil
    end
  end
end

local function unsubscribeEvent(self,event)
  if not events[event] then error('invalid event: '..event,3) end
  if self.events[event] then self.log.df('removed all callbacks for event %s',event) end
  self.events[event]=nil
end


refreshWindows=function(wf)
  -- whenever a wf is edited, refresh the windows to reflect the new filter
  wf.log.v('refreshing windows')
  for _,app in pairs(apps) do
    for _,w in pairs(app.windows) do
      w:setFilter(wf)
    end
  end
  return wf
end

local function start(wf)
  if activeInstances[wf]==true then return wf end
  wf.windows={}
  startGlobalWatcher()
  wf.log.i('windowfilter instance started (active mode)')
  activeInstances[wf]=true
  if applicationInstances[wf] then applicationActiveInstances[wf]=true end
  return refreshWindows(wf)
end

-- keeps the wf in active mode even without subscriptions; used internally by other modules that rely on :getWindows
-- but do not necessarily :subscribe
-- (not documented as the passive vs active distinction should be abstracted away in the user api)
-- more detail: i noticed that even having to call startGlobalWatcher->getWindows->stopGlobalWatcher is
-- *way* faster than hs.window.allWindows(); even so, better to have a way to avoid the overhead if we know
-- we'll call :getWindows often enough
function WF:keepActive()
  if self.doKeepActive then return self end
  self.doKeepActive=true
  self.log.i('keep instance active')
  return start(self)
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

--- hs.window.filter.sortByFocusedLast
--- Constant
--- Sort order for `hs.window.filter:getWindows()`: windows are sorted in order of focus received, most recently first (see also `hs.window.filter:setSortOrder()`)
---
--- Notes:
---   * This is the default sort order for all windowfilters

--- hs.window.filter.sortByFocused
--- Constant
--- Sort order for `hs.window.filter:getWindows()`: windows are sorted in order of focus received, least recently first (see also `hs.window.filter:setSortOrder()`)

--- hs.window.filter.sortByCreatedLast
--- Constant
--- Sort order for `hs.window.filter:getWindows()`: windows are sorted in order of creation, newest first (see also `hs.window.filter:setSortOrder()`)

--- hs.window.filter.sortByCreated
--- Constant
--- Sort order for `hs.window.filter:getWindows()`: windows are sorted in order of creation, oldest first (see also `hs.window.filter:setSortOrder()`)

local sortingComparators={
  focusedLast = function(a,b) return a.timeFocused>b.timeFocused end,
  focused = function(a,b) return a.timeFocused<b.timeFocused end,
  createdLast = function(a,b) return a.timeCreated>b.timeCreated end,
  created = function(a,b) return a.timeCreated<b.timeCreated end,
}
for k in pairs(sortingComparators) do
  windowfilter['sortBy'..ssub(k,1,1):upper()..ssub(k,2)]=k
end

--- hs.window.filter:setSortOrder(sortOrder) -> hs.window.filter object
--- Method
--- Sets the sort order for this windowfilter's `:getWindows()` method
---
--- Parameters:
---  * sortOrder - one of the `hs.window.filter.sortBy...` constants
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---   * The default sort order for all windowfilters (that is, until changed by this method) is `hs.window.filter.sortByFocusedLast`
function WF:setSortOrder(sortOrder)
  if type(sortOrder)~='string' or not sortingComparators[sortOrder] then
    error('sortOrder must be a valid hs.window.filter.sortBy... constant',2) end
  self.log.i('sort order set to '..sortOrder)
  self.sortOrder=sortOrder
  return self
end

local function getWindowObjects(wf,sortOrder)
  local r={}
  local recheckAppName
  for w in pairs(wf.windows) do
    -- filter out any apps that mysteriously vanish
    if not w.app.app:isRunning() then log.wf('app %s disappeared!',w.app.name) w.app:destroyed() recheckAppName=w.app.name
    else r[#r+1]=w end
  end
  if recheckAppName then
    local app=application.get(recheckAppName)
    if app then
      startAppWatcher(app,recheckAppName,0,true)
      r={} -- get windows again, after "starting" "new" app
      for w in pairs(wf.windows) do r[#r+1]=w end
    end
  end
  tsort(r,sortingComparators[sortOrder] or sortingComparators[wf.sortOrder] or sortingComparators.focusedLast)
  return r
end

--- hs.window.filter:getWindows([sortOrder]) -> list of hs.window objects
--- Method
--- Gets the current windows allowed by this windowfilter
---
--- Parameters:
---  * sortOrder - (optional) one of the `hs.window.filter.sortBy...` constants to determine the sort order
---    of the returned list; if omitted, uses the windowfilter's sort order as per `hs.window.filter:setSortOrder()`
---   (defaults to `sortByFocusedLast`)
---
--- Returns:
---  * a list of `hs.window` objects

--TODO allow to pass in a list of candidate windows?
function WF:getWindows(sortOrder)
  local wasActive=activeInstances[self] start(self)
  local r,wins={},getWindowObjects(self,sortOrder)
  for i,w in ipairs(wins) do r[i]=w.window end
  if not wasActive then self:pause() end
  return r
end

--[[
-- hs.window.filter:notify(fn[, fnEmpty][, immediate]) -> hs.window.filter object
-- Method
-- Notify a callback whenever the list of allowed windows change
--
-- Parameters:
--  * fn - a callback function that will be called when:
--    * an allowed window is created or destroyed, and therefore added or removed from the list of allowed windows
--    * a previously allowed window is now filtered or vice versa (e.g. in consequence of a title or position change)
--    It will be passed 2 parameters:
--    * a list of the `hs.window` objects currently (i.e. *after* the change took place) allowed by this
--      windowfilter as per `hs.window.filter:getWindows()` (sorted according to `hs.window.filter:setSortOrder()`)
--    * a string containing the (first) event that caused the change (see the `hs.window.filter.window...` event constants)
--  * fnEmpty - (optional) if provided, when this windowfilter becomes empty (i.e. `:getWindows()` returns
--    an empty list) call this function (with no arguments) instead of `fn`, otherwise, always call `fn`
--  * immediate - (optional) if `true`, also call `fn` (or `fnEmpty`) immediately
--
-- Returns:
--  * the `hs.window.filter` object for method chaining
--
-- Notes:
--  * If `fn` is nil, notifications for this windowfilter will stop.
function WF:notify(fn,fnEmpty,immediate)
  if fn~=nil and type(fn)~='function' then error('fn must be a function or nil',2) end
  if fnEmpty and type(fnEmpty)~='function' then fnEmpty=nil immediate=true end
  if fnEmpty~=nil and type(fnEmpty)~='function' then error('fnEmpty must be a function or nil',2) end
  self.notifyfn = fnEmpty and function(wins)if #wins>0 then return fn(wins) else return fnEmpty()end end or fn
  if fn then start(self) elseif not next(self.events) then self:pause() end
  if fn and immediate then self.notifyfn(self:getWindows()) end
  return self
end
--]]

--- hs.window.filter:subscribe(event, fn[, immediate]) -> hs.window.filter object
--- Method
--- Subscribe to one or more events on the allowed windows
---
--- Parameters:
---  * event - string or list of strings, the event(s) to subscribe to (see the `hs.window.filter` constants); alternatively, this can be a map `{event1=fn1,event2=fn2,...}`: fnN will be subscribed to eventN, and the parameter `fn` will be ignored
---  * fn - function or list of functions, the callback(s) to add for the event(s); each will be passed 3 parameters
---    * a `hs.window` object referring to the event's window
---    * a string containing the application name (`window:application():name()`) for convenience
---    * a string containing the event that caused the callback, i.e. (one of) the event(s) you subscribed to
---  * immediate - (optional) if `true`, also call all the callbacks immediately for windows that satisfy the event(s) criteria
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
---
--- Notes:
---  * Passing lists means that *all* the `fn`s will be called when *any* of the `event`s fires, so it's *not* a shortcut for subscribing distinct callbacks to distinct events; use a map or chained `:subscribe` calls for that.
---  * Use caution with `immediate`: if for example you're subscribing to `hs.window.filter.windowUnfocused`, `fn`(s) will be called for *all* the windows except the currently focused one.
---  * If the windowfilter was paused with `hs.window.filter:pause()`, calling this will resume it.
function WF:subscribe(event,fn,immediate)
  if type(event)=='string' then event={event} end
  if type(event)~='table' then error('event must be a string, a list of strings, or a map',2) end
  if type(fn)=='function' then fn={fn}
  elseif type(fn)=='boolean' then immediate=fn fn=nil end
  if fn and type(fn)~='table' then error('fn must be a function or list of functions',2) end
  local map,k,v={},next(event)
  if type(k)=='string' then
    if type(v)=='function' then for ev,f in pairs(event) do map[ev]={f} end
    elseif type(v)=='table' and type(v[1])=='function' then map=event
    else error('invalid map format, values must be functions or lists of functions',2) end
  else
    if not fn then error('missing parameter fn',2) end
    if #event==0 then error('missing event(s)',2) end
    for i=1,#event do local ev=event[i] if ev then map[ev]=fn else error('missing event(s)',2) end end
  end
  subscribe(self,map) start(self)
  if immediate then
    local windows = getWindowObjects(self)
    for ev,fns in pairs(map) do
      for _,win in ipairs(windows) do
        if ev==windowfilter.windowCreated
          or ev==windowfilter.windowAllowed
          or ev==windowfilter.windowMoved
          or ev==windowfilter.windowTitleChanged
          or (ev==windowfilter.windowFullscreened and win.isFullscreen)
          or (ev==windowfilter.windowUnfullscreened and not win.isFullscreen)
          or (ev==windowfilter.windowMinimized and win.isMinimized)
          or (ev==windowfilter.windowUnminimized and not win.isMinimized)
          or (ev==windowfilter.windowHidden and win.isHidden)
          or (ev==windowfilter.windowUnhidden and not win.isHidden)
          or (ev==windowfilter.windowVisible and win.isVisible)
          or (ev==windowfilter.windowNotVisible and not win.isVisible)
          or (ev==windowfilter.windowInCurrentSpace and win.isInCurrentSpace)
          or (ev==windowfilter.windowNotInCurrentSpace and not win.isInCurrentSpace)
          or (ev==windowfilter.windowOnScreen and win.isVisible and win.isInCurrentSpace)
          or (ev==windowfilter.windowNotOnScreen and (not win.isVisible or not win.isInCurrentSpace))
          or (ev==windowfilter.windowFocused and global.focused==win)
          or (ev==windowfilter.windowUnfocused and global.focused~=win)
        then for _,f in ipairs(fns) do
          f(win.window,win.app.name,ev) end
        end
      end
      local win=windows[1]
      if win then
        if ev==windowfilter.hasWindow then
          for _,f in ipairs(fns) do f(win.window,win.app.name,ev) end
        end
        if ev==windowfilter.windowsChanged then
          for _,f in ipairs(fns) do f(win.window,win.app.name,ev) end
        end
      end
    end
  end
  checkTrackSpacesSubscriptions(self)
  return self
end

--- hs.window.filter:unsubscribe([event][, fn]) -> hs.window.filter object
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
function WF:unsubscribe(e,fns)
  if not e and not fns then error('you must pass at least one of event or fn',2) end
  local tevents,tfns=type(e),type(fns)
  if e==nil then tevents=nil end
  if fns==nil then tfns=nil end
  if tfns=='function' then fns={fns} tfns='lfn' end --?+fn
  if tevents=='function' then fns={e} tfns='lfn' tevents=nil --omitted+fn
  elseif tevents=='string' then e={e} tevents='ls' end --event+?
  if tevents=='table' then
    local k,v=next(e)
    if type(k)=='function' and v==true then fns=e tfns='sfn' tevents=nil --omitted+set of fns
    elseif type(k)=='string' then --set of events, or map
      if type(v)=='table' and type(v[1])=='functions' then tevents='mapl' tfns=nil --map of fnlist+ignored
      elseif type(v)=='function' then tevents='map' tfns=nil --map+ignored
      elseif v==true then tevents='ss' --set of events+?
      else error('invalid event parameter',2) end
    elseif type(k)=='number' then --list of events or functions
      if type(v)=='function' then fns=e tfns='lfn' tevents=nil --omitted+list of fns
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
  if tevents==nil then e=self.events tevents='ss' end --all events
  if tevents=='ss' then local l={} for k in pairs(e) do l[#l+1]=k end e=l tevents='ls'  end --make list
  if tfns=='sfn' then local l={} for k in pairs(fns) do l[#l+1]=k end fns=l tfns='lfn' end --make list

  if tevents=='map' then for ev,fn in pairs(e) do unsubscribe(self,ev,fn) end
elseif tevents=='mapl' then for ev,f in pairs(e) do for _,fn in ipairs(f) do unsubscribe (self,ev,fn) end end
  else
    if tevents~='ls' then error('invalid event parameter',2)
    elseif tfns~=nil and tfns~='lfn' then error('invalid fn parameter',2) end
    for _,ev in ipairs(e) do
      if not tfns then unsubscribeEvent(self,ev)
      else for _,fn in ipairs(fns) do unsubscribe(self,ev,fn) end end
    end
  end
  if not next(self.events) then self.log.i('no more callbacks') return self:unsubscribeAll() end
  checkTrackSpacesSubscriptions(self)
  return self
end

--- hs.window.filter:unsubscribeAll() -> hs.window.filter object
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
---  * You should not use this on the default windowfilter or other shared-use windowfilters
function WF:unsubscribeAll()
  self.events={} if not self.doKeepActive then self:pause() end
  checkTrackSpacesSubscriptions(self)
  return self
end


--- hs.window.filter:resume() -> hs.window.filter object
--- Method
--- Resumes the windowfilter event subscriptions
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function WF:resume()
  if activeInstances[self]==true then self.log.i('windowfilter instance already running, ignoring') return self end
  self.log.i('windowfilter instance resumed')
  return start(self)
end

--- hs.window.filter:pause() -> hs.window.filter object
--- Method
--- Stops the windowfilter event subscriptions; no more event callbacks will be triggered, but the subscriptions remain intact for a subsequent call to `hs.window.filter:resume()`
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.filter` object for method chaining
function WF:pause()
  self.log.i('windowfilter instance paused')
  activeInstances[self]=nil applicationActiveInstances[self]=nil stopGlobalWatcher()
  return self
end

function WF:delete()
  self.log.i(self,'instance deleted')
  activeInstances[self]=nil spacesInstances[self]=nil applicationActiveInstances[self]=nil
  self.events={} self.filters={} self.windows={}
  setmetatable(self,nil)
  if not global.inStartGlobalWatcher then stopGlobalWatcher() end
end


local defaultwf, defaultCurrentSpacewf, defaultwfLogLevel
function windowfilter.setLogLevel(lvl)
  log.setLogLevel(lvl) defaultwfLogLevel=lvl
  if defaultwf then defaultwf.setLogLevel(lvl) end
  if defaultCurrentSpacewf then defaultCurrentSpacewf.setLogLevel(lvl) end
  return windowfilter
end
windowfilter.getLogLevel=log.getLogLevel

local function makeDefault()
  if not defaultwf then
    defaultwf = windowfilter.new(true,'wf-default')
    getmetatable(defaultwf).__tostring=function()return sformat('hs.window.filter.default (%s)',defaultwf.__address) end
    if defaultwfLogLevel then defaultwf.setLogLevel(defaultwfLogLevel) end
    for appname in pairs(windowfilter.ignoreInDefaultFilter) do
      defaultwf:rejectApp(appname)
    end
    defaultwf:setAppFilter('Hammerspoon',{allowTitles={'Preferences','Console'},allowRoles='AXStandardWindow'})
    --    defaultwf:rejectApp'Hammerspoon'
    defaultwf:setDefaultFilter{visible=true}
    defaultwf.log.i('default windowfilter instantiated')
  end
  return defaultwf
end

local function makeDefaultCurrentSpace()
  if not defaultCurrentSpacewf then
    defaultCurrentSpacewf=windowfilter.copy(makeDefault(),'wf-curSpace'):setCurrentSpace(true)
    getmetatable(defaultCurrentSpacewf).__tostring=function()return sformat('hs.window.filter.defaultCurrentSpace (%s)',defaultCurrentSpacewf.__address) end
    if defaultwfLogLevel then defaultCurrentSpacewf.setLogLevel(defaultwfLogLevel) end
    defaultCurrentSpacewf.log.i('default windowfilter (current space) instantiated')
  end
  return defaultCurrentSpacewf
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
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call (or just use
---    `hs.window.filter.defaultCurrentSpace`)

--- hs.window.filter:windowsToWest(window, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all visible windows allowed by this windowfilter that lie to the west a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the westward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned west (i.e. left) of the window, in ascending order of distance
---
--- Notes:
---  * This is a convenience wrapper that returns `hs.window.windowsToWest(window,self:getWindows(),...)`
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call (or just use `hs.window.filter.defaultCurrentSpace`)

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
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call (or just use
---    `hs.window.filter.defaultCurrentSpace`)

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
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call (or just use
---    `hs.window.filter.defaultCurrentSpace`)


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
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call

--- hs.window.filter:focusWindowWest(window, frontmost, strict)
--- Method
--- Focuses the nearest window to the west of a given window
---
--- Parameters:
---  * window - (optional) an `hs.window` object; if nil, `hs.window.frontmostWindow()` will be used
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window in this windowfilter
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the westward axis
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.focusWindowWest(window,self:getWindows(),...)`
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call

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
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call

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
---  * You'll likely want to add `:setCurrentSpace(true)` to the windowfilter used for this method call


--- hs.window.filter.focusEast()
--- Function
--- Convenience function to focus the nearest window to the east
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.filter.defaultCurrentSpace:focusWindowEast(nil,nil,true)`

--- hs.window.filter.focusWest()
--- Function
--- Convenience function to focus the nearest window to the west
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.filter.defaultCurrentSpace:focusWindowWest(nil,nil,true)`

--- hs.window.filter.focusSouth()
--- Function
--- Convenience function to focus the nearest window to the south
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.filter.defaultCurrentSpace:focusWindowSouth(nil,nil,true)`

--- hs.window.filter.focusNorth()
--- Function
--- Convenience function to focus the nearest window to the north
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a convenience wrapper that performs `hs.window.filter.defaultCurrentSpace:focusWindowNorth(nil,nil,true)`


for _,dir in ipairs{'East','North','West','South'}do
  WF['windowsTo'..dir]=function(self,win,...)
    return windowMT['windowsTo'..dir](win,self:getWindows(),...)
  end
  WF['focusWindow'..dir]=function(self,win,...)
    if windowMT['focusWindow'..dir](win,self:getWindows(),...) then self.log.i('focused window '..dir:lower()) end
  end
  windowfilter['focus'..dir]=function()local d=makeDefaultCurrentSpace():keepActive()d['focusWindow'..dir](d,nil,nil,true)end
end


local rawget=rawget
return setmetatable(windowfilter,{
  __index=function(t,k)
    if k=='default' then return makeDefault()
    elseif k=='defaultCurrentSpace' then return makeDefaultCurrentSpace()
    else return rawget(t,k) end
  end,
  __call=function(_,...) return windowfilter.new(...):getWindows() end
})
