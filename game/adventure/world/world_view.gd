class_name WorldView
extends Control
## THE WORLD, DRAWN AS 1.3 DREW IT — `DrawWorldTileRange` (0054d619) and
## `RenderAdventureWorldScene` (0054ac08), read 2026-10-22 and written here
## as our own; only the window is new: the original looked at the world
## through a 512 × 280 hole in its frame (`Advinter.pic`), and this draws
## it on the whole screen, with a zoom.
##
## THE PROJECTION. A world unit (32 to a tile) is 2 pixels across and 1
## down: a tile is a 128 × 64 diamond, and the tile's corner (32 tx, 32 ty)
## is the diamond's left vertex. The camera is a world point drawn at
## [member feet] — the hero's feet, as in the original, which kept them a
## little below the window's middle.
##
## WHAT IS DRAWN, in the original's order: the screen rows of tiles top to
## bottom and each row left to right — the ground, the black terrain's and
## the coast's edge pieces (each quarter of a diamond reading three
## neighbours), the roads, the ground halves of the trees and rocks and of
## the sites; then the hero's shadow; then every upright sprite sorted by
## the height of its foot, the later of two at one height behind. The two
## trees or rocks a tile carries, and where they stand, follow from the
## tile's place alone, so a world looks the same every time it is drawn.
## THE DUNGEONS ([member dungeons], 2026-10-27): a dungeon the hero holds a
## clue to, a card still inside ([method WorldClues.on_world]), stands on
## its tile as 1997 drew it (adventureWorldUi.c 1230–1257): after the
## tile's two trees or rocks — a dungeon tile keeps them — its marker of
## 1997's twenty ([constant DUNGEON_LOOKS], [method dungeon_frames]), the
## ground half drawn with the tile's and the upright among the uprights,
## both 32 less the upright's height above the tile's left corner, foot at
## the corner. [QoL, the owner's ruling A-1 of 2026-10-27: it shows on
## land the hero has not seen too, over the dark — the clue told where it
## stands — where the tile's trees stay hidden.] Plain, a dark mouth ringed
## in gold.
## ARZAKON'S PORTAL ([member portal], part C, 2026-10-28) [ours]: the
## owner's ruling of 2026-10-27 — after the fifth wizard falls his portal
## opens near the map's middle, and after the win, if the hero roams, "the
## portal is a monument made of stone (make it as a new asset)". 1997 had no
## portal on its world, so its pictures are this project's
## (`game/art/world_portal_*`, drawn by `tools/draw_world_portal.gd`, read
## through [method GameSkin.our_art]; the horned arch, the owner's pick of
## the mock-ups): it stands on its tile as a castle stands — a 192 × 192
## frame, its corner at (0, −160) from the tile's left corner, the ground
## half drawn with the ground and the upright among the uprights, its foot
## the tile's middle row — and the tile's trees or rocks make way for it,
## as for a site. Worn with a 2x skin it is the `@2x` picture in the same
## place ([method portal_key]). Like a dungeon it shows on land the hero
## has not seen too: the guides and the journal point to it. Plain, an arch
## drawn in code ([method draw_portal_plain]).
##
## Without the 1997 sheets ([WorldArt]) the same world is drawn plain: a
## diamond of its colour per tile, the roads, a mark per site.
##
## HOW IT IS KEPT ON THE SCREEN [ours]. The original drew its window anew
## every tick; drawn so on a whole screen it cost 4 to 27 ms a time (the
## more the further out the zoom), every tick even standing still. Now the
## world is four pictures laid one over another, in the order above:
##  - the ground ([member _ground]): the tiles, the edges, the roads, the
##    dark over unseen land, the ground halves;
##  - the hero's shadow ([member _shadow]);
##  - everything upright ([member _uprights]), by the height of its foot;
##  - the hero ([member _figure]), with the parts of what stands in front
##    of them drawn again over them — the same picture as the hero drawn
##    in their place among the uprights, the sheets' pixels being either
##    solid or clear (held to the old drawing pixel for pixel; at half size
##    a few pixels of those parts may show their sheet's neighbouring
##    pixel, as half size picks one of two).
##    THE HERO IN FRONT ON A PLACE'S OWN TILE [ours] (the owner's ruling
##    of round C3, part C stage C3, h3-5: "hero in front — drawn over the
##    building on its own tile"; narrowed by the owner, 2026-10-28: "only
##    the portal and castles"): a castle or its ruins and Arzakon's portal
##    are not drawn again over a hero whose feet are on their tile
##    ([method hero_parts]); their foot is the tile's middle row, the
##    hero's feet there, and 1997, queueing the hero after its equals, hid
##    them behind it (on the portal wholly). Towns, villages, cities,
##    domes and dungeon markers stand as 1997 drew them, and off the tile
##    a castle or the portal stands in front as before.
## The ground and the uprights are drawn round one world point
## ([member _anchor]) for the screen and a margin round it, and only moved
## as the camera goes and scaled as it zooms; they are drawn again only
## when the camera leaves the margin, the zoom goes out past it, or what
## they show changes (land seen, a town taken, a lair found, another
## world). The tiles drawn are worked out from the screen's corners
## ([method _tiles_over]) rather than every tile of the map being tried;
## what each tile shows is worked out once a world ([method _recipe]) and
## kept: a town's flags changing keeps them all, a town taken or a site
## gone throws away its tile's alone ([method _look_at_sites]).
## The hero's two pictures are drawn again only when the hero moves or
## turns. Standing still nothing is drawn at all.
## DRAWN AHEAD, OVER FRAMES [ours; the smoothness pass, 0.50.66]: the
## ground and the uprights are drawn into a second picture while the first
## is shown ([WorldView.Picture]), a share of a frame at a time ([constant
## DRAW_MS]), and swapped in whole when done — begun once half the margin
## is walked, or at once (a few frames' shares) when what they show
## changed; drawn in one frame only when the screen would otherwise show
## land not drawn (a leap, a zoom out, a look dragged fast). A zoom easing
## out is covered at the zoom it goes to ([member zoom_goal]). Between
## pictures the tiles a zoom out would want are worked out in spare time
## ([method _warm_recipes]). The same pixels, fewer draw calls: within a
## screen row of tiles — whose diamonds never overlap — the ground's tiles,
## then its edges, then its roads, each sheet in one run, the rows in the
## original's order; the dark over unseen land in one run of quads.
##
## THE GLIDE [QoL; even since the smoothness pass, 0.50.66]: the hero, the
## creatures and the camera following the hero move only on the 60 ms
## tick, and 1997's pace moves them in stops and starts — two units every
## third tick on slow land, a unit and two by turns on a road, a creature
## ambling every other tick. Each is drawn where it stood on average over
## the last ticks ([constant HERO_GLIDE] for the hero, three, the slow
## land's beat; [constant CREATURE_GLIDE] for a creature, two, the amble's):
## an even speed on every land, never past the place the clock holds, and
## at most about 90 ms behind it (on plain land the old slide was 30 ms
## behind and even already; it is now 90 there too, the price of one even
## speed everywhere). [method frame] keeps the clock's ticks and the time
## since the last; while the world waits under a pane the movers walk on
## into the places the clock left them, at [constant SETTLE] times their
## pace, so a creature met is seen to reach the hero. What the game reads —
## [member hero], [member camera], [method project], [method unproject] —
## stays the tick's.
##
## THE CREATURES ([member creatures], part B, 2026-10-23; ui.c 2213–2288)
## walk among the uprights as the hero does: their shadows on the shadow
## picture under everything upright (the hero's first, then by slot), their
## bodies with the hero's on the movers' picture ([member _figure]), back to
## front by the height of the foot — at one height the hero in front of a
## creature and a lower slot in front of a higher, as 1997's queue put a
## newcomer before its equals — each followed by the parts of the uprights
## that stand in front of it. They glide as the hero does. A creature just
## come into view is drawn once its sheets are in hand ([method
## WorldArt.sheet_ready]: a frame or a few later where a worker reads them)
## rather than the frame stalling on them. A
## frame is the hero's formula, `((heading + 2) & 7) · 5 + step`, drawn at
## the feet less the body's anchor ([method WorldArt.creature_anchor]; its
## shadow at the body's anchor too). Without its sheet — the plain world, or
## a skin that lacks it — a creature is a disc of its slot's colour. On land
## the hero has not seen nothing is drawn, a creature neither.
## THEIR NAMES ([member creature_names]; the owner, 2026-10-28, of the
## unused 1997 features: *"only §5, the creature names on the map — small,
## with their own on/off setting in the adventure's options menu"*): 1997
## copied a creature's name for eight ticks of every 32 and drew it nowhere
## ([method WorldCreatures.map_name]); with the world's options' Creature
## names on, it stands small over the creature drawn, gold on a dark edge as
## the place names are, its foot a few pixels over the body's top ([method
## names_shown]) [ours: where and how it is drawn]. A picture of its own over
## the movers, at the screen's size, not the zoom's.

## The world drawn, and the world point at the screen's [member feet].
var world: ShandalarWorld:
	set(value):
		world = value
		_changed()
var camera := Vector2(0, 0):
	set(value):
		camera = value
		_changed()
## The hero, in world units, and how they look: `male` or `female`, and
## facing (0–7, the original's directions; 0 at the start). The places the
## hero had at the last ticks are kept, to glide over ([method frame]); a
## leap (a World Magic, another hero) is not glided over.
var hero := Vector2(0, 0):
	set(value):
		if _hero_ticks.is_empty() or hero.distance_to(value) > LEAP:
			_hero_ticks = PackedVector2Array([value])
		hero = value
		_changed()
var hero_walker := "male":
	set(value):
		hero_walker = value
		_changed()
var hero_facing := 0:
	set(value):
		hero_facing = value
		_changed()
## The walking figure's step, 0 standing, 1–4 walking (`g_world_player_
## animation_frame`): the frame is the facing's fifth plus the step.
var hero_step := 0:
	set(value):
		hero_step = value
		_changed()
## The figure's sheet dressed in the hero's colours ([HeroColors]), or null
## for the 1997 one.
var hero_sheet: Texture2D:
	set(value):
		hero_sheet = value
		_changed()
## The lairs the hero sees ([method WorldLairs.seen]): `{x, y, color}`, in
## world units.
var lairs: Array[Dictionary] = []:
	set(value):
		lairs = value
		_changed()
## The dungeons drawn ([method WorldClues.on_world]): `{index, x, y}`, the
## slot (5–14) and its tile.
var dungeons: Array[Dictionary] = []:
	set(value):
		dungeons = value
		_dungeon_at.clear()
		for dungeon in value:
			_dungeon_at[Vector2i(int(dungeon["x"]), int(dungeon["y"]))] = int(dungeon["index"])
		_changed()
## Arzakon's portal ([member AdventurePlayer.portal]): `{x, y, state}`, its
## tile and [constant FinalBattle.PORTAL_OPEN] or [constant
## FinalBattle.PORTAL_PETRIFIED]; `{}` for none.
var portal: Dictionary = {}:
	set(value):
		portal = value
		_changed()
