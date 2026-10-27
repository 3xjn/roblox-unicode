# Unicode text boundaries

An independent Luau implementation of Unicode 17 line-break opportunities.
It has no Roblox services, font, CSS, React, Tailwind or Coss dependency.
The API is experimental. The Unicode 17 default break-position corpus passes in
Studio; broader conformance and integration limits are described below.

```luau
local Unicode = require(packages.Unicode)
local breaks, reason = Unicode.lineBreaks("One two")
-- { { position = 4, required = false }, { position = 7, required = true } }
```

`position` counts UTF-8 bytes preceding the boundary. Only allowed or required
boundaries are returned; omitted internal boundaries are prohibited. The final
boundary is required, including position zero for empty text. These positions
are not character indices, UTF-16 offsets, or selected display lines.

Invalid UTF-8 and non-scalar input return `nil, reason`. Work is bounded to
65,536 bytes, 16,384 code points and 1,000,000 boundary/lookaround operations.
Exceeding a budget returns no partial result.

`version` identifies the Unicode data version. `lineBreakProperty(codepoint)`
returns the raw UCD line-break class and internal property flags documented in
`data-provenance.json`; the lookup expects an integer Unicode code point.

## Data and implementation

Run `npm run build:unicode` from the workspace root to regenerate the property
table. The TypeScript script downloads official Unicode data into the ignored
artifact cache and checks pinned SHA-256 hashes before generating source.
It uses explicit general-category and emoji data, not Node's ambient Unicode
regular expressions. The generated table has 3,987 merged property ranges and
49 validated line-break classes, including the digit-bearing B2/H2/H3 names.

The opportunity rules adapt `@cto.af/linebreak` 4.0.3 at
`088ff02569c5f213951e819a0578f164455f1075`. Retain `LICENSE.upstream` and
`LICENSE.unicode` when distributing the package. The adaptation groups combining
sequences, preserves a physical trailing ZWJ for LB8a, and clears pending
space-run state at mandatory breaks. It does not blindly inherit the reference
package's conformance claim.

## Observed scope and remaining work

Bounded Studio observations on 2026-10-22 covered UTF-8 byte offsets, spaces,
NBSP, word joiner, combining marks, CJK, trailing ZWJ, CRLF, regional-indicator
pairs, emoji modifiers, zero-width-space runs, mandatory-break state reset,
invalid input and input budgets.

The official Unicode 17 `LineBreakTest.txt` corpus was subsequently run against
the actual Luau module in Studio: all 19,338 cases matched every allowed and
prohibited break position, with no excluded cases. The first run found 31
mismatches caused by a data-parser bug truncating B2/H2/H3; the generator now
accepts digits and validates the entire class inventory. The corrected data
passed the complete corpus on a fresh Play session. See the pinned input and
source hashes in [verification.json](verification.json).

A second complete run also compared required/optional flags using the pinned
corpus's rule annotations: rules 4 and 5 identify mandatory breaks, and the final
boundary is required. All 19,338 cases matched, including 1,110 cases with an
internal mandatory break. The finite corpus does not cover every possible
Unicode sequence or prove CSS, shaping, performance or Volt behavior.
Input/work budgets remain explicit API limits.

CSS wrapping policy, width-dependent line choice, dictionary segmentation,
hyphenation, grapheme segmentation, bidi and language tailoring are separate.
The CSS leaf-paragraph formatter now consumes these opportunities for bounded
normal wrapping and `break-spaces`. CSS tailoring, full Unicode conformance and
mixed inline formatting remain incomplete. The formatter measures complete
candidate lines and reuses native glyph shaping after selecting their boundaries.

## Repository setup

This repository contains the `@3xjn/roblox-unicode` package. It is in active development and has not been published to npm.

Run `npm install` to install development dependencies from the related GitHub repositories.

Build the Luau module with `rojo build default.project.json --output Unicode.rbxm`. Runtime imports expect the related modules as siblings in the Roblox package tree.

The development gallery and cross-package tests remain in the private [roblox-styling workspace](https://github.com/3xjn/roblox-styling).
