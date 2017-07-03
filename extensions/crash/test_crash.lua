hs.crash = require("hs.crash")

function testResidentSize()
local value = hs.crash.residentSize()
assertIsNumber(value)
return success()
end

function testThrowTheWorld()
hs.crash.throwObjCException("foo", "bar")
end
