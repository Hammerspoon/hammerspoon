local plural = {}
local defaultFunction = nil
-- helper functions

local function assertPresentString(functionName, paramName, value)
  if type(value) ~= 'string' or #value == 0 then
    local msg = "Expected param %s of function %s to be a string, but got %s (a value of type %s) instead"
    error(msg:format(paramName, functionName, tostring(value), type(value)))
  end
end

local function assertNumber(functionName, paramName, value)
  if type(value) ~= 'number' then
    local msg = "Expected param %s of function %s to be a number, but got %s (a value of type %s) instead"
    error(msg:format(paramName, functionName, tostring(value), type(value)))
  end
end

-- transforms "foo bar baz" into {'foo','bar','baz'}
local function words(str)
  local result, length = {}, 0
  str:gsub("%S+", function(word)
    length = length + 1
    result[length] = word
  end)
  return result
end

local function isInteger(n)
  return n == math.floor(n)
end

local function between(value, min, max)
  return value >= min and value <= max
end

local function inside(v, list)
  for i=1, #list do
    if v == list[i] then return true end
  end
  return false
end


-- pluralization functions

local pluralization = {}

local f1 = function(n)
  return n == 1 and "one" or "other"
end
pluralization[f1] = words([[
  af asa bem bez bg bn brx ca cgg chr da de dv ee el
  en eo es et eu fi fo fur fy gl gsw gu ha haw he is
  it jmc kaj kcg kk kl ksb ku lb lg mas ml mn mr nah
  nb nd ne nl nn no nr ny nyn om or pa pap ps pt rm
  rof rwk saq seh sn so sq ss ssy st sv sw syr ta te
  teo tig tk tn ts ur ve vun wae xh xog zu
]])

local f2 = function(n)
  return (n == 0 or n == 1) and "one" or "other"
end
pluralization[f2] = words("ak am bh fil guw hi ln mg nso ti tl wa")

local f3 = function(n)
  if not isInteger(n) then return 'other' end
  return (n == 0 and "zero") or
         (n == 1 and "one") or
         (n == 2 and "two") or
         (between(n % 100, 3, 10) and "few") or
         (between(n % 100, 11, 99) and "many") or
         "other"
end
pluralization[f3] = {'ar'}

local f4 = function(n)
  return "other"
end
pluralization[f4] = words([[
  az bm bo dz fa hu id ig ii ja jv ka kde kea km kn
  ko lo ms my root sah ses sg th to tr vi wo yo zh
]])

local f5 = function(n)
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100
  return (n_10 == 1 and n_100 ~= 11 and 'one') or
         (between(n_10, 2, 4) and not between(n_100, 12, 14) and 'few') or
         ((n_10 == 0 or between(n_10, 5, 9) or between(n_100, 11, 14)) and 'many') or
         'other'
end
pluralization[f5] = words('be bs hr ru sh sr uk')

local f6 = function(n)
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100
  return (n_10 == 1 and not inside(n_100, {11,71,91}) and 'one') or
         (n_10 == 2 and not inside(n_100, {12,72,92}) and 'two') or
         (inside(n_10, {3,4,9}) and
          not between(n_100, 10, 19) and
          not between(n_100, 70, 79) and
          not between(n_100, 90, 99)
          and 'few') or
         (n ~= 0 and n % 1000000 == 0 and 'many') or
         'other'
end
pluralization[f6] = {'br'}

local f7 = function(n)
  return (n == 1 and 'one') or
         ((n == 2 or n == 3 or n == 4) and 'few') or
         'other'
end
pluralization[f7] = {'cz', 'sk'}

local f8 = function(n)
  return (n == 0 and 'zero') or
         (n == 1 and 'one') or
         (n == 2 and 'two') or
         (n == 3 and 'few') or
         (n == 6 and 'many') or
         'other'
end
pluralization[f8] = {'cy'}

local f9 = function(n)
  return (n >= 0 and n < 2 and 'one') or
         'other'
end
pluralization[f9] = {'ff', 'fr', 'kab'}

