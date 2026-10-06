extends CardScript
## Staunch Defenders — {3}{W}{W} — Creature — Human Soldier (uncommon, tmp).
## Oracle: When this creature enters, you gain 4 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Staunch Defenders", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["human","soldier"])
	c.oracle("When this creature enters, you gain 4 life.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
