# Faux Film — Design

*Working name; folder `~/github/fauxfilm`. Both are Claude's call and easy to change.*

## Intent and the why

Josh takes photos on his iPhone and wants physical prints that pass as instant
film. They go into **photo collages mixed in with real Fujifilm Instax Mini prints**.
So the point is not "a Polaroid-ish filter". The point is a print that holds up
**lying right next to a real one**: same physical size, same border proportions,
same feel of the frame.

Success: he picks a handful of photos, crops each one, prints a full sheet on his
HP inkjet on glossy paper, cuts them out by hand, and they sit next to real
Instax Minis without looking wrong.

## Goals

1. Turn photos into instant-film-style prints at **exact physical sizes** for these formats:
   - **Instax Mini** (the primary format; this is the film he actually owns)
   - Instax Square
   - Instax Wide
   - Polaroid square (600 / i-Type style)
2. Let him **choose the crop** of each photo inside the picture window (pan + zoom).
3. **Lay prints out on 8.5×11" sheets** for printing, as many as fit, and print at
   **true 100% scale**.
4. Make **hand-cutting** easy and forgiving.

## Non-goals (v1)

- iPhone/iPad app. Photos sync to the Mac's Photos library via iCloud, so a Mac app is enough (his call).
- Captions or handwriting on the bottom strip.
- 4×6", A4 or other paper sizes. He only has full Letter sheets. (Keep paper size a single
  value so it can be added later.)
- Mixing different formats on one sheet. One format per sheet in v1 (Claude's call; a
  collage session can produce several sheets).
- Saving/reopening projects. A session lives while the app is open.
- Sharing, cloud, accounts.

## Anti-goals: failing even if it "works"

- **Wrong physical size.** Any silent "fit to page" or "shrink to printable area" scaling.
  A print that's 2 mm off ruins the whole point.
- **Pure-white, square-cornered, flat border.** That immediately reads as fake next to real film.
- **Cut lines that show.** A full cut line drawn along a print's edge leaves a dark sliver
  whenever a hand cut lands slightly off it.
- **Forcing a film filter.** Some real shots in the collage are crisp, so a heavy film look must be optional.

## Constraints

- **Platform:** native macOS app, Swift + SwiftUI, macOS 15+. He's an experienced Apple
  developer, so it builds and runs in Xcode.
- **Photo source:** his Mac Photos library (iCloud-synced from iPhone). Use the system
  `PhotosPicker` (no full-library permission prompt needed). Also accept images
  dragged in from Finder. Photos will often be HEIC.