## The creatures the hero sees ([method WorldCreatures.seen]): `{slot,
## creature, x, y, heading, frame, color}`, in world units. Each glides
## over its places at the last ticks, by slot (a creature come anew, or one
## that leapt, shows at once).
var creatures: Array[Dictionary] = []:
	set(value):
		var kept := {}
		var kinds := {}
		for creature in value:
			var slot := int(creature["slot"])
			var now := Vector2(int(creature["x"]), int(creature["y"]))
			var ticks: PackedVector2Array = _creature_ticks.get(slot, PackedVector2Array())
			if ticks.is_empty() or int(_creature_kinds.get(slot, -1)) != int(creature["creature"]) \
					or ticks[ticks.size() - 1].distance_to(now) > LEAP:
				ticks = PackedVector2Array([now])
			kept[slot] = ticks
			kinds[slot] = int(creature["creature"])
		_creature_ticks = kept
		_creature_kinds = kinds
		creatures = value
		_changed()
## THE NAMES OVER THE CREATURES (the class's notes): roaming slot → the
## name standing over that creature now ([method WorldCreatures.map_names]),
## `{}` for none — the options' Creature names off ([constant
## WorldHud.NAMES_SETTING]).
var creature_names: Dictionary = {}:
	set(value):
		if value == creature_names:
			return
		creature_names = value
		_changed()
## Twice the 1997 pixels by default (the owner's choice, 2026-10-22): crisp,
## and about the original window's view scaled up; the wheel zooms.
var zoom := DEFAULT_ZOOM:
	set(value):
		zoom = value
		_changed()
const DEFAULT_ZOOM := 2.0
## THE ZOOM GOING TO [ours; the smoothness pass, 0.50.66]: while the zoom
## eases toward a goal ([method WorldScreen.set_zoom]) the pictures are
## drawn to cover the screen at the further out of the two ([method
## _cover_zoom]), so one drawing covers the whole ease out — as many as the
## old jump made, never land left undrawn on the way. 0, the default: none,
## the pictures follow [member zoom] alone.
var zoom_goal := 0.0:
	set(value):
		zoom_goal = value
		_changed()
## LAND THE HERO HAS NOT SEEN is drawn dark and nothing standing on it is
## shown (the owner's choice, 2026-10-22): the 1997 window showed only
## what it marked explored, and the whole screen would show far more.
var fog := true:
	set(value):
		fog = value
		_changed()
const FOG := Color(0.035, 0.026, 0.024, 0.97)
const FOG_EDGE := Color(0.035, 0.026, 0.024, 0.72)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0

## The original's tile, in its screen pixels.
const TILE_W := 128
const TILE_H := 64

## Ground frame by terrain (LANDTILE): 1 water for ocean and marsh, 2 sand
## for blue, 4 grey rock for black, 0 grass for the rest.
## Tree and rock column by terrain (LAND, then LAND2 from 5).
const OBJECT_COLUMN := {3: 0, 1: 1, 2: 2, 5: 3, 6: 4, 8: 5, 13: 6, 10: 7, 15: 8}
## `g_location_marker_sprite_lookup_by_town` (adventureWorldUi.c): pairs of
## (upright, ground half) by look — sixteen looks for towns and cities by
## slot, two for villages by column — as indices into the six location
## sheets read one after another, each counting its end marker.
const TOWN_LOOKS: Array[int] = [1, 7, 5, 11, 28, 32, 25, 29, 0, 6, 35, 36, 13, 19, 33, 34,
	2, 8, 12, 18, 14, 20, 26, 30, 27, 31, 38, 44, 39, 45, 52, 58, 3, 9, 4, 10]
## Where each location sheet starts in that count (24 + 1, 12 + 1, …).
const LOCATION_SHEETS: Array[Array] = [[0, "world_locatn01"], [25, "world_locatn02"],
	[38, "world_locatn03"], [63, "world_locatn04"], [76, "world_locatn05"], [101, "world_locatn06"]]
## `g_castle_sprite_lookup_by_tile_class`: by colour (black, blue, green,
## red, white), a living wizard's castle and its ground half, then a
## beaten wizard's — indices into CASTLES1 (0–11) and CASTLES2 (12–).
const CASTLE_FRAMES: Array[Array] = [[8, 9, 10, 11], [2, 6, 3, 7], [12, 16, 13, 17],
	[14, 18, 15, 19], [0, 4, 1, 5]]
## A town a wizard holds wears his dome (black, blue, green, red, white),
## its ground half always LOCATN04 frame 6.
const DOMES: Array[Array] = [["world_locatn04", 10], ["world_locatn04", 2],
	["world_locatn04", 8], ["world_locatn06", 0], ["world_locatn04", 3]]

## `g_lair_sprite_index_by_color`: a lair's LOCATN07 frame by its colour
## (colourless, black … white), its ground half six frames on; drawn 64
## left of and 96 above its point, at that point's height.
const LAIR_FRAMES: Array[int] = [0, 4, 0, 3, 2, 1]

## `g_dungeon_marker_sprite_lookup` (adventureWorldUi.c 57–83): by dungeon
## slot 5–14, its marker's upright and ground half, as indices into the six
## location sheets read as one ([constant LOCATION_SHEETS]) — the first
## twenty of 1997's twenty-four; the last two pairs (LOCATN05 1/7 and 0/6)
## no slot reaches.
const DUNGEON_LOOKS: Array[int] = [42, 48, 63, 67, 54, 60, 53, 59, 50, 56, 51, 57, 78, 84,
	80, 86, 79, 85, 55, 61]

## [ours] A creature's name over it ([member creature_names]): its size in
## screen points, its ink and edge (the place names' gold), and the gap
## between its foot and the body's top, in screen pixels; how far above its
## feet a creature drawn plain reaches (its disc's top, 1997 pixels).
const NAME_SIZE := 13
const NAME_INK := Color8(232, 190, 110)
const NAME_EDGE := Color8(20, 10, 8)
const NAME_GAP := 3.0
const PLAIN_RISE := 23.0

## [ours] Arzakon's portal's pictures by state ([member portal]): the
## upright's key in `game/art/`; its ground half adds `_ground`, its 2x twin
## `@2x` ([method portal_key]).
const PORTAL_ART := {"open": "world_portal_open", "petrified": "world_portal_petrified"}
## [ours] The portal's frame: where it stands from its tile's left corner,
## and its size — a castle's ([method _site]).
const PORTAL_AT := Vector2(0, -160)
const PORTAL_FRAME := Vector2(192, 192)

## Plain colours by terrain (the overview map's tiles, averaged).
const PLAIN := {0: Color("#387faf"), 1: Color("#3aa19c"), 2: Color("#798d58"),
	3: Color("#7c7574"), 4: Color("#ca7c72"), 5: Color("#c4705d"), 6: Color("#c4b289"),
	7: Color("#6c91c6"), 8: Color("#3b878f"), 9: Color("#7b527d"), 10: Color("#81a565"),
	11: Color("#186342"), 12: Color("#992c32"), 13: Color("#a8947f"), 14: Color("#1d7b89"),
	15: Color("#858d4f")}

var art := WorldArt.new()
## Every tile, in the order the original draws them: by screen row (ty − tx)
## and then across it (tx + ty) — and a margin round the map, which the
## original reads as ocean (`GetWorldTileType` turns a place off the map
## into row or column 0) and so draws as water.
static var _order: Array[Vector2i] = []
const MARGIN := 12

## A step longer than this (world units) since the last tick is a leap,
## shown at once: a tick walks at most three units, a frame that waited
## runs at most twenty ticks.
const LEAP := 32.0
## How far past the screen's edges the ground and the uprights are drawn
## (screen pixels), so the camera can go that far before they are drawn
## again — at the default zoom about a second and a half of walking. The
## next pictures are begun once half of it is walked ([method _refresh]).
const SPARE := 96.0
## [ours; the smoothness pass, 0.50.66] A frame's share (ms) of drawing the
## next pictures ahead ([WorldView.Picture]); twice that once less than a
## quarter of the margin is left; [constant DRAW_SOON_MS] for pictures that
## show something changed (land seen, a town taken), so they come within a
## few frames; and the spare time a frame gives to working out what the
## tiles a zoom out would want show ([method _warm_recipes]).
const DRAW_MS := 1.5
const DRAW_SOON_MS := 4.0
const WARM_MS := 0.4
## THE GLIDE (the class's notes) [QoL]: over how many ticks the hero's
## drawn place is averaged (the slow land's beat, a step every third tick)
## and a creature's (the amble's, a step every other tick); how much faster
## than the walk the movers walk on into their places while the world
## waits; how many of each one's places at the last ticks are kept.
const HERO_GLIDE := 3.0
const CREATURE_GLIDE := 2.0
const SETTLE := 2.0
const KEPT_TICKS := 4
## The pictures are drawn again for a closer zoom once they hold this many
## times the screen's area.
const SHED := 4.0
## What stands on a tile reaches this far round its left corner, unzoomed:
## 96 left, 224 right, 232 up, 72 down (a castle's or a city's tower).
const REACH := Rect2(-96, -232, 320, 304)
## How far below the hero's feet something standing in front of them can
## stand and still reach up over them.
const IN_FRONT := 224

