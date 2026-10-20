# -*- coding: utf-8 -*-
"""Export every slide of a .pptx to PNG via PowerPoint COM.

Use when LibreOffice/poppler are absent but PowerPoint is installed
(typical Windows desktop). Requires pywin32 in the running interpreter.

Usage: python export_pptx_png.py deck.pptx outdir
"""
import os
import sys
import win32com.client


def main(argv):
    src = os.path.abspath(argv[1])
    outdir = os.path.abspath(argv[2])
    os.makedirs(outdir, exist_ok=True)

    ppt = win32com.client.Dispatch("PowerPoint.Application")
    # Visible=0 raises "Hiding the application window is not allowed";
    # WithWindow=False suppresses the window instead.
    ppt.Visible = 1
    pres = ppt.Presentations.Open(src, WithWindow=False)
    pres.Export(outdir, "PNG", 1600, 900)
    pres.Close()
    ppt.Quit()
    print("exported", sorted(os.listdir(outdir)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

