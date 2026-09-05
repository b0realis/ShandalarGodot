extends CardScript
## Carrion Ants — {2}{B}{B} — Creature — Insect — 0/1 — (4ed, uncommon)
## Oracle: {1}: This creature gets +1/+1 until end of turn.
##
## Implementation: Killer Bees grounded but colorless-fed — any mana
## grows the swarm.


func build() -> CardData:
	return CardData.new("Carrion Ants", "{2}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["insect"]) \
		.activated(ActivatedAbility.new(
			"{1}", false,
			[PumpEffect.new(1, 1).self_buff()],
			"{1}: This creature gets +1/+1 until end of turn.")) \
		.oracle("{1}: This creature gets +1/+1 until end of turn.")
