api.doc.doc = {__doc = "Documentation system."}

api.doc.doc.doc = {"doc(thing)", "Prints documentation on the given thing."}
function doc(item)
  if type(item) ~= "table" then
    -- wat
    print("It appears that " .. tostring(item) .. " is not in the documentation system.")
  elseif item.__doc and type(item.__doc) == "string" then
    -- its a group
    print(item.__doc)

    for k, child in pairs(item) do
      if k ~= "__doc" then
        print(child[1])
      end
    end
  elseif # item == 2 and type(item[1] == "string") and type(item[2] == "string") then
    -- its an item
    print(item[1])
    print(item[2])
  else
    -- dunno!
    print("Don't know what " .. tostring(item) .. " is supposed to be. Sorry!")
  end
end

function api.generatedocs(path)
  local file = io.open(path, "w")
  for groupname, group in pairs(api.doc) do
    for itemname, item in pairs(group) do
      local def, docstring = item[1], item[2]
      if def and docstring then
        file:write(def .. " -- " .. docstring .. "\n")
      end
    end
    file:write("\n")
  end
  file:close()
end
