extends CardScript
## Martyrs of Korlis — {3}{W}{W} — Creature — Human — 1/6 — (atq, uncommon)
## Oracle: As long as this creature is untapped, all damage that would be
##         dealt to you by artifacts is dealt to this creature instead.
##
## Implementation: a static writing its controller's
## artifact_damage_redirect while the Martyrs are untapped;
## MtgGame.deal_damage reroutes the damage BEFORE any of the player's own
## prevention, which is what a redirection does. A 1/6 body absorbs six
## artifact damage a turn — and Reverse Polarity still counts nothing,
## because the player took none.


func build() -> CardData:
	return CardData.new("Martyrs of Korlis", "{3}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 6) \
		.with_subtypes(["human"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"As long as Martyrs of Korlis is untapped, all damage that would be dealt "
			+ "to you by artifacts is dealt to it instead.")) \
		.oracle("As long as this creature is untapped, all damage that would be dealt "
			+ "to you by artifacts is dealt to this creature instead.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if not source.tapped:
		game.players[source.controller_id].artifact_damage_redirect = source.id
