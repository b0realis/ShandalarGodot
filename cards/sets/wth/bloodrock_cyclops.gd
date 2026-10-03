extends CardScript
## Bloodrock Cyclops — {2}{R} — Creature — Cyclops (common, wth).
## Oracle: This creature attacks each combat if able.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bloodrock Cyclops", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["cyclops"])
	c.oracle("This creature attacks each combat if able.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
