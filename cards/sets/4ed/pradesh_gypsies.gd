extends CardScript
## Pradesh Gypsies — {2}{G} — Creature — Human Nomad — 1/1 — (4ed, common)
## Oracle: {1}{G}, {T}: Target creature gets -2/-0 until end of turn.
##
## Implementation: activated shrink — a NEGATIVE targeted pump until end
## of turn (power can go below 0; the engine deals no damage for
## non-positive power).


func build() -> CardData:
	var shrink := PumpEffect.new(-2, 0)
	shrink.target_spec = TargetSpec.creature()
	return CardData.new("Pradesh Gypsies", "{2}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "nomad"]) \
		.activated(ActivatedAbility.new(
			"{1}{G}", true,
			[shrink],
			"{1}{G}, {T}: Target creature gets -2/-0 until end of turn.")) \
		.oracle("{1}{G}, {T}: Target creature gets -2/-0 until end of turn.")