## THE PICTURES (see the class's notes): the ground, the hero's shadow,
## the uprights and the hero, children of the view that move and scale as
## one.
var _ground: Node2D
var _shadow: Node2D
var _uprights: Node2D
var _figure: Node2D
## The creatures' names, over all of them at the screen's own size ([member
## creature_names]); what it shows (`[name, foot]` each, [method
## names_shown]); how far above its feet each creature sheet's body reaches
## (1997 pixels, by key, measured once: [method _body_rise]).
var _names: Node2D
var _names_drawn: Array = []
var _rises := {}
## THE GLIDE'S CLOCK ([method frame]): how far the frame is between the
## last tick and the next as the screen said ([member _blend]; 1 while the
## world waits), as the clock last ran ([member _blend_before]); the time
## the world has waited since the last tick, in ticks, at [constant SETTLE]
## times the pace ([member _waited]); the time since the last tick the
## movers are drawn at ([member _since]); and whether the world waited the
## frame before.
var _blend := 1.0
var _blend_before := 0.0
var _waited := 0.0
var _since := 0.0
var _was_waiting := false
## The engine frame [method frame] last ran in (−1: never). A view whose
## clock is not running — no frame this one or the last (a world screen not
## processing, a view drawn without a clock) — draws the movers at the
## clock's places, and glides afresh from them once it runs again.
var _framed_at := -1
## Ticks a second the clock was last seen to run ([method frame]).
var _rate := 1.0 / HeroWalk.TICK
## The hero's places at the last ticks, the latest last ([constant
## KEPT_TICKS]); each creature's by slot, and which creature is in it.
var _hero_ticks := PackedVector2Array()
var _creature_ticks := {}
var _creature_kinds := {}
## The world point (whole units) the ground and the uprights are drawn
## round — their pictures' origin is where it projects — the part of their
## picture they hold (unzoomed), and what they show: the world, the sheets,
## the dark, the page (land seen), the sites, the lairs.
var _anchor := Vector2i.ZERO
var _covered := Rect2()
var _shown: Array = []
## The pictures' tiles in the original's order, their left corners round
## the anchor, whether each is seen (or the dark is off), and what each
## shows ([method _recipe]).
var _tiles: Array[Vector2i] = []
var _lefts := PackedVector2Array()
var _seen := PackedByteArray()
var _tile_recipes: Array = []
## Every upright of the pictures in the order drawn — `[sheet, where,
## frame]` — and the height of each one's foot, rising, for finding those
## in front of the hero.
var _upright_ops: Array = []
var _upright_feet := PackedInt32Array()
## THE PICTURES SHOWN AND THE NEXT ([WorldView.Picture]): what the members
## above are taken from; the next being drawn, or null; a spare one.
var _front: Picture
var _next: Picture
var _spare: Picture
## The next pictures show something changed: drawn at [constant
## DRAW_SOON_MS] a frame.
var _soon := false
## What a tile shows, kept for the world as it was ([member _recipe_for]):
## a tile's is thrown away only when what stands on it changes — its site
## ([method _look_at_sites]) or the portal.
var _recipes := {}
var _recipe_for: Array = []
## The sites as the pictures draw them, by tile: `[slot, type, ruler]` of
## the first slot on it; the sites' hash they were read at; one more each
## time they change ([method _look_at_sites]).
var _site_marks := {}
var _sites_hash := 0
var _sites_drawn := 0
var _portal_at := Vector2i(-1, -1)
## THE TILES A ZOOM OUT WOULD WANT ([method _warm_recipes]), the anchor they
## were listed round and how many are worked out.
var _warm: Array[Vector2i] = []
var _warm_round := Vector2i(1 << 20, 0)
var _warm_done := 0
## The dungeons drawn by their tile: tile → slot ([member dungeons]).
var _dungeon_at := {}
## Whether the world is drawn plain (no 1997 sheets), and what the hero's
## pictures were drawn for: where they stood and how they looked, and
## which drawing of the ground (one more each time new pictures are shown).
var _plain := false
var _figure_drawn: Array = []
var _drawing := 0
## Of those, how many were drawn in one go ([method _draw_pictures]).
var _at_once := 0
## The engine frame whose share of drawing ahead was given, and when that
## share runs out (usec; [method _share]).
var _share_frame := -1
var _share_until := 0


## THE GROUND AND THE UPRIGHTS ONCE DRAWN ROUND AN ANCHOR [ours; the
## smoothness pass, 0.50.66]: what [method _refresh] shows (the view's
## members above are taken from the one shown) or draws ahead, a share of a
## frame at a time ([method _draw_some]). The pictures' draw calls are kept
## in two canvas items of their own under the view's Ground and Uprights,
## hidden until the whole is drawn ([member ground], [member uprights]).
class Picture:
	extends RefCounted
	var anchor := Vector2i.ZERO
	var covered := Rect2()
	var origin := Vector2.ZERO
	var shown: Array = []
	var plain := false
	var tiles: Array[Vector2i] = []
	var lefts := PackedVector2Array()
	var seen := PackedByteArray()
	var recipes: Array = []
	## Where each screen row of [member tiles] begins, and their count last.
	var rows := PackedInt32Array()
	var upright_ops: Array = []
	var upright_feet := PackedInt32Array()
	## The uprights gathered, and their places in the order ([method
	## WorldView._upright_key]), before the sort.
	var standing: Array = []
	var keys := PackedInt64Array()
	## The ground's three sheets (tiles, edges, roads) and whether the 2x
	## skin is worn, read as the drawing began.
	var sheets: Array = []
	var twice := false
	## The dark being gathered: the deep shade's corners and the edge's,
	## then each one's triangles ([method WorldView._put_dark]).
	var dark: Array = []
	var ground: RID
	var uprights: RID
	## How far the drawing is: the step ([enum WorldView.Step]) and the place
	## within it.
	var step := 0
	var at := 0


## The steps a picture is drawn in ([method _draw_some]): each tile's place
## and recipe, the uprights gathered and sorted, the ground (the tiles,
## edges and roads row by row; the dark; the ground halves, lairs and
## portal), the uprights, done.
enum Step { PLAN, GATHER, SORT, LAND, DARK, HALVES, UPRIGHTS, DONE }


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ground = _picture("Ground", _paint_ground)
	_shadow = _picture("Shadow", _paint_shadow)
	_uprights = _picture("Uprights", _paint_uprights)
	_figure = _picture("Figure", _paint_figure)
	_names = _picture("Names", _paint_names)
	_names.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# The pictures' own canvas items are the view's to free.
		for picture in [_front, _next, _spare]:
			if picture != null:
				for item in [picture.ground, picture.uprights]:
					if item.is_valid():
						RenderingServer.free_rid(item)


## One of the view's pictures, drawn by [param paint].
func _picture(called: String, paint: Callable) -> Node2D:
	var picture := Node2D.new()
	picture.name = called
	picture.draw.connect(paint)
	add_child(picture, false, Node.INTERNAL_MODE_FRONT)
	return picture


## The screen point the camera is drawn at: the middle across, a little
## below the middle down (the original kept the feet at 160 of a 280-high
## window).
func feet() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.57)


## A world point on screen, before the zoom: 2 pixels across and 1 down per
## world unit, relative to the camera.
func project(point: Vector2) -> Vector2:
	return _lay(point - camera)


## A screen point (after the zoom) back to the world, at the clock's camera.
func unproject(screen: Vector2) -> Vector2:
	return camera + _unlay((screen - feet()) / zoom)


## A screen point back to the world AS THIS FRAME DRAWS IT ([method
## drawn_at]'s inverse): what the pointer is over while the view glides
## between ticks (the bug pass after the campaign, r4-3: read at the
## clock's camera, a click on a town's edge walked a step beside it).
func unproject_drawn(screen: Vector2) -> Vector2:
	return _shown_camera() + _unlay((screen - feet()) / zoom)


## The inverse of [method _lay].
static func _unlay(offset: Vector2) -> Vector2:
	return Vector2(offset.x / 4.0 - offset.y / 2.0, offset.x / 4.0 + offset.y / 2.0)


## Where world point [param point] is drawn on the screen this frame —
## with the camera slid between ticks ([method frame]), for what is drawn
## over the world and must stay on it.
func drawn_at(point: Vector2) -> Vector2:
	return feet() + _lay(point - _shown_camera()) * zoom


## The projection of a world offset: 2 pixels across and 1 down per unit.
static func _lay(offset: Vector2) -> Vector2:
	return Vector2(2.0 * (offset.x + offset.y), offset.y - offset.x)


static func draw_order() -> Array[Vector2i]:
	if _order.is_empty():
		for ty in range(-MARGIN, ShandalarWorld.TILES + MARGIN):
			for tx in range(-MARGIN, ShandalarWorld.TILES + MARGIN):
				_order.append(Vector2i(tx, ty))
		_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var ra := a.y - a.x
			var rb := b.y - b.x
			if ra != rb:
				return ra < rb
			return a.x + a.y < b.x + b.y)
	return _order


## THE GLIDE (the class's notes) [QoL], called every frame: [param blend]
## the time since the last tick over [constant HeroWalk.TICK] (0–1), or 1
## while the world waits under a pane; [param seconds] the world's time
## the frame ran — when left out, the frame's time at the pace the clock
## was seen to run ([member _rate]: the world's pace, [method
## WorldHud.pace], read off the blend). The ticks the clock ran this frame
## are counted from the two — or, while the world waits, from a mover put
## elsewhere by the tick that opened the pane — and each mover's place at
## each is kept ([member _hero_ticks]); while the world waits the movers
## walk on into their places at [constant SETTLE] times their pace. Draws
## only what moved. Safe at any time — paused, with no world, at 0 or 1.
func frame(blend: float, seconds := -1.0) -> void:
	if not _clocked():
		_hero_ticks = PackedVector2Array([hero])
		_creature_ticks.clear()
		for creature in creatures:
			_creature_ticks[int(creature["slot"])] = PackedVector2Array([Vector2(int(creature["x"]), int(creature["y"]))])
	_framed_at = Engine.get_process_frames()
	var waiting := blend >= 1.0
	_blend = clampf(blend, 0.0, 1.0)
	if seconds < 0.0:
		var delta := get_process_delta_time() if is_inside_tree() else 0.0
		if not waiting and not _was_waiting and delta > 0.0005 and _blend > _blend_before:
			# No tick between: the blend moved at the world's pace (a frame
			# that ran a whole tick and more reads slower than any pace).
			var rate := (_blend - _blend_before) / delta
			if rate > 0.5 / HeroWalk.TICK and rate < 4.0 / HeroWalk.TICK:
				_rate = rate
		seconds = delta * _rate * HeroWalk.TICK
	var ticks := 0
	if not waiting:
		ticks = maxi(1 if _blend < _blend_before else 0,
			roundi(_blend_before + seconds / HeroWalk.TICK - _blend))
	if ticks == 0 and _moved():
		# A tick the arithmetic did not see: the one that opened the pane
		# the world now waits under, or a place given between ticks.
		ticks = 1
	if ticks > 0:
		_keep_ticks(mini(ticks, KEPT_TICKS))
		_waited = 0.0
		if waiting:
			_blend_before = 0.0
	if waiting:
		_waited = minf(_waited + maxf(seconds, 0.0) / HeroWalk.TICK * SETTLE, 64.0)
	else:
		if _was_waiting and ticks == 0:
			# The clock runs on from where it stood: the glide goes on from
			# where the wait left it.
			_waited = maxf(0.0, _waited - maxf(0.0, _blend - _blend_before))
		_blend_before = _blend
	_was_waiting = waiting
	_since = _blend_before + _waited
	_refresh(false)


## Whether the clock runs: [method frame] ran this engine frame or the last.
func _clocked() -> bool:
	return _framed_at >= 0 and Engine.get_process_frames() - _framed_at <= 1


## Whether a mover stands elsewhere than its last kept place.
func _moved() -> bool:
	if not _hero_ticks.is_empty() and _hero_ticks[_hero_ticks.size() - 1] != hero:
		return true
	for creature in creatures:
		var ticks: PackedVector2Array = _creature_ticks.get(int(creature["slot"]), PackedVector2Array())
		if not ticks.is_empty() and ticks[ticks.size() - 1] != Vector2(int(creature["x"]), int(creature["y"])):
			return true
	return false


## [param count] ticks run: every mover's place kept at each (a frame that
## ran more than one moved them in a line between).
func _keep_ticks(count: int) -> void:
	_hero_ticks = _kept(_hero_ticks, hero, count)
	for creature in creatures:
		var slot := int(creature["slot"])
		_creature_ticks[slot] = _kept(_creature_ticks.get(slot, PackedVector2Array()),
			Vector2(int(creature["x"]), int(creature["y"])), count)


## [param ticks] with [param count] more places kept, the last [param now]
## (the others on the line to it), the latest [constant KEPT_TICKS] only.
static func _kept(ticks: PackedVector2Array, now: Vector2, count: int) -> PackedVector2Array:
	var from := now if ticks.is_empty() else ticks[ticks.size() - 1]
	for k in range(1, count + 1):
		ticks.append(from.lerp(now, float(k) / count))
	if ticks.size() > KEPT_TICKS:
		ticks = ticks.slice(ticks.size() - KEPT_TICKS)
	return ticks


