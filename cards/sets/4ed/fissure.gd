extends CardScript
## Fissure — {3}{R}{R} — Instant (4ed, common; first printed in The Dark)
## Oracle: Destroy target creature or land. It can't be regenerated.
##
## Implementation: DestroyEffect with a creature-or-land spec and the
## no-regeneration rider — red's expensive answer-anything instant.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target creature or land",
		func(inst: CardInstance) -> bool:
			return inst.is_creature() or inst.is_land())
	return CardData.new("Fissure", "{3}{R}{R}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(spec, false)) \
		.oracle("Destroy target creature or land. It can't be regenerated.")
