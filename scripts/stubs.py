#!/usr/bin/python
# -*- coding: utf-8 -*-
"""HS autocompletion stubs using EmmyLua annotations for lsp servers"""

import codecs
import json
import os
import re
import sys

typeOverrides = {
    "app": "hs.application",
    "hsminwebtable": "hs.httpserver.hsminweb",
    "notificationobject": "hs.notify",
    "point": "hs.geometry",
    "rect": "hs.geometry",
    "hs.geometry rect": "hs.geometry",
    "size": "hs.geometry",
}


def parseType(module, expr, depth=1):
    t = expr.lower()
    if t in typeOverrides:
        return typeOverrides[t]
    m = re.match(r"^[`'\"]?(hs\.[\w.]+)[`'\"]?([\s+\-\s*]?object)?$", t)
    if m:
        return m.group(1)
    m = re.match(r"^list of [`'\"]?(hs\.[\w.]+)[`'\"]?(\s+objects)?$", t)
    if m:
        return m.group(1) + "[]"
    elif re.match(r"^true|false|bool(ean)?$", t):
        t = "boolean"
    elif t == "string":
        t = "string"
    elif re.match(r"number|integer|float", t):
        t = "number"
    elif re.match(r"array|table|list|object", t):
        t = "table"
    elif re.match(r"none|nil|null|nothing", t):
        return None
    elif t == "self" or re.match(
        "^" + re.escape(module["name"].split(".")
                        [-1].lower()) + r"\s*(object)?$", t
    ):
        t = module["name"]
    else:
        # when multiple types are possible, parse the first type
        parts = re.split(r"(\s*[,\|]\s*|\s+or\s+)", t)
        if len(parts) > 1:
            first = parseType(module, parts[0], depth + 1)
            if first:
                return first
        # if depth == 1:
        #    print((expr, t))
        return None
    return t


def parseSignature(module, expr):
    parts = re.split(r"\s*-+>\s*", expr, 2)
    if len(parts) == 2:
        return (parts[0], parseType(module, parts[1]))
    return (parts[0], None)


def processFunction(f, module, el, returnType=False):
    left, type = parseSignature(module, el["signature"])

    if "(" not in left:
        left = left + "()"

    m = re.match(r"^(.*)\((.*)\)$", left)
    if m:
        name = module["prefix"] + m.group(1)
        params = m.group(2).strip()
        params = re.sub(r"[\[\]\{\}\(\)]+", "", params)
        params = re.sub(r"(\s*\|\s*|\s+or\s+)", "_or_", params)
        params = re.sub(r"\s*,\s*", ",", params)
        params = ", ".join(
            map(
                lambda x: re.sub("^(end|function|false)$",
                                 "_\\1", x), params.split(",")
            )
        )
        addDef = (name + "(" + params + ")") \
            .replace(" ",
                     "") != left.replace(" ", "")
        ret = doc(el, addDef)
        if returnType:
            ret += "---@return " + returnType + "\n"
        elif type:
            ret += "---@return " + type + "\n"
        ret += "function " + name + "(" + params + ") end\n\n"
        f.write(ret)
    else:
        print(
            "Warning: invalid function definition:\n " +
            el["signature"] + "\n " + left
        )


def processVar(f, module, var):
    ret = doc(var)
    left, type = parseSignature(module, module['prefix'] + var["signature"])

    if left.endswith("[]"):
        if type:
            if not type.endswith("[]"):
                type += "[]"
            ret += "---@type " + type + "\n"
        ret += left[0:-2] + " = {}\n"
    else:
        if type:
            ret += "---@type " + type + "\n"
        ret += left + " = nil\n"
    f.write(ret + "\n")


def doc(el, addDef=False):
    ret = ""
    if addDef and "def" in el:
        parts = re.split(r"\s*-+>\s*", el["def"], 2)
        ret += "---`" + parts[0] + "`\n---\n"
    ret += "---" + "---".join(el["doc"].strip().splitlines(True)) + "\n"
    return ret


def processModule(dir, module):
    name = module["prefix"] + module["name"]

    f = codecs.open(dir + "/" + name + ".lua", "w", "utf-8")

    if name == "hs":
        f.write("--- global variable containing loaded spoons\n")
        f.write("spoon = {}\n")

    ret = doc(module)
    ret += "---@class " + name + "\n"
    ret += name + " = {}\n"
    f.write(ret + "\n")

    for function in module["Function"]:
        processFunction(f, module, function)
    for function in module["Method"]:
        processFunction(f, module, function)
    for function in module["Constructor"]:
        processFunction(f, module, function, name)
    for function in module["Variable"]:
        processVar(f, module, function)
    for function in module["Constant"]:
        processVar(f, module, function)

    f.write("\n\n")
    f.close()


def main():
    docsFile = "build/docs.json"
    modulePrefix = ""

    if len(sys.argv) == 2 and sys.argv[1] == 'spoons':
        docsFile = "build/spoon_docs.json"
        modulePrefix = "spoon."

    target = "build/stubs"
    if not os.path.exists(target):
        os.mkdir(target)

    with open(docsFile) as json_file:
        data = json.load(json_file)
        for m in data:
            if m["type"] == "Module":
                m["prefix"] = modulePrefix
                processModule(target, m)
            else:
                raise Exception("Unknown type " + m["type"])


if __name__ == "__main__":
    main()
