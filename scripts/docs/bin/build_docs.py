#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Hammerspoon API Documentation Builder"""

from __future__ import print_function
import argparse
import json
import os
import pprint
import sqlite3
import string
import sys

DEBUG = False

CHUNK_FILE = 0
CHUNK_LINE = 1
CHUNK_SIGN = 2
CHUNK_TYPE = 3
CHUNK_DESC = 4
TYPE_NAMES = ["Deprecated", "Command", "Constant", "Variable", "Function",
              "Constructor", "Field", "Method"]
SECTION_NAMES = ["Parameters", "Returns", "Notes"]
TYPE_DESC = {
        "Constant": "Useful values which cannot be changed",
        "Variable": "Configurable values",
        "Function": "API calls offered directly by the extension",
        "Method": "API calls which can only be made on an object returned "
                  "by a constructor",
        "Constructor": "API calls which return an object, typically one "
                       "that offers API methods",
        "Command": "External shell commands",
        "Field": "Variables which can only be access from an object returned "
                 "by a constructor",
        "Deprecated": "API features which will be removed in an future "
                      "release"}


def dbg(msg):
    """Print a debug message"""
    if DEBUG:
        print("DEBUG: %s" % msg)


def err(msg):
    """Print an error message"""
    print("ERROR: %s" % msg)
    sys.exit(1)


def find_code_files(path):
    """Find all of the code files under a path"""
    code_files = []
    for dirpath, _, files in os.walk(path):
        dbg("Entering: %s" % dirpath)
        for filename in files:
            if filename.endswith(".m") or filename.endswith(".lua"):
                dbg("  Found file: %s/%s" % (dirpath, filename))
                code_files.append("%s/%s" % (dirpath, filename))
    return code_files


def extract_docstrings(filename):
    """Find all of the docstrings in a file"""
    docstrings = []
    is_in_chunk = False
    chunk = None
    i = 0
    with open(filename, "r") as filedata:
        for raw_line in filedata.readlines():
            i += 1
            line = raw_line.decode('utf-8').strip('\n')
            if line.startswith("---") or line.startswith("///"):
                # We're in a chunk of docstrings
                if not is_in_chunk:
                    # This is a new chunk
                    is_in_chunk = True
                    chunk = []
                    # Store the file and line number
                    chunk.append(filename)
                    chunk.append("%d" % i)
                # Append the line to the current chunk
                line = line.strip("/-")
                if len(line) > 0 and line[0] == ' ':
                    line = line[1:]
                chunk.append(line)
            else:
                # We hit a line that isn't a docstring. If we were previously
                #  processing docstrings, we just exited a chunk of docs, so
                #  store it and reset for the next chunk.
                if is_in_chunk and chunk:
                    docstrings.append(chunk)
                    is_in_chunk = False
                    chunk = None

    return docstrings


def find_module_for_item(modules, item):
    """Find the matching module for a given item"""
    dbg("find_module_for_item: Searching for: %s" % item)
    module = None

    # We need a shortcut here for root level items
    if string.count(item, '.') == 1:
        dbg("find_module_for_item: Using root-level shortcut")
        module = "hs"

    # Methods are very easy to shortcut
    if string.count(item, ':') == 1:
        dbg("find_module_for_item: Using method shortcut")
        module = item.split(':')[0]

    if not module:
        matches = []
        for mod in modules:
            if item.startswith(mod):
                matches.append(mod)

        matches.sort()
        dbg("find_module_for_item: Found options: %s" % matches)
        module = matches[-1]

    dbg("find_module_for_item: Found: %s" % module)
    return module


def find_itemname_from_signature(signature):
    """Find the name of an item, from a full signature"""
    return ''.join(signature.split('(')[0])


def remove_method_from_itemname(itemname):
    """Return an itemname without any method name in it"""
    return itemname.split(':')[0]


def find_basename_from_itemname(itemname):
    """Find the base name of an item, from its full name"""
    # (where "base name" means the function/method/variable/etc name
    splitchar = '.'
    if ':' in itemname:
        splitchar = ':'
    return itemname.split(splitchar)[-1].split(' ')[0]


