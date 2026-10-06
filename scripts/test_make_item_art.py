import base64, contextlib, glob, io, json, os, subprocess, sys, tempfile, time, unittest, urllib.error, zipfile
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dst_art, make_item_art


def read(path):
    with open(path, "rb") as f:
        return f.read()


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
        self.assertIn(make_item_art.REFERENCE, make_item_art.build_prompt("a golden axe", base=True))
        self.assertNotIn(make_item_art.REFERENCE, prompt)

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
        self.assertEqual([read(p) for p in saved], [b"first", b"second"])
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
    def test_several_base_icons_are_all_sent(self):
        self.fake_api([b"one"])
        out = self.run_cli("generate", "thing", "--prompt", "a golden hammer", "--base", "hammer",
                           "--base", "goldenaxe")
        self.assertIn("hammer, goldenaxe", out)
        (request,) = self.requests
        self.assertEqual(request.full_url, "https://api.openai.com/v1/images/edits")
        self.assertEqual(request.data.count(b'name="image[]"'), 2)
        self.assertEqual(request.data.count(b"\x89PNG"), 2)

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
        self.assertEqual(read(os.path.join(self.art, "thing", "master.png")), read(candidate))
        icons = os.path.join(self.mod, "images", "inventoryimages")
        self.assertIn(b'name="thing.tex"', read(os.path.join(icons, "thing.xml")))
        dst_art.ktex_to_png(read(os.path.join(icons, "thing.tex")), self.path("icon.png"))
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
        dst_art.ktex_to_png(read(os.path.join(self.mod, "images", "inventoryimages", "thing.tex")),
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

    def test_master_can_be_passed_as_the_candidate(self):
        self.install(self.art_png("c.png", 200, 200, (50, 50, 149, 149)))
        self.install(os.path.join(self.art, "thing", "master.png"), "--ground-size", "80")
        self.assertEqual(self.frame("thing")["w"], 80.0)

    def test_held_frame_covers_every_frame_the_player_animations_ask_for(self):
        self.install(self.art_png("c.png", 200, 200, (50, 50, 149, 149)))
        # hand animations request swap_object frames 0 to 42, mostly frame 1; a frame is shown for
        # the numbers from its own up to its own plus its duration
        self.assertGreater(self.frame("swap_thing")["duration"], 42)
        self.assertEqual(self.frame("thing")["duration"], 1)

    def test_reminder_includes_the_item_name_string(self):
        out = self.install(self.art_png("c.png", 200, 200, (50, 50, 149, 149)))
        self.assertIn('GLOBAL.STRINGS.NAMES.THING = ', out)

    def test_default_pivots(self):
        self.install(self.art_png("c.png", 200, 200, (50, 50, 149, 149)))
        ground, held = self.frame("thing"), self.frame("swap_thing")
        self.assertEqual((ground["x"], ground["y"]), (0.0, -32.0))          # pivot 0.5,0.75 of 128
        # base-game tools (pickaxe, axe, hammer) are about 200 pixels long in the hand, pivot near 0.4,0.8
        self.assertEqual((held["w"], held["h"]), (200.0, 200.0))
        self.assertAlmostEqual(held["x"], (0.5 - 0.4) * 200, places=3)
        self.assertAlmostEqual(held["y"], (0.5 - 0.8) * 200, places=3)

    def test_held_image_and_rotation(self):
        master = self.art_png("c.png", 200, 200, (50, 50, 149, 149))
        tall = self.art_png("h.png", 200, 200, (90, 20, 109, 179))  # 20x160
        self.install(master, "--held-image", tall)
        self.assertTrue(os.path.exists(os.path.join(self.art, "thing", "held.png")))
        frame = self.frame("swap_thing")
        self.assertEqual((frame["w"], frame["h"]), (25.0, 200.0))
        self.install("--held-rotate", "90")   # held.png is reused, now lying on its side
        frame = self.frame("swap_thing")
        self.assertEqual((frame["w"], frame["h"]), (200.0, 25.0))


if __name__ == "__main__":
    unittest.main()
