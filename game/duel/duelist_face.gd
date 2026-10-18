class_name DuelistFace
extends RefCounted
## THE DUELIST'S FACE — the other side of the life register, and the words
## the original used to turn it over.
##
## `Duel.hlp` gives it a topic of its own, **Duelist's Face**, and that
## topic is the whole specification:
##
##   *"When the Life Register flips around to show a face, one of two
##   things is the case. Either you have chosen the `Flip to Face` option
##   from the mini-menu, or there is a spell or effect being cast that
##   could target a player — you or your opponent. In the first case, you
##   can use the same mini-menu option to flip the face back to the
##   register. What you do in the second case depends on your intentions.
##   If you wish to choose yourself or an opponent as a target, simply
##   click on the appropriate exposed face. If not, just select your
##   target (or targets) as normal. When faces are no longer needed, they
##   flip back to show the Life Registers automatically."*
##
## The printed manual says the same thing twice, from the two ends:
## p.119 *"You can right-click on either life register and select Flip to
## Face if you'd rather see your opponent's face"*, and p.121 *"If your
## opponent is a valid target, her Life Register flips over. To target
## your opponent, click on the face instead of a card."*
##
## So: ONE panel, TWO faces, THREE ways to turn it — the mini-menu, the
## automatic flip while a player can be targeted, and the automatic flip
## back when the targeting is over. All three are built
## (`DuelScreen._face_shown`, `_on_life_input`, `_on_life_menu_chosen`).
##
## THE ART. Both grounds are 120x88 files the original ships one of per
## colour, imported by `tools/import_original.py` (whose MANIFEST comment
## records how the pair was told apart, and why
## `Program/DuelArt/Face_*.pic` is a Manalink placeholder rather than the
## 1997 art): `life_panel_<colour>` is the register's wallpaper, which the
## life total is written across, and `duelist_face_<colour>` is the
## colour's own duelist, portrait-cropped to the register.
##
## Both accessors return null without the 1997 skin, exactly as every
## other [GameSkin] accessor does; the caller keeps its flat fallback and
## the flip simply has nothing to show, which is why
## [method DuelScreen._can_flip] greys the menu entry instead of offering
## it.

## The four entries of `@MENU_LIFE` (`Program/Text.res:1873`), the
## mini-menu a right-click on the LIFEPOINTS side opens. `%s` is the other
## duelist's name. `Help...` opens the life register's mini help
## ([DuelMiniHelp], since 2026-10-13).
const MENU_LIFE: Array[String] = [
	"Target %s", "Target yourself", "Flip over to face", "Help...",
]

## `@MENU_FACE` (`Program/Text.res:1844`) — the same menu with the FACE
## showing. Only the third entry differs, which is the clearest statement
## in the string tables that these are two faces of one panel.
const MENU_FACE: Array[String] = [
	"Target %s", "Target yourself", "Flip back to lifepoints", "Help...",
]

## Index of the entry that turns the panel over, in both tables above.
const FLIP := 2

## THE PICTURE KEEPS ITS SHAPE (2026-10-18). Both grounds are 120x88, the
## 1997 register's own shape, and ours is not: the sidebar gives the life
## button about 184x76, so a picture stretched to fill it was drawn half as
## wide again and squeezed — the skull, the crystal ball and the green
## frame nearly twice as wide as drawn. The owner's playtest photo: *"Check
## the art behind life ... It is stretched! How could we fix this
## elegantly?"* — and of the three ways shown him, *"Build B, superb."*
## B scaled the picture evenly to cover the panel, and the panel then
## showed only the middle 56% of its height: *"the images are too cropped
## now!"* So the picture MEETS THE PANEL HALFWAY: the part shown
## ([method shown_region]) has the proportions halfway between the
## picture's and the panel's (their geometric mean), and is drawn over the
## whole panel. The mismatch is split evenly — about a third wider and an
## eighth off the top and the bottom on the 184x76 panel, 75% of the
## height shown — of the three middle ways shown him, *"Yes!"*. The same
## rule serves both sides, any skin and any panel shape, and a panel of
## the picture's own shape shows all of it. The shown part sits inside the
## one-pixel frame line all ten 1997 pictures carry (measured: one flat
## colour all round), so no side keeps a line the others have lost.
const FRAME_LINE := 1


## The part of a picture of [param picture] size that a panel of
## [param panel] size shows, drawn over the whole panel: the largest
## centred rectangle inside the picture's frame line whose proportions are
## halfway between the picture's and the panel's (THE PICTURE KEEPS ITS
## SHAPE). The whole inside for a panel with no size yet.
static func shown_region(picture: Vector2, panel: Vector2) -> Rect2:
	var line := Vector2(FRAME_LINE, FRAME_LINE)
	var inside := Rect2(line, picture - line * 2)
	if inside.size.x <= 0.0 or inside.size.y <= 0.0:
		return Rect2(Vector2.ZERO, picture)
	if panel.x <= 0.0 or panel.y <= 0.0:
		return inside
	var aspect := sqrt(panel.x / panel.y * inside.size.x / inside.size.y)
	var shown := inside.size
	if shown.x / shown.y > aspect:
		shown.x = shown.y * aspect
	else:
		shown.y = shown.x / aspect
	return Rect2(inside.position + (inside.size - shown) / 2.0, shown)


## The colour's duelist, or null without the 1997 skin.
static func portrait(color_key: String) -> Texture2D:
	return GameSkin.texture("duelist_face_" + color_key)


## The register's own ground — the side the life total is written on.
static func register(color_key: String) -> Texture2D:
	return GameSkin.texture("life_panel_" + color_key)


## The mini-menu for a register currently showing [param face_up], with
## `%s` already filled in with [param other_name]. Returns the four labels
## in the original's order; the caller decides which are live.
static func menu_labels(face_up: bool, other_name: String) -> Array[String]:
	var out: Array[String] = []
	for entry in (MENU_FACE if face_up else MENU_LIFE):
		out.append(entry % other_name if entry.contains("%s") else entry)
	return out
