# Item Art Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A script that generates item art with OpenAI's image API and installs it into the `tuning` mod as an inventory icon, a ground build and a held build.

**Architecture:** `scripts/dst_art.py` holds the game-format code (KTEX textures, icon atlases, `build.bin`). `scripts/make_item_art.py` is the command line: `generate` calls OpenAI and saves candidate PNGs, `install` turns a chosen PNG into the three game assets offline. Ground art pairs a new one-frame build with the base game's `cutstone` animation bank, so no animation is authored.

**Tech Stack:** Python 3 standard library (`urllib`, `struct`, `zipfile`, `argparse`, `unittest`), ImageMagick (`magick`).

**Spec:** `docs/superpowers/specs/2026-10-06-item-art-generation-design.md`

## Global Constraints

- Python standard library plus ImageMagick only. No `pip` packages (`openai`, Pillow are not installed and must not be required).
- The API key is read from `OPENAI_API_KEY` and is never printed or written to disk.
- `generate` is the only command that calls the network. `--dry-run` and `install` never do.
- Item names match `[a-z0-9_]+`.
- Default model `gpt-image-2.5-flare`; requests use `size=1024x1024`, `background=transparent`, `output_format=png`; images come back as `data[].b64_json`.
- Ground art: bank `cutstone`, animation `idle`, symbol `cutstone01`. Held art: build and symbol both `swap_<item>`.
- Textures handed to `png_to_ktex` are upside down with premultiplied alpha. Art PNGs on disk (`art/`, candidates) are normal upright PNGs.
- Python style follows `scripts/make_gilded_boomerang.py`: 4 spaces, lines to about 120 columns, short docstrings.
- Tests run with `python3 -m unittest discover -s scripts -p 'test_*.py'` from the repo root.
- The command shell here is zsh and does not see the key. Real `generate` runs go through `fish -c '...'`.

## Review Focus

1. An item name with spaces, capitals or path separators (`"Gold Axe"`, `../x`): rejected with a one-line error before anything is written. Test in Task 3 (`test_rejects_bad_item_name`).
2. A candidate that is entirely transparent (a blank generation): `install` refuses it with a clear message instead of crashing in `magick -trim`. Test in Task 4 (`test_refuses_blank_candidate`).
3. A non-square candidate (a long spear, 300x60): the icon is still exactly 64x64 and nothing is stretched. Test in Task 4 (`test_wide_image_keeps_aspect`).
4. OpenAI returns fewer images than asked, or entries without `b64_json`: the images that did arrive are saved; none at all is a clear error. Tests in Task 3 (`test_saves_what_arrives`, `test_no_images_is_an_error`).
5. Two `generate` runs for the same item in the same second: the second run must not overwrite the first run's candidates. Test in Task 3 (`test_same_second_runs_do_not_overwrite`).

---

### Task 1: Shared texture code and the icon atlas

**Files:**
- Create: `scripts/dst_art.py`
- Create: `scripts/test_dst_art.py`
- Modify: `scripts/make_gilded_boomerang.py` (remove lines 14-66, the `DDS_FOURCC` constant and the KTEX section; import them instead)

**Interfaces:**
- Produces, all in `dst_art`:
  - `ktex_to_png(tex: bytes, png: str) -> None`, `png_to_ktex(png: str) -> bytes`, `read_rgba(png: str) -> (w, h, bytearray)`: moved unchanged.
  - `write_rgba(w: int, h: int, px: bytes, png: str) -> None`
  - `texture_png(src: str, dst: str, canvas: (w, h) | None = None) -> None`: normal PNG to KTEX layout.
  - `from_texture_png(src: str, dst: str) -> None`: the inverse.
  - `write_icon_atlas(png: str, tex_path: str, xml_path: str) -> None`: takes a normal PNG.

- [ ] **Step 1: Write the failing tests**

Create `scripts/test_dst_art.py`:

```python
import glob, os, subprocess, sys, tempfile, unittest, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dst_art

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DST_ANIM = os.path.expanduser("~/.local/share/Steam/steamapps/common/Don't Starve Together/data/anim")


class TmpCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = tmp.name

    def path(self, name):
        return os.path.join(self.tmp, name)

    def box_png(self, name, w, h, box):
        """A transparent w x h PNG with an opaque rectangle box = (x0, y0, x1, y1)."""
        path = self.path(name)
        subprocess.run(["magick", "-size", f"{w}x{h}", "xc:none", "+antialias", "-fill", "rgb(200,100,50)",
                        "-draw", "rectangle %d,%d %d,%d" % box, path], check=True)
        return path


class TextureTest(TmpCase):
    def two_by_two(self):
        px = bytearray(16)  # top-left opaque red, bottom-left half-transparent orange, the rest clear
        px[0:4] = bytes((255, 0, 0, 255))
        px[8:12] = bytes((200, 100, 50, 128))
        dst_art.write_rgba(2, 2, px, self.path("src.png"))
        return self.path("src.png")

    def test_texture_png_flips_and_premultiplies(self):
        dst_art.texture_png(self.two_by_two(), self.path("tex.png"))
        w, h, out = dst_art.read_rgba(self.path("tex.png"))
        self.assertEqual((w, h), (2, 2))
        self.assertEqual(tuple(out[8:12]), (255, 0, 0, 255))   # the top row is now the bottom row
        self.assertEqual(tuple(out[0:4]), (100, 50, 25, 128))  # colour scaled by alpha

    def test_texture_png_canvas_pads_from_top_left(self):
        dst_art.texture_png(self.box_png("src.png", 2, 2, (0, 0, 1, 1)), self.path("tex.png"), canvas=(4, 4))
        w, h, out = dst_art.read_rgba(self.path("tex.png"))
        self.assertEqual((w, h), (4, 4))
        alpha = [out[3::4][row * 4:row * 4 + 4] for row in range(4)]
        # the image sat in the top-left corner, so after the flip it is in the bottom-left corner
        self.assertEqual([list(r) for r in alpha], [[0, 0, 0, 0], [0, 0, 0, 0], [255, 255, 0, 0], [255, 255, 0, 0]])

    def test_from_texture_png_undoes_texture_png(self):
        dst_art.texture_png(self.two_by_two(), self.path("tex.png"))
        dst_art.from_texture_png(self.path("tex.png"), self.path("back.png"))
        _, _, out = dst_art.read_rgba(self.path("back.png"))
        self.assertEqual(tuple(out[0:4]), (255, 0, 0, 255))
        self.assertEqual(out[11], 128)
        for got, want in zip(out[8:11], (200, 100, 50)):
            self.assertAlmostEqual(got, want, delta=2)

    def test_ktex_round_trip_keeps_size_and_alpha(self):
        dst_art.texture_png(self.box_png("src.png", 64, 64, (16, 16, 47, 47)), self.path("tex.png"))
        tex = dst_art.png_to_ktex(self.path("tex.png"))
        self.assertEqual(tex[:4], b"KTEX")
        dst_art.ktex_to_png(tex, self.path("out.png"))
        w, h, out = dst_art.read_rgba(self.path("out.png"))
        self.assertEqual((w, h), (64, 64))
        self.assertEqual(out[3], 0)                        # corner stays clear
        self.assertEqual(out[(32 * 64 + 32) * 4 + 3], 255)  # centre stays solid

    def test_write_icon_atlas(self):
        tex, xml = self.path("gold_axe.tex"), self.path("gold_axe.xml")
        dst_art.write_icon_atlas(self.box_png("icon.png", 64, 64, (8, 8, 55, 55)), tex, xml)
        self.assertEqual(open(tex, "rb").read(4), b"KTEX")
        self.assertEqual(open(xml).read(),
                         '<Atlas><Texture filename="gold_axe.tex" /><Elements>'
                         '<Element name="gold_axe.tex" u1="0" u2="1" v1="0" v2="1" /></Elements></Atlas>\n')


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: FAIL with `ModuleNotFoundError: No module named 'dst_art'`

- [ ] **Step 3: Create `scripts/dst_art.py`**

Move `DDS_FOURCC`, `ktex_to_png`, `png_to_ktex` and `read_rgba` out of `scripts/make_gilded_boomerang.py` without changing their bodies, under this header, then add the new functions below them:

```python
"""Shared pieces for building Don't Starve Together art: KTEX textures, icon atlases and anim builds.

Needs ImageMagick (`magick`).
"""
import os, struct, subprocess, tempfile, zipfile

