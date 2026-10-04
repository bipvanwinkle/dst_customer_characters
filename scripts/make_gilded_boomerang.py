#!/usr/bin/env python3
"""Build the Gilded Boomerang art for the tuning mod from the base game's boomerang.

Recolors the wood of the boomerang (world/thrown), swap_boomerang (held) and inventory icon to gold,
keeping the outlines and rope wraps as drawn, and writes them into tuning/anim and tuning/images.
Needs ImageMagick (`magick`) and an installed copy of DST.

Usage: scripts/make_gilded_boomerang.py [path/to/Don't Starve Together/data]
"""
import colorsys, io, os, re, struct, subprocess, sys, tempfile, zipfile

DEFAULT_DATA = os.path.expanduser("~/.local/share/Steam/steamapps/common/Don't Starve Together/data")
MOD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tuning")
DDS_FOURCC = {0: b"DXT1", 1: b"DXT3", 2: b"DXT5"}


# ---- KTEX <-> PNG ----------------------------------------------------------------------------
# KTEX is the game's texture format: a header bitfield, one header per mipmap, then the mip data.
# Textures are stored upside down and with premultiplied alpha.

def ktex_to_png(tex, png):
    d = tex
    assert d[:4] == b"KTEX"
    bf, = struct.unpack("<I", d[4:8])
    pf, mips = (bf >> 4) & 0x1F, (bf >> 13) & 0x1F
    w, h, _, size = struct.unpack("<HHHI", d[8:18])
    data = d[8 + 10 * mips:][:size]
    hdr = struct.pack("<4sIIIIIII44sII4sIIIIIIIIII", b"DDS ", 124, 0x81007, h, w, size, 0, 1, b"\0" * 44,
                      32, 4, DDS_FOURCC[pf], 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0)
    with tempfile.NamedTemporaryFile(suffix=".dds") as f:
        f.write(hdr + data)
        f.flush()
        subprocess.run(["magick", f.name, png], check=True)