- **Printer:** HP colour inkjet, **glossy photo paper, US Letter (8.5×11")**.
- **Cutting:** by hand.

## Formats

Dimensions in millimetres. **Instax Mini** numbers are the ones that matter most. The
others are best-known values that the builder should sanity-check against published specs.
All borders should live in one data table so they're easy to tweak after a test print.

| Format | Card W × H | Picture W × H | Side | Top | Bottom | Corner radius |
|---|---|---|---|---|---|---|
| Instax Mini | 54 × 86 | 46 × 62 | 4 | 6 | 18 | ~3 |
| Instax Square | 72 × 86 | 62 × 62 | 5 | 7 | 17 | ~3 |
| Instax Wide | 108 × 86 | 99 × 62 | 4.5 | 6 | 18 | ~3 |
| Polaroid square | 88 × 107 | 79 × 79 | 4.5 | 6 | 22 | ~1 |

Orientation as held. Instax Mini is portrait (tall), with the thick strip at the bottom.

## The frame: what makes it look real

- **Colour:** off-white, slightly warm, not `#FFFFFF`. Start near `#F6F4EE` and keep it as one constant.
- **Picture window corners:** real Instax picture windows have very slightly softened
  corners. Keep it subtle.
- **Texture:** optional faint paper noise on the border, off by default if it prints badly.
- **Outer corners:** real Minis have rounded corners, but scissors give square ones. Print
  a **faint corner guide curve** at each corner (light grey, hairline, on the border itself)
  so he can trim the round with scissors or use a corner-rounder punch. It must be a toggle.
- The **glossy border is a known mismatch** (real film is matte on the frame). Accept it.

## The photo look

Applied to the picture only, never the border. Presets, default **None**:

- **None.** The photo as-is.
- **Instant.** Gentle film character: slightly lifted blacks, slight warmth, a touch of
  softness and vignette. Subtle.
- **Faded.** Stronger lift, lower contrast, warmer.

Plus one **"Print brightness"** adjustment applied at print time to every picture on the
sheet. **Why:** inkjet prints on glossy paper usually come out darker than the screen shows,
and he's matching against real film. This is Claude's guess, to be confirmed by his first
print. Default a small brighten, adjustable, and remembered between launches.

Use Core Image. Exact filter recipes are left to the builder.

## Cropping

- Each photo shows inside its picture window at the format's aspect ratio.
- Drag to pan, scroll/pinch or a slider to zoom. The crop can never reveal empty space.
- Default crop: centred, filling the window.
- Rotate 90° button (for when the picture should be sideways in a portrait card).

## Sheet layout and printing

- **Paper:** US Letter, 215.9 × 279.4 mm, portrait.
- **Gap between prints:** 4 mm (so a slightly off cut doesn't eat into the neighbouring print).
- **Grid:** centred on the sheet, as many as fit inside a safe margin. Expected counts with
  4 mm gaps:
  - Instax Mini: **3 × 3 = 9**
  - Instax Square: 2 × 3 = 6
  - Instax Wide: 4, prints rotated 90° on the sheet
  - Polaroid square: 2 × 2 = 4
  The builder may rotate a format on the sheet if that fits more.
- **Safe margin and the 9-per-sheet priority (Claude's call):** 9 Minis per sheet wins.
  A 3-row Mini grid is 266 mm tall, which leaves ~6.7 mm top and bottom on Letter. That's
  enough for the prints but not for crop marks above or below the grid, so the marks follow
  the rule below. At print time, read the printer's imageable area (`NSPrintInfo.imageablePageBounds`).
  If a print would be clipped, warn and offer the next grid down (e.g. 2 rows) for that sheet,
  never scaling down.
- **Cut guides:** **corner crop marks only**: short (~3 mm) hairlines offset ~1 mm from
  the print, never touching it. No continuous cut lines. Marks go **only in the gaps between prints
  and in the side margins**. There are none above the top row or below the bottom row. Every cut line
  is still marked at both ends: vertical cuts by ticks in the row gaps, and the top and bottom edges
  of each row by horizontal ticks in the left and right side margins (plenty of room there: ~23 mm per side
  for Minis).
- **More photos than fit:** overflow onto additional sheets.
- **Empty slots:** left blank (no empty frames printed).

### True-scale printing is the hard requirement

- Render each sheet as **vector PDF in points** (1 mm = 72/25.4 pt), with photos embedded
  at **≥300 dpi** at their printed size.
- Print through the macOS print panel with **scaling 100%** and no automatic fit-to-page.
  The page must not shrink to the printer's imageable area. Pre-set this in
  `NSPrintInfo`; if a driver insists on scaling, warn him.
- **Also offer "Export PDF"** so he can print from Preview if the print path misbehaves.
- **Test print:** a "Print size test" action prints one Instax Mini frame plus a 50 mm ruler line
  on a sheet, so he can lay it against a real Mini and check the size before using up glossy
  paper. Mention it once, on first print.

## Screens (rough)

One window:
- **Left:** tray of added photos (add via Photos picker, Finder drag-in). Each thumbnail is
  already framed in the current format.
- **Centre:** selected photo in its frame, large, for cropping. Look preset picker under it.
- **Top/toolbar:** format picker, Print, Export PDF.
- **Sheet preview** (a toggle or a tab): what the actual pages will look like, with crop marks.

Copies: each photo can be set to print more than once (a simple count, default 1).

**Format is per photo (Claude's call).** Each photo in the tray carries its own format,
crop, look and copy count. The toolbar format picker sets the format for the **selected**
photo(s) and becomes the default for newly added ones. Changing a photo's format resets its
crop to centred/fill (crops don't carry across aspect ratios). On print/export, photos are
**grouped by format**, one or more sheets per format, all in a single print job or PDF in tray order.
The sheet preview shows every page.

## Left to the builder

- Exact Core Image recipes for the looks and the texture.
- Window layout details and visual styling of the app itself.
- Project structure, plus whether to use SwiftUI `ImageRenderer` or Core Graphics for rendering.
- How to model state. Testing approach, but layout math (mm → points, grid counts, crop
  mark positions) must have unit tests because it's the part where silent errors hurt.
- App icon.

## Claude's calls (for Josh to check)

- Name "Faux Film" and folder `~/github/fauxfilm`.
- The other three formats (Instax Square, Instax Wide, Polaroid square).
- Corner crop marks rather than cut lines, plus a 4 mm gap.
- Corner guide curves for rounding, as a toggle.
- Print brightness default (a small brighten).
- One format per sheet, no saved projects, no captions in v1.
- Format set per photo, with sheets grouped by format in one print job.
- 9 per sheet beats crop marks above/below the grid. Outer cut lines are marked from the side margins.
- Film look off by default.
