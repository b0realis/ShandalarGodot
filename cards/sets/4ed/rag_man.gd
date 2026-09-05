extends CardScript
## Rag Man — {2}{B}{B} — Creature — Human Minion — 2/1 — (4ed, rare)
## Oracle: {B}{B}{B}, {T}: Target opponent reveals their hand and discards
##         a creature card at random. Activate only during your turn.
##
## Implementation: a card-local effect that filters the target's hand to
## creature cards and discards one chosen with game.rng — random over the
## CREATURES, exactly as printed (the reveal is what makes the random
## choice fair). Restricted to its controller's turn.


func build() -> CardData:
	return CardData.new("Rag Man", "{2}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["human", "minion"]) \
		.activated(ActivatedAbility.new(
			"{B}{B}{B}", true, [RagEffect.new()],
			"{B}{B}{B}, {T}: Target opponent reveals their hand and discards a "
			+ "creature card at random. Activate only during your turn.") \
			.your_turn_only()) \
		.oracle("{B}{B}{B}, {T}: Target opponent reveals their hand and discards a "
			+ "creature card at random. Activate only during your turn.")


class RagEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pid := target.player_id
		var creatures: Array[CardInstance] = []
		for inst in game.players[pid].hand:
			if inst.data.is_creature():
				creatures.append(inst)
		if creatures.is_empty():
			game.log_line("Rag Man finds no creature card")
			return
		var pick: CardInstance = creatures[game.rng.randi() % creatures.size()]
		game.discard_cards(pid, [pick])

	func describe() -> String:
		return "target opponent discards a creature card at random"
