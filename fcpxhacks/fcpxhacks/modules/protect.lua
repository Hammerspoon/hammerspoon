--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--              P R O T E C T     S U P P O R T     L I B R A R Y             --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Utility function for protecting a table from being modified.
--
-- Module created by David Peterson (https://github.com/randomeizer).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function protect(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function(t, key, value)
            error("attempting to change constant " ..
                   tostring(key) .. " to " .. tostring(value), 2)
        end
    })
end

return protect