# Don't Starve Together mods

## Generating item art

`scripts/make_item_art.py` makes an item's inventory icon, ground art and held art with OpenAI's image
API and writes them into a mod (default `tuning`) in the game's formats. Art comes after gameplay: only
generate it once the item's design is settled. Design notes are in
`docs/superpowers/specs/2026-10-06-item-art-generation-design.md`; `--help` on each command lists every flag.

### 1. Generate candidates (costs money)

```fish
fish -c 'scripts/make_item_art.py generate <item> --prompt "what it looks like" --base pickaxe --base goldenaxe'
```

- Run it through `fish -c`: the key (`OPENAI_API_KEY`) is set in `~/.config/fish/conf.d/secrets.fish`,
  which the agent's own shell does not load. Never read or print that file.
- Always pass two or more `--base` items. Each is a base-game inventory icon sent as a style reference,
  and several of them are what brings the result close to the game's look. Pick items of a similar kind
  and material (for a gold tool: `goldenaxe`, `goldenpickaxe`).
- Write the prompt from the item's design. Name materials and colours plainly ("a bright gold head").
- `--dry-run` prints the request without calling the API. `-n` sets the number of candidates (default 3).
- Candidates land in `art/<item>/candidates/` (gitignored). Look at them, and compare at 64 pixels next
  to real icons before choosing: fine detail that looks good at full size turns to mush in the inventory.

### 2. Install the chosen image (offline, repeatable)

```fish
scripts/make_item_art.py install <item> art/<item>/candidates/<chosen>.png
```

This saves the image as `art/<item>/master.png` (commit it) and writes:

| Asset | File |
|---|---|
| Inventory icon | `tuning/images/inventoryimages/<item>.tex` and `.xml` |
| Ground art | `tuning/anim/<item>.zip` |
| Held art | `tuning/anim/swap_<item>.zip` |

Run `install <item>` with no image to rebuild from the master after changing flags:

- Held art is turned 45 degrees counter-clockwise by default, because icons are drawn diagonally and
  held tools stand upright. Use `--held-rotate 0` for art that is already upright, or another angle.
- The held pivot is found on the handle, four fifths of the way down. Override with `--held-pivot X,Y`.
- `--held-size`, `--ground-size` and `--ground-pivot` adjust the rest.
- For an item that needs a different drawing in the hand, run `generate --held` and pass the result
  with `--held-image`.

### 3. Wire it in Lua

`install` prints the lines to add; it never edits Lua. They are:

- `modmain.lua`: the two `Asset` entries, `RegisterInventoryItemAtlas`, and
  `GLOBAL.STRINGS.NAMES.<ITEM>` (without it the item shows as `MISSING_NAME`).
- Prefab assets: `anim/cutstone.zip`, `anim/<item>.zip`, `anim/swap_<item>.zip`, the icon atlas and image.
- Prefab `fn`: `SetBank("cutstone")`, `SetBuild("<item>")`, `PlayAnimation("idle")`, and the
  `inventoryitem.atlasname`. The ground art borrows the base game's `cutstone` animation.
- On equip: `OverrideSymbol("swap_object", "swap_<item>", "swap_<item>")`.

No animations are written or copied. Mining, attacking and the rest are the player's own animations,
which draw the held image in their `swap_object` slot.

### 4. Check in game

Deploy with `make deploy-tuning-desktop` (or `deploy-tuning-steamdeck`), restart DST, and look at the
item in the inventory, on the ground, and in the hand while idle, facing each direction, and using it.
Only a person looking at the game can confirm this.

### Tests

```fish
python3 -m unittest discover -s scripts -p 'test_*.py'
```
