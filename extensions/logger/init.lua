--- === hs.logger ===
---
--- Simple logger for debugging purposes

-- * This can mainly be useful for diagnosing complex scripts; however there is some overhead involved.
-- * Implementing a mock version could help, although not completely as lua lacks lazy evaluation

local date,time = os.date,os.time
local format,sub=string.format,string.sub
local select,print,concat,min=select,print,table.concat,math.min
local fnutils=require'hs.fnutils'

local          ERROR , WARNING , INFO , DEBUG , VERBOSE  =1,2,3,4,5
local levels={'error','warning','info','debug','verbose'} levels[0]='nothing'
local slevels={{'ERROR',''},{'Warn:',''},{'',''},{'','-- '},{'','    -- '}}
local lastid
local lasttime=0

local fmt={'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s',}
local lf = function(loglevel,lvl,id,fmt,...)
  if loglevel<lvl then return end
  local ct = time()
  local stime = '        '
  if ct-lasttime>0 or lvl<3 then stime=date('%X') lasttime=ct end
  if id==lastid and lvl>3 then id='          ' else lastid=id end
  print(format('%s %s%s %s'..fmt,stime,slevels[lvl][1],id,slevels[lvl][2],...))
end
local l = function(loglevel,lvl,id,...)
  if loglevel>=lvl then return lf(loglevel,lvl,id,concat(fmt,' ',1,min(select('#',...),#fmt)),...) end
end


--- hs.logger.new(id, loglevel) -> logger
--- Function
--- Creates a new logger instance
---
--- Parameters:
---  * id - a string identifier for the instance (usually the module name)
---  * loglevel - can be 'nothing', 'error', 'warning', 'info', 'debug', or 'verbose'; or a corresponding number between 0 and 5; defaults to 'warning' if omitted
---
--- Returns:
---  * the new logger instance
---
--- Usage:
---  * `local log = hs.logger.new('mymodule','debug')`
---  * `log.i('Initializing')` -- will print `[mymodule] Initializing` to the console

local function new(id,loglevel)
  if type(id)~='string' then error('id must be a string',2) end
  id=format('%10s','['..format('%.8s',id)..']')
  local function setLogLevel(lvl)
    if type(lvl)=='string' then
      local i = fnutils.indexOf(levels,string.lower(lvl))
      if i then loglevel = i
      else error('loglevel must be one of '..table.concat(levels,', ',0,#levels),2) end
    elseif type(lvl)=='number' then
      if lvl<0 or lvl>#levels then error('loglevel must be between 0 and '..#levels,2) end
      loglevel=lvl
    else error('loglevel must be a string or a number',2) end
  end
  if not loglevel then loglevel=2 else setLogLevel(loglevel) end

  local r = {
    setLogLevel = setLogLevel,
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
  return r
end
return {new=new}

--- hs.logger:setLogLevel(loglevel)
--- Method
--- Sets the log level of the logger instance
---
--- Parameters:
---  * loglevel - can be 'nothing', 'error', 'warning', 'info', 'debug', or 'verbose'; or a corresponding number between 0 and 5

--- hs.logger:e(...)
--- Method
--- Logs an error to the console
--- 
--- Parameters:
---  * ... - one or more message strings

--- hs.logger:ef(fmt,...)
--- Method
--- Logs a formatted error to the console
--- 
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt

--- hs.logger:w(...)
--- Method
--- Logs a warning to the console
--- 
--- Parameters:
---  * ... - one or more message strings

--- hs.logger:wf(fmt,...)
--- Method
--- Logs a formatted warning to the console
--- 
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt

--- hs.logger:i(...)
--- Method
--- Logs info to the console
--- 
--- Parameters:
---  * ... - one or more message strings

--- hs.logger:f(fmt,...)
--- Method
--- Logs formatted info to the console
--- 
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt

--- hs.logger:d(...)
--- Method
--- Logs debug info to the console
--- 
--- Parameters:
---  * ... - one or more message strings

--- hs.logger:df(fmt,...)
--- Method
--- Logs formatted debug info to the console
--- 
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt

--- hs.logger:v(...)
--- Method
--- Logs verbose info to the console
--- 
--- Parameters:
---  * ... - one or more message strings

--- hs.logger:vf(fmt,...)
--- Method
--- Logs formatted verbose info to the console
--- 
--- Parameters:
---  * fmt - formatting string as per string.format
---  * ... - arguments to fmt

