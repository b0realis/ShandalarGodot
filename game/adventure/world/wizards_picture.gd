class_name WizardsPicture
extends Control
## THE WIZARDS' HALL — 1997's wizards' window (F6; `Statwin.dll`, 1 May
## 1997, its 1.3 source `statwin/src/main.cpp`, cited "SW" below) drawn on
## the hero pane's Wizards tab ([HeroStats]) from Statwin's own stills
## (the owner, 2026-10-27: *"With 1997 stills"* — no movies). One 640 × 480
## picture with no words, scaled to the room it is given, composed afresh
## from the record ([method WorldStatus.wizard_rows]) each time it draws:
##  1. THE GROUND, the throne hall (`Wizbg.bmp`, `wizards_ground`);
##  2. EACH STANDING WIZARD's figure, left to right Blue, Green, White, Red,
##     Black (`*-Sprt.bmp`, green the clear colour; [constant FIGURES]);
##  3. HIS STAFF, a column of lights: the lit picture (`S-*wizy.bmp`) whole,
##     and over the bottom of its band the drained one (`S-*wizr.bmp`) —
##     `band − staff·band/30` rows of it (`draw_progress_total`, SW 2889;
##     [constant STAFFS], [constant STAFF_BANDS]);
##  4. HIS GEMS, one piece of his cluster per town he taps, at most five
##     (`*-Mana.bmp`, `draw_town_count`, SW 2845; [constant GEMS],
##     [constant GEM_PIECES]);
##  5. THE SKULLS at the foot of every colour the hero has beaten creatures
##     of: that colour's column of the step's picture (`<n>skulls.bmp`, black
##     clear, `refresh_duel_wins`, SW 2970; [constant SKULL_COLUMNS]).
## The layers go down in 1997's order, each over all the wizards before the
## next (`apply_progress`, SW 626: figures, staffs, then the skulls; the
## gems as every later refresh drew them, over the figures and staffs — the
## skulls, far below, never meet them).
##
## A BEATEN WIZARD is not drawn: 1997 wiped his figure, staff and gems with
## patches of the ground (`draw_missing_color_progress`, SW 2760) — the hall
## shows where he stood. His skulls stay, his true wins ([WorldStatus]'s
## slip (a)). Picked by a beaten castle's click ([member room]), his OWN
## ROOM is shown instead, whole (`Room-*.bmp`, `show_color_missing_message`,
## SW 2072: the wizard alone, his staff all red — 1997 played his colour's
## movie over it, which is not imported); a click on it gives the hall back
## ([signal room_closed]).
##
## [Ours] A HIGHLIGHTED wizard ([member highlight]) is ringed in gold where
## he stands; the pointer resting on a wizard's place names him ([method
## wizard_at]). Statwin highlighted only to play its movies (modes 1 and 2,
## never shown here: the owner's ruling — the window never opens by
## itself).
##
## Every place is 1997's, in 640 × 480 units; a 2x skin's pictures are worn
## at those sizes ([GameSkin]). Without `wizards_ground` nothing is drawn
## ([method available]) and the tab is words alone.

## A click on the beaten wizard's room: the hall is wanted again.
signal room_closed

const SCREEN := Vector2(640, 480)
## Each wizard's figure: where it stands (SW `g_color_sprite_assets`; the
## picture's top left, the rows and columns of it drawn).
const FIGURES := {"white": Rect2(272, 60, 104, 300), "red": Rect2(376, 48, 136, 300),
	"blue": Rect2(0, 48, 160, 300), "green": Rect2(160, 56, 104, 300), "black": Rect2(516, 48, 124, 300)}
## Each wizard's staff (SW `g_progress_yellow_assets`, `g_progress_red_assets`).
const STAFFS := {"white": Rect2(330, 86, 60, 252), "red": Rect2(468, 80, 60, 260),
	"blue": Rect2(0, 38, 80, 300), "green": Rect2(140, 38, 60, 300), "black": Rect2(580, 12, 60, 324)}
## Each staff's lights, `[top, height]` within its picture
## (SW `g_progress_total_offsets`).
const STAFF_BANDS := {"white": [53, 181], "red": [45, 186], "blue": [70, 192], "green": [85, 190],
	"black": [20, 290]}
## Each wizard's gem cluster, its top left (SW `g_mana_base_assets`, 48 × 48).
const GEMS := {"white": Vector2(294, 30), "red": Vector2(428, 24), "blue": Vector2(58, 12),
	"green": Vector2(184, 24), "black": Vector2(544, 12)}
