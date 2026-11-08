# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**Faux Film Print** is a macOS app (Swift 6, SwiftUI, macOS 15+) that frames photos as
true-size instant-film prints (Instax Mini/Square/Wide, Polaroid Square) and prints them on
US Letter sheets with crop marks for cutting by hand. The core promise: prints match real
instant film in physical size and look. **Never scale a print to fit**, and never write to the
user's original photos.

- Design spec: `docs/superpowers/specs/2026-11-07-fauxfilm-design.md`
- Original build plan: `docs/superpowers/plans/2026-11-07-fauxfilm.md`
- Public repo: https://github.com/JoshLedgard/faux-film-print (MIT)

## Layout

- `FauxFilmKit/`: Swift package with all the logic, fully unit-tested.
  - `Geometry.swift`: `FilmFormat`, `FrameSpec` (border sizes in mm), `Paper`, `MM`.
  - `SheetLayout.swift`: grid per format, crop-mark ticks, `isInside`, `slotIndex(at:)`.
  - `Crop.swift`, `ImageIO+Ops.swift`: crop math, EXIF-correct downsampled decode, rotation.
  - `Looks.swift`: `FilmLook` recipes (per-channel tone curves, grain, softness, vignette) plus strength.
  - `PrintRenderer.swift`: `PrintItem`, `RenderOptions` (incl. bleed), card drawing.
  - `Pagination.swift`, `PDFComposer.swift`: sheets → PDF, size-test page.
  - `Session.swift`, `SessionStore.swift`: observable model and on-disk save/restore.
- `FauxFilm/`: thin SwiftUI app target (window, tray, crop editor, bulk edit, sheet preview, printing).
- `project.yml`: XcodeGen spec. The `.xcodeproj` is generated and git-ignored.
- `scripts/release.sh`: build, sign, notarize, staple and zip a release.
- `docs/icons/`: icon ideas and the chosen icon source (`real-faux.svg`).
- `docs/screenshots/`: README screenshots (sample art only, no personal photos).

## Conventions

- Geometry is in **millimetres, top-left origin, y down**. Convert to PDF points (y up) only at draw time.
- Instax Mini border values matter most; adjust them in `Geometry.swift` after a real test print.
- Kit code is test-first: add or extend a test in `FauxFilmKit/Tests` before changing behaviour.
- After adding or removing app source files, run `xcodegen generate`.
- The app is sandboxed (print + user-selected files). The Photos picker needs no extra entitlement.
- Saved sessions live in the app container under `Application Support/Faux Film/`. Keep that folder
  name even though the app was renamed, so existing sessions keep loading.
- README screenshots must use sample art, never the user's photos. Take them with a build that uses a
  separate bundle id (`PRODUCT_BUNDLE_IDENTIFIER=com.joshledgard.fauxfilm.screenshots`) so the real
  saved session is untouched.

## Commands

```bash
cd FauxFilmKit && swift test                      # unit tests
xcodegen generate                                 # regenerate the Xcode project
xcodebuild -project FauxFilm.xcodeproj -scheme FauxFilm -destination 'platform=macOS' build
scripts/release.sh 1.1                            # signed + notarized zip in build/dist/
gh release create v1.1 build/dist/Faux-Film-Print-1.1.zip --title "Faux Film Print 1.1" --notes-file <notes>
```

Notarization uses the keychain profile `fauxfilm1` (team `D9P7WX2BKD`). Release builds must not
carry `get-task-allow`; `release.sh` sets `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` for that.

## Release notes

Add an entry here for each release, newest first, and use the same text for the GitHub release.

### 1.0 (2026-11-08)

Turn your photos into true-size instant-film prints and print them on US Letter sheets to cut out by hand.

- Instax Mini (9 per sheet), Instax Square, Instax Wide and Polaroid Square frames at exact physical size
- Crop marks for hand cutting, a border bleed so cuts don't leave white slivers, and optional corner-rounding guides
- Film looks (Instax, Polaroid, Faded) with a strength slider, which you can apply to many photos at once
- Prints at 100% scale only: if your printer can't reach the paper edge, it fits fewer per sheet instead of shrinking
- A size-test page to check against a real print before you use glossy paper
- Your photos and crops are saved between launches. Originals are never modified.

**Install:** unzip and drag to Applications. Signed and notarized by Apple. Requires macOS 15+.
