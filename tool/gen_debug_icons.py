#!/usr/bin/env python3
"""Generate debug-build launcher icons from ``brainframe-dev.png``.

Release icons come from ``brainframe.png`` via ``flutter_launcher_icons``
(see ``pubspec.yaml``). That tool only supports flavors for Android and iOS —
not macOS or Windows — so the debug icon is generated here instead, for every
platform, from a single source, mirroring the exact asset layout the release
icons already use. The debug identity (``tech.brainframe.app.debug`` etc.) is
wired separately; see ``docs/debug-build-identity.md``.

The generated files are the debug counterparts of the release assets:

* Android  -> ``android/app/src/debug/res/`` (build-type resource override;
              reuses ``main``'s adaptive XML + background color, replacing only
              the foreground drawable and the legacy launcher bitmap)
* iOS      -> ``ios/Runner/Assets.xcassets/AppIcon-Debug.appiconset/``
* macOS    -> ``macos/Runner/Assets.xcassets/AppIcon-Debug.appiconset/``
* Windows  -> ``windows/runner/resources/app_icon_debug.ico``

The one-time build-config wiring that points debug builds at these assets
(Xcode ``ASSETCATALOG_COMPILER_APPICON_NAME`` and the ``Runner.rc`` ``_DEBUG``
guard) is committed, not regenerated — this script only (re)builds the images
and is safe to re-run.

Regenerate with:  python3 tool/gen_debug_icons.py
Requires Pillow.  Reads/writes paths relative to the repo root; run from
anywhere.
"""

from __future__ import annotations

import glob
import json
import os
import shutil

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "brainframe-dev.png")


def load_source() -> Image.Image:
    img = Image.open(SRC)
    # iOS rejects an alpha channel; the other platforms are fine with RGB too.
    return img.convert("RGB")


def resized(src: Image.Image, px: int) -> Image.Image:
    return src.resize((px, px), Image.LANCZOS)


def write(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("  " + os.path.relpath(path, REPO))


# The dev artwork's "dev" badge sits in a top-right *corner* — the worst place
# for an Android adaptive icon, because launchers crop the outer ~17% of the
# canvas and then mask the result to a circle/squircle, eating the corners.
# Filling the tile (small inset) makes it worse: the badge is cropped away. So
# the debug adaptive icon does the opposite — it insets the whole square well
# inside the launcher "safe zone" so the entire image (badge included) survives
# any mask, and paints the adaptive background with the artwork's own dark tone
# so the shrunk square reads as one cohesive dark icon rather than art floating
# on a plate. (The pre-API-26 legacy bitmap stays full-square and unmasked.)
_ADAPTIVE_INSET = "25%"
_ADAPTIVE_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground"
          android:inset="{inset}" />
  </foreground>
</adaptive-icon>
""".format(inset=_ADAPTIVE_INSET)


def _corner_hex(src: Image.Image) -> str:
    w, h = src.size
    r, g, b = src.crop((0, 0, w // 12, h // 12)).resize((1, 1), Image.LANCZOS).getpixel((0, 0))
    return f"#{r:02X}{g:02X}{b:02X}"


def gen_android(src: Image.Image) -> None:
    print("Android (src/debug/res):")
    main = os.path.join(REPO, "android/app/src/main/res")
    debug = os.path.join(REPO, "android/app/src/debug/res")
    # Override exactly the launcher assets main defines, at identical sizes:
    # the adaptive foreground drawable and the pre-API-26 legacy bitmap.
    patterns = ["drawable-*/ic_launcher_foreground.png", "mipmap-*/ic_launcher.png"]
    for pattern in patterns:
        for path in sorted(glob.glob(os.path.join(main, pattern))):
            rel = os.path.relpath(path, main)
            px = Image.open(path).size[0]
            write(resized(src, px), os.path.join(debug, rel))
    # Safe-zone-inset adaptive descriptor, overriding main's 16% inset for the
    # debug build type.
    xml_path = os.path.join(debug, "mipmap-anydpi-v26/ic_launcher.xml")
    os.makedirs(os.path.dirname(xml_path), exist_ok=True)
    with open(xml_path, "w") as fh:
        fh.write(_ADAPTIVE_ICON_XML)
    print("  " + os.path.relpath(xml_path, REPO))
    # Override the adaptive background color (main's is #FFFFFF white) with the
    # artwork's own dark corner tone so the shrunk square blends into the tile.
    colors_path = os.path.join(debug, "values/colors.xml")
    os.makedirs(os.path.dirname(colors_path), exist_ok=True)
    with open(colors_path, "w") as fh:
        fh.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            f'    <color name="ic_launcher_background">{_corner_hex(src)}</color>\n'
            "</resources>\n"
        )
    print("  " + os.path.relpath(colors_path, REPO))


def gen_appiconset(src: Image.Image, src_set: str, out_set: str) -> None:
    contents = json.load(open(os.path.join(src_set, "Contents.json")))
    # filename -> pixel size (width * scale); duplicate filenames stay consistent.
    sizes: dict[str, int] = {}
    for entry in contents["images"]:
        if "filename" not in entry:
            continue
        width = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        sizes[entry["filename"]] = round(width * scale)
    for filename, px in sizes.items():
        write(resized(src, px), os.path.join(out_set, filename))
    shutil.copyfile(
        os.path.join(src_set, "Contents.json"),
        os.path.join(out_set, "Contents.json"),
    )
    print("  " + os.path.relpath(os.path.join(out_set, "Contents.json"), REPO))


def gen_ios(src: Image.Image) -> None:
    print("iOS (AppIcon-Debug.appiconset):")
    base = os.path.join(REPO, "ios/Runner/Assets.xcassets")
    gen_appiconset(src, os.path.join(base, "AppIcon.appiconset"),
                   os.path.join(base, "AppIcon-Debug.appiconset"))


def gen_macos(src: Image.Image) -> None:
    print("macOS (AppIcon-Debug.appiconset):")
    base = os.path.join(REPO, "macos/Runner/Assets.xcassets")
    gen_appiconset(src, os.path.join(base, "AppIcon.appiconset"),
                   os.path.join(base, "AppIcon-Debug.appiconset"))


def gen_windows(src: Image.Image) -> None:
    print("Windows (app_icon_debug.ico):")
    out = os.path.join(REPO, "windows/runner/resources/app_icon_debug.ico")
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    os.makedirs(os.path.dirname(out), exist_ok=True)
    src.save(out, format="ICO", sizes=ico_sizes)
    print("  " + os.path.relpath(out, REPO))


def main() -> None:
    if not os.path.exists(SRC):
        raise SystemExit(f"source icon not found: {SRC}")
    src = load_source()
    gen_android(src)
    gen_ios(src)
    gen_macos(src)
    gen_windows(src)
    print("done.")


if __name__ == "__main__":
    main()
