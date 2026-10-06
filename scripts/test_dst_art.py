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

    def test_write_icon_atlas(self):
        tex, xml = self.path("gold_axe.tex"), self.path("gold_axe.xml")
        dst_art.write_icon_atlas(self.box_png("icon.png", 64, 64, (8, 8, 55, 55)), tex, xml)
        self.assertEqual(self.read(tex)[:4], b"KTEX")
        self.assertEqual(self.read(xml, "r"),
                         '<Atlas><Texture filename="gold_axe.tex" /><Elements>'
                         '<Element name="gold_axe.tex" u1="0" u2="1" v1="0" v2="1" /></Elements></Atlas>\n')


if __name__ == "__main__":
    unittest.main()
