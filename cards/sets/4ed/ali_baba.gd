extends CardScript
## Ali Baba — {R} — Creature — Human Rogue — 1/1 — (4ed, uncommon)
## Oracle: {R}: Tap target Wall.
##
## Implementation: {R} activated TapEffect filtered to Walls — open
## sesame: tap the Wall, then walk the attackers past it.


func build() -> CardData:
	var wall_spec := TargetSpec.creature("target Wall", _is_wall).only_walls()
	return CardData.new("Ali Baba", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "rogue"]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[TapEffect.new(wall_spec)],
			"{R}: Tap target Wall.")) \
		.oracle("{R}: Tap target Wall.")


static func _is_wall(inst: CardInstance) -> bool:
	return inst.has_subtype("wall")
