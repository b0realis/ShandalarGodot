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
## duelist's name.
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
