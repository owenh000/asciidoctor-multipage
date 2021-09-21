# asciidoctor-multipage

[![Build
Status](https://app.travis-ci.com/owenh000/asciidoctor-multipage.svg?branch=master)](https://app.travis-ci.com/owenh000/asciidoctor-multipage)

*asciidoctor-multipage* is an extension for
[Asciidoctor](https://asciidoctor.org/) that adds a configurable multipage HTML
converter. It extends the stock HTML converter to generate multiple HTML pages
from a single, large source document. The behavior is similar to a printed book
where top levels (such as parts and chapters) are separated by page breaks (and
perhaps blank pages) and lower levels (such as sections and subsections) are
all included in a single chunk with styled headers to establish a visual
hierarchy within the chunk.

This extension has also been used to generate a hierarchical *website* (from a
content perspective, essentially multiple documents) from a single Asciidoctor
document. While in some cases this might work fine (and you are free to use it
this way), please understand that it is designed to work with a single,
well-structured Asciidoctor document rather than as a website generator.

For an example of this extension in use, see
<https://owenh.net/nxlog-user-guide.html>.

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

- Footnotes are currently not supported. See [issue
  #3](https://github.com/owenh000/asciidoctor-multipage/issues/3).
- Asciidoctor's `--template-dir` option is currently not supported. See [issue
  #19](https://github.com/owenh000/asciidoctor-multipage/issues/19).

## Installation

This extension is published on RubyGems as
[asciidoctor-multipage](https://rubygems.org/gems/asciidoctor-multipage).
Install the gem by adding it to your project's Gemfile or gemspec and running
Bundler. Or install it directly:

```
$ gem install asciidoctor-multipage
```

(Run `gem install --user-install asciidoctor-multipage` to install the gem in
your user's home directory.)

## Usage

Be sure to use Asciidoctor v2.0.11 or later.

```
$ asciidoctor -V
Asciidoctor 2.0.11 [https://asciidoctor.org]
```

Use Asciidoctor's `-r` option to require `asciidoctor-multipage` and the `-b`
option to select the `multipage_html5` backend. The following command generates
HTML output from a sample document; view the output by loading
`test/out/sample.html` in a browser.

```
$ asciidoctor -r asciidoctor-multipage -b multipage_html5 \
    -D test/out test/black-box-docs/sample/sample.adoc
```

## Adjusting behavior

The `multipage-level` and `desc` attributes are the most important for using
this extension. For an example of the these attributes in use, see
`test/black-box-docs/sample/sample.adoc`. These attributes work as follows:

- The `multipage-level` *document attribute* specifies the section level at
  which the book is split into separate pages. The value should be an integer
  and matches the Asciidoctor levels. Note that as a physical book would
  normally only have page breaks for the top one or two levels in the hierarchy
  (such as *part* and *chapter* or *chapter* and *section*), a
  `multipage-level` value greater than 2 is generally not recommended.
  - `0` splits into parts (h1),
  - `1` splits into chapters (h2)—the default,
  - `2` splits into sections (h3), etc.
- The `multipage-level` *section attribute* specifies the section level to use
  for splitting the children of that section only. The integer given must be
  equal to or greater than the values of all parent levels.
- The `desc` *section attribute* can be used to provide a description for a
  section when it is listed on its parent landing page.

Some additional attributes are available for customizing the extension's
behavior:

- Set the `multipage-disable-css` *document attribute* if you are using a
  custom stylesheet. You will need to include your own rules for styling the
  elements that are specific to multipage output. The default behavior (without
  this attribute set) is to add a few CSS rules in the document header just
  after the regular stylesheet—whether linked or embedded, default or
  custom—using an automatically registered DocinfoProcessor extension.
- To change the navigation labels, use
  the `multipage-nav-previous-label`, `multipage-nav-up-label`,
  `multipage-nav-home-label`, and `multipage-nav-next-label` *document
  attributes*. See `test/black-box-docs/nav-labels/nav-labels.adoc`.

## Contributing

If this project is useful to you, please consider supporting it through [GitHub
Sponsors](https://github.com/owenh000),
[Liberapay](https://liberapay.com/owenh), or [some other
way](https://owenh.net/support).

Other ways to contribute:

- Share this project with someone else who may be interested
- Contribute a fix for a currently open
  [issue](https://github.com/owenh000/asciidoctor-multipage/issues) (if any)
  using a GitHub pull request (please discuss before working on any large
  changes)
- Open a new issue for a problem you've discovered or a possible enhancement

Thank you for your support! ✨

## Development

- To install dependencies, run `bundler install`.
- To run tests, run `bundler exec rake`.
- To run only a specific black-box document test, run `bundler exec rake test
  BB_TEST_ONLY=sample`, where `sample` is the name of the test to run.
- When code modifications are expected to cause a change in HTML output, or
  when a new black-box test is added, run `bundler exec rake test
  BB_UPDATE_FILES=1` to generate (or update) output HTML files for the
  black-box tests.
- To run tests against multiple versions of Asciidoctor:
  1. run `bundler exec appraisal install` to install dependencies and
  2. run `bundler exec appraisal rake` to run the tests.
- To execute Asciidoctor with the extension (in its present local state) for
  testing, run `bundler exec asciidoctor -r asciidoctor-multipage -b
  multipage_html5 -D test/out test/black-box-docs/sample/sample.adoc` (for
  example).
- To build the current version, run `bundler exec rake build`; the gem will be
  placed in the `pkg/` directory.
- To release a new version:
  1. update the date in `asciidoctor-multipage.gemspec`, remove `.dev` from the
     version in `lib/asciidoctor-multipage/version.rb`, run `bundler lock`, and
     commit the changes;
  2. run `bundler exec rake release`; and
  3. increment the version in `lib/asciidoctor-multipage/version.rb` (adding
     `.dev`), run `bundler lock`, and commit the changes.
- To change versions of Asciidoctor to test against:
  1. update `Appraisals` as required,
  2. run `bundler exec appraisal generate --travis`,
  3. update `.travis.yml` using the output from the previous command, and
  4. commit the changes.

## See also

- <https://owenh.net/asciidoctor-multipage>
- <https://github.com/asciidoctor/asciidoctor/issues/626>

## Copyright and License

Copyright 2019-2021 Owen T. Heisler. MIT license.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

This source code may be used according to the terms of the MIT license. You
should have received a copy of this license along with this program (see
`LICENSE`).