## WHERE A MOVER IS DRAWN: where it stood on average over the last [param
## width] ticks, [param since] ticks after the last of [param ticks] (its
## places at them, the latest last; each held from its tick to the next,
## the oldest held before) — the 1997 steps averaged into an even walk.
static func _glide(ticks: PackedVector2Array, since: float, width: float) -> Vector2:
	var count := ticks.size()
	var latest := ticks[count - 1]
	var held := clampf(since, 0.0, width)
	if count == 1 or held >= width:
		return latest
	# Standing: the place itself, not an average of it a rounding away (a
	# picture standing still is drawn on the very pixels it was).
	var standing := true
	for k in range(count - 1):
		standing = standing and ticks[k] == latest
	if standing:
		return latest
	var sum := latest * held
	var left := width - held
	var i := count - 2
	while left > 0.0:
		var take := minf(1.0, left) if i > 0 else left
		sum += ticks[i] * take
		left -= take
		i -= 1
	return sum / width


## Something shown changed: [method _draw] looks again.
func _changed() -> void:
	queue_redraw()


## The next pictures drawn on every frame they are being drawn, whoever
## else looks at the view ([method _draw_ahead]).
func _process(_delta: float) -> void:
	if _next == null:
		set_process(false)
		return
	_refresh(false)


## The view itself draws only the sea under the pictures, and looks
## whether they must be drawn again.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLAIN[0])
	_refresh(true)


## Where the hero is drawn this frame ([method _glide]) — at the clock's
## place while the clock does not run ([method _clocked]).
func _shown_hero() -> Vector2:
	if _hero_ticks.is_empty() or not _clocked():
		return hero
	return _glide(_hero_ticks, _since, HERO_GLIDE)


## Where creature [param creature] is drawn this frame: glided as the hero
## is, over [constant CREATURE_GLIDE] ticks.
func _shown_creature(creature: Dictionary) -> Vector2:
	var ticks: PackedVector2Array = _creature_ticks.get(int(creature["slot"]), PackedVector2Array())
	if ticks.is_empty() or not _clocked():
		return Vector2(int(creature["x"]), int(creature["y"]))
	return _glide(ticks, _since, CREATURE_GLIDE)


## Where the camera is this frame: with the hero, glided, when it follows
## them; else where it was put.
func _shown_camera() -> Vector2:
	return _shown_hero() if camera == hero else camera


## The zoom the pictures cover the screen at: the further out of the zoom
## and the one it eases to ([member zoom_goal]).
func _cover_zoom() -> float:
	return minf(zoom, zoom_goal) if zoom_goal > 0.0 else zoom


## THE PICTURES KEPT UP: moved and scaled to the camera and the zoom; the
## next ones drawn ahead a share of each frame once half the margin is
## walked or — when [param look_again] (a redraw was asked) — what they
## show changed, and in one go only when the screen would show land not
## drawn ([member _front], [method _draw_ahead]).
func _refresh(look_again: bool) -> void:
	if world == null:
		if not _shown.is_empty():
			_shown = []
			_drop_pictures()
			for picture in [_ground, _shadow, _uprights, _figure]:
				picture.queue_redraw()
		if not _names_drawn.is_empty():
			_names_drawn = []
			_names.queue_redraw()
		return
	if look_again or _shown.is_empty():
		_look_at_sites()
		var shown := [world.get_instance_id(), art.ready(), fog, hash(world.page), _sites_drawn,
			lairs.hash(), dungeons.hash(), portal.hash()]
		if shown != _shown:
			if _shown.size() < 3 or shown.slice(0, 3) != _shown.slice(0, 3):
				# Another world, the sheets come or gone, the dark switched:
				# drawn at once.
				_covered = Rect2()
			else:
				_soon = true
			_shown = shown
	if not get_rect().has_area():
		return
	var camera_now := _shown_camera()
	var cover := _cover_zoom()
	var needed := _screen_round(_anchor, camera_now, cover)
	if _front == null or not _covered.encloses(needed):
		_draw_pictures(camera_now)
	else:
		_draw_ahead(camera_now, cover, needed)
	var at := feet() + _lay(Vector2(_anchor) - camera_now) * zoom
	for picture in [_ground, _shadow, _uprights, _figure]:
		if picture.position != at:
			picture.position = at
		if picture.scale.x != zoom:
			picture.scale = Vector2(zoom, zoom)
	var figure := [_shown_hero(), hero_facing, hero_step, hero_sheet, hero_walker, _drawing]
	for creature in _creatures_drawn():
		figure.append([_shown_creature(creature), creature["creature"], creature["heading"],
			creature["frame"], creature.get("color", 0)])
	if figure != _figure_drawn:
		_figure_drawn = figure
		_shadow.queue_redraw()
		_figure.queue_redraw()
	var named := names_shown()
	if named != _names_drawn:
		_names_drawn = named
		_names.queue_redraw()


## THE NAMES STANDING OVER THE CREATURES this frame ([member
## creature_names]): `[name, foot]` for each creature drawn that has one —
## the foot the middle of the name's baseline, on the screen, over the body's
## top ([method _body_rise]) — in the creatures' order.
func names_shown() -> Array:
	var out := []
	if creature_names.is_empty() or world == null:
		return out
	for creature in _creatures_drawn():
		var called := String(creature_names.get(int(creature["slot"]), ""))
		if called == "":
			continue
		var feet := drawn_at(_shown_creature(creature))
		out.append([called, (feet - Vector2(0, _body_rise(creature) * zoom + NAME_GAP)).round()])
	return out


## How far above its feet creature [param creature]'s body reaches, in 1997
## pixels: its sheet's first frame's opaque top under the frame's anchor —
## measured once a sheet, on its 1x pixels ([method GameSkin.original]) —
## or the plain disc's top without the sheet.
func _body_rise(creature: Dictionary) -> float:
	var key := String(CreatureBook.sprite_keys(int(creature["creature"]))["body"])
	var sheet := art.texture(key) if not _plain else null
	if sheet == null:
		return PLAIN_RISE
	if not _rises.has(key):
		var rise := float(art.creature_top(key))
		var img := GameSkin.original(sheet)
		if img != null:
			var used := img.get_region(Rect2i(art.creature_rect(key, 0))).get_used_rect()
			if used.has_area():
				rise -= used.position.y
		_rises[key] = rise
	return float(_rises[key])


## THE NAMES, each centred on its foot, gold on a dark edge.
func _paint_names() -> void:
	if _names_drawn.is_empty():
		return
	var font := get_theme_font("font", "Label")
	for shown in _names_drawn:
		var text := String(shown[0])
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		var at: Vector2 = (shown[1] as Vector2) - Vector2(roundf(width / 2.0), font.get_descent(NAME_SIZE))
		_names.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, 4, NAME_EDGE)
		_names.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, NAME_INK)


## The screen, in the pictures' own units when drawn round [param anchor]
## with the camera at [param camera_now], at zoom [param at_zoom] (the
## view's own when left out).
func _screen_round(anchor: Vector2i, camera_now: Vector2, at_zoom := 0.0) -> Rect2:
	var z := at_zoom if at_zoom > 0.0 else zoom
	var at := feet() + _lay(Vector2(anchor) - camera_now) * z
	return Rect2(-at / z, size / z)


## THE GROUND AND THE UPRIGHTS DRAWN IN ONE GO, round the camera — the
## screen would otherwise show land not drawn: the next pictures finished
## if they cover it and show what is to be shown, else drawn anew.
func _draw_pictures(camera_now: Vector2) -> void:
	_at_once += 1
	var cover := _cover_zoom()
	var picture := _next
	_next = null
	if picture == null or picture.shown != _shown \
			or not picture.covered.encloses(_screen_round(picture.anchor, camera_now, cover)):
		if picture != null:
			_spare_picture(picture)
		picture = _begin(camera_now, cover)
	_draw_some(picture, 0)
	_show(picture)


## THE NEXT PICTURES DRAWN AHEAD ([member _next]), a share of this frame:
## begun when half the margin round the screen [param needed] is walked,
## the pictures shown are too big for the zoom, or what they show changed
## ([member _soon]) — else the frame's spare time warms the tiles a zoom
## out would want; shown when done if they cover the screen, else drawn
## again round the camera.
func _draw_ahead(camera_now: Vector2, cover: float, needed: Rect2) -> void:
	if _next != null and _next.shown != _shown:
		_spare_picture(_next)
		_next = null
	if _next == null:
		var wanted := _soon or not _covered.encloses(needed.grow(SPARE * 0.5 / cover)) \
			or _covered.get_area() > needed.get_area() * SHED
		if not wanted:
			_warm_recipes(_share(WARM_MS))
			return
		_next = _begin(camera_now, cover)
		set_process(true)
	var ms := DRAW_SOON_MS if _soon else DRAW_MS
	if not _covered.encloses(needed.grow(SPARE * 0.25 / cover)):
		ms = maxf(ms, DRAW_MS * 2.0)
	if not _draw_some(_next, _share(ms)):
		return
	var picture := _next
	_next = null
	if picture.covered.encloses(_screen_round(picture.anchor, camera_now, cover)):
		_show(picture)
	else:
		# The camera went past it while it was drawn: drawn again round it.
		_spare_picture(picture)


## The time (usec) this frame's share of [param ms] runs out: one share a
## frame, however often the pictures are looked at in it.
func _share(ms: float) -> int:
	var now_frame := Engine.get_process_frames()
	if now_frame != _share_frame:
		_share_frame = now_frame
		_share_until = Time.get_ticks_usec() + int(ms * 1000.0)
	return _share_until



## THE NEXT PICTURES DRAWN TO THE END NOW, and shown — for a caller that
## wants the screen as it will be (the tests, a picture taken).
func finish_drawing() -> void:
	if _next == null:
		return
	var picture := _next
	_next = null
	_draw_some(picture, 0)
	_show(picture)


## New pictures begun round [param camera_now], covering the screen and its
## margin at zoom [param cover]: the tiles over it, the sheets as they are.
func _begin(camera_now: Vector2, cover: float) -> Picture:
	var picture := _spare if _spare != null else Picture.new()
	_spare = null
	picture.anchor = Vector2i(roundi(camera_now.x), roundi(camera_now.y))
	picture.covered = _screen_round(picture.anchor, camera_now, cover).grow(SPARE / cover)
	picture.origin = _lay(Vector2(picture.anchor))
	picture.shown = _shown
	picture.plain = not art.ready()
	var recipe_for := [world.get_instance_id(), picture.plain]
	if recipe_for != _recipe_for:
		_recipes.clear()
		_recipe_for = recipe_for
	picture.tiles = _tiles_over(picture.covered, picture.origin)
	picture.lefts = PackedVector2Array()
	picture.lefts.resize(picture.tiles.size())
	picture.seen = PackedByteArray()
	picture.seen.resize(picture.tiles.size())
	picture.recipes = []
	picture.recipes.resize(picture.tiles.size())
	picture.rows = PackedInt32Array()
	picture.upright_ops = []
	picture.upright_feet = PackedInt32Array()
	picture.standing = []
	picture.keys = PackedInt64Array()
	picture.sheets = [] if picture.plain else [art.texture("world_landtile"), art.texture("world_cstline1"),
		art.texture("world_roads")]
	picture.twice = false if picture.plain else _skin_twice()
	picture.step = Step.PLAN
	picture.at = 0
	for item in [picture.ground, picture.uprights]:
		if item.is_valid():
			RenderingServer.canvas_item_clear(item)
			RenderingServer.canvas_item_set_visible(item, false)
	if not picture.ground.is_valid():
		picture.ground = _picture_item(_ground)
		picture.uprights = _picture_item(_uprights)
	return picture


