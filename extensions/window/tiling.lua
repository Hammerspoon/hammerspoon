--- === hs.window.tiling ===
---
--- **WARNING**: EXPERIMENTAL MODULE. DO **NOT** USE IN PRODUCTION.
--- This module is *for testing purposes only*. It can undergo breaking API changes or *go away entirely* **at any point and without notice**.
--- (Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.freenode.net)
---
--- Tile windows
---
--- The `tileWindows` function in this module is primarily meant for use by `hs.window.layout`; however you can call it manually
--- (e.g. for your custom layout engine).

-- BEWARE: horrible code (=accumulation of layers upon layers of ad-hoc fixes) ahead. This thing needs a proper rewrite.
-- very loosely based on http://www.win.tue.nl/~vanwijk/stm.pdf


local geom=require'hs.geometry'
local pairs,ipairs,next,type=pairs,ipairs,next,type
local max,min=math.max,math.min
local log=require'hs.logger'.new'wtiling'

--TODO rewrite this whole thing.

local function tlen(t)local i,e=0,next(t) while e do i,e=i+1,next(t,e) end return i end
local function nextWindow(windowPool)
  local ri,rw=999999
  for win in pairs(windowPool) do if win.idx<ri then rw=win ri=win.idx end end
  return rw
end

local function closestWindow(windowPool,point)
  local rd,rw=999999
  for win in pairs(windowPool) do
    local d=win.posInUnion:distance(point)
    if d<rd then rd=d rw=win end
  end
  return rw
    --[[
  -- return a sorted list of windows closest to a given point
  local res={}
  for win in pairs(windowPool) do res[#res+1]=win end
  tsort(res,function(w1,w2) return w1.posInUnion:distance(point)<w2.posInUnion:distance(point) end)
  return res[1]
  --]]
end

local function switchedwh(r)return geom(r.x,r.y,r.h,r.w)end

local function getCentroid(switchedRectToFill,windowArea,i,n,fillVertically)
  local h=switchedRectToFill.h
  local r=geom.copy(switchedRectToFill):setw(windowArea*n/h)
  if not fillVertically then r=switchedwh(r) r:setw(r.w/n):move(r.w*(i-1),0)
  else r:seth(r.h/n):move(0,r.h*(i-1)) end
  return r.center
end

--- hs.window.tiling.tileWindows(windows,rect[,desiredAspect[,processInOrder[,preserveRelativeArea[,animationDuration]]]])
--- Function
--- Tile (or fit) windows into a rect
---
--- Parameters:
---  * windows - a list of `hs.window` objects indicating the windows to tile or fit
---  * rect - an `hs.geometry` rect (or constructor argument), indicating the desired onscreen region that the windows will be tiled within
---  * desiredAspect - (optional) an `hs.geometry` size (or constructor argument) or a number, indicating the desired optimal aspect ratio (width/height) of the tiled windows; the tiling engine will decide how to subdivide the rect among windows by trying to maintain every window's aspect ratio as close as possible to this; if omitted, defaults to 1 (i.e. try to keep the windows as close to square as possible)
---  * processInOrder - (optional) if `true`, windows will be placed left-to-right and top-to-bottom following the list order in `windows`; if `false` or omitted, the tiling engine will try to maintain the spatial distribution of windows, i.e. (roughly speaking) pick the closest window for each destination "tile"; note that in some cases this isn't possible and the windows might get "reshuffled" around in unexpected ways
---  * preserveRelativeArea - (optional) if `true`, preserve the relative area among windows; that is, if window A is currently twice as large as window B, the same will be true after both windows have been processed and placed into the rect; if `false` or omitted, all windows will have the same area (= area of the rect / number of windows) after processing
---  * animationDuration - (optional) the number of seconds to animate the move/resize operations of the windows; if omitted, defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---   * None
---
--- Notes:
---   * To ensure all windows are placed in a row (side by side), use a very small aspect ratio (for "tall and narrow" windows) like 0.01;
---     similarly, to have all windows in a column, use a very large aspect ratio (for "short and wide") like 100
---   * Hidden and minimized windows will be processed as well: the rect will have "gaps" where the invisible windows
---     would lie, that will get filled as the windows get unhidden/unminimized

-- TODO enforce minimum width? (optional arg)

local function tileWindows(windows,rect,desiredAspect,processInOrder,preserveRelativeArea,animationDuration)
  if type(windows)~='table' then error('windows must be a list of hs.window objects',2)end
  if #windows==0 then return end
  if getmetatable(windows[1])~=hs.getObjectMetatable'hs.window' then error('windows must be a list of hs.window objects',2)end
  local ok,res=pcall(geom.new,rect)
  if not ok or geom.type(res)~='rect' or res.area==0 then error('rect must be a valid hs.geometry rect: '..tostring(res),2)
  else rect=res end
  if not desiredAspect then desiredAspect=1
  elseif type(desiredAspect)~='number' then desiredAspect=geom.new(desiredAspect).aspect end

  log.df('tiling %d windows into %s, aspect=%.2f%s',#windows,rect.string,desiredAspect,preserveRelativeArea and ', preserve relative area' or '')
  local wins={}
  local totalArea,avgWindowArea=0,1/#windows
  local unionRect=windows[1]:frame()
  for i,w in ipairs(windows) do
    local f=w:frame()
    if preserveRelativeArea then totalArea=totalArea+f.area end
    unionRect=unionRect:union(f)
    wins[{frame=f,area=f.area,window=w,idx=i}]=true
  end
  log.vf('window union rect: %s',unionRect.string)
  for win in pairs(wins) do
    win.area=preserveRelativeArea and win.area/totalArea or avgWindowArea
    win.posInUnion=win.frame:toUnitRect(unionRect).center
    log.vf('window #%d at %.2f,%.2f, area %.2f',win.idx,win.posInUnion.x,win.posInUnion.y,win.area)
  end

  local rectToFill=geom(0,0,1,1)
  local doneWindows={}

  repeat
    local rowWindows,rowAspectRatio,rowSwitchedRectToFill={},{},{}
    for dir=1,2 do
      local fillVertically=dir==1
      local desiredRowAspect=fillVertically and desiredAspect or 1/desiredAspect
      local adjustAspect=fillVertically and rect.aspect or 1/rect.aspect
      log.vf('finding optimal %s to fill %s',fillVertically and 'column' or 'row',rectToFill.string)
      local switchedRectToFill=fillVertically and rectToFill or switchedwh(rectToFill)
      rowSwitchedRectToFill[dir]=switchedRectToFill
      local rowDone,bestWidth
      local testn=0
      rowWindows[dir]={}

      repeat
        --TODO seriously: *at least* refactor this loop out to "makeRow" or something
        -- add another window to the row until optimality drops
        local windowsRemaining={}
        for win in pairs(wins) do windowsRemaining[win]=true end
        testn=testn+1
        local testArea,testWindows=0,{}
        for i=1,testn do
          local win
          if processInOrder then win=nextWindow(windowsRemaining)
            log.vf('try %d/%d, pick #%d (area %.2f)',i,testn,win.idx,win.area)
          else
            local centroid=getCentroid(switchedRectToFill,avgWindowArea,i,testn,fillVertically)
            win=closestWindow(windowsRemaining,centroid)
            log.vf('try %d/%d, pick #%d (area %.2f, centroid %.2f,%.2f, distance %.2f)',i,testn,win.idx,win.area,centroid.x,centroid.y,win.posInUnion:distance(centroid))
          end
          testWindows[i]=win
          testArea=testArea+win.area
          windowsRemaining[win]=nil
        end
        local testFrame={x=switchedRectToFill.x,y=switchedRectToFill.y,w=testArea/switchedRectToFill.h}
        local testAspectRatio=1
        -- find optimality
        for _,win in ipairs(testWindows) do
          testFrame.h=win.area/testFrame.w
          local winAspectRatio=(testFrame.w/testFrame.h) * adjustAspect / desiredRowAspect
          --local __=geom(testFrame)
          if winAspectRatio>1 then winAspectRatio=1/winAspectRatio end
          testAspectRatio=min(testAspectRatio,winAspectRatio) --accumulate worst ratio aspect:desiredAspect (optimality)
          win.testFrame=geom.copy(testFrame)
          testFrame.y=testFrame.y+testFrame.h --move frame down for next win in column
        end
        rowAspectRatio[dir]=max(rowAspectRatio[dir] or testAspectRatio,testAspectRatio) -- best so far
        if not next(windowsRemaining) and testAspectRatio<rowAspectRatio[dir] then
          --if this is the last window and it was refused, consider what happens when it goes into its own row
          local lastRect=geom.copy(switchedRectToFill)
          lastRect.x=lastRect.x+bestWidth lastRect.x2=switchedRectToFill.x2
          local lastAspect=fillVertically and lastRect.aspect or 1/lastRect.aspect
          local lastAspectRatio=lastAspect*adjustAspect/desiredRowAspect
          if lastAspectRatio>1 then lastAspectRatio=1/lastAspectRatio end
          rowAspectRatio[dir]=min(lastAspectRatio,rowAspectRatio[dir])
        end
        log.vf('optimality for %s of %d: %.0f%%',fillVertically and 'column' or 'row',testn,testAspectRatio*100)
        if testAspectRatio<rowAspectRatio[dir] then --whops, things got worse, undo
          rowDone=true
        else --yay, improvement, save it
          rowWindows[dir]={}
          for _,win in ipairs(testWindows) do win[dir]=win.testFrame rowWindows[dir][win]=true end
          bestWidth=testFrame.w
          rowAspectRatio[dir]=testAspectRatio
        end
        if not next(windowsRemaining) then rowDone=true end
      until rowDone

      log.vf('%s done, %d windows, optimality %.0f%%',fillVertically and 'column' or 'row',tlen(rowWindows[dir]),rowAspectRatio[dir]*100)
    end
    local bestDir=rowAspectRatio[1]>rowAspectRatio[2] and 1 or 2
    local wasVertical=bestDir==1
    local bestWindows=rowWindows[bestDir]
    log.vf('picking %s of %d windows, optimality %.0f%%',wasVertical and 'column' or 'row',tlen(bestWindows),rowAspectRatio[bestDir]*100)
    local tempRect=rowSwitchedRectToFill[bestDir]
    --save the optimal row: get the row frame
    local tempWindowFrame=next(bestWindows)[bestDir]
    local switchedRowFrame=geom(tempRect.x,tempRect.y,tempWindowFrame.w,tempRect.h)

    for win in pairs(bestWindows) do
      if not wasVertical then
        --switch around the frame
        win.bestFrame=geom(rectToFill.x+win[bestDir].y-rectToFill.y,rectToFill.y,win[bestDir].h,win[bestDir].w)
      else win.bestFrame=win[bestDir] end
      log.vf('window #%d -> %s',win.idx,win.bestFrame.string)
      doneWindows[#doneWindows+1]=win
      wins[win]=nil
    end

    --local rowFrame=geom(rectToFill.y,rectToFill.y,wasVertical and tempWindowFrame.w or rectToFill.w,wasVertical and rectToFill.h or tempWindowFrame.h)
    --get the remaining rect to fill
    local temp=rectToFill.x2y2
    rectToFill:move(wasVertical and switchedRowFrame.w or 0,wasVertical and 0 or switchedRowFrame.w)
    rectToFill.x2y2=temp

  until not next(wins)

  --finally, apply
  --  hs.assert(#doneWindows==#windows,'tileWindows: some windows were not processed',windows)
  for _,win in ipairs(doneWindows) do
    local w,frame=win.window,win.bestFrame:fromUnitRect(rect):floor()
    if w:frame()~=frame then
      log.f('%s (%d) -> %s',w:application():name(),w:id(),frame.string)
      w:setFrame(frame,animationDuration)
    end
  end
end

return {tileWindows=tileWindows,setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel}
