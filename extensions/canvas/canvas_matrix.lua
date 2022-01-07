--- === hs.canvas.matrix ===
---
--- A sub module to `hs.canvas` which provides support for basic matrix manipulations which can be used as the values for `transformation` attributes in the `hs.canvas` module.
---
--- For mathematical reasons that are beyond the scope of this document, a 3x3 matrix can be used to represent a series of manipulations to be applied to the coordinates of a 2 dimensional drawing object.  These manipulations can include one or more of a combination of translations, rotations, shearing and scaling. Within the 3x3 matrix, only 6 numbers are actually required, and this module represents them as the following keys in a Lua table: `m11`, `m12`, `m21`, `m22`, `tX`, and `tY`. For those of a mathematical bent, the 3x3 matrix used within this module can be visualized as follows:
---
---     [  m11,  m12,  0  ]
---     [  m21,  m22,  0  ]
---     [  tX,   tY,   1  ]
---
--- This module allows you to generate the table which can represent one or more of the recognized transformations without having to understand the math behind the manipulations or specify the matrix values directly.
---
--- Many of the methods defined in this module can be used both as constructors and as methods chained to a previous method or constructor. Chaining the methods in this manner allows you to combine multiple transformations into one combined table which can then be assigned to an element in your canvas.
---.
---
--- For more information on the mathematics behind these, you can check the web.  One site I used for reference (but there are many more which go into much more detail) can be found at http://www.cs.trinity.edu/~jhowland/cs2322/2d/2d/.
local USERDATA_TAG = "hs.canvas.matrix"
local module       = require("hs.libcanvasmatrix")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()[USERDATA_TAG] = {
    __type  = USERDATA_TAG,
    __index = module,
    __tostring = function(_)
        return string.format("[ % 10.4f % 10.4f 0 ]\n[ % 10.4f % 10.4f 0 ]\n[ % 10.4f % 10.4f 1 ]",
            _.m11, _.m12, _.m21, _.m22, _.tX, _.tY)
    end,
}

-- Return Module Object --------------------------------------------------

return module
