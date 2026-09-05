extends CardScript
## Spinal Villain — {2}{R} — Creature — Beast — 1/2 — (leg, rare)
## Oracle: {T}: Destroy target blue creature.
##
## Implementation: a repeatable DestroyEffect hosed to blue. The colour
## test reads the PRINTED colour of the target's mana cost
## (data.color_mask), the project-wide convention — no colour-changing
## effect exists in this pool (see docs/audit-vs-mage-go.md).


func build() -> CardData:
	var spec := TargetSpec.creature("target blue creature", _is_blue)
	return CardData.new("Spinal Villain", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["beast"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DestroyEffect.new(spec)],
			"{T}: Destroy target blue creature.")) \
		.oracle("{T}: Destroy target blue creature.")


static func _is_blue(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.U) != 0
