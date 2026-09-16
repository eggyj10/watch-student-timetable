# AppIcon.icon — Icon Composer bundle

An [Icon Composer](https://developer.apple.com/icon-composer/) bundle for the
iOS 26 / watchOS 26 Liquid Glass icon, hand-authored against the schema Icon
Composer emits.

**It is not wired into the build yet, on purpose.** See "Adopting it" below.

## What it is

An `.icon` is a plain folder, not a binary blob:

```
AppIcon.icon/
  icon.json          the manifest: background fill, layer stack, platform masks
  Assets/
    grid.png         the five unlit timetable tiles, white, transparent bg
    now.png          the single lit tile, amber, transparent bg
```

`icon.json` describes a vertical gradient background (`#0B2A4D` → `#1A6AB2`) with
two foreground layers stacked on it. Splitting the tiles across two layers is the
point of the format — the system lights, blurs and parallaxes each layer
separately, which a flat PNG cannot do.

Both layers are 1024×1024 straight-alpha PNGs whose art sits inside the central
62% of the canvas. That keeps the corner tiles inside the circular mask watchOS
applies, which `supported-platforms.circles` opts into.

## Adopting it

The project currently ships the traditional `Assets.xcassets/AppIcon.appiconset`
with a flat 1024 PNG. That works, is still fully supported, and is what builds
today. This bundle is an upgrade you should confirm before switching to.

1. On the Mac, open it: **Xcode ▸ Open Developer Tool ▸ Icon Composer**, then
   open `Icon/AppIcon.icon`. If it opens and previews correctly, the manifest is
   good. **Re-save it from Icon Composer** even if you change nothing — that
   normalises anything the app is fussier about than the schema suggests.
2. If it does *not* open, do not debug the JSON. Start a new document and import
   `Assets/grid.png` and `Assets/now.png` as two layers over a
   `#0B2A4D` → `#1A6AB2` vertical gradient. The artwork is the slow part and it
   is already done; reassembling takes about two minutes.
3. Move it next to the target that uses it and drop the old catalog icon:

   ```bash
   git mv Icon/AppIcon.icon iOS/AppIcon.icon
   cp -R iOS/AppIcon.icon Watch/AppIcon.icon
   git rm -r iOS/Assets.xcassets/AppIcon.appiconset Watch/Assets.xcassets/AppIcon.appiconset
   xcodegen generate
   ```

   `ASSETCATALOG_COMPILER_APPICON_NAME` is already `AppIcon` in `project.yml`, so
   it picks up `AppIcon.icon` by name with no further change.

**Do not keep `AppIcon.icon` and `AppIcon.appiconset` in the same target.** Two
app icons with the same name is the one failure mode worth avoiding; Xcode 26
generates the older icon sizes from the `.icon` itself, so the catalog version is
not needed as a fallback for the iOS 17 deployment target.

## Things worth knowing

- `glass` is `false` on both layers, matching the reference bundle. Setting it
  `true` makes a layer render as actual glass rather than flat fill — worth
  trying on `grid` in Icon Composer, where you can see it.
- `shadow.opacity` and `translucency.value` are both `0.5`. Subtle beats
  dramatic at 40 points wide.
- Apple's rule is that the **foreground stays identical across appearances** and
  only the background changes per mode. Both layers here are appearance-neutral,
  so tinted and clear modes derive correctly from luminance without extra work.
- Editing the artwork means editing the generator, not the PNGs. Geometry lives
  in one place, shared with the flat icon: margin 196, gap 40, 2×3 grid, corner
  radius 34, lit cell at row 1 column 0.
