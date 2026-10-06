extends RefCounted
## Stronghold (_choices, Pack 9). Choices on entry or resolution: colours, players, card names, hidden-zone picks.
##
## - Hermit Druid reveals from the top until a BASIC land card (CR 701.16a,
##   printed supertype — cards in a library have only their printed
##   characteristics); with none, every card it revealed — the whole
##   library — goes to the graveyard. It stops at an empty library.
## - Mulch reveals the top four (fewer if the library is shorter): lands
##   to the hand, the rest to the graveyard.
## - Ransack: the caster looks (only the caster sees them) at the top five
##   of the target player's library and says, card by card, which go to
##   the bottom ("any number"); those go down in the order the caster
##   picks (each one under the last), the rest back on top in the order
##   picked (the first picked ends on top). The hints are public-value
##   only (mir/_spells.gd P.best_first): the caster sends their own worst
##   and an opponent's best cards down.
## tests/cards/test_pack_9_B10_choices.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_spells.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Hermit Druid":
			c.activated(ActivatedAbility.new("{G}", true,
				[F.Action.new(_hermit, "reveal cards from the top of your library until you reveal a basic land card; put it into your hand and the rest into your graveyard", null, true) \
					.with_ai_role(&"dig_for_basic_land")],
				"{G}, {T}: Reveal cards from the top of your library until you reveal a basic land card. Put that card into your hand and all other cards revealed this way into your graveyard."))
		"Mulch":
			c.spell(F.Action.new(_mulch, "reveal the top four cards of your library; put the lands into your hand and the rest into your graveyard", null, true) \
				.with_ai_role(&"dig_lands", {"count": 4}))
		"Ransack":
			c.spell(F.Action.new(_ransack,
				"look at the top five cards of target player's library; put any number of them on the bottom in any order and the rest on top in any order",
				TargetSpec.player()).with_ai_role(&"library_order", {"count": 5}))
		_: return false
	return true


static func _names(cards: Array[CardInstance]) -> Array:
	var out: Array = []
	for card in cards: out.append(card.data.card_name)
	return out

static func _basic_land_card(card: CardInstance) -> bool:
	return card.data.is_land() and (card.data.supertypes & Mtg.Supertype.BASIC) != 0


# --------------------------------------------------------------- Hermit Druid --

static func _hermit(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var library := g.players[pid].library
	var revealed: Array[CardInstance] = []
	var found: CardInstance = null
	for n in range(library.size() - 1, -1, -1):
		var card: CardInstance = library[n]
		revealed.append(card)
		if _basic_land_card(card):
			found = card
			break
	if revealed.is_empty():
		g.log_line("Hermit Druid: %s's library is empty" % g.players[pid].player_name)
		return
	var names := _names(revealed)
	g.reveal_information(-1, "Hermit Druid reveals", names)
	g.log_line("%s reveals %s (Hermit Druid)" % [g.players[pid].player_name, ", ".join(PackedStringArray(names))])
	if found != null: g.library_card_to_hand(found)
	for card in revealed:
		if card != found: g.put_library_card_into_graveyard(card)


# ---------------------------------------------------------------------- Mulch --

static func _mulch(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var library := g.players[pid].library
	var revealed: Array[CardInstance] = []
	for k in mini(4, library.size()):
		revealed.append(library[library.size() - 1 - k])
	if revealed.is_empty(): return
	var names := _names(revealed)
	g.reveal_information(-1, "Mulch reveals", names)
	g.log_line("%s reveals %s (Mulch)" % [g.players[pid].player_name, ", ".join(PackedStringArray(names))])
	for card in revealed:
		if card.data.is_land(): g.library_card_to_hand(card)
	for card in revealed:
		if not card.data.is_land(): g.put_library_card_into_graveyard(card)


# -------------------------------------------------------------------- Ransack --

static func _ransack(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var who := t.player_id
	var library := g.players[who].library
	var seen: Array[CardInstance] = []
	for k in mini(5, library.size()):
		seen.append(library[library.size() - 1 - k])
	if seen.is_empty(): return
	g.reveal_information(pid, "Ransack — the top %d card(s) of %s's library, top first" % [
		seen.size(), g.players[who].player_name], _names(seen))
	var mine := who == pid
	# "Any number of them": one yes/no per card, top first.
	var bottom: Array[CardInstance] = []
	var keep: Array[CardInstance] = []
	for card in seen:
		if g.agents[pid].choose_yes_no(g, pid, "Ransack: put %s on the bottom of %s's library?" % [
				card.data.card_name, g.players[who].player_name], _send_down(g, card, mine)):
			bottom.append(card)
		else:
			keep.append(card)
	# The bottom group in the caster's order: each pick goes under the last.
	while not bottom.is_empty():
		var ranked: Array[CardInstance] = M.P.best_first(g, bottom)
		var next: CardInstance = ranked[0] if ranked.size() == 1 else g.agents[pid].choose_card_in_order(g, pid, ranked,
			"Ransack: choose the next card to put on the bottom")
		if next == null or not bottom.has(next): next = ranked[0]
		g.put_on_bottom_of_library(next)
		bottom.erase(next)
	# The rest on top: the first picked ends on top (reorder_top_of_library).
	var top: Array[CardInstance] = []
	while keep.size() > 1:
		var ranked: Array[CardInstance] = M.P.best_first(g, keep)
		if not mine: ranked.reverse()
		var next := g.agents[pid].choose_card_in_order(g, pid, ranked,
			"Ransack: choose the next card from the top")
		if next == null or not ranked.has(next): next = ranked[0]
		top.append(next)
		keep.erase(next)
	top.append_array(keep)
	if not top.is_empty(): g.reorder_top_of_library(who, top)

## Hint for one card: on one's own library, send down a card worth less
## than an average spell; on an opponent's, one worth at least that much.
static func _send_down(g: MtgGame, card: CardInstance, mine: bool) -> bool:
	var value: float = M.P.card_value(g, card)
	return value < 3.0 if mine else value >= 3.0
