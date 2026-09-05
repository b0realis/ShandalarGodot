extends CardScript
## Land Tax — {W} — Enchantment (4ed, rare; first printed in Legends)
## Oracle: At the beginning of your upkeep, if an opponent controls more
##         lands than you, you may search your library for up to three
##         basic land cards, reveal them, put them into your hand, then
##         shuffle.
##
## Implementation: an upkeep trigger gated on the land-count condition,
## resolving as up to three successive basic-land library searches through
## the controller's DecisionAgent, and so is the COUNT: the original ran
## the same loop, three prompts deep (`@LANDTAX`, Program/prompts.txt —
## *"Pick up to 3 basic lands."* / *"...up to 2 more..."* / *"...up to 1
## more..."*). The hint is three, which is virtually always right. The
## library is shuffled ONCE, after the last search (CR 701.19a: "then
## shuffle" follows the whole search) — the searches themselves leave it
## unshuffled (MtgGame.search_library's shuffle_after) — and not at all
## when the "may" is declined.


func build() -> CardData:
	return CardData.new("Land Tax", "{W}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _collect_taxes,
			"At the beginning of your upkeep, if an opponent controls more lands than you, search your library for up to three basic lands.",
			_behind_on_lands)) \
		.oracle("At the beginning of your upkeep, if an opponent controls more lands than you, you may search your library for up to three basic land cards, reveal them, put them into your hand, then shuffle.")


static func _count_lands(game: MtgGame, pid: int) -> int:
	var lands := 0
	for inst in game.players[pid].battlefield:
		if inst.is_land():
			lands += 1
	return lands


static func _behind_on_lands(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var pid: int = source.controller_id
	return event.data["player"] == pid \
		and _count_lands(game, game.opponent_of(pid)) > _count_lands(game, pid)


static func _collect_taxes(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# Intervening "if" (CR 603.4): the land-count condition is checked
	# AGAIN on resolution — respond by killing the opponent's extra land
	# and the search never happens.
	if not _behind_on_lands(game, source, event):
		game.log_line("Land Tax: the land counts have evened out — no search")
		return
	# "SEARCH YOUR LIBRARY FOR UP TO THREE basic land cards" — a real count,
	# and the original asked for it: `@LANDTAX` (Program/prompts.txt) runs
	# *"Pick up to 3 basic lands."* / *"Pick up to 2 more basic lands."* /
	# *"Pick up to 1 more basic land."*, three prompts, exactly this loop.
	# The hint is three, which is virtually always right.
	var pid := source.controller_id
	var want := game.agents[pid].choose_number(game, pid, 0, 3,
		"Pick up to 3 basic lands.", 3)
	if want <= 0:
		return   # "you may": declined, and nothing to shuffle after
	for i in want:
		game.search_library(pid, _is_basic_land,
			_PROMPTS[mini(i, _PROMPTS.size() - 1)], false, false)
	game.shuffle_library(pid)   # once, after the last search


## `@LANDTAX`'s own three lines, one per search.
const _PROMPTS := [
	"Pick up to 3 basic lands.",
	"Pick up to 2 more basic lands.",
	"Pick up to 1 more basic land.",
]


static func _is_basic_land(inst: CardInstance) -> bool:
	return inst.is_land() and (inst.data.supertypes & Mtg.Supertype.BASIC)