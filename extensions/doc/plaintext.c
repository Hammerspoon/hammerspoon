/*
 * Copyright (c) 2012, Vicent Marti
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include "markdown.h"
#include "plaintext.h"
#include "buffer.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

static void plaintext(struct buf *ob, const struct buf *text)
{
	if (!text || !text->size)
		return;

	bufput(ob, text->data, text->size);
}

static void plaintext_block(struct buf *ob, const struct buf *text)
{
	if (ob->size)
		bufputc(ob, '\n');

	plaintext(ob, text);
	bufputc(ob, '\n');
}

/********************
 * GENERIC RENDERER *
 ********************/
static int
rndr_autolink(struct buf *ob, const struct buf *link, __unused enum mkd_autolink type, __unused void *opaque)
{
	plaintext(ob, link);
	return 1;
}

static void
rndr_blockcode(struct buf *ob, const struct buf *text, __unused const struct buf *lang, __unused void *opaque)
{
	plaintext_block(ob, text);
}

static void
rndr_blockquote(struct buf *ob, const struct buf *text, __unused void *opaque)
{
	plaintext_block(ob, text);
}

static int
rndr_span_element(struct buf *ob, const struct buf *text, __unused void *opaque)
{
	plaintext(ob, text);
	return 1;
}

static int
rndr_linebreak(struct buf *ob, __unused void *opaque)
{
	bufputc(ob, '\n');
	return 1;
}

static void
rndr_header(struct buf *ob, const struct buf *text, __unused int level, __unused void *opaque)
{
	plaintext_block(ob, text);
}

static int
rndr_link(struct buf *ob, __unused const struct buf *link, __unused const struct buf *title, const struct buf *content, __unused void *opaque)
{
	plaintext(ob, content);
	return 1;
}

static void
rndr_list(struct buf *ob, const struct buf *text, __unused int flags, __unused void *opaque)
{
	plaintext_block(ob, text);
}

static void
rndr_listitem(struct buf *ob, const struct buf *text, __unused int flags, __unused void *opaque)
{
	BUFPUTSL(ob, "- ");
	plaintext(ob, text);
	bufputc(ob, '\n');
}

static void
rndr_paragraph(struct buf *ob, const struct buf *text, __unused void *opaque)
{
	plaintext_block(ob, text);
}

static void
rndr_hrule(__unused struct buf *ob, __unused void *opaque)
{
	/* NO OP */
}

static int
rndr_image(__unused struct buf *ob, __unused const struct buf *link, __unused const struct buf *title, __unused const struct buf *alt, __unused void *opaque)
{
	/* NO OP */
	return 1;
}

static int
rndr_raw_html(__unused struct buf *ob, __unused const struct buf *text, __unused void *opaque)
{
	/* NO OP */
	return 1;
}

static void
rndr_table(struct buf *ob, __unused const struct buf *header, const struct buf *body, __unused void *opaque)
{
	plaintext_block(ob, body);
}

static void
rndr_tablerow(struct buf *ob, const struct buf *text, __unused void *opaque)
{
	plaintext_block(ob, text);
}

static void
rndr_tablecell(struct buf *ob, const struct buf *text, __unused int flags, __unused void *opaque)
{
	plaintext_block(ob, text);
}

void
sdtext_renderer(struct sd_callbacks *callbacks)
{
	static const struct sd_callbacks cb_default = {
		rndr_blockcode,
		rndr_blockquote,
		NULL,
		rndr_header,
		rndr_hrule,
		rndr_list,
		rndr_listitem,
		rndr_paragraph,
		rndr_table,
		rndr_tablerow,
		rndr_tablecell,

		rndr_autolink,
		rndr_span_element,
		rndr_span_element,
		rndr_span_element,
		rndr_image,
		rndr_linebreak,
		rndr_link,
		rndr_raw_html,
		rndr_span_element,
		rndr_span_element,
		rndr_span_element,

		NULL,
		NULL,

		NULL,
		NULL,
	};

	/* Prepare the callbacks */
	memcpy(callbacks, &cb_default, sizeof(struct sd_callbacks));
}
