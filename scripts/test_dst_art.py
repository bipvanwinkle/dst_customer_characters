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

    def read(self, path, mode="rb"):
        with open(path, mode) as f:
            return f.read()

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

    def test_opaque_box_bounds_the_visible_pixels(self):
        self.assertEqual(dst_art.opaque_box(self.box_png("a.png", 40, 30, (5, 7, 24, 16))), (5, 7, 20, 10))
        self.assertEqual(dst_art.opaque_box(self.box_png("b.png", 8, 8, (0, 0, 7, 7))), (0, 0, 8, 8))

    def test_opaque_box_ignores_faint_pixels_and_blank_images(self):
        px = bytearray(4 * 4 * 4)
        px[3] = 5                                  # a barely visible speck in the corner
        px[(2 * 4 + 1) * 4 + 3] = 200              # one solid pixel at (1, 2)
        dst_art.write_rgba(4, 4, px, self.path("speck.png"))
        self.assertEqual(dst_art.opaque_box(self.path("speck.png")), (1, 2, 1, 1))
        dst_art.write_rgba(4, 4, bytearray(64), self.path("blank.png"))
        self.assertIsNone(dst_art.opaque_box(self.path("blank.png")))

    def test_write_icon_atlas(self):
        tex, xml = self.path("gold_axe.tex"), self.path("gold_axe.xml")
        dst_art.write_icon_atlas(self.box_png("icon.png", 64, 64, (8, 8, 55, 55)), tex, xml)
        self.assertEqual(self.read(tex)[:4], b"KTEX")
        self.assertEqual(self.read(xml, "r"),
                         '<Atlas><Texture filename="gold_axe.tex" /><Elements>'
                         '<Element name="gold_axe.tex" u1="0" u2="1" v1="0" v2="1" /></Elements></Atlas>\n')


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

    def test_single_frame_build_can_cover_many_frame_numbers(self):
        out = self.path("swap_gold_axe.zip")
        dst_art.write_single_frame_build(self.box_png("art.png", 50, 30, (0, 0, 49, 29)), "swap_gold_axe",
                                         "swap_gold_axe", (0.2, 0.7), out, duration=100)
        with zipfile.ZipFile(out) as z:
            (frame,) = dst_art.parse_build(z.read("build.bin"))["symbols"][0]["frames"]
        self.assertEqual((frame["num"], frame["duration"]), (0, 100))


if __name__ == "__main__":
    unittest.main()
