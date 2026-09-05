extends CardScript
## Dwarven Demolition Team — {2}{R} — Creature — Dwarf — 1/1 — (2ed, uncommon)
## Oracle: {T}: Destroy target Wall.
##
## Implementation: tap-to-wreck — a free (tap-only) activated ability with
## the same Wall filter as Tunnel, but the wall CAN regenerate from this
## one (no rider printed). Subject to summoning sickness like every tap
## ability (CR 602.5g).


func build() -> CardData:
	# An ability/spell that can target ONLY Walls — which Wall of Shadows
	# ("can't be the target of spells that can target only Walls or of
	# abilities that can target only Walls") reads off TargetSpec.only_walls.
	var spec := TargetSpec.creature("target Wall", _is_wall).only_walls()
	return CardData.new("Dwarven Demolition Team", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["dwarf"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DestroyEffect.new(spec)],
			"{T}: Destroy target Wall.")) \
		.oracle("{T}: Destroy target Wall.")


static func _is_wall(inst: CardInstance) -> bool:
	return inst.has_subtype("wall")
