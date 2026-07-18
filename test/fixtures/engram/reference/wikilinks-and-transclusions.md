# Wikilinks & transclusions (for testing)

Obsidian-style `[[wikilink]]` and `![[transclusion]]` syntax, staged here for
manual testing. **BrainFrame does not resolve these yet** — today they render as
literal text — so this note doubles as a "what does the app do with them right
now?" surface *and* as ready-made coverage for when the resolver lands. Every
target below uses a real filename in this engram (or an intentionally missing
one, called out as such), so a future resolver should be able to hit them
without edits.

## Wikilinks

- Bare filename: [[great-blue-heron]]
- Nested path: [[species/birds/barred-owl]]
- With an alias: [[great-blue-heron|the heron]]
- To a heading: [[cedar-marsh#Walks here]]
- Heading + alias: [[markdown-kitchen-sink#Tables|the tables demo]]
- To a block: [[2026-06-01#^heron-channel]]
- Name with spaces: [[Reading List MoC]]
- Inside prose, the [[eastern-bluebird|bluebird]] link sits mid-sentence.
- Unresolved on purpose: [[No Such Note]] — should surface as a broken /
  unresolved link, the way `broken-links.md` does for standard links.

## Transclusions (embeds)

Whole note:

![[eastern-bluebird]]

A single section of a note:

![[great-blue-heron#Where seen]]

A single block, by its `^id`:

![[2026-06-01#^heron-channel]]

An image, resolved by name from anywhere in the engram:

![[trail-map.png]]

An image with a width hint:

![[great-blue-heron.png|200]]

Unresolved embed on purpose:

![[Missing Note]]

## The same target three ways

Handy for eyeballing how each form renders side by side:

- Standard markdown link: [Great Blue Heron](../species/birds/great-blue-heron.md)
- Wikilink: [[great-blue-heron]]
- Section embed: ![[great-blue-heron#On these walks]]