## A canvas item of a picture's own under [param layer], hidden, its sheets
## drawn sharp as the view's.
static func _picture_item(layer: CanvasItem) -> RID:
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, layer.get_canvas_item())
	RenderingServer.canvas_item_set_default_texture_filter(item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	RenderingServer.canvas_item_set_visible(item, false)
	return item


## [param picture] shown: the view's members taken from it, the pictures
## before kept as the spare.
func _show(picture: Picture) -> void:
	var before := _front
	var plain_before := _plain
	_front = picture
	_anchor = picture.anchor
	_covered = picture.covered
	_tiles = picture.tiles
	_lefts = picture.lefts
	_seen = picture.seen
	_tile_recipes = picture.recipes
	_upright_ops = picture.upright_ops
	_upright_feet = picture.upright_feet
	_plain = picture.plain
	RenderingServer.canvas_item_set_visible(picture.ground, not picture.plain)
	RenderingServer.canvas_item_set_visible(picture.uprights, not picture.plain)
	if before != null and before != picture:
		_spare_picture(before)
	if picture.plain or plain_before:
		_ground.queue_redraw()
		_uprights.queue_redraw()
	if picture.shown == _shown:
		_soon = false
	_drawing += 1
	_figure_drawn = []


## [param picture] no longer wanted: hidden, emptied and kept as the spare
## (its canvas items freed should one be kept already).
func _spare_picture(picture: Picture) -> void:
	for item in [picture.ground, picture.uprights]:
		if item.is_valid():
			RenderingServer.canvas_item_clear(item)
			RenderingServer.canvas_item_set_visible(item, false)
	if _spare == null or _spare == picture:
		_spare = picture
		return
	for item in [picture.ground, picture.uprights]:
		if item.is_valid():
			RenderingServer.free_rid(item)
	picture.ground = RID()
	picture.uprights = RID()


## No world: nothing kept.
func _drop_pictures() -> void:
	if _next != null:
		_spare_picture(_next)
		_next = null
	if _front != null:
		_spare_picture(_front)
		_front = null
	_covered = Rect2()
	_tiles = []
	_lefts = PackedVector2Array()
	_seen = PackedByteArray()
	_tile_recipes = []
	_upright_ops = []
	_upright_feet = PackedInt32Array()


## [param picture] drawn on until done or the time [param until] (usec; 0
## for no end): true when done. The steps ([enum Step]) a few tiles, a
## screen row or a few uprights at a time.
func _draw_some(picture: Picture, until: int) -> bool:
	var count := picture.tiles.size()
	while picture.step != Step.DONE:
		if until > 0 and Time.get_ticks_usec() >= until:
			return false
		var at := picture.at
		var end := mini(at + 16, count)
		match picture.step:
			Step.PLAN:
				for i in range(at, end):
					var tile := picture.tiles[i]
					picture.lefts[i] = Vector2(64 * (tile.x + tile.y), 32 * (tile.y - tile.x)) - picture.origin
					picture.seen[i] = 1 if not fog or world.is_explored(tile.x, tile.y) else 0
					if not picture.plain:
						picture.recipes[i] = _recipe(tile)
				picture.at = end
				if end >= count:
					_rows_of(picture)
					picture.step = Step.DONE if picture.plain else Step.GATHER
					picture.at = 0
			Step.GATHER:
				for i in range(at, end):
					_gather(picture, i)
				picture.at = end
				if end >= count:
					_gather_rest(picture)
					picture.step = Step.SORT
			Step.SORT:
				picture.keys.sort()
				for key in picture.keys:
					picture.upright_ops.append(picture.standing[UPRIGHT_COUNT - 1 - (key & (UPRIGHT_COUNT - 1))])
					picture.upright_feet.append((key >> UPRIGHT_BITS) - UPRIGHT_LOW)
				picture.standing = []
				picture.keys = PackedInt64Array()
				picture.step = Step.LAND
				picture.at = 0
			Step.LAND:
				if at < picture.rows.size() - 1:
					_put_row(picture, picture.rows[at], picture.rows[at + 1])
					picture.at = at + 1
				else:
					picture.step = Step.DARK if fog else Step.HALVES
					picture.at = 0
			Step.DARK:
				if at == 0:
					picture.dark = [PackedVector2Array(), PackedVector2Array(), PackedInt32Array(), PackedInt32Array()]
				for i in range(at, end):
					if picture.seen[i] == 0:
						_put_dark(picture, i)
				picture.at = end
				if end >= count:
					_put_dark_all(picture)
					picture.step = Step.HALVES
					picture.at = 0
			Step.HALVES:
				for i in range(at, end):
					if picture.seen[i] != 0:
						for op in picture.recipes[i][1]:
							_put(picture.ground, op, picture.lefts[i])
					if not _dungeon_at.is_empty():
						_put(picture.ground, _dungeon_op(picture.tiles[i], true), picture.lefts[i])
				picture.at = end
				if end >= count:
					_put_halves_rest(picture)
					picture.step = Step.UPRIGHTS
					picture.at = 0
			Step.UPRIGHTS:
				var last := mini(at + 32, picture.upright_ops.size())
				for i in range(at, last):
					_put(picture.uprights, picture.upright_ops[i], Vector2.ZERO)
				picture.at = last
				if last >= picture.upright_ops.size():
					picture.step = Step.DONE
	return true


## Where each screen row of [param picture]'s tiles begins (the tiles come
## row by row, [method _tiles_over]), and their count last.
static func _rows_of(picture: Picture) -> void:
	var rows := PackedInt32Array()
	var row := 1 << 30
	for i in picture.tiles.size():
		var tile := picture.tiles[i]
		if tile.y - tile.x != row:
			row = tile.y - tile.x
			rows.append(i)
	rows.append(picture.tiles.size())
	picture.rows = rows


## The tiles whose pictures can reach [param area] (the pictures' units;
## the map's corner (0, 0) projects to −[param origin]), in the original's
## order: the window of [method draw_order] the screen sees, worked out
## from its corners — a tile's left corner stands at (64 (tx + ty),
## 32 (ty − tx)) less the origin, and what stands on it reaches [constant
## REACH] round that.
static func _tiles_over(area: Rect2, origin: Vector2) -> Array[Vector2i]:
	var first_row := floori((area.position.y - REACH.end.y + origin.y) / 32.0)
	var last_row := ceili((area.end.y - REACH.position.y + origin.y) / 32.0)
	var first_across := floori((area.position.x - REACH.end.x + origin.x) / 64.0)
	var last_across := ceili((area.end.x - REACH.position.x + origin.x) / 64.0)
	var tiles: Array[Vector2i] = []
	for row in range(first_row, last_row + 1):
		# tx + ty and ty − tx are both even or both odd.
		for across in range(first_across + ((first_across + row) & 1), last_across + 1, 2):
			var tile := Vector2i((across - row) / 2, (across + row) / 2)
			if tile.x >= -MARGIN and tile.y >= -MARGIN and tile.x < ShandalarWorld.TILES + MARGIN \
					and tile.y < ShandalarWorld.TILES + MARGIN:
				tiles.append(tile)
	return tiles


## THE UPRIGHTS, gathered in the order drawn (sorted at [enum Step] SORT):
## up by the height of the foot, the later of two at one height behind
## (the queue of `RenderAdventureWorldScene`, sorted on whole numbers). A
## dungeon is queued after its tile's trees or rocks, as 1997 queued it —
## seen or not ([member dungeons]). A castle (or its ruins) and the portal
## carry their tile as a fourth part, `[sheet, where, frame, tile]` ([method
## hero_parts]). Tile [param i]'s.
func _gather(picture: Picture, i: int) -> void:
	var left := picture.lefts[i]
	if picture.seen[i] != 0:
		for upright in picture.recipes[i][2]:
			picture.keys.append(_upright_key(int(left.y) + int(upright[0]), picture.standing.size()))
			var op := [upright[1], Rect2(left + upright[2].position, upright[2].size), upright[3]]
			if upright.size() > 4:
				# The tile's place: its tile beside it ([method hero_parts]).
				op.append(picture.tiles[i])
			picture.standing.append(op)
	if not _dungeon_at.is_empty():
		var dungeon := _dungeon_op(picture.tiles[i], false)
		if not dungeon.is_empty():
			picture.keys.append(_upright_key(int(left.y), picture.standing.size()))
			picture.standing.append([dungeon[0], Rect2(left + dungeon[1].position, dungeon[1].size), dungeon[2]])


## The lairs' uprights and the portal's, after the tiles'.
func _gather_rest(picture: Picture) -> void:
	for lair in lairs:
		var point := _lay(Vector2(int(lair["x"]), int(lair["y"]))) - picture.origin
		var op := _op("world_locatn07", LAIR_FRAMES[clampi(int(lair.get("color", 0)), 0, 5)], point - Vector2(64, 96))
		if not op.is_empty():
			picture.keys.append(_upright_key(int(point.y), picture.standing.size()))
			picture.standing.append(op)
	var gate := _portal_op(picture.origin, false, picture.twice)
	if not gate.is_empty():
		picture.keys.append(_upright_key(int((gate[1] as Rect2).position.y - PORTAL_AT.y), picture.standing.size()))
		gate.append(portal_tile())
		picture.standing.append(gate)


## An upright's place in the order as one number: its foot's height, then
## the later first.
const UPRIGHT_BITS := 21
const UPRIGHT_COUNT := 1 << UPRIGHT_BITS
const UPRIGHT_LOW := 1 << 30


static func _upright_key(foot: int, index: int) -> int:
	return ((foot + UPRIGHT_LOW) << UPRIGHT_BITS) | (UPRIGHT_COUNT - 1 - index)


# ------------------------------------------------------------ the 1997 --

## THE GROUND'S TILES, EDGES AND ROADS of the screen row of tiles [param
## from] to [param to] (exclusive), in the original's order but each sheet
## in one run: the diamonds of one row never overlap (only a row's with the
## next one's, by a pixel along their edges), so drawing the row's tiles,
## then its edges, then its roads leaves the very pixels drawing them tile
## by tile did — in fewer draw calls. A sheet the three are not drawn tile
## by tile.
func _put_row(picture: Picture, from: int, to: int) -> void:
	var item := picture.ground
	var sheets: Array = picture.sheets
	for i in range(from, to):
		for op in picture.recipes[i][0]:
			if not sheets.has(op[0]):
				for j in range(from, to):
					for each in picture.recipes[j][0]:
						_put(item, each, picture.lefts[j])
				return
	for sheet in sheets:
		for i in range(from, to):
			var left := picture.lefts[i]
			for op in picture.recipes[i][0]:
				if op[0] == sheet:
					_put(item, op, left)


## THE DARK over unseen tile [param i], lighter where it meets the seen:
## its diamond's two triangles gathered with the rest of its shade's
## ([member Picture.dark]) and drawn as one polygon each shade when all
## are in ([method _put_dark_all]) — the very polygon a diamond drawn alone
## was ([method _paint_fog]: one colour, the same corners), two draw calls
## for the whole dark instead of one a tile.
func _put_dark(picture: Picture, i: int) -> void:
	var tile := picture.tiles[i]
	var edge := false
	for d in range(1, 9):
		if world.is_explored(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d]):
			edge = true
			break
	var left := picture.lefts[i]
	var shade := 1 if edge else 0
	# Taken out and put back, so the arrays grow in place (not copied).
	var points: PackedVector2Array = picture.dark[shade]
	var corners: PackedInt32Array = picture.dark[shade + 2]
	picture.dark[shade] = PackedVector2Array()
	picture.dark[shade + 2] = PackedInt32Array()
	var first := points.size()
	points.append_array([left, left + Vector2(64, -32), left + Vector2(128, 0), left + Vector2(64, 32)])
	corners.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	picture.dark[shade] = points
	picture.dark[shade + 2] = corners


