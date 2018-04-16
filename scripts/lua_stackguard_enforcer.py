#!/usr/bin/env python
"""
Enforce the usage of Hammerspoon's Lua stack guarding macros
"""

from __future__ import print_function
import sys

from clang.cindex import Config
from clang.cindex import Index
from clang.cindex import CursorKind
from clang.cindex import TypeKind

FILENAME = "Unknown"


def is_function(node):
    """Is the given node a C function or an ObjC method?"""
    return node.kind in [CursorKind.FUNCTION_DECL,
                         CursorKind.OBJC_INSTANCE_METHOD_DECL,
                         CursorKind.OBJC_CLASS_METHOD_DECL]


def is_implementation(node):
    """Is the given node an ObjC @implementation?"""
    return node.kind == CursorKind.OBJC_IMPLEMENTATION_DECL


def is_luastate_param(node):
    """Is the given node a lua_State parameter?"""
    # We need the underlying text tokens to detect the typedef 'lua_State'
    tokens = [x.spelling for x in node.get_tokens()]
    try:
        return node.type.kind == TypeKind.POINTER and \
            tokens[0] == 'lua_State'
    except IndexError:
        return False


def is_lua_call(node):
    """Is the given node a Lua->C call?"""
    params = [x for x in node.get_children() if x.kind == CursorKind.PARM_DECL]
    return node.result_type.kind == TypeKind.INT and len(params) == 1 and \
        is_luastate_param(params[0])


def build_tree(node, recurse=True):
    """Build a tree below a node"""
    if recurse:
        children = [build_tree(c) for c in node.get_children()]
    else:
        children = ['skipped']
    return {'node': node,
            'kind': node.kind,
            'spelling': node.spelling,
            'tokens': ' '.join([x.spelling for x in node.get_tokens()]),
            'children': children}


def contains_lua_calls(item):
    """Check if a node contains any Lua API calls"""
    if 'lua_' in item['tokens']:
        return True
    if 'luaL_' in item['tokens']:
        return True
    if 'LuaSkin' in item['tokens']:
        return True
    return False


def main(filename):
    """Main function"""
    functions = []
    tree = []
    Config.set_library_file(
        "/Library/Developer/CommandLineTools/usr/lib/libclang.dylib")

    index = Index.create()
    ast = index.parse(None, [filename])
    if not ast:
        print("Unable to parse file")
        sys.exit(1)

    # Step 1: Find all the C/ObjC functions
    functions = [x for x in ast.cursor.get_children() if is_function(x)]

    # Step 1a: Add in ObjC class methods
    for item in ast.cursor.get_children():
        if is_implementation(item):
            functions += [x for x in item.get_children() if is_function(x)]

    # Step 2: Filter out all of the functions that are Lua->C calls
    functions = [x for x in functions if not is_lua_call(x)]

    # Step 3: Recursively walk the remaining functions
    tree = [build_tree(x, False) for x in functions]

    # Step 4: Filter the functions down to those which contain Lua calls
    tree = [x for x in tree if contains_lua_calls(x)]

    for thing in tree:
        stacktxt = "NO STACKGUARD"
        hasstackentry = "_lua_stackguard_entry" in thing['tokens']
        hasstackexit = "_lua_stackguard_exit" in thing['tokens']
        if hasstackentry and hasstackexit:
            continue
        if hasstackentry and not hasstackexit:
            stacktxt = "STACK ENTRY, BUT NO EXIT"
        if hasstackexit and not hasstackentry:
            stacktxt = "STACK EXIT, BUT NO ENTRY (THIS IS A CRASH)"
        print(u"%s :: %s :: %s" % (filename, thing['spelling'], stacktxt))


if __name__ == '__main__':
    main(sys.argv[1])
