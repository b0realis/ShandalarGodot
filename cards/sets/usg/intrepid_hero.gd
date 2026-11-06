extends CardScript
## Intrepid Hero — {2}{W} — Creature — Human Soldier (rare, usg).
## Oracle: {T}: Destroy target creature with power 4 or greater.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Intrepid Hero", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("{T}: Destroy target creature with power 4 or greater.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
