#!/usr/bin/env -S -P/usr/bin:${PATH} python3
# -*- coding: utf-8 -*-
"""Hammerspoon API Documentation Builder"""


import argparse
import json
import os
import pprint
import sqlite3
import sys
import re

DEBUG = False
FAIL_ON_WARN = True
HAS_WARNED = False

LINT_MODE = False
LINTS = []

CHUNK_FILE = 0
CHUNK_LINE = 1
CHUNK_SIGN = 2
CHUNK_TYPE = 3
CHUNK_DESC = 4
TYPE_NAMES = ["Deprecated", "Command", "Constant", "Variable", "Function",
              "Constructor", "Field", "Method"]
SECTION_NAMES = ["Parameters", "Returns", "Notes", "Examples"]
TYPE_DESC = {
    "Constant": "Useful values which cannot be changed",
    "Variable": "Configurable values",
    "Function": "API calls offered directly by the extension",
    "Method": "API calls which can only be made on an object returned by a constructor",
    "Constructor": "API calls which return an object, typically one that offers API methods",
    "Command": "External shell commands",
    "Field": "Variables which can only be accessed from an object returned by a constructor",
    "Deprecated": "API features which will be removed in an future release"
}
LINKS = [
    {"name": "Website", "url": "https://www.hammerspoon.org/"},
    {"name": "GitHub page",
     "url": "https://github.com/Hammerspoon/hammerspoon"},
    {"name": "Getting Started Guide",
     "url": "https://www.hammerspoon.org/go/"},
    {"name": "Spoon Plugin Documentation",
     "url": "https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md"},
    {"name": "Official Spoon repository",
     "url": "https://www.hammerspoon.org/Spoons"},
    {"name": "IRC channel",
     "url": "irc://irc.libera.chat/#hammerspoon"},
    {"name": "Mailing list",
     "url": "https://groups.google.com/forum/#!forum/hammerspoon/"},
    {"name": "LuaSkin API docs",
     "url": "https://www.hammerspoon.org/docs/LuaSkin/"}
]

ARGUMENTS = None


def dbg(msg):
    """Print a debug message"""
    if DEBUG:
        print("DEBUG: %s" % msg)


def warn(msg):
    """Print a warning message"""
    global HAS_WARNED
    print("WARN: %s" % msg)
    HAS_WARNED = True


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
            line = raw_line.strip('\n')
            if line.startswith("----") or line.startswith("////"):
                dbg("Skipping %s:%d - too many comment chars" % (filename, i))
                continue
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
    if not ARGUMENTS.standalone and item.count('.') == 1:
        dbg("find_module_for_item: Using root-level shortcut")
        module = "hs"

    # Methods are very easy to shortcut
    if item.count(':') == 1:
        dbg("find_module_for_item: Using method shortcut")
        module = item.split(':')[0]

    if not module:
        matches = []
        for mod in modules:
            if item.startswith(mod):
                matches.append(mod)

        matches.sort()
        dbg("find_module_for_item: Found options: %s" % matches)
        try:
            module = matches[-1]
        except IndexError:
            err("Unable to find module for: %s" % item)

    dbg("find_module_for_item: Found: %s" % module)
    return module