## The dark gathered ([method _put_dark]) drawn: the deep shade, then the
## lighter at its edge — no two diamonds overlap, so in either order.
func _put_dark_all(picture: Picture) -> void:
	for shade in 2:
		var points: PackedVector2Array = picture.dark[shade]
		if points.is_empty():
			continue
		RenderingServer.canvas_item_add_triangle_array(picture.ground, picture.dark[shade + 2], points,
			PackedColorArray([FOG_EDGE if shade == 1 else FOG]))
	picture.dark = []


## The lairs' ground halves and the portal's, after the tiles'.
func _put_halves_rest(picture: Picture) -> void:
	for lair in lairs:
		var point := _lay(Vector2(int(lair["x"]), int(lair["y"]))) - picture.origin
		var frame := LAIR_FRAMES[clampi(int(lair.get("color", 0)), 0, 5)]
		_put(picture.ground, _op("world_locatn07", frame + 6, point - Vector2(64, 96)), Vector2.ZERO)
	_put(picture.ground, _portal_op(picture.origin, true, picture.twice), Vector2.ZERO)


## Draw [param op] (`[sheet, where, frame]`, round a tile's left corner) at
## [param left] into canvas item [param item] — as [method
## CanvasItem.draw_texture_rect_region] draws it.
static func _put(item: RID, op: Array, left: Vector2) -> void:
	if op.is_empty():
		return
	var where: Rect2 = op[1]
	(op[0] as Texture2D).draw_rect_region(item, Rect2(left + where.position, where.size), op[2])


## THE GROUND PLAIN (no 1997 sheets): drawn here, on the Ground picture
## itself; the 1997 ground is the pictures' own canvas items ([method _put]).
func _paint_ground() -> void:
	if world == null or _tiles.is_empty() or not _plain:
		return
	_paint_plain()


## The uprights are the pictures' own canvas items; plain, there are none.
func _paint_uprights() -> void:
	pass


## WHAT A ZOOM OUT WOULD WANT, worked out in a frame's spare time until
## [param until] (usec): what the tiles over the screen at the furthest
## zoom out show ([method _recipe]), round the pictures' anchor — listed
## again once it moved four tiles — so the first zoom out draws without
## working them out (the smoothness pass, 0.50.66: some 2,000 tiles, 19 ms
## on a desk). They are kept as every tile drawn always was: about 1 KB a
## tile, 2 MB the furthest zoom's screen, 7.6 MB the whole map at most.
func _warm_recipes(until: int) -> void:
	if _plain or _front == null:
		return
	var away := _warm_round - _anchor
	if absi(away.x) > 128 or absi(away.y) > 128:
		_warm_round = _anchor
		_warm = _tiles_over(_screen_round(_anchor, Vector2(_anchor), ZOOM_MIN).grow(SPARE / ZOOM_MIN),
			_lay(Vector2(_anchor)))
		_warm_done = 0
		return
	while _warm_done < _warm.size() and Time.get_ticks_usec() < until:
		var end := mini(_warm_done + 8, _warm.size())
		for i in range(_warm_done, end):
			var tile := _warm[i]
			if not _recipes.has(tile):
				_recipe(tile)
		_warm_done = end


## THE SITES AS DRAWN, looked at again when they change: the tile of a site
## whose slot, kind or ruler changed — a town taken, its dome gone, a castle
## beaten — has what it shows worked out again, and the pictures are drawn
## again ([member _sites_drawn]); a town's other flags (visited, quests,
## prices) change nothing drawn (the bug pass after a duel's spoils threw
## every tile's away). The portal's tile likewise.
func _look_at_sites() -> void:
	var gate := portal_tile()
	if gate != _portal_at:
		_recipes.erase(gate)
		_recipes.erase(_portal_at)
		_portal_at = gate
	var sites_hash := world.sites.hash()
	if sites_hash == _sites_hash:
		return
	_sites_hash = sites_hash
	var marks := {}
	for i in world.sites.size():
		var site: Dictionary = world.sites[i]
		var tile := Vector2i(int(site.get("x", -1)), int(site.get("y", -1)))
		if not marks.has(tile):
			marks[tile] = [i, int(site.get("type", 0)), TownStatus.ruler(world, i)]
	if marks == _site_marks:
		return
	for tile in marks:
		if _site_marks.get(tile, []) != marks[tile]:
			_recipes.erase(tile)
	for tile in _site_marks:
		if not marks.has(tile):
			_recipes.erase(tile)
	_site_marks = marks
	_sites_drawn += 1


## THE SHADOWS, under everything upright: the hero's, then the creatures'
## by slot (ui.c 2203, 2272), each at its body's anchor.
func _paint_shadow() -> void:
	if world == null or _plain or _tiles.is_empty():
		return
	_blit(_shadow, _op("world_sego_f", _hero_frame(), _hero_at() - Vector2(77, 61)), Vector2.ZERO)
	for creature in _creatures_drawn():
		var keys := CreatureBook.sprite_keys(int(creature["creature"]))
		var sheet := art.texture(String(keys["shadow"]))
		if sheet == null or art.texture(String(keys["body"])) == null:
			continue
		var frame := WorldArt.creature_frame(int(creature["heading"]), int(creature["frame"]))
		var rect := art.creature_rect(String(keys["shadow"]), frame)
		var at := _creature_at(creature) - art.creature_anchor(String(keys["body"]))
		_shadow.draw_texture_rect_region(sheet, Rect2(at, rect.size), rect)


## THE MOVERS — the hero and the creatures, back to front by their feet
## ([method movers]) — each with the parts of what stands in front of it
## drawn again over it ([method _in_front_of]), so they stand among the
## uprights as in the original's one queue.
func _paint_figure() -> void:
	if world == null or _tiles.is_empty():
		return
	for mover in movers():
		if mover.is_empty():
			_paint_hero()
		else:
			_paint_creature(mover)


## THE ORDER THE MOVERS ARE DRAWN IN: back to front by the height of the
## foot; at one height a higher slot first, the hero last (in front) — the
## original queued the hero before the creatures, slots up, and put each
## newcomer before its equals. The hero is `{}`, a creature its record.
func movers() -> Array[Dictionary]:
	var order: Array[Dictionary] = [{}]
	order.append_array(_creatures_drawn())
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa := _mover_foot(a)
		var fb := _mover_foot(b)
		if fa != fb:
			return fa < fb
		return _mover_rank(a) > _mover_rank(b))
	return order


## A mover's foot on the pictures: the height its feet are drawn at.
func _mover_foot(mover: Dictionary) -> float:
	return _hero_at().y if mover.is_empty() else _creature_at(mover).y


## A mover's rank at one height: the hero −1, a creature its slot — the
## higher drawn first, behind.
static func _mover_rank(mover: Dictionary) -> int:
	return -1 if mover.is_empty() else int(mover["slot"])


## The creatures drawn: on land the hero has seen (or the dark off).
## [ours; the smoothness pass, 0.50.66] — and whose sheets are in hand
## ([method WorldArt.sheet_ready]): a creature just come into view, its
## sheets read on a worker, is drawn a frame or a few later rather than the
## frame stalling on them; where nothing reads on a worker (the tests, the
## web) the sheets are read as it is drawn, as always.
func _creatures_drawn() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for creature in creatures:
		if fog and not world.is_explored(int(creature["x"]) / 32, int(creature["y"]) / 32):
			continue
		if not _plain:
			var keys := CreatureBook.sprite_keys(int(creature["creature"]))
			if not art.sheet_ready(String(keys["body"])) or not art.sheet_ready(String(keys["shadow"])):
				continue
		out.append(creature)
	return out


## THE HERO, standing among the uprights.
func _paint_hero() -> void:
	var at := _hero_at()
	if _plain:
		draw_hero_plain(_figure, at)
		return
	var key := "world_ego_f" if hero_walker == "female" else "world_ego_m"
	var sheet := hero_sheet if hero_sheet != null else art.texture(key)
	if sheet == null:
		return
	var frame_rect := art.frame_rect(key, _hero_frame())
	var figure := Rect2(at - Vector2(77, 61), frame_rect.size)
	_figure.draw_texture_rect_region(sheet, figure, frame_rect)
	for part in hero_parts(figure):
		_figure.draw_texture_rect_region(part[0], part[1], part[2])


## THE PARTS DRAWN AGAIN OVER THE HERO whose frame is [param figure]
## ([method _in_front_of]) — but not the place on the hero's own tile (the
## class's notes, h3-5 [ours]: the hero in front of it).
func hero_parts(figure: Rect2) -> Array:
	return _in_front_of(_hero_at().y, figure, hero_tile())


## The tile the hero is drawn on this frame (slid between ticks).
func hero_tile() -> Vector2i:
	var shown := _shown_hero()
	return Vector2i(floori(shown.x / 32.0), floori(shown.y / 32.0))


## CREATURE [param creature], standing among the uprights — its sheet's
## frame at its feet less its anchor, or a disc of its colour without it.
func _paint_creature(creature: Dictionary) -> void:
	var at := _creature_at(creature)
	var key := String(CreatureBook.sprite_keys(int(creature["creature"]))["body"])
	var sheet := art.texture(key) if not _plain else null
	if sheet == null:
		draw_creature_plain(_figure, at, int(creature.get("color", 0)))
		return
	var rect := art.creature_rect(key, WorldArt.creature_frame(int(creature["heading"]), int(creature["frame"])))
	var body := Rect2(at - art.creature_anchor(key), rect.size)
	_figure.draw_texture_rect_region(sheet, body, rect)
	for part in _in_front_of(at.y, body):
		_figure.draw_texture_rect_region(part[0], part[1], part[2])


