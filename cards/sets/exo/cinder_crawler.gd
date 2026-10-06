extends CardScript
## Cinder Crawler — {1}{R} — Creature — Salamander (common, exo).
## Oracle: {R}: This creature gets +1/+0 until end of turn. Activate only if this creature is blocked.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cinder Crawler", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["salamander"])
	c.oracle("{R}: This creature gets +1/+0 until end of turn. Activate only if this creature is blocked.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
