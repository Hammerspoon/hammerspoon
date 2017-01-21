local variants = {}

local function reverse(arr, length)
  local result = {}
  for i=1, length do result[i] = arr[length-i+1] end
  return result, length
end

local function concat(arr1, len1, arr2, len2)
  for i = 1, len2 do
    arr1[len1 + i] = arr2[i]
  end
  return arr1, len1 + len2
end

function variants.ancestry(locale)
  local result, length, accum = {},0,nil
  locale:gsub("[^%-]+", function(c)
    length = length + 1
    accum = accum and (accum .. '-' .. c) or c
    result[length] = accum
  end)
  return reverse(result, length)
end

function variants.isParent(parent, child)
  return not not child:match("^".. parent .. "%-")
end

function variants.root(locale)
  return locale:match("[^%-]+")
end

function variants.fallbacks(locale, fallbackLocale)
  if locale == fallbackLocale or
     variants.isParent(fallbackLocale, locale) then
     return variants.ancestry(locale)
  end
  if variants.isParent(locale, fallbackLocale) then
    return variants.ancestry(fallbackLocale)
  end

  local ancestry1, length1 = variants.ancestry(locale)
  local ancestry2, length2 = variants.ancestry(fallbackLocale)

  return concat(ancestry1, length1, ancestry2, length2)
end

return variants
