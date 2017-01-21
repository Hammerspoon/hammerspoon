---
--- Tests hs.finalcutpro
---

local fcpx 			= require("hs.finalcutpro")
local inspect 		= require("hs.inspect")
local log 			= require("hs.logger").new("fcptest")

local function test()
	local ui = fcpx.applicationUI()
	log.d("UI: \n"..inspect(ui.element:buildTree()))
end

return test