def get_section_from_chunk(chunk, sectionname):
    """Extract a named section of a chunk"""
    section = []
    in_section = False

    for line in chunk:
        if line == sectionname:
            in_section = True
            continue
        if in_section:
            if line == "":
                # We've reached the end of the section
                break
            else:
                section.append(line)
    return section


def strip_sections_from_chunk(chunk):
    """Remove the Parameters/Returns/Notes sections from a chunk"""
    stripped_chunk = []
    in_section = False
    for line in chunk:
        if line[:-1] in SECTION_NAMES:
            # We hit a section
            in_section = True
            continue
        elif line == "":
            # We hit the end of a section
            in_section = False
            continue
        else:
            if not in_section:
                stripped_chunk.append(line)

    return stripped_chunk


def process_docstrings(docstrings):
    """Process the docstrings into a proper structure"""
    docs = {}

    # First we'll find all of the modules and prepare the docs structure
    for chunk in docstrings:
        if chunk[2].startswith("==="):
            # This is a module definition
            modulename = chunk[CHUNK_SIGN].strip("= ")
            dbg("process_docstrings: Module: %s at %s:%s" % (
                modulename,
                chunk[CHUNK_FILE],
                chunk[CHUNK_LINE]))
            docs[modulename] = {}
            docs[modulename]["header"] = chunk
            docs[modulename]["items"] = {}

    # Now we'll get all of the item definitions
    for chunk in docstrings:
        if not chunk[2].startswith("==="):
            # This is an item definition
            itemname = find_itemname_from_signature(chunk[CHUNK_SIGN])
            dbg("process_docstrings: Found item: %s at %s:%s" % (
                itemname,
                chunk[CHUNK_FILE],
                chunk[CHUNK_LINE]))
            modulename = find_module_for_item(docs.keys(), itemname)
            dbg("process_docstrings:   Assigning item to module: %s" %
                modulename)
            docs[modulename]["items"][itemname] = chunk

    return docs


def process_module(modulename, raw_module):
    """Process the docstrings for a module"""
    dbg("Processing module: %s" % modulename)
    dbg("Header: %s" % raw_module["header"][CHUNK_DESC])
    module = {}
    module["name"] = modulename
    module["desc"] = raw_module["header"][CHUNK_DESC]
    module["doc"] = '\n'.join(raw_module["header"][CHUNK_DESC:])
    module["stripped_doc"] = '\n'.join(raw_module["header"][CHUNK_DESC+1:])
    module["items"] = []  # Deprecated
    module["Function"] = []
    module["Method"] = []
    module["Constructor"] = []
    module["Constant"] = []
    module["Variable"] = []
    module["Command"] = []
    module["Field"] = []
    # NOTE: I don't like having the deprecated type, I think we should revist
    #       this later and find another way to annotate deprecations
    module["Deprecated"] = []
    for itemname in raw_module["items"]:
        dbg("  Processing item: %s" % itemname)
        chunk = raw_module["items"][itemname]
        if chunk[CHUNK_TYPE] not in TYPE_NAMES:
            err("UNKNOWN TYPE: %s (%s)" % (chunk[CHUNK_TYPE],
                                           pprint.pformat(chunk)))
        basename = find_basename_from_itemname(itemname)

        item = {}
        item["name"] = basename
        item["signature"] = chunk[CHUNK_SIGN]
        item["def"] = chunk[CHUNK_SIGN]  # Deprecated
        item["type"] = chunk[CHUNK_TYPE]
        item["desc"] = chunk[CHUNK_DESC]
        item["doc"] = '\n'.join(chunk[CHUNK_DESC:])

        for section in ["Parameters", "Returns", "Notes"]:
            if section + ':' in chunk:
                item[section.lower()] = get_section_from_chunk(chunk,
                                                               section + ':')

        item["stripped_doc"] = '\n'.join(strip_sections_from_chunk(
                                            chunk[CHUNK_DESC+1:]))
        module[item["type"]].append(item)
        module["items"].append(item)  # Deprecated

        dbg("    %s" % pprint.pformat(item).replace('\n', "\n            "))
    return module


