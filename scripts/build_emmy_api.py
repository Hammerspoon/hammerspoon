#!/usr/bin/python
# -*- coding: utf-8 -*-
"""Hammerspoon EmmyLua API Builder"""

import json, re, os

import codecs
import sys 

def func(el):
  d = el['signature'].replace("-->", "->")
  ret = d.split(" ->")[0] \
     .replace("[, ", ", _").replace("[ , ", ", _").replace("[", "_") \
     .replace("]", "").replace(" | ", "_or_").replace("|", "_or_") \
     .replace(" or ", "_or_").replace("function", "fn") \
     .replace("end", "theend").replace("{", "").replace("}", "") \
      .replace("))", ")")
  ret += "\n  __IGNORE(" + re.sub("^.*\(", "", ret) + "\n"
  return ret
  

def processFunction(f, module, function):
  # if not "(" in function["def"]:
  #   return processVar(f, module, function)
  ret = doc(function)
  ret += "function "
  ret += func(function)
  ret += " end\n"
  f.write(ret + "\n")

def processConstructor(f, module, function):
  ret = doc(function)
  ret += "---@return " + module["name"] + "\n"
  ret += "function "
  ret += func(function)
  ret += " end\n"
  f.write(ret + "\n")

def processVar(f, module, var):
  ret = doc(var)

  if var["def"].endswith(" -> boolean"):
    ret += "---@type boolean\n"
    var["def"] = var["def"].replace(" -> boolean", "")

  if var["def"].endswith(" -> number"):
    ret += "---@type number\n"
    var["def"] = var["def"].replace(" -> number", "")


  var["def"] = re.sub(" -> table.*", "", var["def"])
  if "(" in var["def"]:
    return processFunction(f, module, var)

  if var["def"].endswith("[]"):
    ret += var["def"][0:-2] + " = {}\n"
  else:
    ret += var["def"] + " = nil\n"
  f.write(ret + "\n")

def doc(el):
  return "---" + "---".join(el["doc"].strip().splitlines(True)) + "\n"

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

  for function in module['Function']:
    processFunction(f, module, function)
  for function in module['Method']:
    processFunction(f, module, function)
  for function in module['Constructor']:
    processConstructor(f, module, function)
  for function in module['Variable']:
    processVar(f, module, function)
  for function in module['Constant']:
    processVar(f, module, function)

  f.write("\n\n")
  f.close()

def main():
  target = "build/emmy-api"
  if not os.path.exists(target):
    os.mkdir(target)
  
  with open('build/docs.json') as json_file:
    data = json.load(json_file)
    c = 0
    for m in data:
      if m["type"] == "Module":
        processModule(target, m)
      else:
        raise Exception("Unknown type " + m["type"])


if __name__ == "__main__":
    main()
