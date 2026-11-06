extends CardScript
## Reliquary Monk — {2}{W} — Creature — Human Monk Cleric (common, uds).
## Oracle: When this creature dies, destroy target artifact or enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reliquary Monk", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","monk","cleric"])
	c.oracle("When this creature dies, destroy target artifact or enchantment.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