DDS_FOURCC = {0: b"DXT1", 1: b"DXT3", 2: b"DXT5"}


# ---- KTEX <-> PNG ----------------------------------------------------------------------------
# KTEX is the game's texture format: a header bitfield, one header per mipmap, then the mip data.
# Textures are stored upside down and with premultiplied alpha.

# ktex_to_png, png_to_ktex and read_rgba go here, moved as they are.


def write_rgba(w, h, px, png):
    subprocess.run(["magick", "-size", f"{w}x{h}", "-depth", "8", "RGBA:-", png], input=bytes(px), check=True)


def texture_png(src, dst, canvas=None):
    """Normal PNG -> the layout KTEX stores: upside down with premultiplied alpha.

    `canvas` (w, h) first pads the image out from its top-left corner.
    """
    cmd = ["magick", src, "-background", "none", "-gravity", "NorthWest"]
    if canvas:
        cmd += ["-extent", "%dx%d" % canvas]
    w, h = canvas or read_rgba(src)[:2]
    px = bytearray(subprocess.check_output(cmd + ["-flip", "-depth", "8", "RGBA:-"]))
    for i in range(0, len(px), 4):
        a = px[i + 3]
        px[i:i + 3] = bytes(c * a // 255 for c in px[i:i + 3])
    write_rgba(w, h, px, dst)


def from_texture_png(src, dst):
    """The inverse of texture_png: turn a decoded texture upright and undo the alpha premultiply."""
    w, h, _ = read_rgba(src)
    px = bytearray(subprocess.check_output(["magick", src, "-flip", "-depth", "8", "RGBA:-"]))
    for i in range(0, len(px), 4):
        a = px[i + 3]
        if a:
            px[i:i + 3] = bytes(min(255, c * 255 // a) for c in px[i:i + 3])
    write_rgba(w, h, px, dst)


# ---- Inventory icons -------------------------------------------------------------------------

def write_icon_atlas(png, tex_path, xml_path):
    """Write a normal PNG as a single-image inventory atlas: the .tex plus the .xml that maps it."""
    name = os.path.basename(tex_path)
    with tempfile.TemporaryDirectory() as tmp:
        tex_png = os.path.join(tmp, "tex.png")
        texture_png(png, tex_png)
        open(tex_path, "wb").write(png_to_ktex(tex_png))
    open(xml_path, "w").write(
        f'<Atlas><Texture filename="{name}" /><Elements>'
        f'<Element name="{name}" u1="0" u2="1" v1="0" v2="1" /></Elements></Atlas>\n')
```

- [ ] **Step 4: Point the gilded boomerang script at the shared code**

In `scripts/make_gilded_boomerang.py`, delete the `DDS_FOURCC` line and the whole `# ---- KTEX <-> PNG` section (through the end of `read_rgba`), and add this import after the existing `import` line:

```python
from dst_art import ktex_to_png, png_to_ktex, read_rgba
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: `Ran 5 tests` ... `OK`

- [ ] **Step 6: Check the gilded boomerang script still produces the same art**

```bash
scripts/make_gilded_boomerang.py
git status --short tuning/images
old=$(mktemp -d)
for z in boomerang_gilded swap_boomerang_gilded; do
  git show HEAD:tuning/anim/$z.zip > $old/$z.zip
  for m in build.bin atlas-0.tex; do
    cmp <(unzip -p tuning/anim/$z.zip $m) <(unzip -p $old/$z.zip $m) && echo "$z/$m same"
  done
done
rm -r $old
git checkout tuning/anim
```

Expected: `git status` prints nothing for `tuning/images` (the `.tex` and `.xml` are byte-identical), and four `same` lines. The zips themselves differ only by their embedded timestamps, so they are restored with `git checkout`.

- [ ] **Step 7: Commit**

```bash
git add scripts/dst_art.py scripts/test_dst_art.py scripts/make_gilded_boomerang.py
git commit -m "scripts: share KTEX code in dst_art, add icon atlas writer"
```

---

### Task 2: Reading and writing `build.bin`

**Files:**
- Modify: `scripts/dst_art.py` (append a `# ---- Anim builds` section)
- Modify: `scripts/test_dst_art.py` (add `BuildTest`)

**Interfaces:**
- Consumes: `read_rgba`, `texture_png`, `png_to_ktex`, `ktex_to_png` from Task 1.
- Produces:
  - `strhash(s: str) -> int`
  - `parse_build(data: bytes) -> dict` with keys `version`, `name`, `atlases` (list of str), `symbols` (list of `{"hash", "frames": [{"num", "duration", "x", "y", "w", "h", "vert_index", "vert_count"}]}`), `verts` (list of 6-tuples `x, y, z, u, v, w`), `names` (list of `(hash, name)`).
  - `write_build(build: dict) -> bytes`
  - `write_single_frame_build(png: str, build_name: str, symbol: str, pivot: (float, float), out_zip: str) -> None`. `pivot` is the point of the image, as fractions of its width and height from the top left, that sits at the symbol's origin.

- [ ] **Step 1: Write the failing tests**

Add to `scripts/test_dst_art.py`, above the `if __name__` block:

```python
class BuildTest(TmpCase):
    def test_strhash_matches_game_hashes(self):
        self.assertEqual(dst_art.strhash("swap_boomerang"), 0xB2D9F4B6)
        self.assertEqual(dst_art.strhash("boomerang01"), 0x6DE856C3)
        self.assertEqual(dst_art.strhash("BrokeTool01"), 0x500C4CD2)

    def round_trip(self, zips):
        for path in zips:
            with zipfile.ZipFile(path) as z:
                if "build.bin" not in z.namelist():
                    continue
                data = z.read("build.bin")
            self.assertEqual(dst_art.write_build(dst_art.parse_build(data)), data, path)

    def test_round_trip_mod_builds(self):
        zips = sorted(glob.glob(os.path.join(ROOT, "tuning", "anim", "*.zip")))
        self.assertTrue(zips)
        self.round_trip(zips)

    @unittest.skipUnless(os.path.isdir(DST_ANIM), "no DST install")
    def test_round_trip_base_game_builds(self):
        self.round_trip(sorted(glob.glob(os.path.join(DST_ANIM, "*.zip")))[::15])

    def test_single_frame_build(self):
        out = self.path("gold_axe.zip")
        dst_art.write_single_frame_build(self.box_png("art.png", 50, 30, (0, 0, 49, 29)), "gold_axe", "cutstone01",
                                         (0.5, 0.75), out)
        with zipfile.ZipFile(out) as z:
            self.assertEqual(z.namelist(), ["build.bin", "atlas-0.tex"])
            build, tex = dst_art.parse_build(z.read("build.bin")), z.read("atlas-0.tex")
        self.assertEqual((build["version"], build["name"], build["atlases"]), (6, "gold_axe", ["atlas-0.tex"]))
        self.assertEqual(build["names"], [(dst_art.strhash("cutstone01"), "cutstone01")])
        (symbol,) = build["symbols"]
        self.assertEqual(symbol["hash"], dst_art.strhash("cutstone01"))
        (frame,) = symbol["frames"]
        self.assertEqual(frame, {"num": 0, "duration": 1, "x": 0.0, "y": -7.5, "w": 50.0, "h": 30.0,
                                 "vert_index": 0, "vert_count": 6})
        xs, ys, _, us, vs, _ = zip(*build["verts"])
        self.assertEqual(len(build["verts"]), 6)
        self.assertEqual((min(xs), max(xs), min(ys), max(ys)), (-25.0, 25.0, -22.5, 7.5))
        self.assertEqual((min(us), max(us), min(vs), max(vs)), (0.0, 50 / 64, 1 - 30 / 32, 1.0))
        # the top of the image (smallest y) carries v = 1, as in the game's own builds
        self.assertEqual({v for y, v in zip(ys, vs) if y == -22.5}, {1.0})
        dst_art.ktex_to_png(tex, self.path("atlas.png"))
        self.assertEqual(dst_art.read_rgba(self.path("atlas.png"))[:2], (64, 32))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: 4 errors, each `AttributeError: module 'dst_art' has no attribute ...`

- [ ] **Step 3: Implement the build code**

Append to `scripts/dst_art.py`:

```python
# ---- Anim builds -----------------------------------------------------------------------------
# An anim zip's build.bin lists symbols, each a set of frames that are quads into atlas-0.tex.
# Animations live in a separate bank, so a new build can be paired with a base-game animation.

def strhash(s):
    """The game's string hash, used for symbol names."""
    h = 0
    for c in s.lower():
        h = (ord(c) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF
    return h


def parse_build(data):
    assert data[:4] == b"BILD"
    pos = 4

    def take(fmt):
        nonlocal pos
        vals = struct.unpack_from("<" + fmt, data, pos)
        pos += struct.calcsize("<" + fmt)
        return vals

    def take_str():
        nonlocal pos
        n, = take("I")
        s = data[pos:pos + n].decode("latin-1")
        pos += n
        return s

    version, nsymbols, _ = take("III")  # the third field is the total frame count
    build = {"version": version, "name": take_str()}
    build["atlases"] = [take_str() for _ in range(take("I")[0])]
    build["symbols"] = []
    for _ in range(nsymbols):
        sym_hash, nframes = take("II")
        frames = []
        for _ in range(nframes):
            num, duration = take("II")
            x, y, w, h = take("ffff")
            vert_index, vert_count = take("II")
            frames.append({"num": num, "duration": duration, "x": x, "y": y, "w": w, "h": h,
                           "vert_index": vert_index, "vert_count": vert_count})
        build["symbols"].append({"hash": sym_hash, "frames": frames})
    build["verts"] = [take("ffffff") for _ in range(take("I")[0])]
    build["names"] = [(take("I")[0], take_str()) for _ in range(take("I")[0])]
    assert pos == len(data), (pos, len(data))
    return build


def write_build(build):
    def pstr(s):
        return struct.pack("<I", len(s)) + s.encode("latin-1")

    out = bytearray(b"BILD")
    out += struct.pack("<III", build["version"], len(build["symbols"]),
                       sum(len(s["frames"]) for s in build["symbols"]))
    out += pstr(build["name"]) + struct.pack("<I", len(build["atlases"]))
    for atlas in build["atlases"]:
        out += pstr(atlas)
    for sym in build["symbols"]:
        out += struct.pack("<II", sym["hash"], len(sym["frames"]))
        for f in sym["frames"]:
            out += struct.pack("<IIffffII", f["num"], f["duration"], f["x"], f["y"], f["w"], f["h"],
                               f["vert_index"], f["vert_count"])
    out += struct.pack("<I", len(build["verts"]))
    for vert in build["verts"]:
        out += struct.pack("<ffffff", *vert)
    out += struct.pack("<I", len(build["names"]))
    for name_hash, name in build["names"]:
        out += struct.pack("<I", name_hash) + pstr(name)
    return bytes(out)


def write_single_frame_build(png, build_name, symbol, pivot, out_zip):
    """Write a normal PNG as an anim zip holding a one-symbol, one-frame build.

    `pivot` is the point of the image, as fractions of its width and height from the top left,
    that sits at the symbol's origin.
    """
    w, h, _ = read_rgba(png)
    aw, ah = (max(4, 1 << (n - 1).bit_length()) for n in (w, h))  # atlas sides are powers of two
    x0, y0 = -pivot[0] * w, -pivot[1] * h
    x1, y1, u1, v1 = x0 + w, y0 + h, w / aw, 1 - h / ah
    # two triangles; v runs from 1 at the top of the image because the texture is stored upside down
    verts = [(x0, y0, 0, 0, 1, 0), (x1, y0, 0, u1, 1, 0), (x0, y1, 0, 0, v1, 0),
             (x1, y0, 0, u1, 1, 0), (x1, y1, 0, u1, v1, 0), (x0, y1, 0, 0, v1, 0)]
    frame = {"num": 0, "duration": 1, "x": x0 + w / 2, "y": y0 + h / 2, "w": w, "h": h,
             "vert_index": 0, "vert_count": 6}
    build = {"version": 6, "name": build_name, "atlases": ["atlas-0.tex"],
             "symbols": [{"hash": strhash(symbol), "frames": [frame]}], "verts": verts,
             "names": [(strhash(symbol), symbol)]}
    with tempfile.TemporaryDirectory() as tmp:
        tex_png = os.path.join(tmp, "atlas.png")
        texture_png(png, tex_png, canvas=(aw, ah))
        tex = png_to_ktex(tex_png)
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("build.bin", write_build(build))
        z.writestr("atlas-0.tex", tex)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: `Ran 9 tests` ... `OK`

- [ ] **Step 5: Commit**

```bash
git add scripts/dst_art.py scripts/test_dst_art.py
git commit -m "scripts: read and write anim build.bin, single-frame builds"
```

---

### Task 3: `generate`

**Files:**
- Create: `scripts/make_item_art.py` (executable)
- Create: `scripts/test_make_item_art.py`
- Modify: `.gitignore` (append the candidates rule)

**Interfaces:**
- Consumes: `dst_art.ktex_to_png`, `dst_art.read_rgba`, `dst_art.from_texture_png`.
- Produces, in `make_item_art`:
  - `fail(msg) -> NoReturn` (`sys.exit("error: " + msg)`), `check_item(name)`, `magick(*args)`.
  - `build_prompt(text, held=False, base=False) -> str`
  - `main(argv=None)`, with a hidden top-level `--art DIR` option (before the command) that tests use to redirect `art/`.
  - Constants `ROOT`, `DEFAULT_DATA`, `DEFAULT_MODEL`, `STYLE`, `HELD`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/test_make_item_art.py`:

```python
import base64, contextlib, glob, io, json, os, subprocess, sys, tempfile, time, unittest, urllib.error, zipfile
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dst_art, make_item_art

HAVE_DST = os.path.exists(os.path.join(make_item_art.DEFAULT_DATA, "databundles", "images.zip"))


class CliCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = tmp.name
        self.art = os.path.join(self.tmp, "art")
        env = mock.patch.dict(os.environ, {"OPENAI_API_KEY": "sk-test-secret"})
        env.start()
        self.addCleanup(env.stop)

    def path(self, name):
        return os.path.join(self.tmp, name)

    def run_cli(self, *argv):
        """Run the command line; returns what it printed."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            make_item_art.main(["--art", self.art, *argv])
        return out.getvalue()

    def fails(self, *argv):
        """Run the command line expecting an error exit; returns the message."""
        with self.assertRaises(SystemExit) as caught:
            self.run_cli(*argv)
        self.assertIsInstance(caught.exception.code, str)
        return caught.exception.code

    def candidates(self, item="thing"):
        return sorted(glob.glob(os.path.join(self.art, item, "candidates", "*.png")))

    def fake_api(self, images):
        """Patch urlopen to answer with these image byte strings (None = an entry with no image)."""
        self.requests = []
        reply = {"data": [{"b64_json": base64.b64encode(i).decode()} if i is not None else {} for i in images]}

        def urlopen(request, timeout=None):
            self.requests.append(request)
            return io.BytesIO(json.dumps(reply).encode())

        patch = mock.patch("urllib.request.urlopen", urlopen)
        patch.start()
        self.addCleanup(patch.stop)

    def no_network(self):
        patch = mock.patch("urllib.request.urlopen", side_effect=AssertionError("network call"))
        patch.start()
        self.addCleanup(patch.stop)


class GenerateTest(CliCase):
    def test_prompt_carries_style_and_item(self):
        prompt = make_item_art.build_prompt("  a golden axe ")
        self.assertIn(make_item_art.STYLE, prompt)
        self.assertTrue(prompt.endswith("The item: a golden axe"))
        self.assertNotIn(make_item_art.HELD, prompt)
        self.assertIn(make_item_art.HELD, make_item_art.build_prompt("a golden axe", held=True))
        self.assertIn("reference", make_item_art.build_prompt("a golden axe", base=True))

    def test_rejects_bad_item_name(self):
        self.no_network()
        for name in ("Gold Axe", "../x", "gold-axe", ""):
            self.assertIn("item name", self.fails("generate", name, "--prompt", "an axe"))
        self.assertFalse(os.path.exists(self.art))

    def test_dry_run_prints_the_request_and_stops(self):
        self.no_network()
        del os.environ["OPENAI_API_KEY"]
        out = self.run_cli("generate", "thing", "--prompt", "a golden axe", "-n", "2", "--dry-run")
        self.assertIn(make_item_art.DEFAULT_MODEL, out)
        self.assertIn("The item: a golden axe", out)
        self.assertIn("2", out)
        self.assertEqual(self.candidates(), [])

    def test_missing_key_is_a_clear_error(self):
        self.no_network()
        del os.environ["OPENAI_API_KEY"]
        self.assertIn("OPENAI_API_KEY", self.fails("generate", "thing", "--prompt", "an axe"))

    def test_saves_candidates_and_sends_the_right_request(self):
        self.fake_api([b"first", b"second"])
        out = self.run_cli("generate", "thing", "--prompt", "a golden axe", "-n", "2")
        saved = self.candidates()
        self.assertEqual([open(p, "rb").read() for p in saved], [b"first", b"second"])
        for p in saved:
            self.assertIn(p, out)
        self.assertNotIn("sk-test-secret", out)
        (request,) = self.requests
        self.assertEqual(request.full_url, "https://api.openai.com/v1/images/generations")
        self.assertEqual(request.get_header("Authorization"), "Bearer sk-test-secret")
        body = json.loads(request.data)
        self.assertEqual({k: body[k] for k in ("model", "n", "size", "background", "output_format")},
                         {"model": make_item_art.DEFAULT_MODEL, "n": 2, "size": "1024x1024",
                          "background": "transparent", "output_format": "png"})
        self.assertIn("The item: a golden axe", body["prompt"])

    def test_model_flag_and_held_prefix(self):
        self.fake_api([b"one"])
        self.run_cli("generate", "thing", "--prompt", "an axe", "--held", "--model", "gpt-image-2.5-sunburst")
        (saved,) = self.candidates()
        self.assertTrue(os.path.basename(saved).startswith("held-"))
        body = json.loads(self.requests[0].data)
        self.assertEqual(body["model"], "gpt-image-2.5-sunburst")
        self.assertIn(make_item_art.HELD, body["prompt"])

    def test_saves_what_arrives(self):
        self.fake_api([b"only", None])
        self.run_cli("generate", "thing", "--prompt", "an axe", "-n", "3")
        self.assertEqual(len(self.candidates()), 1)

    def test_no_images_is_an_error(self):
        self.fake_api([None])
        self.assertIn("no images", self.fails("generate", "thing", "--prompt", "an axe"))
        self.assertEqual(self.candidates(), [])

    def test_same_second_runs_do_not_overwrite(self):
        self.fake_api([b"a", b"b"])
        with mock.patch.object(time, "strftime", return_value="20261006-120000"):
            self.run_cli("generate", "thing", "--prompt", "an axe", "-n", "2")
            self.run_cli("generate", "thing", "--prompt", "an axe", "-n", "2")
        self.assertEqual(len(self.candidates()), 4)

    def test_api_error_reports_and_saves_nothing(self):
        error = urllib.error.HTTPError("https://api.openai.com/v1/images/generations", 400, "Bad Request", {},
                                       io.BytesIO(b'{"error": {"message": "prompt was rejected"}}'))
        with mock.patch("urllib.request.urlopen", side_effect=error):
            message = self.fails("generate", "thing", "--prompt", "an axe")
        self.assertIn("400", message)
        self.assertIn("prompt was rejected", message)
        self.assertNotIn("sk-test-secret", message)
        self.assertEqual(self.candidates(), [])

    def test_missing_imagemagick_is_a_clear_error(self):
        self.no_network()
        with mock.patch("shutil.which", return_value=None):
            self.assertIn("ImageMagick", self.fails("generate", "thing", "--prompt", "an axe", "--dry-run"))

    def test_missing_dst_install_is_a_clear_error(self):
        self.no_network()
        message = self.fails("generate", "thing", "--prompt", "an axe", "--base", "boomerang",
                             "--data", self.path("nowhere"))
        self.assertIn("DST install", message)

    @unittest.skipUnless(HAVE_DST, "no DST install")
    def test_unknown_base_item_is_a_clear_error(self):
        self.no_network()
        self.assertIn("no_such_item_xyz", self.fails("generate", "thing", "--prompt", "an axe",
                                                     "--base", "no_such_item_xyz"))

    @unittest.skipUnless(HAVE_DST, "no DST install")
    def test_base_icon_goes_to_the_edit_endpoint(self):
        self.fake_api([b"one"])
        out = self.run_cli("generate", "thing", "--prompt", "a golden boomerang", "--base", "boomerang")
        self.assertIn("boomerang", out)
        (request,) = self.requests
        self.assertEqual(request.full_url, "https://api.openai.com/v1/images/edits")
        self.assertTrue(request.get_header("Content-type").startswith("multipart/form-data; boundary="))
        self.assertIn(b'name="image"; filename="base.png"', request.data)
        self.assertIn(b"\x89PNG", request.data)
        self.assertIn(b'name="background"\r\n\r\ntransparent', request.data)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: an import error for `test_make_item_art`: `ModuleNotFoundError: No module named 'make_item_art'`

- [ ] **Step 3: Implement `generate`**

Create `scripts/make_item_art.py` and `chmod +x` it:

```python
#!/usr/bin/env python3
"""Generate art for a mod item with OpenAI's image API and install it in the game's formats.

  generate <item> --prompt TEXT   save candidate images to art/<item>/candidates/ (calls the API)
  install <item> [candidate]      write the inventory icon, ground build and held build from one image

Needs ImageMagick (`magick`). generate needs OPENAI_API_KEY in the environment, and an installed copy
of DST for --base.
"""
import argparse, base64, json, os, re, shutil, subprocess, sys, tempfile, time, urllib.error, urllib.request
import uuid, zipfile

import dst_art

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DEFAULT_DATA = os.path.expanduser("~/.local/share/Steam/steamapps/common/Don't Starve Together/data")
DEFAULT_MODEL = "gpt-image-2.5-flare"
API = "https://api.openai.com/v1/images/"
STYLE = ("A single game item drawn in the art style of Don't Starve: hand-drawn, with thick uneven dark "
         "outlines, sketchy cross-hatched shading, a muted earthy palette and a slightly crooked gothic look. "
         "The object is centred, fills most of the frame and sits on a fully transparent background, "
         "with no shadow, no ground, no text and no border.")
HELD = ("Drawn as it is held in a hand: the object runs diagonally, with its grip at the bottom left "
        "and its working end at the top right.")
REFERENCE = "Use the attached image as the reference for drawing style, line weight and proportions."


def fail(msg):
    sys.exit("error: " + msg)


def check_item(name):
    if not re.fullmatch(r"[a-z0-9_]+", name):
        fail(f"item name {name!r} must be lowercase letters, digits and underscores")


def magick(*args):
    subprocess.run(["magick", *args], check=True)


# ---- generate --------------------------------------------------------------------------------

def build_prompt(text, held=False, base=False):
    parts = [STYLE] + ([HELD] if held else []) + ([REFERENCE] if base else [])
    return " ".join(parts + ["The item: " + text.strip()])


def base_icon(data, item, out_png):
    """Cut a base-game item's inventory icon out of the DST install, upright and enlarged, as a reference."""
    images = os.path.join(data, "databundles", "images.zip")
    if not os.path.exists(images):
        fail(f"no DST install at {data} (needed for --base)")
    pattern = r'<Element name="%s\.tex" u1="([\d.]+)" u2="([\d.]+)" v1="([\d.]+)" v2="([\d.]+)"' % re.escape(item)
    with zipfile.ZipFile(images) as z, tempfile.TemporaryDirectory() as tmp:
        for xml_name in sorted(n for n in z.namelist() if re.match(r"images/inventoryimages\d+\.xml$", n)):
            m = re.search(pattern, z.read(xml_name).decode())
            if m:
                break
        else:
            fail(f"no base-game inventory icon named {item}")
        u1, u2, v1, v2 = map(float, m.groups())
        atlas, crop, upright = (os.path.join(tmp, n) for n in ("atlas.png", "crop.png", "upright.png"))
        dst_art.ktex_to_png(z.read(xml_name[:-4] + ".tex"), atlas)
        aw, ah, _ = dst_art.read_rgba(atlas)
        w, h = round((u2 - u1) * aw), round((v2 - v1) * ah)
        magick(atlas, "-crop", f"{w}x{h}+{round(u1 * aw)}+{round(v1 * ah)}", "+repage", crop)
        dst_art.from_texture_png(crop, upright)
        magick(upright, "-resize", "512x512", out_png)


def multipart(fields, name, filename, data):
    """Encode form fields plus one PNG file; returns (body, content type)."""
    boundary = uuid.uuid4().hex
    body = b""
    for key, value in fields.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
    body += (f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
             "Content-Type: image/png\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    return body, "multipart/form-data; boundary=" + boundary


def request_images(key, model, prompt, n, reference=None):
    """Ask OpenAI for n transparent PNGs; with a reference image, through the edit endpoint."""
    fields = {"model": model, "prompt": prompt, "n": n, "size": "1024x1024", "background": "transparent",
              "output_format": "png"}
    if reference:
        url = API + "edits"
        body, content_type = multipart(fields, "image", "base.png", open(reference, "rb").read())
    else:
        url, body, content_type = API + "generations", json.dumps(fields).encode(), "application/json"
    request = urllib.request.Request(url, data=body, headers={"Authorization": "Bearer " + key,
                                                              "Content-Type": content_type})
    try:
        with urllib.request.urlopen(request, timeout=600) as reply:
            data = json.load(reply).get("data") or []
    except urllib.error.HTTPError as e:
        with e:
            try:
                message = json.load(e)["error"]["message"]
            except Exception:
                message = e.reason
        fail(f"OpenAI API error {e.code}: {message}")
    except urllib.error.URLError as e:
        fail(f"could not reach OpenAI: {e.reason}")
    images = [base64.b64decode(d["b64_json"]) for d in data if d.get("b64_json")]
    if not images:
        fail("OpenAI returned no images")
    return images


def free_path(path):
    """This path, or the same name with a counter if a file is already there."""
    stem, ext = os.path.splitext(path)
    n = 1
    while os.path.exists(path):
        n += 1
        path = f"{stem}-{n}{ext}"
    return path


def cmd_generate(args):
    check_item(args.item)
    prompt = build_prompt(args.prompt, held=args.held, base=bool(args.base))
    with tempfile.TemporaryDirectory() as tmp:
        reference = None
        if args.base:
            reference = os.path.join(tmp, "base.png")
            base_icon(args.data, args.base, reference)
        print(f"model:  {args.model}\nimages: {args.n}\nprompt: {prompt}")
        if args.base:
            print(f"reference: base-game icon of {args.base}")
        if args.dry_run:
            return
        key = os.environ.get("OPENAI_API_KEY")
        if not key:
            fail("OPENAI_API_KEY is not set in the environment")
        images = request_images(key, args.model, prompt, args.n, reference)
    out = os.path.join(args.art, args.item, "candidates")
    os.makedirs(out, exist_ok=True)
    stamp = ("held-" if args.held else "") + time.strftime("%Y%m%d-%H%M%S")
    for i, image in enumerate(images, 1):
        path = free_path(os.path.join(out, f"{stamp}-{i}.png"))
        open(path, "wb").write(image)
        print("saved", path)


# ---- command line ----------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--art", default=os.path.join(ROOT, "art"), help=argparse.SUPPRESS)
    commands = parser.add_subparsers(dest="command", required=True)

    gen = commands.add_parser("generate", help="save candidate images for an item (calls the OpenAI API)")
    gen.add_argument("item")
    gen.add_argument("--prompt", required=True, help="what the item looks like")
    gen.add_argument("--base", metavar="GAME_ITEM", help="base-game item whose icon is sent as a reference")
    gen.add_argument("--held", action="store_true", help="draw the item as held in a hand")
    gen.add_argument("-n", type=int, default=3, help="number of candidates (default 3)")
    gen.add_argument("--model", default=DEFAULT_MODEL)
    gen.add_argument("--data", default=DEFAULT_DATA, help="DST data directory, for --base")
    gen.add_argument("--dry-run", action="store_true", help="print the request and stop")
    gen.set_defaults(run=cmd_generate)

    args = parser.parse_args(argv)
    if not shutil.which("magick"):
        fail("ImageMagick (`magick`) is not installed")
    args.run(args)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Ignore candidates**

Append to `.gitignore`:

```
# Generated art candidates; the chosen master.png is kept
art/*/candidates/
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: `Ran 23 tests` ... `OK` (14 new; the three `--base` tests that need DST are skipped on a machine without it)

- [ ] **Step 6: Check the dry run by hand**

Run: `scripts/make_item_art.py generate art_test --prompt "a boomerang carved from gold" --base boomerang --dry-run`
Expected: four lines (model, images, prompt, reference), no network call, no `art/` directory created.

- [ ] **Step 7: Commit**

```bash
git add scripts/make_item_art.py scripts/test_make_item_art.py .gitignore
git commit -m "scripts: make_item_art generate, candidate images from OpenAI"
```

---

### Task 4: `install`

**Files:**
- Modify: `scripts/make_item_art.py` (add the install section and its parser)
- Modify: `scripts/test_make_item_art.py` (add `InstallTest`)

**Interfaces:**
- Consumes: `dst_art.write_icon_atlas`, `dst_art.write_single_frame_build`, `dst_art.read_rgba`; `fail`, `check_item`, `magick`, `ROOT` from Task 3.
- Produces: the `install` command; constants `GROUND_BANK = "cutstone"`, `GROUND_SYMBOL = "cutstone01"`.

- [ ] **Step 1: Write the failing tests**

Add to `scripts/test_make_item_art.py`, above the `if __name__` block:

```python
class InstallTest(CliCase):
    def setUp(self):
        super().setUp()
        self.mod = self.path("mod")
        os.mkdir(self.mod)

    def art_png(self, name, w, h, box, background="none"):
        path = self.path(name)
        subprocess.run(["magick", "-size", f"{w}x{h}", f"xc:{background}", "+antialias", "-fill", "rgb(200,100,50)",
                        "-draw", "rectangle %d,%d %d,%d" % box, path], check=True)
        return path

    def install(self, *argv):
        return self.run_cli("install", "thing", *argv, "--mod", self.mod)

    def build(self, name):
        with zipfile.ZipFile(os.path.join(self.mod, "anim", name + ".zip")) as z:
            return dst_art.parse_build(z.read("build.bin"))

    def frame(self, name):
        return self.build(name)["symbols"][0]["frames"][0]

    def test_writes_icon_ground_and_held_art(self):
        candidate = self.art_png("c.png", 200, 200, (50, 50, 149, 149))
        out = self.install(candidate)
        self.assertEqual(open(os.path.join(self.art, "thing", "master.png"), "rb").read(),
                         open(candidate, "rb").read())
        icons = os.path.join(self.mod, "images", "inventoryimages")
        self.assertIn('name="thing.tex"', open(os.path.join(icons, "thing.xml")).read())
        dst_art.ktex_to_png(open(os.path.join(icons, "thing.tex"), "rb").read(), self.path("icon.png"))
        self.assertEqual(dst_art.read_rgba(self.path("icon.png"))[:2], (64, 64))
        ground, held = self.build("thing"), self.build("swap_thing")
        self.assertEqual((ground["name"], ground["names"][0][1]), ("thing", "cutstone01"))
        self.assertEqual((held["name"], held["names"][0][1]), ("swap_thing", "swap_thing"))
        self.assertEqual((self.frame("thing")["w"], self.frame("thing")["h"]), (128.0, 128.0))
        for line in ('SetBank("cutstone")', 'SetBuild("thing")',
                     'OverrideSymbol("swap_object", "swap_thing", "swap_thing")',
                     'Asset("ANIM", "anim/swap_thing.zip")', 'RegisterInventoryItemAtlas'):
            self.assertIn(line, out)

    def test_wide_image_keeps_aspect(self):
        self.install(self.art_png("c.png", 400, 200, (50, 70, 349, 129)))  # the art itself is 300x60
        dst_art.ktex_to_png(open(os.path.join(self.mod, "images", "inventoryimages", "thing.tex"), "rb").read(),
                            self.path("icon.png"))
        w, h, px = dst_art.read_rgba(self.path("icon.png"))
        self.assertEqual((w, h), (64, 64))
        alpha = px[3::4]
        solid_rows = [y for y in range(64) if max(alpha[y * 64:y * 64 + 64]) > 127]
        solid_cols = [x for x in range(64) if max(alpha[x::64]) > 127]
        self.assertAlmostEqual(len(solid_cols), 60, delta=2)
        self.assertAlmostEqual(len(solid_rows), 12, delta=2)
        frame = self.frame("thing")
        self.assertEqual((frame["w"], frame["h"]), (128.0, 26.0))

    def test_refuses_candidate_without_transparency(self):
        message = self.fails("install", "thing", self.art_png("c.png", 64, 64, (8, 8, 55, 55), "white"),
                             "--mod", self.mod)
        self.assertIn("transparent", message)
        self.assertFalse(os.path.exists(os.path.join(self.art, "thing", "master.png")))
        self.assertEqual(os.listdir(self.mod), [])

    def test_refuses_blank_candidate(self):
        blank = self.path("blank.png")
        subprocess.run(["magick", "-size", "64x64", "xc:none", blank], check=True)
        self.assertIn("blank", self.fails("install", "thing", blank, "--mod", self.mod))
        self.assertEqual(os.listdir(self.mod), [])

    def test_missing_candidate_file(self):
        self.assertIn("no such image", self.fails("install", "thing", self.path("nope.png"), "--mod", self.mod))

    def test_needs_a_master_first(self):
        self.assertIn("master.png", self.fails("install", "thing", "--mod", self.mod))

    def test_missing_mod_directory(self):
        candidate = self.art_png("c.png", 64, 64, (8, 8, 55, 55))
        self.assertIn("mod", self.fails("install", "thing", candidate, "--mod", self.path("nowhere")))

    def test_rejects_bad_item_name(self):
        candidate = self.art_png("c.png", 64, 64, (8, 8, 55, 55))
        self.assertIn("item name", self.fails("install", "Gold Axe", candidate, "--mod", self.mod))

    def test_rebuilds_from_the_master_with_new_sizes(self):
        self.install(self.art_png("c.png", 200, 200, (50, 50, 149, 149)))
        self.install("--ground-size", "80", "--held-size", "90", "--ground-pivot", "0,0", "--held-pivot", "1,1")
        ground, held = self.frame("thing"), self.frame("swap_thing")
        self.assertEqual((ground["w"], ground["x"], ground["y"]), (80.0, 40.0, 40.0))
        self.assertEqual((held["w"], held["x"], held["y"]), (90.0, -45.0, -45.0))

    def test_default_pivots(self):
        self.install(self.art_png("c.png", 200, 200, (50, 50, 149, 149)))
        ground, held = self.frame("thing"), self.frame("swap_thing")
        self.assertEqual((ground["x"], ground["y"]), (0.0, -32.0))          # pivot 0.5,0.75 of 128
        self.assertAlmostEqual(held["x"], (0.5 - 0.2) * held["w"], places=3)
        self.assertAlmostEqual(held["y"], (0.5 - 0.7) * held["h"], places=3)

    def test_held_image_and_rotation(self):
        master = self.art_png("c.png", 200, 200, (50, 50, 149, 149))
        tall = self.art_png("h.png", 200, 200, (90, 20, 109, 179))  # 20x160
        self.install(master, "--held-image", tall)
        self.assertTrue(os.path.exists(os.path.join(self.art, "thing", "held.png")))
        frame = self.frame("swap_thing")
        self.assertEqual((frame["w"], frame["h"]), (16.0, 128.0))
        self.install("--held-rotate", "90")   # held.png is reused, now lying on its side
        frame = self.frame("swap_thing")
        self.assertEqual((frame["w"], frame["h"]), (128.0, 16.0))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: the 11 `InstallTest` tests fail or error with `invalid choice: 'install'` (argparse exits with code 2).

- [ ] **Step 3: Implement `install`**

In `scripts/make_item_art.py`, add under the `API` constant:

```python
GROUND_BANK, GROUND_SYMBOL = "cutstone", "cutstone01"  # a base-game bank whose idle is one static symbol
LUA = """\
-- modmain.lua
table.insert(Assets, Asset("ATLAS", "images/inventoryimages/{item}.xml"))
table.insert(Assets, Asset("IMAGE", "images/inventoryimages/{item}.tex"))
RegisterInventoryItemAtlas(GLOBAL.resolvefilepath("images/inventoryimages/{item}.xml"), "{item}.tex")

-- prefab assets
Asset("ANIM", "anim/{bank}.zip"),
Asset("ANIM", "anim/{item}.zip"),
Asset("ANIM", "anim/swap_{item}.zip"),
Asset("ATLAS", "images/inventoryimages/{item}.xml"),
Asset("IMAGE", "images/inventoryimages/{item}.tex"),

-- prefab fn
inst.AnimState:SetBank("{bank}")
inst.AnimState:SetBuild("{item}")
inst.AnimState:PlayAnimation("idle")
inst.components.inventoryitem.atlasname = "images/inventoryimages/{item}.xml"

-- on equip
owner.AnimState:OverrideSymbol("swap_object", "swap_{item}", "swap_{item}")"""
```

Add this section between the generate section and the command line section:

```python
# ---- install ---------------------------------------------------------------------------------

def adopt(src, dst):
    """Copy a chosen image into the item's art folder, refusing ones that cannot work in game."""
    if not os.path.exists(src):
        fail(f"no such image: {src}")
    try:
        alpha = dst_art.read_rgba(src)[2][3::4]
    except subprocess.CalledProcessError:
        fail(f"{src} is not a readable image")
    if max(alpha) == 0:
        fail(f"{src} is blank (completely transparent)")
    if min(alpha) == 255:
        fail(f"{src} has no transparent background, so it would show as a solid square in game")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)


def cmd_install(args):
    check_item(args.item)
    item = args.item
    mod = os.path.join(ROOT, args.mod)
    if not os.path.isdir(mod):
        fail(f"no mod directory {mod}")
    master, held = (os.path.join(args.art, item, n) for n in ("master.png", "held.png"))
    if args.candidate:
        adopt(args.candidate, master)
    if args.held_image:
        adopt(args.held_image, held)
    if not os.path.exists(master):
        fail(f"no {master} yet; pass a candidate image to install")
    icons, anim = os.path.join(mod, "images", "inventoryimages"), os.path.join(mod, "anim")
    os.makedirs(icons, exist_ok=True)
    os.makedirs(anim, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        icon, ground, hand = (os.path.join(tmp, n) for n in ("icon.png", "ground.png", "hand.png"))
        magick(master, "-trim", "+repage", "-resize", "60x60", "-background", "none", "-gravity", "center",
               "-extent", "64x64", icon)
        dst_art.write_icon_atlas(icon, os.path.join(icons, item + ".tex"), os.path.join(icons, item + ".xml"))
        magick(master, "-trim", "+repage", "-resize", f"{args.ground_size}x{args.ground_size}", ground)
        dst_art.write_single_frame_build(ground, item, GROUND_SYMBOL, args.ground_pivot,
                                         os.path.join(anim, item + ".zip"))
        magick(held if os.path.exists(held) else master, "-background", "none", "-trim", "+repage",
               "-rotate", str(args.held_rotate), "-trim", "+repage",
               "-resize", f"{args.held_size}x{args.held_size}", hand)
        dst_art.write_single_frame_build(hand, "swap_" + item, "swap_" + item, args.held_pivot,
                                         os.path.join(anim, f"swap_{item}.zip"))
    print(f"wrote icon, ground and held art for {item} to {os.path.normpath(mod)}\n")
    print(LUA.format(item=item, bank=GROUND_BANK))


def pivot(text):
    try:
        x, y = (float(v) for v in text.split(","))
    except ValueError:
        raise argparse.ArgumentTypeError("expected X,Y as fractions of the image, e.g. 0.5,0.75")
    return x, y
```

In `main`, add the parser before `args = parser.parse_args(argv)`:

```python
    ins = commands.add_parser("install", help="write the icon, ground build and held build from one image")
    ins.add_argument("item")
    ins.add_argument("candidate", nargs="?", help="image to adopt as the master (omit to rebuild from it)")
    ins.add_argument("--held-image", metavar="PNG", help="separate image for the held art")
    ins.add_argument("--ground-size", type=int, default=128, metavar="PX", help="long side on the ground")
    ins.add_argument("--ground-pivot", type=pivot, default=(0.5, 0.75), metavar="X,Y")
    ins.add_argument("--held-size", type=int, default=128, metavar="PX", help="long side in the hand")
    ins.add_argument("--held-rotate", type=float, default=0, metavar="DEG", help="clockwise turn before use")
    ins.add_argument("--held-pivot", type=pivot, default=(0.2, 0.7), metavar="X,Y", help="the grip point")
    ins.add_argument("--mod", default="tuning", help="mod directory (default tuning)")
    ins.set_defaults(run=cmd_install)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s scripts -p 'test_*.py'`
Expected: `Ran 34 tests` ... `OK`

- [ ] **Step 5: Commit**

```bash
git add scripts/make_item_art.py scripts/test_make_item_art.py
git commit -m "scripts: make_item_art install, icon plus ground and held builds"
```

---

### Task 5: First real run and the in-game check

This task spends money (one `generate` call of 3 images) and needs a person looking at the game. Nothing from it is committed except a spec correction, if one is needed.

**Files:**
- Temporary, not committed: `tuning/scripts/prefabs/art_test.lua`, two lines in `tuning/modmain.lua`, `art/art_test/`, `tuning/anim/art_test.zip`, `tuning/anim/swap_art_test.zip`, `tuning/images/inventoryimages/art_test.*`

- [ ] **Step 1: Generate candidates for a test item**

Run: `fish -c 'scripts/make_item_art.py generate art_test --prompt "a short one-handed pickaxe with a gold head and a rope-wrapped wooden handle" --base pickaxe'`
Expected: three `saved art/art_test/candidates/...png` lines. Look at each image (Read tool) and confirm the background is transparent and the style is close to the game's.

If the API rejects a parameter, fix `request_images` to match the error message, add a test for the corrected request, and rerun.

- [ ] **Step 2: Install the best candidate**

Run: `scripts/make_item_art.py install art_test art/art_test/candidates/<chosen>.png`
Expected: the "wrote icon, ground and held art" line and the Lua reminder; `tuning/anim/art_test.zip`, `tuning/anim/swap_art_test.zip` and `tuning/images/inventoryimages/art_test.tex`/`.xml` exist.

- [ ] **Step 3: Wire a throwaway prefab**

Create `tuning/scripts/prefabs/art_test.lua`:

```lua
local assets = {
	Asset("ANIM", "anim/cutstone.zip"),
	Asset("ANIM", "anim/art_test.zip"),
	Asset("ANIM", "anim/swap_art_test.zip"),
	Asset("ATLAS", "images/inventoryimages/art_test.xml"),
	Asset("IMAGE", "images/inventoryimages/art_test.tex"),
}

local function onequip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "swap_art_test", "swap_art_test")
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("cutstone")
	inst.AnimState:SetBuild("art_test")
	inst.AnimState:PlayAnimation("idle")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.atlasname = "images/inventoryimages/art_test.xml"
	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)

	return inst
end

return Prefab("art_test", fn, assets)
```

In `tuning/modmain.lua`, change `PrefabFiles = { "boomerang_gilded" }` to `PrefabFiles = { "boomerang_gilded", "art_test" }` and add below the existing `RegisterInventoryItemAtlas` line:

```lua
RegisterInventoryItemAtlas(GLOBAL.resolvefilepath("images/inventoryimages/art_test.xml"), "art_test.tex")
```

- [ ] **Step 4: Deploy and check in game (person)**

Ask which machine to deploy to, then run `make deploy-tuning-desktop` or `make deploy-tuning-steamdeck`. In a world with the mod enabled, open the console and run `c_give("art_test")`, then check in order:

1. Icon: the item shows in the inventory slot, upright, with a clean transparent edge.
2. Ground: drop it. It shows upright at a sensible size, sitting on the ground rather than sunk into it.
3. Held: equip it. It shows in the hand facing down, up and sideways, with the grip in the fist.

- [ ] **Step 5: Tune or fix from what was seen**

- Wrong size or position: rerun `install art_test` with `--ground-size`, `--ground-pivot`, `--held-size`, `--held-rotate`, `--held-pivot`, redeploy, recheck. If the defaults are clearly off for a typical item, change them in `main` and in `test_default_pivots`.
- Upside down or dark fringes: the flip or premultiply in `dst_art.texture_png` is wrong for that asset; fix it there and update `TextureTest`.
- Held art missing in some facings: the hand animations ask for frame numbers above 0. Give the swap frame a longer `duration` in `write_single_frame_build` (a parameter defaulting to 1) and retest.
- Record any correction in the spec.

- [ ] **Step 6: Remove the test item**

```bash
git checkout tuning/modmain.lua
rm -r tuning/scripts/prefabs/art_test.lua art/art_test tuning/anim/art_test.zip tuning/anim/swap_art_test.zip \
      tuning/images/inventoryimages/art_test.tex tuning/images/inventoryimages/art_test.xml
git status --short
```

Expected: `git status` shows only intended changes from Step 5, if any. Redeploy so the test item is gone from the installed mod.

- [ ] **Step 7: Commit any fixes**

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
git add -A scripts docs
git commit -m "scripts: make_item_art fixes from the in-game check"
```

Skip if Step 5 changed nothing.
