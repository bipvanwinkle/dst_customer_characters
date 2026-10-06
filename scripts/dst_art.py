"""Shared pieces for building Don't Starve Together art: KTEX textures, icon atlases and anim builds.

Needs ImageMagick (`magick`).
"""
import os, struct, subprocess, tempfile, zipfile

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
        with open(tex_path, "wb") as f:
            f.write(png_to_ktex(tex_png))
    with open(xml_path, "w") as f:
        f.write(f'<Atlas><Texture filename="{name}" /><Elements>'
                f'<Element name="{name}" u1="0" u2="1" v1="0" v2="1" /></Elements></Atlas>\n')
