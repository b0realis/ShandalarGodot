extends CardScript
## Martyr's Cry — {W}{W} — Sorcery — (drk, rare)
## Oracle: Exile all white creatures. For each creature exiled this way,
##         its controller draws a card.
##
## Implementation: symmetric, and it reads LIVE colours — a creature a
## Purelace painted white goes with the rest, and one a Lace painted away
## from white is spared.


func build() -> CardData:
	return CardData.new("Martyr's Cry", "{W}{W}", Mtg.CardType.SORCERY) \
		.spell(MartyrsCryEffect.new()) \
		.oracle("Exile all white creatures. For each creature exiled this way, its controller draws a card.")


class MartyrsCryEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var martyrs: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if inst.is_creature() and inst.has_color(Mtg.ManaColor.W):
				martyrs.append(inst)
		# ONE RESOLUTION, ONE BRACKET (CR 704.3, 2026-09-10). A MASS EXILE
		# needs no death replacement to be visible either:
		# MtgGame.exile_permanent ends with check_state_based_actions(), so
		# unbracketed an Aura orphaned by the first martyr was swept before
		# the second one left. The draws are inside it too — they are the
		# same resolution, and a draw from an empty library is judged when
		# the whole thing has landed. Nothing may return between the two
		# calls: a deferral left open freezes state-based actions for the
		# rest of the game.
		game.begin_simultaneous()
		var owed := [0, 0]
		for inst in martyrs:
			if inst.zone != Mtg.Zone.BATTLEFIELD:
				continue
			owed[inst.controller_id] += 1
			game.exile_permanent(inst)
		for pid in [0, 1]:
			if owed[pid] > 0:
				game.draw_cards(pid, owed[pid])
		game.end_simultaneous()

	func describe() -> String:
		return "exiles all white creatures; their controllers draw for each"