## Where creature [param creature]'s feet are on the pictures.
func _creature_at(creature: Dictionary) -> Vector2:
	return _lay(_shown_creature(creature) - Vector2(_anchor))


## The parts of the uprights in front of a hero whose feet stand at height
## [param feet_y] — their foot as low or lower: the hero came last in the
## original's queue, so behind anything at their own height — that fall on
## the hero's frame [param figure]: `[sheet, where, frame]`, cut on whole
## pixels of the sheet so they fall on the ones drawn below (only at half
## size and the like can a cut part pick the neighbouring pixel of its
## sheet), in the uprights' order. The place standing on tile [param own]
## is left out (the hero in front of it, [method hero_parts]).
func _in_front_of(feet_y: float, figure: Rect2, own := Vector2i(-1, -1)) -> Array:
	var parts: Array = []
	var first := _upright_feet.bsearch(ceili(feet_y), true)
	for i in range(first, _upright_feet.size()):
		if _upright_feet[i] > feet_y + IN_FRONT:
			break
		var op: Array = _upright_ops[i]
		if op.size() > 3 and op[3] == own:
			continue
		var where: Rect2 = op[1]
		var over := where.intersection(figure)
		if not over.has_area():
			continue
		var from := (over.position - where.position).floor()
		var to := (over.end - where.position).ceil().min(where.size)
		parts.append([op[0], Rect2(where.position + from, to - from), Rect2(op[2].position + from, to - from)])
	return parts


## Where the hero's feet are on the pictures, and their frame.
func _hero_at() -> Vector2:
	return _lay(_shown_hero() - Vector2(_anchor))


func _hero_frame() -> int:
	return ((hero_facing + 2) & 7) * 5 + clampi(hero_step, 0, 4)


## The dark over unseen land, lighter where it meets the seen — on the
## plain world's picture ([method _put_dark] for the 1997 one).
func _paint_fog(canvas: CanvasItem) -> void:
	for i in _tiles.size():
		if _seen[i] != 0:
			continue
		var tile := _tiles[i]
		var edge := false
		for d in range(1, 9):
			if world.is_explored(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d]):
				edge = true
				break
		var left := _lefts[i]
		canvas.draw_colored_polygon(PackedVector2Array([left, left + Vector2(64, -32),
			left + Vector2(128, 0), left + Vector2(64, 32)]), FOG_EDGE if edge else FOG)


## Draw [param op] (`[sheet, where, frame]`, round a tile's left corner)
## at [param left] on [param canvas].
static func _blit(canvas: CanvasItem, op: Array, left: Vector2) -> void:
	if not op.is_empty():
		canvas.draw_texture_rect_region(op[0], Rect2(left + op[1].position, op[1].size), op[2])


## Frame [param frame] of sheet [param key] with its corner at [param at]:
## `[sheet, where, frame]`, or [] when the skin lacks the sheet.
func _op(key: String, frame: int, at: Vector2) -> Array:
	var sheet := art.texture(key)
	if sheet == null:
		return []
	var rect := art.frame_rect(key, frame)
	return [sheet, Rect2(at, rect.size), rect]


## WHAT A TILE SHOWS, round its left corner, worked out once a world:
## `[ground, ground halves, uprights]` — the ground and the ground halves
## as `[sheet, where, frame]`, the uprights as `[foot, sheet, where,
## frame]` (the foot's height below the corner).
func _recipe(tile: Vector2i) -> Array:
	if _recipes.has(tile):
		return _recipes[tile]
	var ground: Array = []
	_ground_of(tile, ground)
	var halves: Array = []
	var uprights: Array = []
	_standing_on(tile, halves, uprights)
	var recipe := [ground, halves, uprights]
	_recipes[tile] = recipe
	return recipe


## The ground of [param tile]: its land, the black terrain's and the
## coast's edge pieces, its roads.
func _ground_of(tile: Vector2i, ops: Array) -> void:
	var box := Vector2(0, -32)
	var code := world.terrain(tile.x, tile.y)
	var colors := ShandalarWorld.magic_mask(code)
	if code == 0 or code == 8:
		_add(ops, _op("world_landtile", 1, box))
	else:
		if code == 1:
			_add(ops, _op("world_landtile", 2, box))
		else:
			_add(ops, _op("world_landtile", 4 if colors == 2 else 0, box))
		var coast := 0
		var black := 0
		for d in range(1, 9):
			coast >>= 1
			black >>= 1
			var next := world.terrain(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d])
			var next_colors := ShandalarWorld.magic_mask(next)
			if next == 0 or next == 8 or (next != code and (colors | next_colors) & 4 != 0):
				coast |= 0x80
			if colors != 2 and next_colors == 2:
				black |= 0x80
		_edges(black, 4, box, ops)
		_edges(coast, 0, box, ops)
	var roads := world.road_bits(tile.x, tile.y)
	for i in 8:
		if roads & (1 << i) != 0:
			_add(ops, _op("world_roads", ((i - 2) & 7) + 1, box))


static func _add(ops: Array, op: Array) -> void:
	if not op.is_empty():
		ops.append(op)


## The four quarters of a diamond, each reading its two edge neighbours
## and the corner between (bits of the eight directions, wrapped): top
## N NE E, bottom S SW W, left W NW N, right E SE S.
func _edges(bits: int, first_row: int, box: Vector2, ops: Array) -> void:
	if bits == 0:
		return
	bits |= bits << 8
	for i in 4:
		var three := 0
		match i:
			0: three = bits & 7
			1: three = (bits >> 4) & 7
			2: three = (bits >> 6) & 7
			3: three = (bits >> 2) & 7
		if three == 0:
			continue
		var at := box + (Vector2(32, (i & 1) * 32) if i < 2 else Vector2((i & 1) * 64, 16))
		_add(ops, _op("world_cstline1", (first_row + i) * 7 + three - 1, at))


## What stands on [param tile]: its two trees or rocks, or its site — the
## ground halves into [param halves], the uprights into [param uprights].
func _standing_on(tile: Vector2i, halves: Array, uprights: Array) -> void:
	if tile == portal_tile():
		return  # [ours] the portal stands alone on its tile, as a site does
	var flags := world.tile_flags(tile.x, tile.y)
	var code := world.terrain(tile.x, tile.y)
	if flags & ShandalarWorld.SITE == 0 and OBJECT_COLUMN.has(code):
		var pattern := absi(tile.y) * 3 + absi(tile.x) * 7
		var ox := TILE_W / ((pattern % 5) * 2 + 4)
		var oy := (pattern % 4) * 2 + 5
		if code == 1:
			ox = 0
			oy = 0
		var column: int = OBJECT_COLUMN[code]
		var row := pattern % 11
		if column >= 5:
			column %= 5
			row += 11
		_object(row, column, Vector2(ox, -oy), halves, uprights)
		row = (pattern + tile.x) % 11 + (11 if row >= 11 else 0)
		_object(row, column, Vector2(-ox, oy), halves, uprights)
	if flags & ShandalarWorld.SITE != 0:
		_site(tile, halves, uprights)


## One tree or rock standing at [param foot]: its ground half and its
## upright, both at the foot less the frame's anchor.
func _object(row: int, column: int, foot: Vector2, halves: Array, uprights: Array) -> void:
	var upright := "world_land2" if row >= 11 else "world_land"
	var ground := "world_sland2" if row >= 11 else "world_sland"
	var frame := (row % 11) * 5 + column
	var at := foot - Vector2(0, art.top(upright, frame))
	_add(halves, _op(ground, frame, at))
	_stand(uprights, int(foot.y), _op(upright, frame, at))


## [param op] standing with its foot [param foot] below the tile's corner;
## [param place] marks it the tile's place (a fifth part, true — [method
## hero_parts]).
static func _stand(uprights: Array, foot: int, op: Array, place := false) -> void:
	if not op.is_empty():
		uprights.append([foot, op[0], op[1], op[2], true] if place else [foot, op[0], op[1], op[2]])


func _site(tile: Vector2i, halves: Array, uprights: Array) -> void:
	var index := _site_index(tile)
	if index < 0:
		return
	var site: Dictionary = world.sites[index]
	var kind: int = site["type"]
	if kind == ShandalarWorld.CASTLE or kind == 5:
		var color := _color_index(world.terrain(tile.x, tile.y))
		var frames: Array = CASTLE_FRAMES[color]
		var pick := 0 if kind == ShandalarWorld.CASTLE else 2
		var at := Vector2(0, -160)
		var half := _castle_ref(frames[pick + 1])
		_add(halves, _op(half[0], half[1], at))
		var whole := _castle_ref(frames[pick])
		_stand(uprights, 0, _op(whole[0], whole[1], at), true)
		return
	var ruler := TownStatus.ruler(world, index)
	if ruler != 0:
		var dome: Array = DOMES[ruler - 1]
		var at := Vector2(0, -166)
		_add(halves, _op("world_locatn04", 6, at))
		_stand(uprights, 0, _op(dome[0], dome[1], at))
		return
	var look := ((tile.x & 1) + 16) * 2 if kind == ShandalarWorld.VILLAGE else (index % 16) * 2
	var upright := _location(TOWN_LOOKS[look])
	var ground := _location(TOWN_LOOKS[look + 1])
	var height := art.frame_size(upright[0]).y
	var at := Vector2(0, 24 - height)
	_add(halves, _op(ground[0], ground[1], at))
	_stand(uprights, 0, _op(upright[0], upright[1], at))


## ARZAKON'S PORTAL'S TILE ([member portal]), (−1, −1) when none stands (or
## its state is none the pictures know).
func portal_tile() -> Vector2i:
	if portal.is_empty() or not PORTAL_ART.has(String(portal.get("state", ""))):
		return Vector2i(-1, -1)
	return Vector2i(int(portal.get("x", -1)), int(portal.get("y", -1)))


## The portal's picture in `game/art/` for [param state]: the upright, or
## with [param ground] its ground half; the `@2x` twin when [param twice];
## "" for a state with no picture.
static func portal_key(state: String, ground: bool, twice: bool) -> String:
	var key := String(PORTAL_ART.get(state, ""))
	if key == "":
		return ""
	return key + ("_ground" if ground else "") + (GameSkin.SCALED_SUFFIX if twice else "")


## Whether the skin worn is a 2x one — its ground sheet's scale, the
## hi-res skin's pictures being twice their slots ([method GameSkin.scale_of]).
func _skin_twice() -> bool:
	return GameSkin.scale_of(art.texture("world_landtile")) > 1


## The portal's upright — or with [param ground] its ground half — as
## `[sheet, where, frame]` on the pictures drawn round [param origin]: the
## castle's frame at its tile's left corner, all of the picture's own
## pixels drawn into it (twice as many with [param twice], and the 1x
## picture should the `@2x` one be missing); [] for no portal.
func _portal_op(origin: Vector2, ground: bool, twice: bool) -> Array:
	var tile := portal_tile()
	if tile.x < 0:
		return []
	var state := String(portal["state"])
	var sheet := GameSkin.our_art(portal_key(state, ground, twice))
	if sheet == null and twice:
		sheet = GameSkin.our_art(portal_key(state, ground, false))
	if sheet == null:
		return []
	var left := Vector2(64 * (tile.x + tile.y), 32 * (tile.y - tile.x)) - origin
	return [sheet, Rect2(left + PORTAL_AT, PORTAL_FRAME), Rect2(Vector2.ZERO, sheet.get_size())]


