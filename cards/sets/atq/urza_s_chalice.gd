extends CardScript
## Urza's Chalice — {1} — Artifact — (atq, common)
## Oracle: Whenever a player casts an artifact spell, you may pay {1}. If
##         you do, you gain 1 life.
##
## Implementation: a SPELL_CAST trigger gated on the card being an
## artifact — ANY player's, as printed — offering {1} for a life. In an
## artifact mirror it adds up; anywhere else it is a one-mana blank.


func build() -> CardData:
	return CardData.new("Urza's Chalice", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _pay,
			"Whenever a player casts an artifact spell, you may pay {1}. If you do, "
			+ "you gain 1 life.",
			_is_artifact_spell)) \
		.oracle("Whenever a player casts an artifact spell, you may pay {1}. If you "
			+ "do, you gain 1 life.")


static func _is_artifact_spell(_game: MtgGame, _source: CardInstance,
		event: GameEvent) -> bool:
	var spell: CardInstance = event.data.get("instance")
	return spell != null and spell.data.is_type(Mtg.CardType.ARTIFACT)


static func _pay(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	var cost := ManaCost.parse("{1}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid, "Pay {1} to gain 1 life?", true) \
			and game.try_pay(pid, cost):
		game.adjust_life(pid, 1)
