# Faux Film Print

A macOS app that turns photos into true-size instant-film prints (Instax Mini, Instax Square,
Instax Wide, Polaroid Square) and lays them out on US Letter sheets with crop marks for
cutting by hand.

## Download

Grab `Faux-Film-Print-1.0.zip` from the [Releases](../../releases) page, unzip it, and drag
**Faux Film Print** into Applications. Requires macOS 15 or later. The app is signed and
notarized by Apple.

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open FauxFilm.xcodeproj
```

Run the **FauxFilm** scheme. The project file is generated, so re-run `xcodegen generate`
after adding or removing files.

## Releasing

`scripts/release.sh 1.1` builds, signs with Developer ID, notarizes, staples and zips the app into
`build/dist/`. Then attach it to a GitHub release.

## Tests

All layout, crop, rendering and PDF logic lives in `FauxFilmKit` and is tested there:

```bash
cd FauxFilmKit && swift test
```

## Using it

1. **Add Photos** (from your Photos library) or drag image files into the window.
2. Pick a format in the toolbar. It applies to the selected photos and to new ones.
3. Drag to move the photo in its frame, pinch or use the slider to zoom, and **Rotate** if needed.
4. Toggle **Sheets** to preview the printed pages.
5. **File ▸ Print Size Test** first. Print it on plain paper and check it against a real print.
6. **Print** at 100%. If your printer can't reach close enough to the paper edge, Faux Film Print prints
   fewer per sheet instead of shrinking anything.

Your photos and their crops are saved automatically and come back next time. Faux Film Print keeps
its own copy of each photo in its private storage folder and never changes your originals.
Removing a photo from the list deletes that copy. You can also click any print in the
**Sheets** preview to jump to its crop editor.

Settings (⌘,) has print brightness (inkjet prints often come out darker than the screen),
corner rounding guides and an optional border texture.

Border sizes live in `FauxFilmKit/Sources/FauxFilmKit/Geometry.swift`. Tweak them there after a test print.

## License

MIT. See [LICENSE](LICENSE).
