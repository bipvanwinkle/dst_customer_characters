# Item art generation

Date: 2026-10-06

## Purpose

Items in the `tuning` mod are designed gameplay-first. Once an item's design is settled it needs art:
an inventory icon, a look on the ground and, for equippable items, a look in the character's hand.
This tool generates that art with OpenAI's image API and writes it into the mod in the game's formats.

Success: for a finished item, one `generate` and one `install` produce an icon, ground art and held art
that show correctly in game, with no Windows-only or third-party modding tools.

## Scope

In scope:

- Generating candidate images from a prompt, optionally with a base-game icon as reference.
- Writing the inventory icon, ground build and held (swap) build for one item in the `tuning` mod.

Out of scope:

- Writing animations (`anim.bin`). Ground art pairs a new build with a base-game animation bank.
- Multi-frame or animated art, character sprites, portraits and Workshop preview images.
- Generating the Lua wiring. Registering assets and pointing the prefab at them is a hand edit per item.
- Mods other than `tuning` (the mod directory is a flag, defaulting to `tuning`).

## Workflow

`scripts/make_item_art.py` has two commands.

### `generate <item> --prompt TEXT [--base GAME_ITEM] [--held] [-n N] [--model ID] [--dry-run]`

- Builds the request prompt from `TEXT` plus a fixed style preamble describing Don't Starve's
  hand-drawn look (thick dark outlines, muted palette, transparent background, single centred object).
- With `--base`, extracts that item's icon from the DST install (`databundles/images.zip`, the
  `inventoryimages*.xml` atlases) and sends it as a reference image through the image edit endpoint.
  Without it, uses the image generation endpoint.
- Saves `N` candidates (default 3) as `art/<item>/candidates/<timestamp>-<i>.png`, or
  `held-<timestamp>-<i>.png` with `--held`.
- Prints the model, prompt and image count before calling the API. `--dry-run` stops there.
- Reads the key from the `OPENAI_API_KEY` environment variable and exits with a clear message if it
  is unset. The key is never printed or written to disk.

This is the only command that calls the API or costs money.

### `install <item> [candidate] [--held-image PNG] [--ground-size PX] [--held-size PX] [--held-rotate DEG] [--held-pivot X,Y] [--mod DIR]`

- Copies the chosen candidate to `art/<item>/master.png` (and `--held-image` to
  `art/<item>/held.png`), trims transparent margins, then writes:

| Asset | File | Derivation |
|---|---|---|
| Inventory icon | `<mod>/images/inventoryimages/<item>.tex` and `.xml` | Master scaled to fit 64x64, single-image atlas as for `boomerang_gilded` |
| Ground art | `<mod>/anim/<item>.zip` | One-symbol, one-frame build; master scaled to `--ground-size` on its long side; pivot at the image centre |
| Held art | `<mod>/anim/swap_<item>.zip` | One-symbol, one-frame build named `swap_<item>` with symbol `swap_<item>`; `held.png` if present, otherwise the master; rotated by `--held-rotate`, scaled to `--held-size`, pivot at `--held-pivot` (fractions of width and height, the grip point) |

- Run with no candidate argument, it rebuilds from the existing `master.png`, so sizes and pivots can
  be tuned without regenerating.
- Prints the Lua lines the item needs (`Asset` entries, `RegisterInventoryItemAtlas`, `SetBuild`,
  `OverrideSymbol`) as a reminder. It does not edit Lua files.

`art/<item>/master.png` and `held.png` are committed. `art/*/candidates/` is gitignored.

## Code layout

- `scripts/dst_art.py`: shared library.
  - KTEX conversion (`ktex_to_png`, `png_to_ktex`, `read_rgba`), moved unchanged out of
    `make_gilded_boomerang.py`, which then imports them.
  - `write_icon_atlas(png, tex_path, xml_path)`: the single-image `.tex` plus `.xml` atlas.
  - `parse_build(bytes)` and `write_build(build)`: the `build.bin` reader and writer.
  - `write_single_frame_build(png, build_name, symbol, pivot, out_zip)`: one image to an anim zip.
- `scripts/make_item_art.py`: argument parsing, prompt assembly, the OpenAI HTTP call and the two commands.
- `scripts/test_dst_art.py`: `unittest` tests.

Python standard library plus ImageMagick (`magick`) only, as in the existing script. HTTP uses `urllib`.

## `build.bin` layout

Verified by parsing both builds in `tuning/anim/` to their final byte. Little-endian throughout;
strings are a `uint32` length followed by the bytes.

```
"BILD"
uint32 version (6)
uint32 symbol count
uint32 total frame count
string build name
uint32 atlas count, then one string per atlas ("atlas-0.tex")
per symbol:
    uint32 name hash
    uint32 frame count
    per frame:
        uint32 frame number, uint32 duration
        float32 x, y, w, h        (bounding box; x,y is the box centre relative to the pivot)
        uint32 first vertex index, uint32 vertex count
uint32 vertex count
per vertex: float32 x, y, z, u, v, w
uint32 hash count, then per entry: uint32 hash, string name
```

A single-frame build has one symbol, one frame (number 0, duration 1) and six vertices: two triangles
covering the image, with `u,v` spanning the whole atlas and `v` flipped because KTEX is stored upside
down.

The name hash, confirmed against `swap_boomerang`, `boomerang01` and `broketool01`:

```python
def strhash(s):
    h = 0
    for c in s.lower():
        h = (ord(c) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF
    return h
```

The atlas is the image padded to power-of-two dimensions, converted with `png_to_ktex`.

## Stages

Each stage ends with an in-game check before the next begins.

1. **Icon.** `dst_art.py` with the KTEX move and `write_icon_atlas`; `generate` and `install` writing
   the icon only. Check: the icon shows in the inventory.
2. **Ground art.** `parse_build`, `write_build`, `write_single_frame_build`; `install` writes
   `<item>.zip`. Choose the base-game bank to borrow and record the choice and the symbol name it
   expects in this spec. Check: the item shows correctly when dropped.
3. **Held art.** `install` writes `swap_<item>.zip`; `--held` generation. Check: the item sits
   correctly in the hand facing each direction.

## Testing

- `write_build(parse_build(b)) == b` for both builds in `tuning/anim/` and for a sample of base-game
  builds when the DST install is present (skipped otherwise).
- `strhash` against the three known hashes.
- `write_single_frame_build` output parses back to one symbol, one frame, six vertices and the
  requested pivot.
- PNG to KTEX to PNG keeps dimensions and alpha.
- Prompt assembly and `--dry-run` make no network call.

The OpenAI call itself is not unit tested; it is exercised by real `generate` runs.

## Error handling

- Missing key, missing `magick`, missing DST install (only needed for `--base`) and unknown `--base`
  item each exit non-zero with a one-line message naming the problem.
- API errors print the status and OpenAI's error message, and save nothing.
- `install` refuses a candidate with no transparency, since it would produce a solid square in game.

## Open items, settled during the build

- **Default model.** The key can use `gpt-image-1`, `gpt-image-1.5`, `gpt-image-2` and
  `gpt-image-2.5`. Before stage 1's first real run, check which support transparent backgrounds and
  reference images, pick the default and record it here. `--model` overrides it.
- **Ground bank.** Chosen and verified in stage 2.
- **Held art from the master.** If a rotated master does not read well in hand for the first real
  item, `--held` generation becomes the documented default for equippable items.