def png_to_ktex(png):
    """PNG -> KTEX DXT5 with a full mip chain, laid out like the game's own textures."""
    w, h, _ = read_rgba(png)
    sizes = [(w, h)]
    while sizes[-1] != (1, 1):
        sizes.append((max(1, sizes[-1][0] // 2), max(1, sizes[-1][1] // 2)))
    with tempfile.NamedTemporaryFile(suffix=".dds") as f:
        subprocess.run(["magick", png, "-define", "dds:compression=dxt5", "-define", f"dds:mipmaps={len(sizes) - 1}",
                        f"DDS:{f.name}"], check=True)
        dds = open(f.name, "rb").read()
    assert dds[84:88] == b"DXT5"
    data, mips, off = dds[128:], [], 0
    for mw, mh in sizes:
        pitch = max(1, (mw + 3) // 4) * 16
        size = pitch * max(1, (mh + 3) // 4)
        mips.append((mw, mh, pitch, data[off:off + size]))
        off += size
    assert off == len(data), (off, len(data))
    # platform 0, DXT5, 2D texture, flags 3, as in the base game's boomerang atlas
    bf = 0 | (2 << 4) | (1 << 9) | (len(mips) << 13) | (3 << 18) | (0xFFF << 20)
    out = bytearray(b"KTEX" + struct.pack("<I", bf))
    for mw, mh, pitch, d in mips:
        out += struct.pack("<HHHI", mw, mh, pitch, len(d))
    for *_, d in mips:
        out += d
    return bytes(out)


def read_rgba(png):
    w, h = map(int, subprocess.check_output(["magick", "identify", "-format", "%w %h", png]).split())
    return w, h, bytearray(subprocess.check_output(["magick", png, "-depth", "8", "RGBA:-"]))


# ---- Recolor ---------------------------------------------------------------------------------

# Gold ramp by lightness: deep bronze shadows -> gold -> pale highlight
RAMP = [(0.0, (0.10, 0.06, 0.01)), (0.25, (0.45, 0.28, 0.04)), (0.5, (0.85, 0.62, 0.12)),
        (0.75, (1.0, 0.85, 0.35)), (1.0, (1.0, 0.97, 0.80))]


def ramp(t):
    for (t0, c0), (t1, c1) in zip(RAMP, RAMP[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(a + (b - a) * k for a, b in zip(c0, c1))
    return RAMP[-1][1]


def gild(src, dst):
    w, h, px = read_rgba(src)
    for i in range(0, len(px), 4):
        a = px[i + 3]
        if a == 0:
            continue
        r, g, b = (min(1, px[i + j] / a) for j in range(3))
        hue, light, sat = colorsys.rgb_to_hls(r, g, b)
        # Only the reddish-brown wood; the yellow rope wraps and black outlines stay as drawn
        if sat < 0.2 or light < 0.08 or not (hue < 30 / 360 or hue > 340 / 360):
            continue
        px[i:i + 3] = bytes(round(c * a) for c in ramp(min(1.0, light * 1.9)))
    subprocess.run(["magick", "-size", f"{w}x{h}", "-depth", "8", "RGBA:-", dst], input=bytes(px), check=True)


def gild_ktex(tex, tmp):
    src, dst = os.path.join(tmp, "src.png"), os.path.join(tmp, "dst.png")
    ktex_to_png(tex, src)
    gild(src, dst)
    return png_to_ktex(dst)


# ---- Builds and icon -------------------------------------------------------------------------

def rename_build(build, name):
    """build.bin starts with BILD, version, symbol and frame counts, then the length-prefixed build name."""
    assert build[:4] == b"BILD"
    n, = struct.unpack("<I", build[16:20])
    return build[:16] + struct.pack("<I", len(name)) + name.encode() + build[20 + n:]


def write_anim(src_zip, build_name, out_zip, tmp):
    with zipfile.ZipFile(src_zip) as z:
        build, tex = z.read("build.bin"), z.read("atlas-0.tex")
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("build.bin", rename_build(build, build_name))
        z.writestr("atlas-0.tex", gild_ktex(tex, tmp))


def write_icon(images_zip, out_tex, out_xml, tmp):
    with zipfile.ZipFile(images_zip) as z:
        for xml_name in sorted(n for n in z.namelist() if re.match(r"images/inventoryimages\d+\.xml$", n)):
            xml = z.read(xml_name).decode()
            m = re.search(r'<Element name="boomerang.tex" u1="([\d.]+)" u2="([\d.]+)" v1="([\d.]+)" v2="([\d.]+)"', xml)
            if m:
                tex = z.read(xml_name[:-4] + ".tex")
                break
    u1, u2, v1, v2 = map(float, m.groups())
    atlas = os.path.join(tmp, "atlas.png")
    ktex_to_png(tex, atlas)
    aw, ah, _ = read_rgba(atlas)
    x, y = round(u1 * aw), round(v1 * ah)
    size = round((u2 - u1) * aw)
    size = 64 if abs(size - 64) <= 2 else size
    icon, gold = os.path.join(tmp, "icon.png"), os.path.join(tmp, "icon_gold.png")
    subprocess.run(["magick", atlas, "-crop", f"{size}x{size}+{x}+{y}", "+repage", icon], check=True)
    gild(icon, gold)
    open(out_tex, "wb").write(png_to_ktex(gold))
    open(out_xml, "w").write(
        '<Atlas><Texture filename="boomerang_gilded.tex" /><Elements>'
        '<Element name="boomerang_gilded.tex" u1="0" u2="1" v1="0" v2="1" /></Elements></Atlas>\n')


def main():
    data = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DATA
    os.makedirs(os.path.join(MOD_DIR, "anim"), exist_ok=True)
    os.makedirs(os.path.join(MOD_DIR, "images", "inventoryimages"), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        write_anim(os.path.join(data, "anim", "boomerang.zip"), "boomerang_gilded",
                   os.path.join(MOD_DIR, "anim", "boomerang_gilded.zip"), tmp)
        write_anim(os.path.join(data, "anim", "swap_boomerang.zip"), "swap_boomerang_gilded",
                   os.path.join(MOD_DIR, "anim", "swap_boomerang_gilded.zip"), tmp)
        images = os.path.join(MOD_DIR, "images", "inventoryimages")
        write_icon(os.path.join(data, "databundles", "images.zip"), os.path.join(images, "boomerang_gilded.tex"),
                   os.path.join(images, "boomerang_gilded.xml"), tmp)
    print("wrote gilded boomerang art to", os.path.normpath(MOD_DIR))


if __name__ == "__main__":
    main()
