extends CardScript
## Candelabra of Tawnos — {1} — Artifact — (atq, rare)
## Oracle: {X}, {T}: Untap X target lands.
##
## Implementation: the ability's {X} feeds both the cost and the target
## count (activate_ability's x_value reaches TargetPlan), so untapping
## three lands really costs {3} plus the tap.


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


func build() -> CardData:
	return CardData.new("Candelabra of Tawnos", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{X}", true,
			[UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target land", _is_land)).x_targets()],
			"{X}, {T}: Untap X target lands.")) \
		.oracle("{X}, {T}: Untap X target lands.")
