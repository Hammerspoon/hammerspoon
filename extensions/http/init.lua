-- Simple loader for the Objective C code
local http = require("hs.http.internal")

--- hs.http.get(url, headers) -> int, string, table
--- Function
--- This is a simple wrapper function for GET requests
---
--- Parameters
---  * url - A string representing the URL
---  * headers - A table containing string keys and values representing the request headers
---
--- Returns:
---  * An int representing the http response status
---  * a string containing the response body
---  * a table representing the respinse headers
http.get = function(url,headers)
	return http.doRequest(url,"GET",nil,headers)
end

--- hs.http.post(url, data, headers) -> int, string, table
--- Function
--- This is a simple wrapper function for POST requests
---
--- Parameters
---  * url - A string representing the URL
---  * data - A string representing the request body
---  * headers - A table containing string keys and values representing the request headers
---
--- Returns:
---  * An int representing the http response status
---  * a string containing the response body
---  * a table representing the respinse headers
http.post = function(url,data,headers)
	return http.doRequest(url,"POST",data,headers)
end

http.asyncGet = function(url, headers, callback)
	http.doAsyncRequest(url,"GET",nil,headers,callback)
end

http.asyncPost = function(url, data, headers, callback)
	http.doAsyncRequest(url, "POST", data, headers, callback)
end

return http