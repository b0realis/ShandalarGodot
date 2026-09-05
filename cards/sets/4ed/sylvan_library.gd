extends CardScript
## Sylvan Library — {1}{G} — Enchantment — (4ed, rare)
## Oracle: At the beginning of your draw step, you may draw two additional
##         cards. If you do, choose two cards in your hand drawn this turn.
##         For each of those cards, pay 4 life or put the card on top of
##         your library.
##
## Implementation: NOT a draw replacement — the printed card is a plain
## DRAW_STEP trigger, and the ROADMAP filed it with the replacement cluster
## by mistake. What it did need is the engine's record of WHICH cards were
## drawn this turn (MtgPlayer.drawn_this_turn), because "cards in your hand
## drawn this turn" is a set of cards, not a count.
##
## Cards drawn this turn that have since left the hand are not offered; if
## fewer than two are left, as many as there are is what the card gets
## (CR 608.2, "as much as possible").
##
## The three prompts are the original's own — `@SYLVAN_LIBRARY`,
## `Program/prompts.txt:855`: `Pay 4 life.` / `Put back on library.` /
## `Select card drawn this turn to discard.`
##
## The heuristic pays the 4 life only while that leaves the seat above 10,
## which is the cautious half of the famous Sylvan Library decision; a human
## seat is asked properly, since the whole thing happens inside a trigger's
## resolution and the pre-flight reaches it.


func build() -> CardData:
	return CardData.new("Sylvan Library", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DRAW_STEP, _dig,
			"At the beginning of your draw step, you may draw two additional cards.",
			_your_draw_step)) \
		.oracle("At the beginning of your draw step, you may draw two additional "
			+ "cards. If you do, choose two cards in your hand drawn this turn. For "
			+ "each of those cards, pay 4 life or put the card on top of your library.")


static func _your_draw_step(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _dig(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	# CR 603.6 / 608.2h: the trigger resolves even if the enchantment has
	# gone — nothing in the effect refers back to it, so Disenchanting the
	# Library in response to its own trigger does NOT refund the two cards.
	if not game.agents[pid].choose_yes_no(game, pid,
			"Draw two additional cards with Sylvan Library?", true):
		return
	game.draw_cards(pid, 2)
	var settled: Array[CardInstance] = []
	for _i in 2:
		var drawn: Array[CardInstance] = []
		for inst in game.players[pid].drawn_this_turn:
			if inst.zone == Mtg.Zone.HAND and not settled.has(inst) \
					and not drawn.has(inst):
				drawn.append(inst)
		if drawn.is_empty():
			return
		drawn.sort_custom(_cheapest_first)
		# `@SYLVAN_LIBRARY` entry 3.
		var pick := game.agents[pid].choose_card(game, pid, drawn,
			"Select card drawn this turn to discard.")
		if pick == null or not drawn.has(pick):
			pick = drawn[0]
		settled.append(pick)
		# `@SYLVAN_LIBRARY` entries 1 and 2 — the whole card in one question.
		var affordable := game.players[pid].life > 14
		if game.agents[pid].choose_yes_no(game, pid, "Pay 4 life.", affordable):
			game.adjust_life(pid, -4)
		else:
			game.put_from_hand_on_top_of_library(pick)


## The default agent takes candidates[0], so the card a player would put
## back — the cheapest — is offered first.
static func _cheapest_first(a: CardInstance, b: CardInstance) -> bool:
	var av := a.data.cost.mana_value()
	var bv := b.data.cost.mana_value()
	if av != bv:
		return av < bv
	return a.id < b.id