def strip_paragraph(text):
    """Strip <p> from the start of a string, and </p>\n from the end"""
    text = text.replace("<p>", "")
    text = text.replace("</p>\n", "")
    return text


def process_markdown(data):
    """Pre-render GitHub-flavoured Markdown, and syntax-highlight code"""
    import mistune
    from pygments import highlight
    from pygments.lexers import get_lexer_by_name
    from pygments.formatters import html

    class HighlightRenderer(mistune.Renderer):
        def block_code(self, code, lang):
            if not lang:
                return '\n<pre><code>%s</code></pre>\n' % \
                    mistune.escape(code)
            lexer = get_lexer_by_name(lang, stripall=True)
            formatter = html.HtmlFormatter()
            return highlight(code, lexer, formatter)

    md = mistune.Markdown(renderer=HighlightRenderer())

    for i in xrange(0, len(data)):
        module = data[i]
        module["desc_gfm"] = md(module["desc"])
        module["doc_gfm"] = md(module["doc"])
        for item_type in TYPE_NAMES:
            items = module[item_type]
            for j in xrange(0, len(items)):
                item = items[j]
                item["def_gfm"] = strip_paragraph(md(item["def"]))
                item["doc_gfm"] = md(item["doc"])
                items[j] = item
        # Now do the same for the deprecated 'items' list
        for j in xrange(0, len(module["items"])):
            item = module["items"][j]
            item["def_gfm"] = strip_paragraph(md(item["def"]))
            item["doc_gfm"] = md(item["doc"])
            module["items"][j] = item
        data[i] = module
    return data


def do_processing(directories):
    """Run all processing steps for one or more directories"""
    raw_docstrings = []
    codefiles = []
    processed_docstrings = []

    for directory in directories:
        codefiles += find_code_files(directory)
    if len(codefiles) == 0:
        err("No .m/.lua files found")

    for filename in codefiles:
        raw_docstrings += extract_docstrings(filename)
    if len(raw_docstrings) == 0:
        err("No docstrings found")

    docs = process_docstrings(raw_docstrings)

    if len(docs) == 0:
        err("No modules found")

    for module in docs:
        dbg("Processing: %s" % module)
        module_docs = process_module(module, docs[module])
        module_docs["items"].sort(key=lambda item: item["name"])
        for item_type in TYPE_NAMES:
            module_docs[item_type].sort(key=lambda item: item["name"])
        processed_docstrings.append(module_docs)

    processed_docstrings.sort(key=lambda module: module["name"])
    return processed_docstrings


def write_json(filepath, data):
    """Write out a JSON version of the docs"""
    with open(filepath, "wb") as jsonfile:
        jsonfile.write(json.dumps(data, sort_keys=True, indent=2,
                                  separators=(',', ': '),
                                  ensure_ascii=False).encode('utf-8'))


def write_sql(filepath, data):
    """Write out an SQLite DB of docs metadata, for Dash"""
    db = sqlite3.connect(filepath)
    cur = db.cursor()

    try:
        cur.execute("DROP TABLE searchIndex;")
    except sqlite3.OperationalError:
        # This table won't have existed in a blank database
        pass
    cur.execute("CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, "
                "type TEXT, path TEXT);")
    cur.execute("CREATE UNIQUE INDEX anchor ON searchIndex (name, type, "
                "path);")

    for module in data:
        cur.execute("INSERT INTO searchIndex VALUES(NULL, '%(modname)s', "
                    "'Module', '%(modname)s.html');" %
                    {"modname": module["name"]})
        for item in module["items"]:
            cur.execute("INSERT INTO searchIndex VALUES(NULL, "
                        "'%(modname)s.%(itemname)s', "
                        "'%(itemtype)s', '%(modname)s.html#%(itemname)s');" %
                        {"modname": module["name"], "itemname": item["name"],
                         "itemtype": item["type"]})

    cur.execute("VACUUM;")
    db.commit()


