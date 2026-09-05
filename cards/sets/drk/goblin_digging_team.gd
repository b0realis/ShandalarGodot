extends CardScript
## Goblin Digging Team — {R} — Creature — Goblin — 1/1 — (drk, common)
## Oracle: {T}, Sacrifice this creature: Destroy target Wall.
##
## Implementation: tap + self-sacrifice cost (paid up front, CR 601.2h —
## the goblins are in the graveyard while the demolition resolves) with
## the Wall-filtered DestroyEffect payload.


func build() -> CardData:
	# An ability/spell that can target ONLY Walls — which Wall of Shadows
	# ("can't be the target of spells that can target only Walls or of
	# abilities that can target only Walls") reads off TargetSpec.only_walls.
	var spec := TargetSpec.creature("target Wall", _is_wall).only_walls()
	return CardData.new("Goblin Digging Team", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["goblin"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DestroyEffect.new(spec)],
			"{T}, Sacrifice this creature: Destroy target Wall.").with_sacrifice_cost()) \
		.oracle("{T}, Sacrifice this creature: Destroy target Wall.")


static func _is_wall(inst: CardInstance) -> bool:
	return inst.has_subtype("wall")
