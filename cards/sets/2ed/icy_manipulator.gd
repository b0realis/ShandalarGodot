extends CardScript
## Icy Manipulator — {4} — Artifact (2ed, uncommon)
## Oracle: {1}, {T}: Tap target artifact, creature, or land.
##
## Implementation: mana+tap activated ability with a TapEffect over an
## artifact/creature/land-filtered spec (i.e. everything but a lone
## enchantment). The pool's premier tempo tool: tap a blocker on your
## turn, tap a land on theirs.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact, creature, or land", _valid_target)
	return CardData.new("Icy Manipulator", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{1}", true,
			[TapEffect.new(spec)],
			"{1}, {T}: Tap target artifact, creature, or land.")) \
		.oracle("{1}, {T}: Tap target artifact, creature, or land.")


static func _valid_target(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) \
		or inst.is_creature() or inst.is_land()
