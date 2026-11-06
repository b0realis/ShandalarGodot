extends CardScript
## Fledgling Osprey — {U} — Creature — Bird (common, uds).
## Oracle: This creature has flying as long as it's enchanted.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fledgling Osprey", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.oracle("This creature has flying as long as it's enchanted.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
