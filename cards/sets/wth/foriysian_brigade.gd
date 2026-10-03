extends CardScript
## Foriysian Brigade — {3}{W} — Creature — Human Soldier (uncommon, wth).
## Oracle: This creature can block an additional creature each combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Foriysian Brigade", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["human","soldier"])
	c.oracle("This creature can block an additional creature each combat.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
