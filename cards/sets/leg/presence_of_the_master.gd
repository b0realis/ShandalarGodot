extends CardScript
## Presence of the Master — {3}{W} — Enchantment — (leg, uncommon)
## Oracle: Whenever a player casts an enchantment spell, counter it.
##
## Implementation: a SPELL_CAST trigger gated on the cast card being an
## enchantment. Symmetric and absolute — no payment, no choice. Once
## resolved it locks every later enchantment out of the game, including
## its controller's own (and including a second Presence).


func build() -> CardData:
	return CardData.new("Presence of the Master", "{3}{W}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _counter,
			"Whenever a player casts an enchantment spell, counter it.",
			_is_enchantment)) \
		.oracle("Whenever a player casts an enchantment spell, counter it.")


static func _is_enchantment(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var spell: CardInstance = event.data["instance"]
	return spell != null and spell.data.is_type(Mtg.CardType.ENCHANTMENT)


static func _counter(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var spell: CardInstance = event.data["instance"]
	if spell != null and spell.zone == Mtg.Zone.STACK:
		game.counter_spell(spell)