## The five pieces of each cluster, lit one a town in this order
## (SW `g_town_mana_source_rects`, in the cluster's own picture).
const GEM_PIECES := {
	"white": [Rect2(31, 13, 16, 15), Rect2(3, 13, 18, 15), Rect2(18, 4, 15, 16), Rect2(9, 28, 17, 15),
		Rect2(26, 27, 18, 17)],
	"red": [Rect2(32, 10, 13, 14), Rect2(4, 13, 14, 14), Rect2(17, 13, 14, 14), Rect2(8, 27, 15, 15),
		Rect2(24, 25, 17, 17)],
	"blue": [Rect2(30, 18, 18, 15), Rect2(0, 8, 19, 18), Rect2(19, 1, 15, 18), Rect2(6, 28, 19, 17),
		Rect2(27, 31, 17, 16)],
	"green": [Rect2(32, 15, 14, 16), Rect2(4, 12, 14, 16), Rect2(8, 5, 14, 13), Rect2(8, 28, 16, 14),
		Rect2(24, 28, 16, 15)],
	"black": [Rect2(29, 8, 19, 19), Rect2(0, 14, 17, 20), Rect2(12, 0, 19, 21), Rect2(0, 33, 26, 14),
		Rect2(23, 29, 20, 16)]}
## Each colour's column of a skull picture, the same place on the hall
## (SW `g_duel_win_skull_rects`: the picture is 640 × 240, drawn at y 240).
const SKULL_COLUMNS := {"white": Rect2(260, 240, 120, 240), "red": Rect2(380, 240, 140, 240),
	"blue": Rect2(0, 240, 140, 240), "green": Rect2(140, 240, 120, 240), "black": Rect2(520, 240, 120, 240)}
## 1997's order, White, Red, Blue, Green, Black (`MapWizardColorToDisplayIndex`,
## adventure_new_game.c 553): the order every layer is drawn in.
const ORDER: Array[String] = ["white", "red", "blue", "green", "black"]
## The ring round a highlighted wizard [ours].
const RING := Color8(255, 220, 120)
## The keyed pictures with their edges bled ([method picture]), by the
## skin texture's instance.
static var _bled := {}


## The record drawn ([method WorldStatus.wizard_rows]).
var rows: Array[Dictionary] = []:
	set(value):
		rows = value
		queue_redraw()
## The wizard ringed, by colour word; "" for none.
var highlight := "":
	set(value):
		highlight = value
		queue_redraw()
## The beaten wizard whose room is shown instead of the hall; "" for the hall.
var room := "":
	set(value):
		room = value
		queue_redraw()


func _init() -> void:
	name = "WizardsPicture"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gui_input.connect(_clicked)


## Whether the skin holds Statwin's hall to draw.
static func available() -> bool:
	return GameSkin.texture("wizards_ground") != null


## Whether the skin holds wizard [param color]'s room.
static func has_room(color: String) -> bool:
	return GameSkin.texture("wizards_room_" + color) != null


## The drained part of wizard [param color]'s staff with [param staff] lights
## lit: `[where on the hall, where in the drained picture]`, empty when it is
## all lit. `filled = staff·band/30` rows of the band stay lit; the rest of
## the band, its bottom, is drained (SW 2889).
static func drained(color: String, staff: int) -> Array[Rect2]:
	var band: Array = STAFF_BANDS[color]
	var filled := clampi(staff, 0, WorldStatus.STAFF) * int(band[1]) / WorldStatus.STAFF
	var shown := int(band[1]) - filled
	if shown <= 0:
		return [] as Array[Rect2]
	var at: Rect2 = STAFFS[color]
	var source := Rect2(0, int(band[0]) + filled, at.size.x, shown)
	return [Rect2(at.position + source.position, source.size), source] as Array[Rect2]


## The pieces of wizard [param color]'s cluster lit for [param gems] towns:
## `[[where on the hall, where in the cluster's picture]]`.
static func gem_pieces(color: String, gems: int) -> Array[Array]:
	var out: Array[Array] = []
	var at: Vector2 = GEMS[color]
	for i in clampi(gems, 0, 5):
		var piece: Rect2 = GEM_PIECES[color][i]
		out.append([Rect2(at + piece.position, piece.size), piece])
	return out


## The scale and offset the hall is drawn at in this control: the whole
## picture, its shape kept, centred.
func stage() -> Transform2D:
	var k := minf(size.x / SCREEN.x, size.y / SCREEN.y)
	if k <= 0.0:
		k = 1.0
	var left := (size - SCREEN * k) / 2.0
	return Transform2D(0.0, Vector2(k, k), 0.0, left)


## The wizard whose place (his figure's rect) is under [param at], in this
## control's own pixels; "" for none.
func wizard_at(at: Vector2) -> String:
	var point := stage().affine_inverse() * at
	for color in ORDER:
		if (FIGURES[color] as Rect2).has_point(point):
			return color
	return ""


func _row(color: String) -> Dictionary:
	for row in rows:
		if String(row.get("color", "")) == color:
			return row
	return {}


