extends CardScript
## Pandora's Box — {5} — Artifact — (past, common)
## Oracle: {3}, {T}: Choose a random summon card from all players' decks.
##         For each player, flip a coin. If the flip ends up heads, put a
##         token creature into play and treat it as though an exact copy of
##         the chosen summon card were just played.
##
## Implementation: one creature card is rolled out of BOTH libraries (the
## card itself stays where it is — the Box only copies it), then each player
## flips. A winning flip creates a token from that card's own CardData, so
## the copy has its printed abilities, not just its body.


static func _is_creature_card(inst: CardInstance) -> bool:
	return inst.data.is_creature()


func build() -> CardData:
	return CardData.new("Pandora's Box", "{5}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{3}", true,
			[OpenTheBoxEffect.new(_is_creature_card)],
			"{3}, {T}: Choose a random summon card from all players' decks; each player flips a coin for a copy.")) \
		.oracle("{3}, {T}: Choose a random summon card from all players' decks. For each player, flip a coin. If the flip ends up heads, put a token creature into play and treat it as though an exact copy of the chosen summon card were just played.")


class OpenTheBoxEffect extends EffectBase:
	var creature_filter: Callable

	func _init(filter: Callable) -> void:
		creature_filter = filter

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var chosen := RandomEffects.card_in_libraries(game, creature_filter)
		if chosen == null:
			game.log_line("Pandora's Box finds no summon card")
			return
		game.log_line("Pandora's Box chooses %s" % chosen.data.card_name)
		for p in game.players:
			if p.has_lost:
				continue
			if game.flip_coin(p.id):
				game.create_token(p.id, chosen.data)

	func describe() -> String:
		return "each player flips for a token copy of a random summon card"
