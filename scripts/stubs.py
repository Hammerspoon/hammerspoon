#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Hammerspoon autocompletion stubs using EmmyLua annotations for lua lsp servers"""

import codecs
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

typeOverrides = {
    "app": "hs.application",
    "hsminwebtable": "hs.httpserver.hsminweb",
    "notificationobject": "hs.notify",
    "point": "hs.geometry",
    "rect": "hs.geometry",
    "hs.geometry rect": "hs.geometry",
    "size": "hs.geometry",
}


def parseType(module, expr: str, depth=1):
    t = expr.lower()
    if t in typeOverrides:
        t = typeOverrides[t]
    elif m := re.match("^[`'\"]?(hs\.[\w.]+)[`'\"]?([\s+\-\s*]?object)?$", t):
        t = m.group(1)
    elif m := re.match("^list of [`'\"]?(hs\.[\w.]+)[`'\"]?(\s+objects)?$", t):
        t = m.group(1) + "[]"
    elif re.match("^true|false|bool(ean)?$", t):
        t = "boolean"
    elif t == "string":
        t = "string"
    elif re.match("number|integer|float", t):
        t = "number"
    elif re.match("array|table|list|object", t):
        t = "table"
    elif re.match("none|nil|null|nothing", t):
        return None
    elif t == "self" or re.match(
        "^" + re.escape(module["name"].split(".")[-1].lower()) + "\s*(object)?$", t
    ):
        t = module["name"]
    else:
        # when multiple types are possible, parse the first type
        if len(parts := re.split("(\s*[,\|]\s*|\s+or\s+)", t)) > 1:
            if first := parseType(module, parts[0], depth + 1):
                return first
        # if depth == 1:
        #    print((expr, t))
        return None
    return t


def parseSignature(module, expr: str):
    parts = re.split("\s*-+>\s*", expr, 2)
    if len(parts) == 2:
        return (parts[0], parseType(module, parts[1]))
    return (parts[0], None)


def processFunction(f, module, el, returnType=False):
    left, type = parseSignature(module, el["signature"])
    if m := re.match("^(.*)\((.*)\)$", left):
        name = m.group(1)
        params = m.group(2).strip()
        params = re.sub("[\[\]\{\}\(\)]+", "", params)
        params = re.sub("(\s*\|\s*|\s+or\s+)", "_or_", params)
        params = re.sub("\s*,\s*", ",", params)
        params = ", ".join(
            map(
                lambda x: re.sub("^(end|function|false)$", "_\\1", x), params.split(",")
            )
        )
        addDef = (name + "(" + params + ")").replace(" ", "") != left.replace(" ", "")
        ret = doc(el, addDef)
        if returnType:
            ret += "---@return " + returnType + "\n"
        elif type:
            ret += "---@return " + type + "\n"
        ret += "function " + name + "(" + params + ") end\n\n"
        f.write(ret)
    else:
        print(
            "Warning: invalid function definition:\n " + el["signature"] + "\n " + left
        )


def processVar(f, module, var):
    ret = doc(var)
    left, type = parseSignature(module, var["signature"])

    # if "(" in var["def"]:
    #    return processFunction(f, module, var)

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
        parts = re.split("\s*-+>\s*", el["def"], 2)
        ret += "---`" + parts[0] + "`\n---\n"
    ret += "---" + "---".join(el["doc"].strip().splitlines(True)) + "\n"
    return ret


def processModule(dir, module):
    name = module["name"]

    f = codecs.open(dir + "/" + name + ".lua", "w", "utf-8")

    if name == "hs":
        f.write("function __IGNORE(...) end\n")
        f.write("--- global variable that contains loaded spoons\nspoon = {}\n")

    ret = doc(module)
    ret += "---@class " + name + "\n"
    ret += name + " = {}\n"
    f.write(ret + "\n")

    for function in module["Function"]:
        processFunction(f, module, function)
    for function in module["Method"]:
        processFunction(f, module, function)
    for function in module["Constructor"]:
        processFunction(f, module, function, module["name"])
    for function in module["Variable"]:
        processVar(f, module, function)
    for function in module["Constant"]:
        processVar(f, module, function)

    f.write("\n\n")
    f.close()


def main():
    target = "build/stubs"
    if not os.path.exists(target):
        os.mkdir(target)

    with open("build/docs.json") as json_file:
        data = json.load(json_file)
        c = 0
        for m in data:
            if m["type"] == "Module":
                processModule(target, m)
            else:
                raise Exception("Unknown type " + m["type"])


if __name__ == "__main__":
    main()
