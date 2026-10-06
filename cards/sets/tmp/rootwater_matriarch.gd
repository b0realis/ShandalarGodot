extends CardScript
## Rootwater Matriarch — {2}{U}{U} — Creature — Merfolk (rare, tmp).
## Oracle: {T}: Gain control of target creature for as long as that creature is enchanted.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwater Matriarch", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["merfolk"])
	c.oracle("{T}: Gain control of target creature for as long as that creature is enchanted.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
