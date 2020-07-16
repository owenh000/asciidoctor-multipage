# asciidoctor-multipage

A multipage HTML converter for Asciidoctor—extends the Html5Converter to
generate multiple HTML pages from the document tree.

See also:

- <https://github.com/asciidoctor/asciidoctor/issues/626>
- <https://github.com/asciidoctor/asciidoctor-extensions-lab/pull/96>
- <https://github.com/asciidoctor/asciidoctor-extensions-lab/blob/master/lib/multipage-html5-converter.rb>

## Features

- Generates a root (top level) landing page with a list of child sections.
- Generates branch (intermediate level) landing pages as required, each with
  a list of child sections.
- Generates leaf (content level) pages with the actual content.
- Allows the chunking depth to be configured with the `multipage-level`
  document attribute (the default is 1—split into chapters).
- Supports variable chunking depth between sections in the document (by
  setting the `multipage-level` attribute on individual sections).
- Uses section IDs to name each page (eg. "introduction.html").
- Supports cross-references between pages.
- Generates a full Table of Contents for each page, but with relevant entries
  only (the TOC collapses as required for each page).
- Includes a description for each section on the branch/leaf landing pages
  (from the `desc` attribute, if set).
- Generates previous/up/home/next navigation links for each page.
- Allows the TOC entry for the current page to be styled with CSS.
- Supports standalone and embedded (--no-header-footer) HTML output.
- Retains correct section numbering throughout.

## Notes and limitations

- Only Asciidoctor v1.5.7.1 is supported. See [issue
  #2](https://github.com/owenh000/asciidoctor-multipage/issues/2).
- Footnotes are currently not supported. See [issue
  #3](https://github.com/owenh000/asciidoctor-multipage/issues/3).
- Inline anchors in unordered list items require the fix for [asciidoctor issue
  #2812](https://github.com/asciidoctor/asciidoctor/issues/2812).
- Block-level content in table cells, with the AsciiDoc "a" attribute, is not
  supported. See [issue
  #1](https://github.com/owenh000/asciidoctor-multipage/issues/1).

## Usage

Be sure to use Asciidoctor v1.5.7.1. Other versions are not yet supported.

There is an extensive sample document under `test/` that showcases the
extension's functionality.

```
$ gem list asciidoctor$
asciidoctor (1.5.7.1)

$ asciidoctor -r ./asciidoctor-multipage.rb -b multipage_html5 \
    test/sample.adoc
```
