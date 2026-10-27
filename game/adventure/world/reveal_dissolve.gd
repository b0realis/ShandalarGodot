class_name RevealDissolve
extends TileReveal
## THE WORLD SHOWN BLOCK BY BLOCK — 1.3's `BlitRectByRandomTileOrder`
## (opt57_shandalar_ui_fx.c 223): after a new adventure begins, Leap of
## Fate or Sword of Resistance, the new view replaced the old in small
## squares in a random order, over a moment. Here the old view (a picture
## taken before the move, or black for a new adventure) is drawn in
## [constant BLOCK]-pixel squares that vanish at random over
## [constant SECONDS]; then the overlay is gone. It takes no input.
##
## One of the transitions ([TileReveal], which draws it): a click or a key
## ends it at once, and with the Options' "Transitions" off — or headless —
## the new view is simply there (the overlay made, and gone at once, so the
## world screen may still place it).

const BLOCK := 16.0
const SECONDS := 0.6


## Cover [param host] with the old view [param picture] (null for black)
## and dissolve it; the overlay frees itself when done.
static func over(host: Control, picture: Texture2D) -> RevealDissolve:
	var cover := RevealDissolve.new()
	cover.name = "RevealDissolve"
	cover.before = picture
	cover.ground = Color.BLACK
	cover.seconds = SECONDS
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return cover


## The screen as it now stands, for [method over]; null when it cannot be
## read (no renderer). The picture is in the window's pixels, which are the
## canvas's units only in a 1280 × 800 window ([method source_rect] maps
## them).
static func picture_of(host: Control) -> Texture2D:
	return TileReveal.picture_of(host)


func _ready() -> void:
	if not TileReveal.wanted():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		finish()
		return
	var area := get_viewport_rect().size
	grid = Vector2i(maxi(int(ceil(area.x / BLOCK)), 1), maxi(int(ceil(area.y / BLOCK)), 1))
	order = TileReveal.Order.RANDOM
	super._ready()


## The part of the old picture under canvas square [param square]: the
## picture is the window's pixels (1920 × 1080, say) while the canvas the
## squares are laid on is the stretched base size (1422 × 800 there), so
## the square is scaled by the one over the other — else the old view
## would show zoomed and shifted.
func source_rect(square: Rect2) -> Rect2:
	var canvas := get_viewport_rect().size
	if before == null or canvas.x <= 0.0 or canvas.y <= 0.0:
		return square
	var pixels := before.get_size() / canvas
	return Rect2(square.position * pixels, square.size * pixels)


func _source_now() -> Rect2:
	return source_rect(Rect2(Vector2.ZERO, size))
