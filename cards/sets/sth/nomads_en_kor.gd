extends CardScript
## Nomads en-Kor — {W} — Creature — Kor Nomad Soldier (common, sth).
## Oracle: {0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nomads en-Kor", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["kor","nomad","soldier"])
	c.oracle("{0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