## DUNGEON [param index] (5–14)'s marker: `[[sheet, frame] of the upright,
## [sheet, frame] of its ground half]` — the pair `(index − 5) · 2` of
## [constant DUNGEON_LOOKS]; `[]` for a slot that is no dungeon.
static func dungeon_frames(index: int) -> Array:
	var pair := (index - 5) * 2
	if pair < 0 or pair + 1 >= DUNGEON_LOOKS.size():
		return []
	return [_location(DUNGEON_LOOKS[pair]), _location(DUNGEON_LOOKS[pair + 1])]


## The marker of the dungeon drawn at [param tile] — its ground half when
## [param ground], else its upright — round the tile's left corner, both
## 32 less the upright's height above it (1997's `tile_base_screen_y −
## height + g_world_camera_minimap_panel_y`, 0x20 at 640): `[sheet, where,
## frame]`, or [] for none there (or a skin without the sheet).
func _dungeon_op(tile: Vector2i, ground: bool) -> Array:
	var frames := dungeon_frames(int(_dungeon_at.get(tile, -1)))
	if frames.is_empty():
		return []
	var upright: Array = frames[0]
	var look: Array = frames[1] if ground else upright
	var height := art.frame_size(String(upright[0])).y
	return _op(String(look[0]), int(look[1]), Vector2(0, 32 - height))


## `FindTownAtWorldCoordinates`: the first slot standing on the tile.
func _site_index(tile: Vector2i) -> int:
	for i in world.sites.size():
		if int(world.sites[i]["x"]) == tile.x and int(world.sites[i]["y"]) == tile.y:
			return i
	return -1


## A terrain's one colour, 0 black … 4 white.
static func _color_index(code: int) -> int:
	match ShandalarWorld.magic_mask(code):
		0x02: return 0
		0x04: return 1
		0x08: return 2
		0x10: return 3
	return 4


## An index into the six location sheets read as one: [sheet, frame].
static func _location(index: int) -> Array:
	for i in range(LOCATION_SHEETS.size() - 1, -1, -1):
		if index >= int(LOCATION_SHEETS[i][0]):
			return [LOCATION_SHEETS[i][1], index - int(LOCATION_SHEETS[i][0])]
	return [LOCATION_SHEETS[0][1], index]


static func _castle_ref(index: int) -> Array:
	return ["world_castles1", index] if index < 12 else ["world_castles2", index - 12]


# ----------------------------------------------------------- the plain --

## The world plain, on the ground's picture: a diamond of its colour per
## tile, the dark, the roads, a mark per site, per dungeon (seen or not)
## and per lair.
func _paint_plain() -> void:
	var canvas := _ground
	for i in _tiles.size():
		var tile := _tiles[i]
		var left := _lefts[i]
		var points := PackedVector2Array([left, left + Vector2(64, -32),
			left + Vector2(128, 0), left + Vector2(64, 32)])
		canvas.draw_colored_polygon(points, PLAIN.get(world.terrain(tile.x, tile.y), PLAIN[0]))
	if fog:
		_paint_fog(canvas)
	var origin := _lay(Vector2(_anchor))
	for i in _tiles.size():
		if _seen[i] == 0:
			continue
		var tile := _tiles[i]
		var middle := _lefts[i] + Vector2(64, 0)
		var roads := world.road_bits(tile.x, tile.y)
		for d in range(1, 9):
			if roads & (1 << (d - 1)) != 0:
				var to := _lay(Vector2((tile.x + ShandalarWorld.DX[d]) * 32 + 16,
					(tile.y + ShandalarWorld.DY[d]) * 32 + 16)) - origin
				canvas.draw_line(middle, middle.lerp(to, 0.5), Color8(123, 63, 7), 3.0)
	for i in _tiles.size():
		var tile := _tiles[i]
		if world.tile_flags(tile.x, tile.y) & ShandalarWorld.SITE == 0 or _seen[i] == 0:
			continue
		var index := _site_index(tile)
		if index < 0:
			continue
		var kind: int = world.sites[index]["type"]
		var middle := _lefts[i] + Vector2(64, 0)
		var radius: float = [0, 7, 11, 14, 18, 18][clampi(kind, 0, 5)]
		canvas.draw_circle(middle, radius + 2, Color(0, 0, 0, 0.6))
		canvas.draw_circle(middle, radius, Color8(236, 222, 196) if kind < 4 else Color8(232, 190, 110))
	for dungeon in dungeons:
		draw_dungeon_plain(canvas, _lay(Vector2(int(dungeon["x"]) * 32 + 16, int(dungeon["y"]) * 32 + 16)) - origin)
	for lair in lairs:
		var mouth := _lay(Vector2(int(lair["x"]), int(lair["y"]))) - origin
		canvas.draw_circle(mouth, 12, Color(0, 0, 0, 0.6))
		canvas.draw_circle(mouth, 9, Color8(40, 26, 20))
		canvas.draw_arc(mouth, 10, 0, TAU, 20, Color8(232, 190, 110), 2.0)
	var gate := portal_tile()
	if gate.x >= 0:
		draw_portal_plain(canvas, _lay(Vector2(gate.x * 32 + 16, gate.y * 32 + 16)) - origin,
			String(portal["state"]))


## A dungeon plain, its tile's middle at [param at] on [param canvas]: a
## dark mouth ringed in gold, as a lair's, with the gold step of the way
## down inside it.
static func draw_dungeon_plain(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_circle(at, 14, Color(0, 0, 0, 0.6))
	canvas.draw_circle(at, 11, Color8(14, 10, 12))
	canvas.draw_arc(at, 12, 0, TAU, 24, Color8(232, 190, 110), 2.5)
	canvas.draw_arc(at, 5, 0, TAU, 16, Color8(232, 190, 110), 1.5)


## [ours] ARZAKON'S PORTAL plain, its tile's middle at [param at] on [param
## canvas]: a horned arch on a plinth, standing on the middle, with the
## 0.6-black rim every plain mark wears — dark slate round a violet void
## with a pale heart while open ([constant FinalBattle.PORTAL_OPEN]); grey
## stone sealed with a carved ring and a crack, the right horn broken and
## moss on it once petrified.
static func draw_portal_plain(canvas: CanvasItem, at: Vector2, state: String) -> void:
	var stone := state == FinalBattle.PORTAL_PETRIFIED
	for rim in portal_plain_rim(at, stone):
		canvas.draw_colored_polygon(rim, Color(0, 0, 0, 0.6))
	var shapes := _portal_plain_shapes(at, stone)
	canvas.draw_colored_polygon(shapes[0], Color8(104, 100, 96) if stone else Color8(52, 46, 66))
	for i in range(1, shapes.size()):
		canvas.draw_colored_polygon(shapes[i], Color8(150, 146, 140) if stone else Color8(72, 64, 90))
	var hole := Color8(104, 100, 96) if stone else Color8(124, 64, 200)
	canvas.draw_rect(Rect2(at + Vector2(-8, -30), Vector2(16, 28)), hole)
	canvas.draw_circle(at + Vector2(0, -30), 8, hole)
	if stone:
		var groove := Color8(84, 80, 76)
		canvas.draw_arc(at + Vector2(0, -20), 5, deg_to_rad(200), deg_to_rad(520), 20, groove, 1.4)
		canvas.draw_polyline(PackedVector2Array([at + Vector2(-13, -24), at + Vector2(-10, -16),
			at + Vector2(-13, -9)]), groove, 1.2)
		canvas.draw_colored_polygon(_oval(at + Vector2(15, 1), Vector2(3, 2)), Color8(98, 136, 66))
		canvas.draw_colored_polygon(_oval(at + Vector2(-6, -45), Vector2(2.5, 1.6)), Color8(98, 136, 66))
	else:
		canvas.draw_colored_polygon(_oval(at + Vector2(0, -18), Vector2(5, 9)), Color8(196, 160, 255))
		canvas.draw_colored_polygon(_oval(at + Vector2(0, -16), Vector2(2, 4)), Color8(240, 228, 255))


## The plain portal's rim: its shapes' one silhouette grown by 2, drawn once
## so no two shapes darken it twice.
static func portal_plain_rim(at: Vector2, petrified: bool) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	for shape in _portal_plain_shapes(at, petrified):
		var joined := shape
		var apart: Array[PackedVector2Array] = []
		for piece in pieces:
			var merged := Geometry2D.merge_polygons(piece, joined)
			if merged.size() == 1:
				joined = merged[0]
			else:
				apart.append(piece)
		apart.append(joined)
		pieces = apart
	var out: Array[PackedVector2Array] = []
	for piece in pieces:
		out.append_array(Geometry2D.offset_polygon(piece, 2.0))
	return out


## The plain portal's shapes round its tile's middle [param at]: the plinth,
## the body, its round top and the two horns (the right one broken when
## [param petrified]).
static func _portal_plain_shapes(at: Vector2, petrified: bool) -> Array[PackedVector2Array]:
	var right_tip := Vector2(17, -42) if petrified else Vector2(21, -50)
	return [_box(at + Vector2(-20, -2), Vector2(40, 7)), _box(at + Vector2(-16, -30), Vector2(32, 29)),
		_oval(at + Vector2(0, -30), Vector2(16, 16)),
		PackedVector2Array([at + Vector2(-13, -36), at + Vector2(-21, -50), at + Vector2(-9, -40)]),
		PackedVector2Array([at + Vector2(13, -36), at + right_tip, at + Vector2(9, -40)])]


static func _box(corner: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([corner, corner + Vector2(size.x, 0), corner + size, corner + Vector2(0, size.y)])


static func _oval(middle: Vector2, radii: Vector2, steps := 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var angle := TAU * i / steps
		out.append(middle + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return out


## A creature plain, standing at [param at] on [param canvas]: a disc of
## its slot's colour [param color] (1 black … 5 white; [constant
## WorldArt.AMULET_INKS]), outlined.
static func draw_creature_plain(canvas: CanvasItem, at: Vector2, color: int) -> void:
	var ink: Color = WorldArt.AMULET_INKS[clampi(color, 1, 5) - 1]
	canvas.draw_circle(at + Vector2(0, -12), 11, Color(0, 0, 0, 0.6))
	canvas.draw_circle(at + Vector2(0, -12), 9, ink)
	canvas.draw_arc(at + Vector2(0, -12), 10, 0, TAU, 20, Color8(232, 190, 110), 1.5)


## The hero plain, standing at [param at] on [param canvas].
static func draw_hero_plain(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_circle(at + Vector2(0, -14), 9, Color8(150, 22, 18))
	canvas.draw_rect(Rect2(at + Vector2(-5, -8), Vector2(10, 8)), Color8(150, 22, 18))