func _draw() -> void:
	draw_set_transform_matrix(stage())
	if room != "":
		var picture := GameSkin.texture("wizards_room_" + room)
		if picture != null:
			draw_texture_rect(picture, Rect2(Vector2.ZERO, SCREEN), false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
	var ground := GameSkin.texture("wizards_ground")
	if ground == null:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	draw_texture_rect(ground, Rect2(Vector2.ZERO, SCREEN), false)
	# The figures, then the staffs, then the gems — the standing wizards'.
	for color in ORDER:
		if _standing(color):
			_whole("wizards_figure_" + color, FIGURES[color])
	for color in ORDER:
		if _standing(color):
			_whole("wizards_staff_lit_" + color, STAFFS[color])
			var drain := picture("wizards_staff_drained_" + color)
			var part := drained(color, int(_row(color).get("staff", WorldStatus.STAFF)))
			if drain != null and not part.is_empty():
				draw_texture_rect_region(drain, part[0], part[1])
	for color in ORDER:
		if _standing(color):
			var cluster := picture("wizards_gems_" + color)
			if cluster != null:
				for piece in gem_pieces(color, int(_row(color).get("gems", 0))):
					draw_texture_rect_region(cluster, piece[0], piece[1])
	# The skulls, every colour's, a beaten wizard's too.
	for color in ORDER:
		var step := int(_row(color).get("skulls", 0))
		var skulls := picture("wizards_skulls_%d" % step) if step > 0 else null
		if skulls != null:
			var column: Rect2 = SKULL_COLUMNS[color]
			draw_texture_rect_region(skulls, column, Rect2(column.position.x, 0, column.size.x, column.size.y))
	if highlight != "" and FIGURES.has(highlight):
		var ring: Rect2 = (FIGURES[highlight] as Rect2).grow(-2.0)
		draw_rect(ring, Color(RING, 0.12))
		draw_rect(ring, RING, false, 3.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Whether wizard [param color] stands in the hall: in the record, unbeaten.
func _standing(color: String) -> bool:
	var row := _row(color)
	return not row.is_empty() and not bool(row.get("beaten", false))


## The picture [param key] drawn whole at [param at] (its top-left rows and
## columns, as Statwin's blits took them).
func _whole(key: String, at: Rect2) -> void:
	var shown := picture(key)
	if shown != null:
		draw_texture_rect_region(shown, at, Rect2(Vector2.ZERO, at.size))


## The skin's keyed picture [param key] once more, its clear pixels given
## their opaque neighbours' colour ([method Image.fix_alpha_edges]) and kept:
## the hall is drawn scaled and filtered, and a clear pixel keeps its key's
## colour (the figures' green, the staffs' and skulls' black), which would
## otherwise bleed round every figure as a fringe. Null without it.
static func picture(key: String) -> Texture2D:
	var source := GameSkin.texture(key)
	if source == null:
		return null
	var memo := source.get_instance_id()
	if not _bled.has(memo):
		var image := source.get_image()
		if image == null:
			_bled[memo] = source
		else:
			keep_bled(source, bleed(image))
	return _bled[memo]


## [param image] (a keyed picture's pixels) with its clear pixels given
## their opaque neighbours' colour — changed and returned. It touches
## nothing shared: a worker thread may bleed a picture it decoded
## ([PaneWarmer]).
static func bleed(image: Image) -> Image:
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.fix_alpha_edges()
	return image


## [param bled] ([method bleed]) kept as [param source]'s bled picture, at
## its drawn size — unless one is kept already. Main thread.
static func keep_bled(source: Texture2D, bled: Image) -> void:
	var memo := source.get_instance_id()
	if not _bled.has(memo):
		_bled[memo] = GameSkin.texture_of(bled, Vector2i(source.get_size()))


## Whether [param source]'s bled picture is kept.
static func bled_kept(source: Texture2D) -> bool:
	return source != null and _bled.has(source.get_instance_id())


## THE KEYED PICTURES THE HALL BLEEDS for the record [param shown] ([method
## WorldStatus.wizard_rows]) — what [method _draw] asks [method picture]
## for: each standing wizard's figure, staffs and gems, every colour's
## skulls' step — for [PaneWarmer] to make before the Wizards tab opens.
static func pictures_for(shown: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for color in ORDER:
		var row := {}
		for one in shown:
			if String(one.get("color", "")) == color:
				row = one
		if not row.is_empty() and not bool(row.get("beaten", false)):
			for part in ["wizards_figure_", "wizards_staff_lit_", "wizards_staff_drained_", "wizards_gems_"]:
				out.append(part + color)
	for row in shown:
		var step := int(row.get("skulls", 0))
		if step > 0 and not out.has("wizards_skulls_%d" % step):
			out.append("wizards_skulls_%d" % step)
	return out


func _get_tooltip(at: Vector2) -> String:
	if room != "":
		return "Click for the hall"
	var color := wizard_at(at)
	var row := _row(color)
	return String(row.get("name", "")) if not row.is_empty() else ""


## A click on the room: the hall again (the control takes the mouse, so
## the click goes no further).
func _clicked(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and room != "":
		room = ""
		room_closed.emit()
