extends CardScript
## Gate to Phyrexia — {B}{B} — Enchantment — (atq, uncommon)
## Oracle: Sacrifice a creature: Destroy target artifact. Activate only
##         during your upkeep and only once each turn.
##
## Implementation: an ActivatedAbility with a creature-sacrifice cost, a
## DestroyEffect payload, and both timing riders the engine now has —
## during_step(UPKEEP) + your_turn_only() + per_turn(1). Two black mana
## for a repeatable artifact answer was Antiquities' hardest hoser.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)
	return CardData.new("Gate to Phyrexia", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"", false, [DestroyEffect.new(spec)],
			"Sacrifice a creature: Destroy target artifact. Activate only during your "
			+ "upkeep and only once each turn.") \
			.with_sacrifice_of("creature", _is_creature) \
			.during_step(Mtg.Step.UPKEEP).your_turn_only().per_turn(1)) \
		.oracle("Sacrifice a creature: Destroy target artifact. Activate only during "
			+ "your upkeep and only once each turn.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()
