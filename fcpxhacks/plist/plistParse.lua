-- plistParser (https://codea.io/talk/discussion/1269/code-plist-parser)
-- version 1.01
--
-- based on an XML parser by Roberto Ierusalimschy at:
-- lua-users.org/wiki/LuaXml
--
-- Takes a string-ified .plist file as input, and outputs
-- a table. Nested dictionaries and arrays are parsed into
-- subtables. Table structure will match the structure of
-- the .plist file
--
-- usage:
-- local plistStr = <string-ified plist file>
-- local plistTable = plistParse(plistStr)
--

local plp = {}

function plp.nextTag(s, i)
    return string.find(s, "<(%/?)([%w:]+)(%/?)>", i)
end

function plp.array(s, i)
    local arr, nextTag, array, dictionary = {}, plp.nextTag, plp.array, plp.dictionary
    local ni, j, c, label, empty

    while true do
        ni, j, c, label, empty = nextTag(s, i)
        assert(ni)

        if c == "" then
            if empty == "/" then
                if label == "dict" or label == "array" then
                    arr[#arr+1] = {}
                else
                    arr[#arr+1] = (label == "true") and true or false
                end
            elseif label == "array" then
                arr[#arr+1], i, j = array(s, j+1)
            elseif label == "dict" then
                arr[#arr+1], i, j = dictionary(s, j+1)
            else
                i = j + 1
                ni, j, c, label, empty = nextTag(s, i)

                local val = string.sub(s, i, ni-1)
                if label == "integer" or label == "real" then
                    arr[#arr+1] = tonumber(val)
                else
                    arr[#arr+1] = val
                end
            end
        elseif c == "/" then
            assert(label == "array")
            return arr, j+1, j
        end

        i = j + 1
    end
end

function plp.dictionary(s, i)
    local dict, nextTag, array, dictionary = {}, plp.nextTag, plp.array, plp.dictionary
    local ni, j, c, label, empty

    while true do
        ni, j, c, label, empty = nextTag(s, i)
        assert(ni)

        if c == "" then
            if label == "key" then
                i = j + 1
                ni, j, c, label, empty = nextTag(s, i)
                assert(c == "/" and label == "key")

                local key = string.sub(s, i, ni-1)

                i = j + 1
                ni, j, c, label, empty = nextTag(s, i)

                if empty == "/" then
                    if label == "dict" or label == "array" then
                        dict[key] = {}
                    else
                        dict[key] = (label == "true") and true or false
                    end
                else
                    if label == "dict" then
                        dict[key], i, j = dictionary(s, j+1)
                    elseif label == "array" then
                        dict[key], i, j = array(s, j+1)
                    else
                        i = j + 1
                        ni, j, c, label, empty = nextTag(s, i)

                        local val = string.sub(s, i, ni-1)
                        if label == "integer" or label == "real" then
                            dict[key] = tonumber(val)
                        else
                            dict[key] = val
                        end
                    end
                end
            end
        elseif c == "/" then
            assert(label == "dict")
            return dict, j+1, j
        end

        i = j + 1
    end
end

local function plistParse(s)
    local i, ni, tag, version, empty = 0

    while label ~= "plist" do
        ni, i, label, version = string.find(s, "<([%w:]+)(.-)>", i+1)


        -- BUG: Something is going funky here with complex plist's:

        if ni == nil then
        	print("Fatal Error: Something has gone wrong in plistParse. Giving up.")
        	return nil
        else
        	assert(ni)
        end

    end

    ni, i, _, label, empty = plp.nextTag(s, i)

    if empty == "/" then
        return {}
    elseif label == "dict" then
        return plp.dictionary(s, i+1)
    elseif label == "array" then
        return plp.array(s, i+1)
    end
end

return plistParse