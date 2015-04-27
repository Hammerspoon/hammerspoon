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

--- hs.http.asyncGet(url, headers, callback)
--- Function
--- Simple wrapper to create an async GET request
---
--- Parameters:
---  * url - A string representing the URL
---  * headers - A table containing the request headers
---  * callback - the callback to be called when the request succeeds or fails
---
--- Notes:
---  * In case of a failure the callback will only be called with two parameters.
---    first a negative integer indicating, there is an error. The second parameter is the error message
---  * In case of success the callback will be called with the parameter status, data, headers
http.asyncGet = function(url, headers, callback)
	http.doAsyncRequest(url,"GET",nil,headers,callback)
end

--- hs.http.asyncPost(url, data, headers, callback)
--- Function
--- Simple wrapper to create an async POST request
---
--- Parameters:
---  * url - A string representing the URL
---  * data - String representing the request body
---  * headers - A table containing the request headers
---  * callback - Function to be called when the request succeeds or fails
---
--- Notes:
---  * See hs.http.asyncGet
http.asyncPost = function(url, data, headers, callback)
	http.doAsyncRequest(url, "POST", data, headers, callback)
end

return http