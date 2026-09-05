extends CardScript
## Arena of the Ancients — {3} — Artifact — (leg, rare)
## Oracle: Legendary creatures don't untap during their controllers' untap
##         steps.
##         When this artifact enters, tap all legendary creatures.
##
## Implementation: a static setting cur_skips_untap on every legendary
## creature plus an ETB trigger that taps them all. Symmetric, and in a
## set built around legends it is a one-sided Winter Orb for whoever
## isn't playing them.


func build() -> CardData:
	return CardData.new("Arena of the Ancients", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Legendary creatures don't untap during their controllers' untap steps.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _tap_them_all,
			"When Arena of the Ancients enters, tap all legendary creatures.",
			_is_self)) \
		.oracle("Legendary creatures don't untap during their controllers' untap "
			+ "steps.\nWhen this artifact enters, tap all legendary creatures.")


static func _is_legendary(inst: CardInstance) -> bool:
	return inst.is_creature() and (inst.data.supertypes & Mtg.Supertype.LEGENDARY) != 0


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _is_legendary(inst):
			inst.cur_skips_untap = true


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _tap_them_all(game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	for inst in game.all_battlefield():
		if _is_legendary(inst):
			game.tap_permanent(inst)
