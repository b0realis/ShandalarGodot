extends CardScript
## Orcish Settlers — {1}{R} — Creature — Orc (uncommon, wth).
## Oracle: {X}{X}{R}, {T}, Sacrifice this creature: Destroy X target lands.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Orcish Settlers", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["orc"])
	c.oracle("{X}{X}{R}, {T}, Sacrifice this creature: Destroy X target lands.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
