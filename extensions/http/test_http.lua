-- hs.http = require("hs.http")
-- hs = require("hs")

_G["respCode"] = 0
_G["respBody"] = ""
_G["respHeaders"] = {}

_G["callback"] = function(code, body, headers)
  _G["respCode"] = code
  _G["respBody"] = body
  _G["respHeaders"] = headers
end

function testHttpDoAsyncRequestWithCachePolicyParamValues()
  if (type(_G["respCode"]) == "number" and type(_G["respBody"]) == "string" and type(_G["respHeaders"]) == "table" and _G["respCode"] > 0) then
    -- check return code
    assertIsEqual(200, _G["respCode"])
    assertGreaterThan(0, string.len(_G["respBody"]))
    return success()
  else
    return "Waiting for success..."
  end
end

-- check request should be redirected if [enableRedirect|cachePolicy] param is given as cachePolicy
--  check point: response code == 200
function testHttpDoAsyncRequestWithCachePolicyParam()
  _G["respCode"] = 0
  _G["respBody"] = ""
  _G["respHeaders"] = {}
  hs.http.doAsyncRequest(
    'http://google.com',
    'GET',
    nil,
    { ['accept-language'] = 'en', ['user-agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.88 Safari/537.36', Accept = '*/*' },
    _G["callback"],
    'protocolCachePolicy'
  )

  return success()
end

function testHttpDoAsyncRequestWithoutEnableRedirectAndCachePolicyParamValues()
  if (type(_G["respCode"]) == "number" and type(_G["respBody"]) == "string" and type(_G["respHeaders"]) == "table" and _G["respCode"] > 0) then
    -- check return code
    assertIsEqual(200, _G["respCode"])
    assertGreaterThan(0, string.len(_G["respBody"]))
    return success()
  else
    return "Waiting for success..."
  end
end

-- check request should be redirected if [enableRedirect|cachePolicy] param is not given.
--  check point: response code == 200
function testHttpDoAsyncRequestWithoutEnableRedirectAndCachePolicyParam()
  _G["respCode"] = 0
  _G["respBody"] = ""
  _G["respHeaders"] = {}
  hs.http.doAsyncRequest(
    'http://google.com',
    'GET',
    nil,
    { ['accept-language'] = 'en', ['user-agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.88 Safari/537.36', Accept = '*/*' },
    _G["callback"]
  )

  return success()
end

function testHttpDoAsyncRequestWithRedirectionValues()
  if (type(_G["respCode"]) == "number" and type(_G["respBody"]) == "string" and type(_G["respHeaders"]) == "table" and _G["respCode"] > 0) then
    -- check return code
    assertIsEqual(200, _G["respCode"])
    assertGreaterThan(0, string.len(_G["respBody"]))
    return success()
  else
    return "Waiting for success..."
  end
end

-- check request should be redirected if [enableRedirect|cachePolicy] param is set to true as enableRedirect
--  check point: response code == 200
function testHttpDoAsyncRequestWithRedirection()
  _G["respCode"] = 0
  _G["respBody"] = ""
  _G["respHeaders"] = {}
  hs.http.doAsyncRequest(
    'http://google.com',
    'GET',
    nil,
    { ['accept-language'] = 'en', ['user-agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.88 Safari/537.36', Accept = '*/*' },
    _G["callback"],
    true
  )

  return success()
end

function testHttpDoAsyncRequestWithoutRedirectionValues()
  if (type(_G["respCode"]) == "number" and type(_G["respBody"]) == "string" and type(_G["respHeaders"]) == "table" and _G["respCode"] > 0) then
    -- check return code
    assertIsEqual(301, _G["respCode"])
    return success()
  else
    return "Waiting for success..."
  end
end

-- check request should not be redirected if [enableRedirect|cachePolicy] param is set to false as enableRedirect
--  check point: response code == 301
function testHttpDoAsyncRequestWithoutRedirection()
  _G["respCode"] = 0
  _G["respBody"] = ""
  _G["respHeaders"] = {}
  hs.http.doAsyncRequest(
    'http://google.com',
    'GET',
    nil,
    { ['accept-language'] = 'en', ['user-agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.88 Safari/537.36', Accept = '*/*' },
    _G["callback"],
    false
  )

  return success()
end
