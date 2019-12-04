--
-- These globals can be set and accessed:
--
globals = {
    "rawrequire",
}

--
-- These globals can only be accessed:
--
read_globals = {
    "hs",
    "ls",
    "spoon",
}

--
-- Hammerspoon Tests:
--
files["**/test_*.lua"] = {
    read_globals = {
        "assertFalse",
        "assertGreaterThan",
        "assertGreaterThanOrEqualTo",
        "assertIsAlmostEqual",
        "assertIsBoolean",
        "assertIsEqual",
        "assertIsFunction",
        "assertIsNil",
        "assertIsNotNil",
        "assertIsNumber",
        "assertIsString",
        "assertIsTable",
        "assertIsType",
        "assertIsUserdata",
        "assertIsUserdataOfType",
        "assertLessThan",
        "assertLessThanOrEqualTo",
        "assertListsEqual",
        "assertTableNotEmpty",
        "assertTablesEqual",
        "assertTrue",
        "failure",
        "success",
    },
    ignore = {
        "111" -- Setting an undefined global variable
    }
}

--
-- Warnings to ignore:
--
ignore = {
    "631" -- Line is too long.
}