--- === hs.logger ===
---
--- Simple logger for debugging purposes
---
--- Note: "methods" in this module are actually "static" functions - see `hs.logger.new()`
local date,time = os.date,os.time
local min,max,tmove=math.min,math.max,table.move
local sformat,ssub,slower,srep,sfind=string.format,string.sub,string.lower,string.rep,string.find
local type,select,rawget,rawset,print,printf=type,select,rawget,rawset,print,hs.printf

local ERROR,WARNING,INFO,DEBUG,VERBOSE=1,2,3,4,5
local MAXLEVEL=VERBOSE
local LEVELS={nothing=0,error=ERROR,warning=WARNING,info=INFO,debug=DEBUG,verbose=VERBOSE}
local function toLogLevel(lvl)
  if type(lvl)=='string' then
    return LEVELS[slower(lvl)] or error('invalid log level',3)
  elseif type(lvl)=='number' then
    return max(0,min(MAXLEVEL,lvl))
  else error('loglevel must be a string or a number',3) end
end

local LEVELFMT={{'ERROR:',''},{'** Warning:',''},{'',''},{'','    '},{'','        '}}
local lasttime,lastid=0
local idlen,idf,idempty=10,'%10.10s:','           '
local timeempty='        '

local logger = {} -- module
local instances=setmetatable({},{__mode='kv'})

