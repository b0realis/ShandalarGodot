# Regional terrain palettes

`WorldTerrainPalette` controls terrain presentation without changing terrain
types, movement, mana, random generation or the world's fingerprint. It works
with the original skin, upscaled skins and the plain map fallback.

## Built-in presets

| ID | Name | Look |
| --- | --- | --- |
| `shandalar` | Shandalar | The chosen skin's original colors. |

The mainland defaults to Shandalar. An explicit choice overrides a region's
default, including on an already saved map.

```gdscript
WorldTerrainPalette.set_preset(world, WorldTerrainPalette.SHANDALAR)
```

## Terrain types and individual tiles

The order is **world preset → terrain-type style → individual-tile style**.
A tile can select its own preset and override individual tint layers. Other
layers keep their inherited settings. A layer setting replaces that whole
layer's setting; tints do not multiply repeatedly as inheritance is resolved.

```gdscript
# Give every plains tile a warmer ground tint.
WorldTerrainPalette.set_terrain_style(world, 6, {
    "ground": {"tint": "#d9b484", "strength": 0.25},
})

# Make one patch cooler. Neighboring cells keep their own styles.
WorldTerrainPalette.tint_tile(world, Vector2i(30, 31), Color("#88aacc"), 0.35)

# Use the original palette on one tile, with a separate tint for its trees/rocks.
WorldTerrainPalette.set_tile_style(world, Vector2i(30, 31), {
    "preset": WorldTerrainPalette.SHANDALAR,
    "objects": {"tint": "#b3c58a", "strength": 0.2},
})

# Remove overrides and resume inheritance.
WorldTerrainPalette.set_tile_style(world, Vector2i(30, 31), {})
WorldTerrainPalette.set_terrain_style(world, 6, {})
```

These functions return `true` on success, `false` for invalid input. Coordinates
are world grid cells (0–63 on each axis); terrain codes are 0–15, as defined by
`ShandalarWorld`. The optional final argument to `tint_tile` selects the layer.

| Layer | Affects |
| --- | --- |
| `ground` | Ground diamonds and their edge pieces; terrain on both maps. |
| `objects` | Trees, rocks and their ground halves. |
| `roads` | Road sprites and road lines on both maps. |

Buildings, heroes, roaming creatures, shadows, cards and interface art are
outside these layers. Tint colors are `#RRGGBB`; strength is 0–1. Strength 0
keeps the original color; 1 applies the full RGB multiplier. Alpha stays intact.
Tints can darken or color a patch; use a preset's color remapping when it should
become brighter or change green vegetation into another hue.

`resolve(world, tile)` returns a copy of the effective settings. `modulate`
turns a layer's tint into a draw color. Use the setters when editing: they notify
the world view, map and minimap immediately and invalidate cached tile recipes.

## Adding another preset

Add an entry to `WorldTerrainPalette.PROFILES` with a stable ID and a display
`name`. The optional `grass`,
`foliage` and `water` vectors are **target hue (0–1), saturation multiplier,
brightness multiplier, strength (0–1)**. Each recipe targets its own colors
and atlas cells, preserving neutral stone, sandy shores and brown soil. Water
is adjusted consistently in the open-water tile, shore edges, water painted
into coastal tree sprites and map tiles;
the original water texture is shared by sea and marsh. Omit `water` to retain
the skin's water colors. `plain` supplies representative colors by terrain
code for the minimap and the plain fallback; their water colors use the same
water recipe. Optional `tints` supplies default `ground`,
`objects` or `roads` layer settings in the same format shown above.

Associate a region with that ID in `REGIONS`, or select it with `set_preset`.
No renderer changes or new skin files are required. Extend the recolor mask or
sheet selection only when the new look needs to affect a different kind of art.

## Persistence and cost

Settings live in `world.expansion.appearance`, containing `preset`, `terrains`
(keys such as `"6"`) and `tiles` (keys such as `"30,31"`). Only JSON values are
stored. Both active and inactive regional maps retain their settings in saves;
old saves without appearance settings use their region's default. Unknown
presets, invalid coordinates, malformed colors and out-of-range strengths are
rejected before loading a save or applying an edit.

Preset remapping is cached by skin texture and preset. Per-tile tints use draw
colors, so different tints share the same textures. The renderer preserves its
depth order and tint when tree fragments are drawn again in front of a hero.
The skin ZIP and its textures are never modified.