def find_itemname_from_signature(signature):
    """Find the name of an item, from a full signature"""
    return ''.join(re.split(r"[\(\[\s]", signature)[0])


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
    """Remove the Parameters/Returns/Notes/Examples sections from a chunk"""
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
            modulename = find_module_for_item(list(docs.keys()), itemname)
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
    module["type"] = "Module"
    module["desc"] = raw_module["header"][CHUNK_DESC]
    module["doc"] = '\n'.join(raw_module["header"][CHUNK_DESC:])
    module["stripped_doc"] = '\n'.join(raw_module["header"][CHUNK_DESC + 1:])
    module["submodules"] = []
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
        item["file"] = chunk[CHUNK_FILE]
        item["lineno"] = chunk[CHUNK_LINE]

        for section in ["Parameters", "Returns", "Notes", "Examples"]:
            if section + ':' in chunk:
                item[section.lower()] = get_section_from_chunk(chunk,
                                                               section + ':')

        item["stripped_doc"] = '\n'.join(strip_sections_from_chunk(chunk[CHUNK_DESC + 1:]))
        module[item["type"]].append(item)
        module["items"].append(item)  # Deprecated

        dbg("    %s" % pprint.pformat(item).replace('\n', "\n            "))

        # The rest of this code is only for functions/constructors/methods
        if item["type"] not in ["Function", "Constructor", "Method"]:
            continue

        def is_actual_parameter(some_text):
            return some_text.startswith(" * ")

        try:
            if item['desc'].startswith("Alias for [`"):
                item["parameters"] = []
                item["returns"] = []
                item["notes"] = []
                pass
            else:
                sig_without_return = item["signature"].split("->")[0]
                sig_params = re.sub(r".*\((.*)\).*", r"\1", sig_without_return)
                sig_param_arr = re.split(r',|\|', sig_params)
                sig_arg_count = len(sig_param_arr)

                # Check if there are more than a single line of description at the top of the function
                params_index = chunk[CHUNK_DESC:].index("Parameters:")
                desc_section = [x for x in chunk[CHUNK_DESC:][0:params_index] if x != '']
                if len(desc_section) > 1:
                    message = "Function description should be a single line. Other content may belong in Notes: %s" % sig_without_return
                    warn(message)
                    LINTS.append({
                        "file": item["file"],
                        "line": int(item["lineno"]),
                        "title": "Docstring function/method/constructor description should not be multiline",
                        "message": message,
                        "annotation_level": "failure"

                    })

                # Clean up Parameters
                clean_params = []
                numlines = len(item["parameters"])
                try:
                    for i in range(0, numlines):
                        line = item["parameters"][i]

                        if line.startswith(" * "):
                            # This is the start of a new parameter, add it to clean_params
                            clean_params.append(line.rstrip())
                        elif line.startswith("  * ") or line.startswith("   * "):
                            if line.startswith("  * "):
                                # Sub-lists should start with two spaces in GitHub Flavoured Markdown, so add in the missing space in this item
                                line = " " + line
                            # This is a sub-parameter of the previous parameter, add it to that string in clean_params
                            prev_clean_line = clean_params[-1]
                            prev_clean_line += '\n' + line.rstrip()
                            clean_params[-1] = prev_clean_line
                        else:
                            # This should have been on the line before
                            prev_clean_line = clean_params[-1]
                            prev_clean_line += ' ' + line.strip()
                            clean_params[-1] = prev_clean_line
                except:
                    message = "PARAMETERS FORMAT ISSUE: Unable to parse Parameters for: %s" % sig_without_return
                    warn(message)
                    LINTS.append({
                        "file": item["file"],
                        "line": int(item["lineno"]),
                        "title": "Docstring function/method/constructor parameter parsing error",
                        "message": message,
                        "annotation_level": "failure"
                    })
                item["parameters"] = clean_params

                # Check the number of parameters in the signature matches the number in Parameters
                parameter_count = len(item["parameters"])
                if parameter_count != sig_arg_count:
                    message = "SIGNATURE/PARAMETER COUNT MISMATCH: '%s' says %d parameters ('%s'), but Parameters section has %d entries:\n%s\n" % (sig_without_return, sig_arg_count, ','.join(sig_param_arr), parameter_count, '\n'.join(item["parameters"]))
                    warn(message)
                    LINTS.append({
                        "file": item["file"],
                        "line": int(item["lineno"]),
                        "title": "Docstring signature/parameter mismatch",
                        "message": message,
                        "annotation_level": "failure"
                    })

                # Check if we have zero items for Returns.
                # This is a lint error in Hammerspoon, but in Standalone (ie Spoons) we'll let it slide and assume they meant to have no returns
                if "returns" not in item:
                    item["returns"] = []
                if len(item["returns"]) == 0 and not ARGUMENTS.standalone:
                    message = "RETURN COUNT ERROR: '%s' does not specify a return value" % (sig_without_return)
                    warn(message)
                    LINTS.append({
                        "file": item["file"],
                        "line": int(item["lineno"]),
                        "title": "Docstring missing return value",
                        "message": message,
                        "annotation_level": "failure"
                    })

                # Having validated the Returns, we will now remove any "None" ones
                if len(item["returns"]) == 1 and item["returns"][0] == "* None":
                    item["returns"] = []

                # Check if we have zero items for Notes
                if "notes" not in item:
                    item["notes"] = []

                # Check if we have zero items for Examples
                if "examples" not in item:
                    item["examples"] = []

        except:
            message = "Unable to parse parameters for %s\n%s\n" % (item["signature"], sys.exc_info()[1])
            warn(message)
            LINTS.append({
                "file": item["file"],
                "line": int(item["lineno"]),
                "title": "Docstring Parameters parse failure",
                "message": message,
                "annotation_level": "failure"
            })
            if FAIL_ON_WARN:
                sys.exit(1)
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

    for i in range(0, len(data)):
        module = data[i]
        module["desc_gfm"] = md(module["desc"])
        module["doc_gfm"] = md(module["doc"])
        for item_type in TYPE_NAMES:
            items = module[item_type]
            for j in range(0, len(items)):
                item = items[j]
                dbg("Preparing template data for: %s" % item["def"])
                item["def_gfm"] = strip_paragraph(md(item["def"]))
                item["doc_gfm"] = md(item["doc"])
                if item_type in ["Function", "Constructor", "Method"]:
                    item["parameters_gfm"] = md('\n'.join(item["parameters"]))
                    item["returns_gfm"] = md('\n'.join(item["returns"]))
                    item["notes_gfm"] = md('\n'.join(item["notes"]))
                items[j] = item
        # Now do the same for the deprecated 'items' list
        for j in range(0, len(module["items"])):
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
    module_tree = {}

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
        module_docs["items"].sort(key=lambda item: item["name"].lower())
        for item_type in TYPE_NAMES:
            module_docs[item_type].sort(key=lambda item: item["name"].lower())
        processed_docstrings.append(module_docs)

        # Add this module to our module tree
        module_parts = module.split('.')
        cursor = module_tree
        for part in module_parts:
            if part not in cursor:
                cursor[part] = {}
            cursor = cursor[part]

    # Iterate over the modules, consulting the module tree, to find their
    # submodules
    # (Note that this is done as a separate step after the above loop, to
    #  ensure that we know about all possible modules by this point)
    i = 0
    for module in processed_docstrings:
        dbg("Finding submodules for: %s" % module["name"])
        module_parts = module["name"].split('.')
        cursor = module_tree
        for part in module_parts:
            cursor = cursor[part]
        # cursor now points at this module, so now we can check for subs
        for sub in list(cursor.keys()):
            processed_docstrings[i]["submodules"].append(sub)
        processed_docstrings[i]["submodules"].sort()
        i += 1

    processed_docstrings.sort(key=lambda module: module["name"].lower())
    return processed_docstrings