--- hs.logger.setGlobalLogLevel(lvl)
--- Function
--- Sets the log level for all logger instances (including objects' loggers)
---
--- Parameters:
---  * lvl
---
--- Returns:
---  * None
logger.setGlobalLogLevel=function(lvl)
  lvl=toLogLevel(lvl)
  for log in pairs(instances) do
    log.setLogLevel(lvl)
  end
end

--- hs.logger.setModulesLogLevel(lvl)
--- Function
--- Sets the log level for all currently loaded modules
---
--- Parameters:
---  * lvl
---
--- Returns:
---  * None
---
--- Notes:
---  * This function only affects *module*-level loggers, object instances with their own loggers (e.g. windowfilters) won't be affected;
---    you can use `hs.logger.setGlobalLogLevel()` for those
logger.setModulesLogLevel=function(lvl)
  for ext,mod in pairs(package.loaded) do
    if string.sub(ext,1,3)=='hs.' and mod~=hs then
      if mod.setLogLevel then mod.setLogLevel(lvl) end
    end
  end
end

local history={}
local histIndex,histSize=0,0
--- hs.logger.historySize([size]) -> number
--- Function
--- Sets or gets the global log history size
---
--- Parameters:
---  * size - (optional) the desired number of log entries to keep in the history;
---    if omitted, will return the current size; the starting value is 0 (disabled)
---
--- Returns:
---  * the current or new history size
---
--- Notes:
---  * if you change history size (other than from 0) after creating any logger instances, things will likely break
logger.historySize=function(sz)
  if sz==nil then return histSize end
  if type(sz)~='number' then error('size must be a number')end
  sz=min(sz,10000) histSize=sz
  return sz
end
local function store(s)
  histIndex=histIndex+1
  if histIndex>histSize then histIndex=1 end
  history[histIndex]=s
end

--- hs.logger.history() -> list of log entries
--- Function
--- Returns the global log history
---
--- Parameters:
---  * None
---
--- Returns:
---  * a list of (at most `hs.logger.historySize()`) log entries produced by all the logger instances, in chronological order;
---    each entry is a table with the following fields:
---    * time - timestamp in seconds since the epoch
---    * level - a number between 1 (error) and 5 (verbose)
---    * id - a string containing the id of the logger instance that produced this entry
---    * message - a string containing the logged message
logger.history=function()
  local start=histIndex+1
  if not history[start] then return history end
  if start>histSize then start=1
  else tmove(history,1,start-1,histSize+1) end -- append
  tmove(history,start,histSize+start,1) --shift down
  tmove(history,histSize*2+1,histSize*2+start,histSize+1) --cleanup
  histIndex=histSize
  return history
end

local formatID = function(theID)
  if utf8.len(theID) > idlen then
    if logger.truncateID == "head" then
      theID = ssub(theID, -idlen)
      if logger.truncateIDWithEllipsis then
          theID = "…" .. ssub(theID, 2)
      end
    else
      theID = ssub(theID, 1, idlen)
      if logger.truncateIDWithEllipsis then
          theID = ssub(theID, 1, idlen - 1) .. "…"
      end
    end
    theID = theID .. ":"
  else
    theID = sformat(idf,theID)
  end
  return theID
end

--- hs.logger.printHistory([entries[, level[, filter[, caseSensitive]]]])
--- Function
--- Prints the global log history to the console
---
--- Parameters:
---  * entries - (optional) the maximum number of entries to print; if omitted, all entries in the history will be printed
---  * level - (optional) the desired log level (see `hs.logger:setLogLevel()`); if omitted, defaults to `verbose`
---  * filter - (optional) a string to filter the entries (by logger id or message) via `string.find` plain matching
---  * caseSensitive - (optional) if true, filtering is case sensitive
---
--- Returns:
---  * None
logger.printHistory=function(entries,lvl,flt,case)
  entries=entries or histSize
  local hist=logger.history()
  local filt=hist
  if flt and not case then flt=slower(flt) end
  if lvl or flt then
    lvl=toLogLevel(lvl or 5)
    filt={}
    for _,e in ipairs(hist) do
      if e.level<=lvl and (not flt or sfind(case and e.id or slower(e.id),flt,1,true) or sfind(case and e.mesage or slower(e.message),flt,1,true)) then
        filt[#filt+1]=e
      end
    end
  end
  for i=max(1,#filt-entries+1),#filt do
    local e=filt[i]
    printf('%s %s%s %s%s',date('%X',e.time),LEVELFMT[e.level][1],formatID(e.id),LEVELFMT[e.level][2],e.message)
--     printf('%s %s%s %s%s',date('%X',e.time),LEVELFMT[e.level][1],sformat(idf,e.id),LEVELFMT[e.level][2],e.message)
  end
end

-- logger
local lf = function(loglevel,lvl,id,fmt,...)
  if histSize<=0 and loglevel<lvl then return end
  local ct = time()
  local msg=sformat(fmt,...)
  if histSize>0 then store({time=ct,level=lvl,id=id,message=msg}) end
  if loglevel<lvl then return end
  id=formatID(id)
--   id=sformat(idf,id)
  local stime = timeempty
  if ct-lasttime>0 or lvl<3 then stime=date('%X') lasttime=ct end
  if id==lastid and lvl>3 then id=idempty else lastid=id end
  if lvl==ERROR then print'********' end
  printf('%s %s%s %s%s',stime,LEVELFMT[lvl][1],id,LEVELFMT[lvl][2],msg)
  if lvl==ERROR then print'********' end
end
local l = function(loglevel,lvl,id,...)
  if histSize>0 or loglevel>=lvl then return lf(loglevel,lvl,id,srep('%s',select('#',...),' '),...) end
end

logger.idLength=function(len)
  if len==nil then return idlen end
  if type(len)~='number' or len<4 then error('len must be a number >=4',2)end
  len=min(len,40) idlen=len
  idf='%'..len..'.'..len..'s:'
  idempty=srep(' ',len+1)
end

logger.truncateID = "tail"
logger.truncateIDWithEllipsis = false

--- hs.logger.defaultLogLevel
--- Variable
--- Default log level for new logger instances.
---
--- The starting value is 'warning'; set this (to e.g. 'info') at the top of your `init.lua` to affect
--- all logger instances created without specifying a `loglevel` parameter
logger.defaultLogLevel = 'warning'

--- hs.logger.new(id, loglevel) -> logger
--- Function
--- Creates a new logger instance
---
--- Parameters:
---  * id - a string identifier for the instance (usually the module name)
---  * loglevel - (optional) can be 'nothing', 'error', 'warning', 'info', 'debug', or 'verbose', or a corresponding number
---    between 0 and 5; uses `hs.logger.defaultLogLevel` if omitted
---
--- Returns:
---  * the new logger instance
---
--- Notes:
---  * the logger instance created by this method is not a regular object, but a plain table with "static" functions;
---    therefore, do not use the colon syntax for so-called "methods" in this module (as in `mylogger:setLogLevel(3)`);
---    you must instead use the regular dot syntax: `mylogger.setLogLevel(3)`
---
--- Example:
--- ```lua
--- local log = hs.logger.new('mymodule','debug')
--- log.i('Initializing') -- will print "[mymodule] Initializing" to the console
--- ```
function logger.new(id,loglevel)
  if type(id)~='string' then error('id must be a string',2) end
  --  id=sformat('%10s','['..sformat('%.8s',id)..']')
  local function setLogLevel(lvl)loglevel=toLogLevel(lvl)end
  setLogLevel(loglevel or logger.defaultLogLevel)
  local r = {
    setLogLevel = setLogLevel,
    getLogLevel = function()return loglevel end,
    e = function(...) return l(loglevel,ERROR,id,...) end,
    w = function(...) return l(loglevel,WARNING,id,...) end,
    i = function(...) return l(loglevel,INFO,id,...) end,
    d = function(...) return l(loglevel,DEBUG,id,...) end,
    v = function(...) return l(loglevel,VERBOSE,id,...) end,

    ef = function(fmt,...) return lf(loglevel,ERROR,id,fmt,...) end,
    wf = function(fmt,...) return lf(loglevel,WARNING,id,fmt,...) end,
    f = function(fmt,...) return lf(loglevel,INFO,id,fmt,...) end,
    df = function(fmt,...) return lf(loglevel,DEBUG,id,fmt,...) end,
    vf = function(fmt,...) return lf(loglevel,VERBOSE,id,fmt,...) end,
  }
  r.log=r.i r.logf=r.f
  instances[r]=true
  return setmetatable(r,{
    __index=function(t,k)
      return k=='level' and loglevel or rawget(t,k)
    end,
    __newindex=function(t,k,v)
      if k=='level' then return setLogLevel(v) else return rawset(t,k,v) end
    end
  })
end
return logger

--- hs.logger:setLogLevel(loglevel)
--- Method
--- Sets the log level of the logger instance
---
--- Parameters:
---  * loglevel - can be 'nothing', 'error', 'warning', 'info', 'debug', or 'verbose'; or a corresponding number between 0 and 5
---
--- Returns:
---  * None

--- hs.logger:getLogLevel() -> number
--- Method
--- Gets the log level of the logger instance
---
--- Parameters:
---  * None
---
--- Returns:
---  * The log level of this logger as a number between 0 and 5

--- hs.logger.level
--- Field
--- The log level of the logger instance, as a number between 0 and 5

--- hs.logger:e(...)
--- Method
--- Logs an error to the console
---
--- Parameters:
---  * ... - one or more message strings
---
--- Returns:
---  * None

--- hs.logger:ef(fmt,...)
--- Method
--- Logs a formatted error to the console
---
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt
---
--- Returns:
---  * None

--- hs.logger:w(...)
--- Method
--- Logs a warning to the console
---
--- Parameters:
---  * ... - one or more message strings
---
--- Returns:
---  * None

--- hs.logger:wf(fmt,...)
--- Method
--- Logs a formatted warning to the console
---
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt
---
--- Returns:
---  * None

--- hs.logger:i(...)
--- Method
--- Logs info to the console
---
--- Parameters:
---  * ... - one or more message strings
---
--- Returns:
---  * None

--- hs.logger:f(fmt,...)
--- Method
--- Logs formatted info to the console
---
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt
---
--- Returns:
---  * None

--- hs.logger:d(...)
--- Method
--- Logs debug info to the console
---
--- Parameters:
---  * ... - one or more message strings
---
--- Returns:
---  * None

--- hs.logger:df(fmt,...)
--- Method
--- Logs formatted debug info to the console
---
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt
---
--- Returns:
---  * None

--- hs.logger:v(...)
--- Method
--- Logs verbose info to the console
---
--- Parameters:
---  * ... - one or more message strings
---
--- Returns:
---  * None

--- hs.logger:vf(fmt,...)
--- Method
--- Logs formatted verbose info to the console
---
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt
---
--- Returns:
---  * None

