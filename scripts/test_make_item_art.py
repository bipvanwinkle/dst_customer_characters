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
