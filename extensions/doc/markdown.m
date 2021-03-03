/// === hs.doc.markdown ===
///
/// Markdown to HTML and plaintext conversion support used by hs.doc
///
/// This module provides Github-Flavored-Markdown conversion support used by hs.doc.  This module is a Lua wrapper to the C code portion of the Ruby gem `github-markdown`, available at https://rubygems.org/gems/github-markdown/versions/0.6.9.
///
/// The Ruby gem `github-markdown` was chosen as the code base for this module because it is the tool used to generate the official Hammerspoon Dash docset.
///
/// The Lua wrapper portion is licensed under the MIT license by the Hammerspoon development team.  The C code portion of the Ruby gem is licensed under the MIT license by GitHub, Inc.

// #import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#include "markdown.h"
#include "html.h"
#include "plaintext.h"
#include "houdini.h"

static LSRefTable refTable = LUA_NOREF;

typedef enum {
    GFM,
    MARKDOWN,
    PLAINTEXT,
} ModeType;

#pragma mark - Support Functions and Classes

static struct {
    struct sd_markdown *md;
    struct html_renderopt render_opts;
} g_markdown, g_GFM, g_plaintext;

static void rndr_blockcode_github(struct buf *ob, const struct buf *text, const struct buf *lang, __unused void *opaque) {
    if (ob->size)
        bufputc(ob, '\n');

    if (!text || !text->size) {
        BUFPUTSL(ob, "<pre><code></code></pre>");
        return;
    }

    if (lang && lang->size) {
        size_t i = 0, lang_size;
        const char *lang_name = NULL;

        while (i < lang->size && !isspace(lang->data[i]))
            i++;

        if (lang->data[0] == '.') {
            lang_name = (const char *)(lang->data + 1);
            lang_size = i - 1;
        } else {
            lang_name = (const char *)lang->data;
            lang_size = i;
        }

//         if (rb_block_given_p()) {
//             VALUE hilight;
//
//             hilight = rb_yield_values(2,
//                 geefem_str_new(text->data, text->size),
//                 geefem_str_new(lang_name, lang_size));
//
//             if (!NIL_P(hilight)) {
//                 Check_Type(hilight, T_STRING);
//                 bufput(ob, RSTRING_PTR(hilight), RSTRING_LEN(hilight));
//                 return;
//             }
//         }

        BUFPUTSL(ob, "<pre lang=\"");
        houdini_escape_html0(ob, (const uint8_t *)lang_name, lang_size, 0);
        BUFPUTSL(ob, "\"><code>");

    } else {
        BUFPUTSL(ob, "<pre><code>");
    }

    houdini_escape_html0(ob, text->data, text->size, 0);
    BUFPUTSL(ob, "</code></pre>\n");
}

/* Max recursion nesting when parsing Markdown documents */
static const int GITHUB_MD_NESTING = 32;

/* Default flags for all Markdown pipelines:
 *
 *  - NO_INTRA_EMPHASIS: disallow emphasis inside of words
 *  - LAX_SPACING: Do spacing like in Markdown 1.0.0 (i.e.
 *      do not require an empty line between two different
 *      blocks in a paragraph)
 *  - STRIKETHROUGH: strike out words with `~~`, same semantics
 *      as emphasis
 *  - TABLES: the tables extension from PHP-Markdown extra
 *  - FENCED_CODE: the fenced code blocks extension from
 *      PHP-Markdown extra, but working with ``` besides ~~~.
 *  - AUTOLINK: Well. That. Link stuff automatically.
 */
static const int GITHUB_MD_FLAGS =
    MKDEXT_NO_INTRA_EMPHASIS |
    MKDEXT_LAX_SPACING |
    MKDEXT_STRIKETHROUGH |
    MKDEXT_TABLES |
    MKDEXT_FENCED_CODE |
    MKDEXT_AUTOLINK;

/* Init the default pipeline */
static void ghmd__init_md(void)
{
    struct sd_callbacks callbacks;

    /* No extra flags to the Markdown renderer */
    sdhtml_renderer(&callbacks, &g_markdown.render_opts, 0);
    callbacks.blockcode = &rndr_blockcode_github;

    g_markdown.md = sd_markdown_new(
        GITHUB_MD_FLAGS,
        GITHUB_MD_NESTING,
        &callbacks,
        &g_markdown.render_opts
    );
}