local f10 = function(n)
  return (n == 1 and 'one') or
         (n == 2 and 'two') or
         ((n == 3 or n == 4 or n == 5 or n == 6) and 'few') or
         ((n == 7 or n == 8 or n == 9 or n == 10) and 'many') or
         'other'
end
pluralization[f10] = {'ga'}

local f11 = function(n)
  return ((n == 1 or n == 11) and 'one') or
         ((n == 2 or n == 12) and 'two') or
         (isInteger(n) and (between(n, 3, 10) or between(n, 13, 19)) and 'few') or
         'other'
end
pluralization[f11] = {'gd'}

local f12 = function(n)
  local n_10 = n % 10
  return ((n_10 == 1 or n_10 == 2 or n % 20 == 0) and 'one') or
         'other'
end
pluralization[f12] = {'gv'}

local f13 = function(n)
  return (n == 1 and 'one') or
         (n == 2 and 'two') or
         'other'
end
pluralization[f13] = words('iu kw naq se sma smi smj smn sms')

local f14 = function(n)
  return (n == 0 and 'zero') or
         (n == 1 and 'one') or
         'other'
end
pluralization[f14] = {'ksh'}

local f15 = function(n)
  return (n == 0 and 'zero') or
         (n > 0 and n < 2 and 'one') or
         'other'
end
pluralization[f15] = {'lag'}

local f16 = function(n)
  if not isInteger(n) then return 'other' end
  if between(n % 100, 11, 19) then return 'other' end
  local n_10 = n % 10
  return (n_10 == 1 and 'one') or
         (between(n_10, 2, 9) and 'few') or
         'other'
end
pluralization[f16] = {'lt'}

local f17 = function(n)
  return (n == 0 and 'zero') or
         ((n % 10 == 1 and n % 100 ~= 11) and 'one') or
         'other'
end
pluralization[f17] = {'lv'}

local f18 = function(n)
  return((n % 10 == 1 and n ~= 11) and 'one') or
         'other'
end
pluralization[f18] = {'mk'}

local f19 = function(n)
  return (n == 1 and 'one') or
         ((n == 0 or
          (n ~= 1 and isInteger(n) and between(n % 100, 1, 19)))
          and 'few') or
         'other'
end
pluralization[f19] = {'mo', 'ro'}

local f20 = function(n)
  if n == 1 then return 'one' end
  if not isInteger(n) then return 'other' end
  local n_100 = n % 100
  return ((n == 0 or between(n_100, 2, 10)) and 'few') or
         (between(n_100, 11, 19) and 'many') or
         'other'
end
pluralization[f20] = {'mt'}

local f21 = function(n)
  if n == 1 then return 'one' end
  if not isInteger(n) then return 'other' end
  local n_10, n_100 = n % 10, n % 100

  return ((between(n_10, 2, 4) and not between(n_100, 12, 14)) and 'few') or
         ((n_10 == 0 or n_10 == 1 or between(n_10, 5, 9) or between(n_100, 12, 14)) and 'many') or
         'other'
end
pluralization[f21] = {'pl'}

local f22 = function(n)
  return (n == 0 or n == 1) and 'one' or
         'other'
end
pluralization[f22] = {'shi'}

local f23 = function(n)
  local n_100 = n % 100
  return (n_100 == 1 and 'one') or
         (n_100 == 2 and 'two') or
         ((n_100 == 3 or n_100 == 4) and 'few') or
         'other'
end
pluralization[f23] = {'sl'}

local f24 = function(n)
  return (isInteger(n) and (n == 0 or n == 1 or between(n, 11, 99)) and 'one')
         or 'other'
end
pluralization[f24] = {'tzm'}

local pluralizationFunctions = {}
for f,locales in pairs(pluralization) do
  for _,locale in ipairs(locales) do
    pluralizationFunctions[locale] = f
  end
end

-- public interface

function plural.get(locale, n)
  assertPresentString('i18n.plural.get', 'locale', locale)
  assertNumber('i18n.plural.get', 'n', n)

  local f = pluralizationFunctions[locale] or defaultFunction

  return f(math.abs(n))
end

function plural.setDefaultFunction(f)
  defaultFunction = f
end

function plural.reset()
  defaultFunction = pluralizationFunctions['en']
end

plural.reset()

return plural