def write_annotations(filepath, data):
    """Write out a JSON file with our linter errors"""
    with open(filepath, "wb") as jsonfile:
        jsonfile.write(json.dumps(data, indent=2,
                                  separators=(',', ': '),
                                  ensure_ascii=False).encode('utf-8'))


def write_json(filepath, data):
    """Write out a JSON version of the docs"""
    with open(filepath, "wb") as jsonfile:
        jsonfile.write(json.dumps(data, sort_keys=True, indent=2,
                                  separators=(',', ': '),
                                  ensure_ascii=False).encode('utf-8'))


def write_json_index(filepath, data):
    """Write out a JSON index of the docs"""
    index = []
    for item in data:
        entry = {}
        entry["name"] = item["name"]
        entry["desc"] = item["desc"]
        entry["type"] = item["type"]
        index.append(entry)
        for subtype in TYPE_NAMES:
            for subitem in item[subtype]:
                entry = {}
                entry["name"] = subitem["name"]
                entry["module"] = item["name"]
                entry["desc"] = subitem["desc"]
                entry["type"] = subitem["type"]
                index.append(entry)
    with open(filepath, "wb") as jsonfile:
        jsonfile.write(json.dumps(index, sort_keys=True, indent=2,
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
            try:
                cur.execute("INSERT INTO searchIndex VALUES(NULL, "
                            "'%(modname)s.%(itemname)s', "
                            "'%(itemtype)s', '%(modname)s.html#%(itemname)s');" %
                            {"modname": module["name"], "itemname": item["name"],
                             "itemtype": item["type"]})
            except:
                err("DB Insert failed on %s:%s(%s)" % (module["name"], item["name"], item["type"]))

    db.commit()
    cur.execute("VACUUM;")


def write_templated_output(output_dir, template_dir, title, data, extension):
    """Write out a templated version of the docs"""
    from jinja2 import Environment

    jinja = Environment(trim_blocks=True, lstrip_blocks=True)

    # Make sure we have a valid output_dir
    if not os.path.isdir(output_dir):
        try:
            os.makedirs(output_dir)
        except Exception as error:
            err("Output directory is not a directory, "
                "and/or can't be created: %s" % error)

    # Prepare for writing index.<extensions>
    try:
        outfile = open(output_dir + "/index." + extension, "wb")
    except Exception as error:
        err("Unable to create %s: %s" % (output_dir + "/index." + extension,
            error))

    # Prepare for reading index.j2.<extension>
    try:
        tmplfile = open(template_dir + "/index.j2." + extension, "r")
    except Exception as error:
        err("Unable to open index.j2.%s: %s" % (extension, error))

    if extension == "html":
        # Re-process the doc data to convert Markdown to HTML
        data = process_markdown(data)
        # Write out the data as a file, for later debugging
        write_json(output_dir + "/templated_docs.json", data)

    # Render and write index.<extension>
    template = jinja.from_string(tmplfile.read())
    render = template.render(data=data, links=LINKS, title=title)
    outfile.write(render.encode("utf-8"))
    outfile.close()
    tmplfile.close()
    dbg("Wrote index." + extension)

    # Render and write module docs
    try:
        tmplfile = open(template_dir + "/module.j2." + extension, "r")
        template = jinja.from_string(tmplfile.read())
    except Exception as error:
        err("Unable to open module.j2.%s: %s" % (extension, error))

    for module in data:
        with open("%s/%s.%s" % (output_dir,
                                module["name"],
                                extension), "wb") as docfile:
            render = template.render(module=module,
                                     type_order=TYPE_NAMES,
                                     type_desc=TYPE_DESC)
            docfile.write(render.encode("utf-8"))
            dbg("Wrote %s.%s" % (module["name"], extension))

    tmplfile.close()


def write_html(output_dir, template_dir, title, data):
    """Write out an HTML version of the docs"""
    write_templated_output(output_dir, template_dir, title, data, "html")


def write_markdown(output_dir, template_dir, title, data):
    """Write out a Markdown version of the docs"""
    write_templated_output(output_dir, template_dir, title, data, "md")


def main():
    """Main entrypoint"""
    global DEBUG
    global ARGUMENTS

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
    commands.add_argument("-m", "--markdown", action="store_true",
                          dest="markdown", default=False,
                          help="Output Markdown docs")
    parser.add_argument("-n", "--standalone",
                        help="Process a single module only",
                        action="store_true", default=False,
                        dest="standalone")
    parser.add_argument("-d", "--debug", help="Enable debugging output",
                        action="store_true", default=False,
                        dest="debug")
    parser.add_argument("-e", "--templates", action="store",
                        help="Directory of HTML templates",
                        dest="template_dir", default="scripts/docs/templates")
    parser.add_argument("-o", "--output_dir", action="store",
                        dest="output_dir", default="build/",
                        help="Directory to write outputs to")
    parser.add_argument("-i", "--title", action="store",
                        dest="title", default="Hammerspoon",
                        help="Title for the index page")
    parser.add_argument("-l", "--lint", action="store_true",
                        dest="lint_mode", default=False,
                        help="Run in Lint mode. No docs will be built")
    parser.add_argument("DIRS", nargs=argparse.REMAINDER,
                        help="Directories to search")
    arguments, leftovers = parser.parse_known_args()

    if arguments.debug:
        DEBUG = True
    dbg("Arguments: %s" % arguments)

    if not arguments.validate and \
       not arguments.json and \
       not arguments.sql and \
       not arguments.html and \
       not arguments.markdown and \
       not arguments.lint_mode:
        parser.print_help()
        err("At least one of validate/json/sql/html/markdown is required.")

    if len(arguments.DIRS) == 0:
        parser.print_help()
        err("At least one directory is required. See DIRS")

    # Store global copy of our arguments
    ARGUMENTS = arguments

    if arguments.lint_mode:
        global LINT_MODE
        global FAIL_ON_WARN
        LINT_MODE = True
        FAIL_ON_WARN = False

    results = do_processing(arguments.DIRS)

    if arguments.validate:
        # If we got this far, we already processed the docs, and validated them
        pass
    if arguments.lint_mode:
        write_annotations(arguments.output_dir + "/annotations.json", LINTS)
    if arguments.json:
        write_json(arguments.output_dir + "/docs.json", results)
        write_json_index(arguments.output_dir + "/docs_index.json", results)
    if arguments.sql:
        write_sql(arguments.output_dir + "/docs.sqlite", results)
    if arguments.html:
        write_html(arguments.output_dir + "/html/",
                   arguments.template_dir,
                   arguments.title, results)
    if arguments.markdown:
        write_markdown(arguments.output_dir + "/markdown/",
                       arguments.template_dir,
                       arguments.title, results)


if __name__ == "__main__":
    main()
    if FAIL_ON_WARN and HAS_WARNED:
        sys.exit(1)
