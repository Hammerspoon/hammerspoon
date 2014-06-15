print("done")

__api.hotkey_setup(function(uid)
    print("got: " .. tostring(uid))
end)

local uid, carbonkey = __api.hotkey_register(true, true, true, false, "s")

print(uid, carbonkey)
