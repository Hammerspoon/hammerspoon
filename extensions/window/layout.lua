--- === hs.window.layout ===
---
--- **WARNING**: EXPERIMENTAL MODULE. DO **NOT** USE IN PRODUCTION.
--- This module is *for testing purposes only*. It can undergo breaking API changes or *go away entirely* **at any point and without notice**.
--- (Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.freenode.net)
---
--- Window management
---
--- Windowlayouts work by selecting certain windows via windowfilters and arranging them onscreen according to specific rules.
---
--- A **layout** is composed of a list of rules and, optionally, a screen arrangement definition.
--- Rules within a layout are evaluated in order; once a window is acted upon by a rule, subsequent rules will not affect it further.
--- A **rule** needs a **windowfilter**, producing a dynamic list of windows (the "window pool") to which the rule is applied,
--- and a list of commands, evaluated in order.
--- A **command** acts on one or more of the windows, and is composed of:
--- * an **action**, it can be
---   - `move`: moves the window(s) to a specified onscreen rect (if the action is omitted, `move` is assumed)
---   - `minimize`, `maximize`, `fullscreen`
---   - `tile`, `fit`: tiles the windows onto a specified rect, using `hs.window.tiling.tileWindows()`; for `fit`, the
---     `preserveRelativeArea` parameter will be set to true
---   - `hide`, `unhide`: hides or unhides the window's application (like when using cmd-h)
---   - `noaction`: skip action on the window(s)
--- * a **maxn** number, indicating how many windows from this rule's window pool will be affected (at most) by this command;
---   if omitted (or if explicitly the string `all`) all the remaining windows will be processed by this command; processed
---   windows are "consumed" and are excluded from the window pool for subsequent commands in this rule, and from subsequent rules
--- * a **selector**, describing the sort order used to pick the first *maxn* windows from the window pool for this command;
---   it can be one of `focused` (pick *maxn* most recently focused windows), `frontmost` (pick the recent focused window if its
---   application is frontmost applicaion, otherwise the command will be skipped), `newest` (most recently created), `oldest`
---   (least recently created), or `closest` (pick the *maxn* windows that are closest to the destination rect); if omitted,
---   defaults to `closest` for move, tile and fit, and `newest` for everything else
--- * an `hs.geometry` *size* (only valid for tile and fit) indicating the desired optimal aspect ratio for the tiled windows;
---   if omitted, defaults to 1x1 (i.e. square windows)
--- * for move, tile and fit, an `hs.geometry` *rect*, or a *unit rect* plus a *screen hint* (for `hs.screen.find()`),
---   indicating the destination rect for the command
--- * for fullscreen and maximize, a *screen hint* indicating the desired screen; if omitted, uses the window's current screen
---
--- You should place higher-priority rules (with highly specialized windowfilters) first, and "fallback" rules
--- (with more generic windowfilters) last; similarly, *within* a rule, you should have commands for the more "important"
--- (i.e. relevant to your current workflow) windows first (move, maximize...) and after that deal with less prominent
--- windows, if any remain, e.g. by placing them out of the way (minimize).
--- `unhide` and `hide`, if used, should usually go into their own rules (with a windowfilter that allows invisible windows
--- for `unhide`) that come *before* other rules that deal with actual window placement - unlike the other actions,
--- they don't "consume" windows making them unavailable for subsequent rules, as they act on applications.
---
--- In order to avoid dealing with deeply nested maps, you can define a layout in your scripts via a list, where each element
--- (or row) denotes a rule; in turn every rule can be a simplified list of two elements:
---   - a windowfilter or a constructor argument table for one (see `hs.window.filter.new()` and `hs.window.filter:setFilters()`)
---   - a single string containing all the commands (action and parameters) in order; actions and selectors can be shortened to
---     3 characters; all tokens must be separated by spaces (do not use spaces inside `hs.geometry` constructor strings);
---     for greater clarity you can separate commands with `|` (pipe character)
---
--- Some command string examples:
--- - `"move 1 [0,0,50,50] -1,0"` moves the closest window to the topleft quadrant of the left screen
--- - `"max 0,0"` maximizes all the windows onto the primary screen, one on top of another
--- - `"move 1 foc [0,0,30,100] 0,0 | tile all foc [30,0,100,100] 0,0"` moves the most recently focused window to the left third,
--- and tiles the remaining windows onto the right side, keeping the most recently focused on top and to the left
--- - `"1 new [0,0,50,100] 0,0 | 1 new [50,0,100,100] 0,0 | min"` divides the primary screen between the two newest windows
--- and minimizes any other windows
---
--- Each layout can work in "passive" or "active" modes; passive layouts must be triggered manually (via `hs.hotkey.bind()`,
--- `hs.menubar`, etc.) while active layouts continuously keep their rules enforced (see `hs.window.layout:start()`
--- for more information); in general you should avoid having multiple active layouts targeting the same windows, as the
--- results will be unpredictable (if such a situation is detected, you'll see an error in the Hammerspoon console); you
--- *can* have multiple active layouts, but be careful to maintain a clear "separation of concerns" between their respective windowfilters.
---
--- Each layout can have an associated screen configuration; if so, the layout will only be valid while the current screen
--- arrangement satisfies it; see `hs.window.layout:setScreenConfiguration()` for more information.

--TODO full examples in the wiki

local application = require 'hs.application'

local pairs,ipairs,next,type,pcall=pairs,ipairs,next,type,pcall
local floor=math.floor
local sformat,ssub,gmatch,gsub=string.format,string.sub,string.gmatch,string.gsub
local tonumber,tostring=tonumber,tostring
local tpack,tremove,tconcat=table.pack,table.remove,table.concat

local window=hs.window
local windowfilter=require'hs.window.filter'
local tileWindows=require'hs.window.tiling'.tileWindows
local geom,screen,timer,eventtap=require'hs.geometry',require'hs.screen',require'hs.timer',require'hs.eventtap'

local logger=require'hs.logger'
local log=logger.new'wlayout'
local layout={} -- module and class
layout.setLogLevel=log.setLogLevel
layout.getLogLevel=log.getLogLevel

local winbuf,appbuf={},{} -- action buffers for windows and apps
local rulebuf={} -- buffer for rules to apply
local screenCache={} -- memoize screen.find() on current screens

local activeInstances={} -- wlayouts currently in 'active mode'
local screenInstances={} -- wlayouts that care about screen configuration (they become active/inactive as screens change)


local function tlen(t)local i,e=0,next(t) while e do i,e=i+1,next(t,e) end return i end
local function errorf(s,...) local args=tpack(...) error(sformat(s,...),args[#args]+1) end
local function strip(s) return type(s)=='string' and s:gsub('%s+','') or s end

local MOVE,TILE,FIT,HIDE,UNHIDE,MINIMIZE,MAXIMIZE,FULLSCREEN,RESTORE='move','tile','fit','hide','unhide','minimize','maximize','fullscreen','restore'
local NOACTION='noaction'
local CREATEDLAST,CREATEDFIRST,FOCUSEDLAST,CLOSEST,FRONTMOST='createdLast','created','focusedLast','closest','frontmost'
local ACTIONS={mov=MOVE,fra=MOVE,til=TILE,fit=FIT,hid=HIDE,unh=UNHIDE,sho=UNHIDE,max=MAXIMIZE,ful=FULLSCREEN,fs=FULLSCREEN,min=MINIMIZE,res=RESTORE,noa=NOACTION}
local SELECTORS={cre=CREATEDLAST,new=CREATEDLAST,old=CREATEDFIRST,foc=FOCUSEDLAST,clo=CLOSEST,pos=CLOSEST,fro=FRONTMOST}

local function getaction(s,i)
  if type(s)~='string' then return nil,i end
  local r=ACTIONS[ssub(s,1,3)] return r,r and i+1 or i
end
local function getmaxnumber(n,i)
  if n=='all' then return nil,i+1 end
  n=tonumber(n) if type(n)=='number' and n<1000 then return n,i+1 else return nil,i end
end
local function getselector(s,i)
  if type(s)~='string' then return nil,i end
  local r=SELECTORS[ssub(s,1,3)] return r,r and i+1 or i
end
local function getaspect(a,i)
  if type(a)=='string' then
    if a:sub(1,3)=='hor' or a=='row' then return 0.01,i+1
    elseif a:sub(1,3)=='ver' or a:sub(1,3)=='col' then return 100,i+1 end
  end
  --  if type(a)=='number' then return a,i+1 end
  local ok,res=pcall(geom.new,a)
  if ok and res:type()=='size' then return res.aspect,i+1 else return nil,i end
end
local function getrect(r,i)
  local ok,res=pcall(geom.new,r)
  if ok and geom.type(res)=='rect' then return res,i+1 else return nil,i end
end
local function getunitrect(r,i)
  local ok,res=pcall(geom.new,r)
  if ok and geom.type(res)=='unitrect' then return res,i+1 else return nil,i end
end

local function validatescreen(s,i)
  if getaction(s,i) then return nil,i
  elseif type(s)=='number' and s>=1000 then return s,i+1
  elseif type(s)=='string' or type(s)=='table' then
    local ok,res=pcall(geom.new,s) --disallow full frame, as it could be mistaken for the next cmd (implicit 'move')
    if ok then
      local typ=geom.type(res)
      if typ=='point' or typ=='size' then return s,i+1 else return nil,i end
    end
    if type(s)=='string' then return s,i+1 else return nil,i end
  end
  return nil,i
end
local function screenstr(s)
  if type(s)=='number' then return s
  elseif type(s)=='string' or type(s)=='table' then
    local ok,res=pcall(geom.new,s)
    if ok then return res.string end
    if type(s)=='string' then return s end
  end
end

local function validateCommand(command,ielem,icmd,irule,l)
  local idx=irule..'.'..icmd
  if command.irule~=irule or command.icmd~=icmd then errorf('invalid indices %d.%d, %s expected',command.irule,command.icmd,idx,6) end
  local function error(s) return errorf('invalid %s, token %d in rule %s',s,ielem,idx,7) end
  local action=getaction(command.action,0)
  if not action then error'action' end
  local logs=sformat('rule %d.%d: %s',irule,icmd,action)
  --  if action==RESTORE then command.max=999 return command,ielem,icmd+1 end
  if command.max then
    if type(command.max)~='number' or floor(command.max)~=command.max or command.max<1 or command.max>999 then error'max number' end
    --    if command.action~=UNHIDE and command.max<1 then error'max number' end --allow "unhide 0"
    logs=logs..' '..command.max
  else logs=logs..' all' end
  if command.select then
    if not getselector(command.select,0) then error'selector'
    else logs=logs..' '..command.select end
  end
  if action==MAXIMIZE or action==FULLSCREEN or action==NOACTION then
    if command.screen then
      if not validatescreen(command.screen,ielem) then error'screen'end
      logs=logs..' screen='..screenstr(command.screen)
    end
  elseif action==MOVE or action==TILE or action==FIT then
    if action==TILE or action==FIT then
      if command.aspect then
        if type(command.aspect)~='number' or command.aspect<=0 or command.aspect==command.aspect/2 then error'aspect'
        else logs=logs..' aspect='..sformat('%.2f',command.aspect) end
      end
    end
    if command.rect then
      local rect=geom.new(command.rect)
      if geom.type(rect)~='rect' then error'rect'
      else logs=logs..' rect='..rect.string end
    else
      if not command.unitrect then errorf('need rect or unitrect, token %d in rule %s',ielem,idx,6) end
      local unitrect=geom.new(command.unitrect)
      if geom.type(unitrect)~='unitrect' then error'unitrect'
      else logs=logs..' unitrect='..unitrect.string end
      if not validatescreen(command.screen,ielem) then error'screen'end
      logs=logs..' screen='..screenstr(command.screen)
    end
  elseif action==HIDE or action==MINIMIZE or action==UNHIDE or action==RESTORE then
    if getselector(command.select,0)==CLOSEST then error'selector' end
  else error'action' end

  l.i(logs)
  return command,ielem,icmd+1
end

local function parseCommand(rule,ielem,icmd,irule,l)
  if type(rule[ielem])=='table' and rule[ielem].action then
    return validateCommand(rule[ielem],ielem,icmd,irule,l),ielem+1,icmd+1
  end
  local r={irule=irule,icmd=icmd}
  r.action,ielem=getaction(rule[ielem],ielem)
  --optional number of windows to process for this cmd
  r.max,ielem=getmaxnumber(rule[ielem],ielem)
  --  r.max=r.max or 999
  if not r.action then r.action=MOVE
  elseif r.action==RESTORE then return validateCommand(r,ielem,icmd,irule,l) end
  r.select,ielem=getselector(rule[ielem],ielem)
  if not r.select then
    if r.action==MOVE or r.action==TILE or r.action==FIT then r.select=CLOSEST
    else r.select=CREATEDLAST end
  end
  if r.action==HIDE or r.action==MINIMIZE or r.action==UNHIDE then
    return validateCommand(r,ielem,icmd,irule,l)
  elseif r.action==FULLSCREEN or r.action==MAXIMIZE then
    r.screen,ielem=validatescreen(rule[ielem],ielem)
    return validateCommand(r,ielem,icmd,irule,l)
  end
  -- move or tile
  if r.action==TILE or r.action==FIT then
    -- optional aspect
    r.aspect,ielem=getaspect(rule[ielem],ielem)
  end
  -- now rect or unitrect+screen
  r.rect,ielem=getrect(rule[ielem],ielem)
  if not r.rect then
    r.unitrect,ielem=getunitrect(rule[ielem],ielem)
    r.screen,ielem=validatescreen(rule[ielem],ielem)
  end
  validateCommand(r,ielem,icmd,irule,l)
  --  if (r.action==MINIMIZE or r.action==HIDE) and elemi<=#row then error(r.action..' must be the last action in a rule',2)end
  return r,ielem,icmd+1
end

local function getwf(wf,idx,logname,loglevel) return windowfilter.new(wf,'r'..idx..'-'..(logname or 'wlayout'),loglevel) end
local function wferror(wfkey,irule,res)
  errorf('element %s in rule %d must be a windowfilter object or valid constructor argument\n%s',wfkey,irule,res,5)
end
local function parseRule(self,rule,irule)
  local logname,loglevel=self.logname,self.loglevel
  local r={windowlayout=self,irule=irule}
  log.df('parsing rule %d, getting windowfilter',irule)
  local ok,res,wfkey
  if rule.windowfilter then
    wfkey='windowfilter'
    ok,res=pcall(getwf,rule.windowfilter,irule,logname,loglevel)
    if not ok then wferror(wfkey,irule,res,4)
    else r.windowfilter=res end
  else
    for k,_ in pairs(rule) do
      if type(k)=='string' then wfkey,ok,res=k,pcall(getwf,{[k]=rule[k]},irule,logname,loglevel) break end
    end
    if ok then r.windowfilter=res
    elseif ok==false then wferror(wfkey,irule,res,4)
    elseif ok==nil then
      wfkey,ok,res=1,pcall(getwf,rule[1],irule,logname,loglevel)
      if not ok then wferror(wfkey,irule,res,4) end
      r.windowfilter=res
    end
  end
  --  hs.assert(r.windowfilter,'invalid rule windowfilter',rule)
  local split,slog={},{}
  for i=(wfkey==1 and 2 or 1),#rule do
    local elem=rule[i]
    if type(elem)=='string' then
      elem=gsub(elem,'%s+[|>/-,]%s+',' ')
      for s in gmatch(elem,'%s*%g+%s*') do
        split[#split+1]=strip(s)
        slog[#slog+1]=strip(s)
      end
    else
      split[#split+1]=elem
      slog[#slog+1]=tostring(elem)
    end
  end
  log.vf('tokenized rule %d: %s',irule,tconcat(slog,'|'))
  local ielem,icmd,cmd=1,1
  while ielem<=#split do
    cmd,ielem,icmd=parseCommand(split,ielem,icmd,irule,log)
    cmd.windowlayout=self
    r[#r+1]=cmd
  end
  return r
end

local function parseRules(rules,self)
  local r={}
  for _,row in ipairs(rules) do
    if type(row)~='table' then rules={rules} break end
  end
  self.log.vf('will parse %d rules',#rules)
  for irule=1,#rules do
    r[irule]=parseRule(self,rules[irule],irule)
  end
  return r
end

--- hs.window.layout.new(rules[,logname[,loglevel]]) -> hs.window.layout object
--- Constructor
--- Creates a new hs.window.layout instance
---
--- Parameters:
---  * rules - a table containing the rules for this windowlayout (see the module description); additionally, if a special key `screens`
---    is present, its value must be a valid screen configuration as per `hs.window.layout:setScreenConfiguration()`
---  * logname - (optional) name of the `hs.logger` instance for the new windowlayout; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new windowlayout
---
--- Returns:
---  * a new windowlayout instance
local function __tostring(self) return sformat('hs.window.layout: %s (%s)',self.logname or '...',self.__address) end
function layout.new(rules,logname,loglevel)
  if type(rules)~='table' then error('rules must be a table',2)end
  local o={log=logname and logger.new(logname,loglevel) or log,logname=logname,loglevel=loglevel}
  o.__address=gsub(tostring(o),'table: ','')
  setmetatable(o,{__index=layout,__tostring=__tostring,__gc=layout.delete})
  if logname then o.setLogLevel=o.log.setLogLevel o.getLogLevel=o.log.getLogLevel end
  local mt=getmetatable(rules)
  if mt and mt.__index==layout then
    o.log.i('new windowlayout copy')
    rules=rules.rules
  else
    o.log.i('new windowlayout')
  end
  o.rules=parseRules(rules,o)
  o:setScreenConfiguration(rules.screens)
  return o
end

--- hs.window.layout:getRules() -> table
--- Method
--- Return a table with all the rules (and the screen configuration, if present) defined for this windowlayout
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the rules of this windowlayout; you can pass this table (optionally
---    after performing valid manipulations) to `hs.window.layout.new()`
function layout:getRules()
  local r={}
  for _,rule in ipairs(self.rules) do
    local nrule={}
    nrule.windowfilter=rule.windowfilter:getFilters()
    for _,command in ipairs(rule) do
      nrule[#nrule+1]={
        action=command.action,max=command.max,select=command.select,aspect=command.aspect,
        rect=command.rect and geom.new(command.rect).table,
        unitrect=command.unitrect and geom.new(command.unitrect).table,
        screen=command.screen,--irule=irule,icmd=icmd,
      }
    end
    r[#r+1]=nrule
  end
  r.screens=self.screens
  return r
end

local function findScreen(s)
  if not s then return elseif not screenCache[s] then screenCache[s]=screen.find(s) end
  return screenCache[s]
end

-- applies pending actions on windows and apps (winbuf,appbuf)
local function performPendingActions()
  -- show apps
  if not next(winbuf) and not next(appbuf) then return end
  log.vf('applying %d pending actions',tlen(winbuf))
  for app,command in pairs(appbuf) do
    if command.hide==false and app:isHidden() then
      app:unhide()
      command.log.f('rule %d.%d: %s unhidden',command.irule,command.icmd,app:name())
    end
  end

  -- move/min/max/fs
  for win,command in pairs(winbuf) do
    local idx,appname,id=command.irule..'.'..command.icmd,win:application():name(),win:id()
    local action=command.action
    if action==MINIMIZE then
      if not win:isMinimized() then
        win:minimize()
        command.log.f('rule %s: %s (%d) minimized',idx,appname,id)
      end
      winbuf[win]=nil
    else
      if win:isMinimized() then
        win:unminimize()
        command.log.f('rule %s: %s (%d) unminimized',idx,appname,id)
      end
      if action~=TILE and action~=FIT then
        winbuf[win]=nil
        local winscreen=win:screen()
        local toscreen=findScreen(command.screen) or winscreen
        if win:isFullScreen() and (action~=FULLSCREEN or toscreen~=winscreen) then
          win:setFullScreen(false)
          command.log.f('rule %s: %s (%d) unfullscreened',idx,appname,id)
        end
        if action==FULLSCREEN then
          if toscreen~=winscreen then win:moveToScreen(toscreen) end
          if not win:isFullScreen() then
            win:setFullScreen(true)
            command.log.f('rule %s: %s (%d) fullscreened to %s',idx,appname,id,toscreen:name())
          end
        elseif action==MAXIMIZE then
          local frame=toscreen:frame()
          if win:frame()~=frame then
            win:setFrame(toscreen:frame())
            command.log.f('rule %s: %s (%d) maximized to %s',idx,appname,id,toscreen:name())
          end
        elseif action==MOVE then
          local frame=command.rect or toscreen:fromUnitRect(command.unitrect)
          if win:frame()~=frame then
            win:setFrame(frame)
            command.log.f('rule %s: %s (%d) moved to %s',idx,appname,id,frame.string)
          end
        --elseif action==NOACTION then
        --else --hs.assert(false,'(422) wrong action: '..action,command)
        end
      end
    end
  end

  -- tile remaining windows
  local toTile={}
  for win,command in pairs(winbuf) do
    --    hs.assert(command.action==TILE or command.action==FIT,'(431) unexptected action: '..command.action,command)
    local idx=command.irule..'.'..command.icmd
    if not toTile[idx] then toTile[idx]=command
    end
    local e=toTile[idx]
    e[command.nwindow]=win
    winbuf[win]=nil
  end
  for idx,command in pairs(toTile) do
    --FIXME assert for lack of holes in the list
    --    hs.assert(#command>0,'(443)',command)
    --    hs.assert(#command<=(command.max or 999),'(444)',command)
    local toscreen=findScreen(command.screen) or command[1]:screen()
    local frame=command.rect or toscreen:fromUnitRect(command.unitrect)
    command.log.f('rule %s: %s %d windows into %s by %s',idx,command.action,#command,frame.string,command.select)
    --    tileWindows(command,frame,command.aspect,command.select~=CLOSEST,command.action==FIT)
    tileWindows(command,frame,command.aspect,false,command.action==FIT) -- always tile by position
  end

  -- hide apps
  for app,command in pairs(appbuf) do
    if command.hide==true and not app:isHidden() then
      app:hide()
      command.log.f('rule %d.%d: %s hidden',command.irule,command.icmd,app:name())
    end
    appbuf[app]=nil
  end
  --  hs.assert(not next(winbuf) and not next(appbuf),'(432)')
end

local function removeFromList(win,winlist)
  local id=win:id() for i,w in ipairs(winlist) do if w:id()==id then tremove(winlist,i) return end end
end
local function findDestinationFrame(s,unitrect,candidateWindow)
  local toscreen=findScreen(s) or (candidateWindow and candidateWindow:screen() or findScreen'0,0')
  return unitrect and toscreen:fromUnitRect(unitrect) or toscreen:frame()
end
local function findClosestWindow(winlist,destFrame) --winlist must be sorted by focusedLast
  --  hs.assert(#winlist>0,'no candidates for closest window')
  local center,rd,rwin=destFrame.center,999999
  for _,w in ipairs(winlist) do -- first, try the "smallest" of all windows already fully inside frame
    local frame=w:frame()
    -- TODO?   if w:isVisible() then
    if frame:inside(destFrame) then
      local distance=frame.xy:distance(center)+frame.x2y2:distance(center)
      if distance<rd then rd=distance rwin=w end
    end
  end
  if rwin then return rwin end
  for _,w in ipairs(winlist) do -- otherwise, just get the closest
    local frame=w:frame()
    local distance=frame:distance(center)
    if distance<rd then rd=distance rwin=w end
  end
  --  hs.assert(rwin,'no closest window to '..destFrame.string,winlist)
  return rwin
end

-- applies a layout rule onto the action buffers
local function applyRule(rule)
  local irule=rule.irule
  local l=rule.windowlayout.log
  --  local rule=self.rules[irule]
  local windows,windowsCreated=rule.windowfilter:getWindows(FOCUSEDLAST),rule.windowfilter:getWindows(CREATEDLAST)
  log.vf('applying rule %d to %d windows',irule,#windows)
  local icmd,nprocessed=1,0
  --local ASSERT_ITER=1
  --  local readdUnhiddenWindows={}
  while icmd<=#rule and windows[1] do
    --    ASSERT_ITER=ASSERT_ITER+1 hs.assert(ASSERT_ITER<100,'applyRule looping',rule.irule)
    local command,win=rule[icmd]
    local selector=command.select
    if selector==CLOSEST then
      local destFrame=command.rect or findDestinationFrame(command.screen,command.unitrect)
      win=findClosestWindow(windows,destFrame)
      l.vf('found closest window %d to %s',win:id(),destFrame.string)
    elseif selector==FOCUSEDLAST then
      win=windows[1]
    elseif selector==CREATEDLAST then
      win=windowsCreated[1]
    elseif selector==CREATEDFIRST then
      win=windowsCreated[#windowsCreated]
    elseif selector==FRONTMOST then
      if windows[1]:application() == application.frontmostApplication() then
        win=windows[1]
        nprocessed = 999
      else
        icmd=icmd+1 nprocessed=0
        goto _next_
      end
    end
    --    hs.assert(win,'no window to apply rule',rule)

    removeFromList(win,windows) removeFromList(win,windowsCreated)
    nprocessed=nprocessed+1

    local buffered=winbuf[win]
    if buffered and buffered.windowlayout~=rule.windowlayout then
      l.ef('multiple active windowlayout instances for %s (%s)!',win:application():name(),win:id())
    end


    local action=command.action
    if action==HIDE or action==UNHIDE then
      local app=win:application()
      if not appbuf[app] or appbuf[app].irule>irule then
        appbuf[app]={hide=action==HIDE,log=l,irule=irule,icmd=icmd}
      end
      --      if action==UNHIDE then tinsert(readdUnhiddenWindows,win) end
      --      action=NOACTION
    else
      if not buffered or buffered.irule>irule then
        --        hs.assert(command.irule==irule and command.icmd==icmd,'(451) wrong indices: '..irule..'.'..icmd,command)
        command.log=l
        winbuf[win]={action=action,select=command.select,rect=command.rect,unitrect=command.unitrect,screen=command.screen,
          max=command.max,aspect=command.aspect,log=command.log,irule=command.irule,icmd=command.icmd,nwindow=nprocessed,windowlayout=rule.windowlayout}
        --        winbuf[win]=command winbuf[win].nwindow=nprocessed
        l.df('pending action "%s" for %s (%d), %d total',action,win:application():name(),win:id(),tlen(winbuf))
      end
    end
    if nprocessed>=(command.max or 999) then --done with this cmd
      icmd=icmd+1 nprocessed=0
      --        for i=#readdUnhiddenWindows,1,-1 do --was UNHIDE, now done
      --          local w=readdUnhiddenWindows[i] tinsert(windows,w,1) tinsert(windowsCreated,w,1)
      --        end
    end
    ::_next_::
  end
end

-- applies pending rules
local function applyPendingRules()
  for rule in pairs(rulebuf) do applyRule(rule) end
  rulebuf={} return performPendingActions()
end


--- hs.window.layout:apply()
--- Method
--- Applies the layout
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.layout` object
---
--- Notes:
---  * if a screen configuration is defined for this windowfilter, and currently not satisfied, this method will do nothing
function layout:apply()
  if screenInstances[self] and not self._screenConfigurationAllowed then
    self.log.i('current screen configuration not allowed, ignoring apply') return self end
  local batchID=windowfilter.startBatchOperation()
  for _,rule in ipairs(self.rules) do applyRule(rule) end
  self.log.i('Applying layout') performPendingActions()
  windowfilter.stopBatchOperation(batchID)
  return self
end

--- hs.window.layout.applyDelay
--- Variable
--- When "active mode" windowlayouts apply a rule, they will pause briefly for this amount of time in seconds, to allow windows
--- to "settle" in their new configuration without triggering other rules (or the same rule), which could result in a
--- cascade (or worse, a loop) or rules being applied. Defaults to 1; increase this if you experience unwanted repeated
--- triggering of rules due to sluggish performance.
layout.applyDelay=1


local DISTANT_FUTURE=315360000 -- 10 years (roughly)

--delay applying autolayouts while e.g. a window is being dragged with the mouse or moved via keyboard shortcuts
--or while switching focus with cmd-alt or cmd-`
local function checkMouseOrMods()
  local mbut=eventtap.checkMouseButtons()
  local mods=eventtap.checkKeyboardModifiers(true)._raw
  return mods>0 or mbut.left or mbut.right or mbut.middle
end
local MODS_INTERVAL=0.2 -- recheck for (lack of) mouse buttons and mod keys after this interval

local modsTimer=timer.waitWhile(checkMouseOrMods,function(tmr)applyPendingRules()tmr:start():setNextTrigger(DISTANT_FUTURE)end,MODS_INTERVAL)

--- hs.window.layout:start() -> hs.window.layout object
--- Method
--- Puts a windowlayout instance in "active mode"
---
--- When in active mode, a windowlayout instance will constantly monitor the windowfilters for its rules,
--- by subscribing to all the relevant events. As soon as any change is detected (e.g. when you drag a window,
--- switch focus, open or close apps/windows, etc.) the relative rule will be automatically re-applied.
--- In other words, the rules you defined will remain enforced all the time, instead of waiting for manual
--- intervention via `hs.window.layout:apply()`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.layout` object
---
--- Notes:
---  * if a screen configuration is defined for this windowfilter, and currently not satisfied, this
---    windowfilter will be put in "active mode" but will remain paused until the screen configuration
---    requirements are met
function layout:start()
  if activeInstances[self] then self.log.d('windowlayout instance already started') return self end
  layout._hasActiveInstances=true -- used by hs.grid to pause all during modal operation
  activeInstances[self]=true
  self.log.i('starting windowlayout instance (active mode)')
  return self:resume()
end

--- hs.window.layout:resume() -> hs.window.layout object
--- Method
--- Resumes an active windowlayout instance after it was paused
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.layout` object
---
--- Notes:
---  * if a screen configuration is defined for this windowfilter, and currently not satisfied, this method will do nothing
function layout:resume()
  if not activeInstances[self] then self.log.i('windowlayout instance not started, ignoring resume') return self end
  if self.autolayout then self.log.d('windowlayout instance already running, ignoring resume') return self end
  if screenInstances[self] and not self._screenConfigurationAllowed then
    self.log.d('current screen configuration not allowed, ignoring resume') return self end
  for _,rule in ipairs(self.rules) do
    --timers and upvalues galore
    local hasFocusedSelector--,hasPositionSelector
    for _,cmd in ipairs(rule) do
      if cmd.select==FOCUSEDLAST or cmd.select==FRONTMOST then hasFocusedSelector=true end
      --      elseif cmd.select==CLOSEST then hasPositionSelector=true end
    end
    rule.callback=function()
      rulebuf[rule]=true modsTimer:setNextTrigger(MODS_INTERVAL)
      rule.windowfilter:unsubscribe(windowfilter.windowMoved,rule.callback)
      rule.resubTimer:setNextTrigger(MODS_INTERVAL+window.animationDuration+layout.applyDelay)
    end
    if not rule.resubTimer then
      rule.resubTimer=timer.new(DISTANT_FUTURE,
        function()rule.windowfilter:subscribe(windowfilter.windowMoved,rule.callback)end):start()
    end
    rule.windowfilter:subscribe({windowfilter.windowVisible,windowfilter.windowNotVisible,windowfilter.windowMoved},rule.callback)
    if hasFocusedSelector then rule.windowfilter:subscribe({windowfilter.windowFocused,windowfilter.windowUnfocused},rule.callback) end
  end
  self.log.i('windowlayout instance resumed')
  self:apply()
  self.autolayout=true
  return self
end

--- hs.window.layout:pause() -> hs.window.layout object
--- Method
--- Pauses an active windowlayout instance; while paused no automatic window management will occur
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.layout` object
function layout:pause()
  if not activeInstances[self] then self.log.i('windowlayout instance not started, ignoring pause') return self end
  if not self.autolayout then self.log.d('windowlayout instance already paused, ignoring') return self end
  for _,rule in ipairs(self.rules) do
    if rule.callback then rule.windowfilter:unsubscribe(rule.callback) rule.callback=nil end
    if rule.resubTimer then rule.resubTimer:setNextTrigger(DISTANT_FUTURE) end
  end
  --  if self.timer then self.timer:stop() self.timer=nil end
  self.autolayout=false
  self.log.i('windowlayout instance paused')
  return self
end

--- hs.window.layout:stop() -> hs.window.layout object
--- Method
--- Stops a windowlayout instance (i.e. not in "active mode" anymore)
---
--- Parameters:
---  * None
---
--- Returns:
---  * the `hs.window.layout` object
function layout:stop()
  if not activeInstances[self] then self.log.d('windowlayout instance already stopped') return self end
  if self.autolayout then self:pause() end
  activeInstances[self]=nil self.autolayout=nil
  self.log.i('windowlayout instance stopped')
  return self
end

local screenWatcher

function layout:delete()
  self:stop()
  for _,rule in ipairs(self.rules) do rule.windowfilter:delete() end self.rules={}
  self.log.i('windowlayout instance deleted')
  screenInstances[self]=nil
  if not next(activeInstances) and not next(screenInstances) then
    --global stop
    if screenWatcher then screenWatcher:stop() screenWatcher=nil end
  end
  setmetatable(self,nil)
end

--- hs.window.layout.screensChangedDelay
--- Variable
--- The number of seconds to wait, after a screen configuration change has been detected, before
--- resuming any active windowlayouts that are allowed in the new configuration; defaults
--- to 10, to give sufficient time to OSX to do its own housekeeping
layout.screensChangedDelay = 10

local screensChangedTimer
local function screensChanged()
  log.d'screens changed, pausing all active instances'
  layout.pauseAllInstances()
  screenCache={}
  screensChangedTimer:setNextTrigger(layout.screensChangedDelay)
end
local function checkScreenInstances()
  -- check screenInstances, set them active appropriately
  local newActiveInstances={}
  for wl in pairs(activeInstances) do newActiveInstances[wl]=true end
  for wl in pairs(screenInstances) do
    newActiveInstances[wl]=true
    wl.log.v('checking screen configuration')
    for hint, pos in pairs(wl.screens) do
      local screens=tpack(screen.find(hint))
      if pos==false then if #screens>0 then newActiveInstances[wl]=nil wl.log.df('screen %s is present, required absent',screens[1]:name()) break end
      elseif pos==true then if #screens==0 then newActiveInstances[wl]=nil wl.log.df('screen %s is absent, required present',hint) break end
      else
        local sp,found=findScreen(pos),nil
        if not sp then newActiveInstances[wl]=nil wl.log.df('screen at %s is absent, %s required',pos,hint) break end
        local spid=sp:id()
        for _,s in ipairs(screens) do if s:id()==spid then found=true break end end
        if not found then newActiveInstances[wl]=nil wl.log.df('screen at %s is not %s',pos,hint) break end
      end
    end
  end
  for wl in pairs(screenInstances) do if not newActiveInstances[wl] and wl._screenConfigurationAllowed then
    wl.log.i('current screen configuration not allowed')
    wl._screenConfigurationAllowed=nil
    if activeInstances[wl] then wl:pause() end
  end end
  for wl in pairs(newActiveInstances) do
    wl.log.i('current screen configuration is allowed')
    wl._screenConfigurationAllowed=true
    if activeInstances[wl] then wl:resume() end
  end
  if next(screenInstances) then if not screenWatcher then screenWatcher=screen.watcher.new(screensChanged):start() end
  elseif screenWatcher then screenWatcher:stop() screenWatcher=nil end
  --  layout.resumeAllInstances()
end
local function processScreensChanged()
  log.i'applying new screen configuration'
  screensChangedTimer:setNextTrigger(DISTANT_FUTURE)
  return checkScreenInstances()
end

screensChangedTimer=timer.new(DISTANT_FUTURE,processScreensChanged):start()

--- hs.window.layout:setScreenConfiguration(screens) -> hs.window.layout object
--- Method
--- Determines the screen configuration that permits applying this windowlayout
---
--- With this method you can define different windowlayouts for different screen configurations
--- (as per System Preferences->Displays->Arrangement).
--- For example, suppose you define two "graphics design work" windowlayouts, one for "desk with dual monitors"
--- and one for "laptop only mode":
--- * "passive mode" use: you call `:apply()` on *both* on your chosen hotkey (via `hs.hotkey:bind()`), but
---   only the appropriate layout for the current arrangement will be applied
--- * "active mode" use: you just call `:start()` on both windowlayouts; as you switch between workplaces
---   (by attaching or detaching external screens) the correct layout "kicks in"
---   automatically - this is in effect a convenience wrapper that calls `:pause()` on the no longer relevant
---   layout, and `:resume()` on the appropriate one, at every screen configuration change
---
--- Parameters:
---  * screens - a map, where each *key* must be a valid "hint" for `hs.screen.find()`, and the corresponding
---    value can be:
---    * `true` - the screen must be currently present (attached and enabled)
---    * `false` - the screen must be currently absent
---    * an `hs.geometry` point (or constructor argument) - the screen must be present and in this specific
---      position in the current arragement (as per `hs.screen:position()`)
---
--- Returns:
---  * the `hs.window.layout` object
---
--- Notes:
---  * if `screens` is `nil`, any previous screen configuration is removed, and this windowlayout will be always allowed
---  * for "active" windowlayouts, call this method *before* calling `hs.window.layout:start()`
---  * by using `hs.geometry` size objects as hints you can define separate layouts for the same physical
---    screen at different resolutions
---
--- Usage:
--- ```
--- local laptop_layout,desk_layout=... -- define your layouts
--- -- just the laptop screen:
--- laptop_layout:setScreenConfiguration{['Color LCD']='0,0',dell=false,['3840x2160']=false}:start()
--- -- attached to a 4k primary + a Dell on the right:
--- desk_layout:setScreenConfiguration{['3840x2160']='0,0',['dell']='1,0',['Color LCD']='-1,0'}:start()
--- -- as above, but in clamshell mode (laptop lid closed):
--- clamshell_layout:setScreenConfiguration{['3840x2160']='0,0',['dell']='1,0',['Color LCD']=false}:start()
--- ```
function layout:setScreenConfiguration(screens)
  if not screens then
    screenInstances[self]=nil
    self.screens=nil self.log.i'screen configuration removed'
  else
    if type(screens)~='table' then error('screens must be a map',2) end
    local r={}
    for hint,pos in pairs(screens) do
      local s=validatescreen(hint,0) if not s then errorf('invalid screen hint: %s',hint,2) end
      if type(pos)=='boolean' then
        r[s]=pos self.log.f('screen configuration: %s %s',s,pos and 'present' or 'absent')
      else
        local ok,res=pcall(geom.new,pos)
        if not ok or geom.type(res)~='point' then errorf('invalid screen position: %s',pos,2) end
        r[s]=res self.log.f('screen configuration: %s at %s',s,res.string)
      end
    end
    self.screens=r screenInstances[self]=true
  end
  checkScreenInstances()
  return self
end

--- hs.window.layout.pauseAllInstances()
--- Function
--- Pauses all active windowlayout instances
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function layout.pauseAllInstances() for wl in pairs(activeInstances) do wl:pause() end end

--- hs.window.layout.resumeAllInstances()
--- Function
--- Resumes all active windowlayout instances
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function layout.resumeAllInstances() for wl in pairs(activeInstances) do wl:resume() end end

--- hs.window.layout.applyLayout(rules)
--- Function
--- Applies a layout
---
--- Parameters:
---  * rules - see `hs.window.layout.new()`
---
--- Returns:
---  * None
---
--- Notes:
---  * this is a convenience wrapper for "passive mode" use that creates, applies, and deletes a windowlayout object;
---    do *not* use shared windowfilters in `rules`, as they'll be deleted; you can just use constructor argument maps instead

-- Note: the windowfilters are created on the fly, used and immediately deleted when done, must warn user against passing in his own windowfilters, or allow
-- *another* parameter (meh), or set up __mode='k' and __gc in wf's activeInstances; this to make stuff like
-- layout.apply{hs.application.frontmostApplication():title,...} straightforward
function layout.applyLayout(rules) layout.new(rules):apply():delete() end


--TODO...
--function layout.getLayout(layout,includeScreen)
--layout is optional
-- to detect tiling: no intersections, union area = sum of areas
--end

--TODO "restore" action

-- for 'restore': settings.set should be 1. screen definitions if provided or 2.screens geometry as per old windowlayouts


return layout
