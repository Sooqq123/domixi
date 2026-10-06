#!/usr/bin/env python3
"""Create compact contact sheets from rendered guide pages for visual QA."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--render-root", type=Path)
    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parents[5]
    render_root = args.render_root or (repo_root / "tmp/pdfs/student-guides")
    for guide_dir in sorted(path for path in render_root.iterdir() if path.is_dir()):
        pages = sorted(guide_dir.glob("page-*.png"))
        if not pages:
            continue
        thumbnails = []
        for page_number, page_path in enumerate(pages, start=1):
            with Image.open(page_path) as image:
                thumb = image.convert("RGB")
                thumb.thumbnail((280, 396))
                card = Image.new("RGB", (300, 430), "white")
                card.paste(thumb, ((300 - thumb.width) // 2, 8))
                draw = ImageDraw.Draw(card)
                draw.text((12, 408), f"Page {page_number}", fill="#243447", font=ImageFont.load_default())
                thumbnails.append(card)
        columns = 4
        rows = (len(thumbnails) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * 300, rows * 430), "#DDE4EA")
        for index, thumb in enumerate(thumbnails):
            x = (index % columns) * 300
            y = (index // columns) * 430
            sheet.paste(thumb, (x, y))
        output = render_root / f"{guide_dir.name}_contact.png"
        sheet.save(output, optimize=True)
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
