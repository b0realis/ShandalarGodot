extends CardScript
## Killer Bees — {1}{G}{G} — Creature — Insect — 0/1 — (4ed, uncommon)
## Oracle: Flying
##         {G}: This creature gets +1/+1 until end of turn.
##
## Implementation: green's famous mana-sink flyer — flying + a full
## +1/+1 self_buff per {G}. Every forest is another bee.


func build() -> CardData:
	return CardData.new("Killer Bees", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["insect"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{G}", false,
			[PumpEffect.new(1, 1).self_buff()],
			"{G}: This creature gets +1/+1 until end of turn.")) \
		.oracle("Flying\n{G}: This creature gets +1/+1 until end of turn.")