/* Init the GFM pipeline */
static void ghmd__init_gfm(void)
{
    struct sd_callbacks callbacks;

    /*
     * The following extensions to the HTML output are enabled:
     *
     *  - HARD_WRAP: line breaks are replaced with <br>
     *      entities
     */
    sdhtml_renderer(&callbacks, &g_GFM.render_opts, HTML_HARD_WRAP);
    callbacks.blockcode = &rndr_blockcode_github;

    /* The following extensions to the parser are enabled, on top
     * of the common ones:
     *
     *  - SPACE_HEADERS: require a space between the `#` and the
     *      name of a header (prevents collisions with the Issues
     *      filter)
     */
    g_GFM.md = sd_markdown_new(
        GITHUB_MD_FLAGS | MKDEXT_SPACE_HEADERS,
        GITHUB_MD_NESTING,
        &callbacks,
        &g_GFM.render_opts
    );
}

static void ghmd__init_plaintext(void)
{
    struct sd_callbacks callbacks;

    sdtext_renderer(&callbacks);
    g_plaintext.md = sd_markdown_new(
        GITHUB_MD_FLAGS,
        GITHUB_MD_NESTING,
        &callbacks, NULL
    );
}

#pragma mark - Module Functions

/// hs.doc.markdown.convert(markdown, [type]) -> output
/// Function
/// Converts markdown encoded text to html or plaintext.
///
/// Parameters:
///  * markdown - a string containing the input text encoded using markdown tags
///  * type     - an optional string specifying the conversion options and output type.  Defaults to "gfm".  The currently recognized types are:
///    * "markdown"  - specfies that the output should be HTML with the standard GitHub/Markdown extensions enabled.
///    * "gfm"       - specifies that the output should be HTML with additional GitHub extensions enabled.
///    * "plaintext" - specifies that the output should plain text with the standard GitHub/Markdown extensions enabled.
///
/// Returns:
///  * an HTML or plaintext representation of the markdown encoded text provided.
///
/// Notes:
///  * The standard GitHub/Markdown extensions enabled for all conversions are:
///    * NO_INTRA_EMPHASIS -  disallow emphasis inside of words
///    * LAX_SPACING       - supports spacing like in Markdown 1.0.0 (i.e. do not require an empty line between two different blocks in a paragraph)
///    * STRIKETHROUGH     - support strikethrough with double tildes (~)
///    * TABLES            - support Markdown tables
///    * FENCED_CODE       - supports fenced code blocks surround by three back-ticks (`) or three tildes (~)
///    * AUTOLINK          - HTTP URL's are treated as links, even if they aren't marked as such with Markdown tags
///
///  * The "gfm" type also includes the following extensions:
///   * HARD_WRAP     - line breaks are replaced with <br> entities
///   * SPACE_HEADERS - require a space between the `#` and the name of a header (prevents collisions with the Issues filter)
static int to_html(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    ModeType mode = GFM ;
    if (lua_gettop(L) == 2) {
        NSString *modeString = [skin toNSObjectAtIndex:2] ;
        if ([modeString isEqualToString:@"gfm"]) {
            mode = GFM ;
        } else if ([modeString isEqualToString:@"markdown"] || [modeString isEqualToString:@"readme"]) {
            mode = MARKDOWN ;
        } else if ([modeString isEqualToString:@"plaintext"]) {
            mode = PLAINTEXT;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalide mode, %@, specified", modeString] UTF8String]) ;
        }
    }

    NSData *textBody = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;

    struct buf *output_buf;
    struct sd_markdown *md = NULL;

    /* check for rendering mode */
    if (mode == MARKDOWN) {
        md = g_markdown.md;
    } else if (mode == GFM) {
        md = g_GFM.md;
    } else if (mode == PLAINTEXT) {
        md = g_plaintext.md;
    } else {
       return luaL_error(L, "Invalid render mode");
    }

    /* initialize buffers */
    output_buf = bufnew(128);

    /* render the magic */
    sd_markdown_render(output_buf, [textBody bytes], [textBody length], md);

    /* build the Lua string */
    NSData *outputData = [NSData dataWithBytes:output_buf->data length:output_buf->size];
    [skin pushNSObject:outputData];
    bufrelease(output_buf);

    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"convert", to_html},
    {NULL, NULL}
};

int luaopen_hs_doc_markdown(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:"hs.doc.markdown" functions:moduleLib metaFunctions:nil] ;

    ghmd__init_md();
    ghmd__init_gfm();
    ghmd__init_plaintext();

    return 1;
}
