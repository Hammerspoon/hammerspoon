pprint = {}


doc.pprint = {__doc = "Simple table printing module."}


doc.pprint.pairs = {"pprint.pairs(tbl)", "Pretty-prints the table."}
function pprint.pairs(tbl)
   print('{')
   for k,v in pairs(tbl) do
      print(k, '=', v)
   end
   print('}')
end

doc.pprint.ipairs = {"pprint.ipairs(tbl)", "Pretty-prints the table as an array."}
function pprint.ipairs(tbl)
   local res = '['
   for _, val in ipairs(tbl) do
      if type(val) == type('') then val = "'" .. val .. "'"
      res = res .. val .. ', '
   end
   res = string.sub(res, 1, -3) .. ']'
   print(res)
end