def write_html(output_dir, template_dir, data):
    """Write out an HTML version of the docs"""
    from jinja2 import Environment

    jinja = Environment(trim_blocks=True, lstrip_blocks=True)

    # Make sure we have a valid output_dir
    if not os.path.isdir(output_dir):
        try:
            os.makedirs(output_dir)
        except Exception as error:
            err("Output directory is not a directory, "
                "and/or can't be created: %s" % error)

    # Prepare for writing index.html
    try:
        outfile = open(output_dir + "/index.html", "wb")
    except Exception as error:
        err("Unable to create %s: %s" % (output_dir + "/index.html",
            error))

    # Prepare for reading index.j2.html
    try:
        tmplfile = open(template_dir + "/index.j2.html", "r")
    except Exception as error:
        err("Unable to open index.j2.html: %s" % error)

    # Re-process the doc data to convert Markdown to HTML
    data = process_markdown(data)

    # Render and write index.html
    template = jinja.from_string(tmplfile.read().decode('utf-8'))
    render = template.render(data=data)
    outfile.write(render.encode("utf-8"))
    outfile.close()
    tmplfile.close()
    dbg("Wrote index.html.")

    # Render and write module docs
    try:
        tmplfile = open(template_dir + "/module.j2.html", "r")
        template = jinja.from_string(tmplfile.read().decode('utf-8'))
    except Exception as error:
        err("Unable to open module.j2.html: %s" % error)

    for module in data:
        with open("%s/%s.html" % (output_dir, module["name"]), "wb") as docfile:
            render = template.render(module=module,
                                     type_order=TYPE_NAMES,
                                     type_desc=TYPE_DESC)
            docfile.write(render.encode("utf-8"))
            dbg("Wrote %s.html" % module["name"])

    tmplfile.close()


def main():
    """Main entrypoint"""
    global DEBUG

    parser = argparse.ArgumentParser()
    commands = parser.add_argument_group("Commands")
    commands.add_argument("-v", "--validate", action="store_true",
                          dest="validate", default=False,
                          help="Ensure all docstrings are valid")
    commands.add_argument("-j", "--json", action="store_true",
                          dest="json", default=False,
                          help="Output docs.json")
    commands.add_argument("-s", "--sql", action="store_true",
                          dest="sql", default=False,
                          help="Output docs.sqlite")
    commands.add_argument("-t", "--html", action="store_true",
                          dest="html", default=False,
                          help="Output HTML docs")
    parser.add_argument("-d", "--debug", help="Enable debugging output",
                        action="store_true", default=False,
                        dest="debug")
    parser.add_argument("-e", "--templates", action="store",
                        help="Directory of HTML templates",
                        dest="template_dir", default="scripts/docs/templates")
    parser.add_argument("-o", "--output_dir", action="store",
                        dest="output_dir", default="build/",
                        help="Directory to write outputs to")
    parser.add_argument("DIRS", nargs=argparse.REMAINDER,
                        help="Directories to search")
    arguments, leftovers = parser.parse_known_args()

    if arguments.debug:
        DEBUG = True
    dbg("Arguments: %s" % arguments)

    if not arguments.validate and \
       not arguments.json and \
       not arguments.sql and \
       not arguments.html:
        parser.print_help()
        err("At least one of validate/json/sql/html is required.")

    if len(arguments.DIRS) == 0:
        parser.print_help()
        err("At least one directory is required. See DIRS")

    results = do_processing(arguments.DIRS)

    if arguments.validate:
        # If we got this far, we already processed the docs, and validated them
        pass
    if arguments.json:
        write_json(arguments.output_dir + "/docs.json", results)
    if arguments.sql:
        write_sql(arguments.output_dir + "/docs.sqlite", results)
    if arguments.html:
        write_html(arguments.output_dir + "/html/",
                   arguments.template_dir, results)


if __name__ == "__main__":
    main()
