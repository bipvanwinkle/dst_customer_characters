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
        with open(reference, "rb") as f:
            body, content_type = multipart(fields, "image", "base.png", f.read())
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
        with open(path, "wb") as f:
            f.write(image)
        print("saved", path)


# ---- install ---------------------------------------------------------------------------------

def adopt(src, dst):
    """Copy a chosen image into the item's art folder, refusing ones that cannot work in game."""
    if not os.path.exists(src):
        fail(f"no such image: {src}")
    try:
        alpha = dst_art.read_rgba(src)[2][3::4]
    except subprocess.CalledProcessError:
        fail(f"{src} is not a readable image")
    if dst_art.opaque_box(src) is None:
        fail(f"{src} is blank (completely transparent)")
    if min(alpha) == 255:
        fail(f"{src} has no transparent background, so it would show as a solid square in game")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.abspath(src) != os.path.abspath(dst):
        shutil.copyfile(src, dst)


def trim(src, dst, rotate=0):
    """Crop an image to its visible pixels, after turning it clockwise by `rotate` degrees."""
    if rotate:
        magick(src, "-background", "none", "-rotate", str(rotate), "+repage", dst)
        src = dst
    x, y, w, h = dst_art.opaque_box(src)
    magick(src, "-crop", f"{w}x{h}+{x}+{y}", "+repage", dst)


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
        art, icon, ground, hand = (os.path.join(tmp, n) for n in ("art.png", "icon.png", "ground.png", "hand.png"))
        trim(master, art)
        magick(art, "-resize", "60x60", "-background", "none", "-gravity", "center", "-extent", "64x64", icon)
        dst_art.write_icon_atlas(icon, os.path.join(icons, item + ".tex"), os.path.join(icons, item + ".xml"))
        magick(art, "-resize", f"{args.ground_size}x{args.ground_size}", ground)
        dst_art.write_single_frame_build(ground, item, GROUND_SYMBOL, args.ground_pivot,
                                         os.path.join(anim, item + ".zip"))
        trim(held if os.path.exists(held) else master, hand, rotate=args.held_rotate)
        magick(hand, "-resize", f"{args.held_size}x{args.held_size}", hand)
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

    args = parser.parse_args(argv)
    if not shutil.which("magick"):
        fail("ImageMagick (`magick`) is not installed")
    args.run(args)


if __name__ == "__main__":
    main()
