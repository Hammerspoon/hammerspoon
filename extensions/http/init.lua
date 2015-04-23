-- Simple loader for the Objective C code
local http = require("hs.http.internal")

http.get = function(url,headers)
	return http.doRequest(url,"GET",nil,headers)
end

http.post = function(url,data,headers)
	return http.doRequest(url,"POST",data,headers)
end

return http