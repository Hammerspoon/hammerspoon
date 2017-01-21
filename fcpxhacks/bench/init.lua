
--------------------------------------------------------------------------------
-- TIME FUNCTION EXECUTION:
-- Use this to benchmark sections of code. Wrap them in a function inside this
-- function call. Eg:
--
-- local _bench = require("hs.bench")	
-- 
-- local foo = _bench("Foo Test", function()
--     return do.somethingHere()
-- end) --_bench
--------------------------------------------------------------------------------
-- local clock = os.clock
local clock = require("hs.timer").secondsSinceEpoch
local _timeindent = 0
local _timelog = {}

function bench(label, fn, ...)
	loops = loops or 1
	local result = nil
	local t = _timelog
	
	t[#t+1] = {label = label, indent = _timeindent}
	_timeindent = _timeindent + 2
	local start = clock()
	for i=1,loops do result = fn(...) end
	local stop = clock()
	local total = stop - start
	_timeindent = _timeindent - 2
	t[#t+1] = {label = label, indent = _timeindent, value = total}
	
	if _timeindent == 0 then
		-- print when we are back at zero indents.
		local text = nil
		for i,v in ipairs(_timelog) do
			text = v.value and string.format("%0.3fms", v.value*1000) or "START"
			debugMessage(string.format("%"..v.indent.."s%40s: %"..(30-v.indent).."s", "", v.label, text))
		end
		-- clear the log
		_timelog = {}
	end
	
	return result
end

return bench