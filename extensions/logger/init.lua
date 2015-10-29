--- === hs.logger ===
---
--- Simple logger for debugging purposes
---
--- Note: "methods" in this module
local date,time = os.date,os.time
local tconcat,min,max=table.concat,math.min,math.max
local sformat,ssub,slower=string.format,string.sub,string.lower
local select,print,rawget,rawset=select,print,rawget,rawset

local          ERROR , WARNING , INFO , DEBUG , VERBOSE  =1,2,3,4,5
local MAXLEVEL=VERBOSE
--local levels={'error','warning','info','debug','verbose'} levels[0]='nothing'
local LEVELS={nothing=0,error=ERROR,warning=WARNING,info=INFO,debug=DEBUG,verbose=VERBOSE}
local LEVELFMT={{'ERROR',''},{'Warn:',''},{'',''},{'','-- '},{'','    -- '}}
local lastid
local lasttime=0

local FMT={'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s',}
local lf = function(loglevel,lvl,id,fmt,...)
  if loglevel<lvl then return end
  if lvl==ERROR then print'********' end
  local ct = time()
  local stime = '        '
  if ct-lasttime>0 or lvl<3 then stime=date('%X') lasttime=ct end
  if id==lastid and lvl>3 then id='          ' else lastid=id end
  print(sformat('%s %s%s %s'..fmt,stime,LEVELFMT[lvl][1],id,LEVELFMT[lvl][2],...))
  if lvl==ERROR then print'********' end
end
local l = function(loglevel,lvl,id,...)
  if loglevel>=lvl then return lf(loglevel,lvl,id,tconcat(FMT,' ',1,min(select('#',...),#FMT)),...) end
end


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
--- Usage:
--- ```
--- local log = hs.logger.new('mymodule','debug')
--- log.i('Initializing') -- will print "[mymodule] Initializing" to the console
--- ```

local logger = {}

--- hs.logger.defaultLogLevel
--- Variable
--- Default log level for new logger instances.
---
--- The starting value is 'warning'; set this (to e.g. 'info') at the top of your `init.lua` to affect
--- all logger instances created without specifying a `loglevel` parameter
logger.defaultLogLevel = 'warning'

function logger.new(id,loglevel)
  if type(id)~='string' then error('id must be a string',2) end
  id=sformat('%10s','['..sformat('%.8s',id)..']')
  local function setLogLevel(lvl)
    if type(lvl)=='string' then
      loglevel=LEVELS[slower(lvl)] or error('invalid log level',2)
    elseif type(lvl)=='number' then
      loglevel=max(0,min(MAXLEVEL,lvl))
    else error('loglevel must be a string or a number',2) end
  end
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

