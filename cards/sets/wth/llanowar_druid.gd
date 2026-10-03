extends CardScript
## Llanowar Druid — {1}{G} — Creature — Elf Druid (common, wth).
## Oracle: {T}, Sacrifice this creature: Untap all Forests.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Llanowar Druid", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["elf","druid"])
	c.oracle("{T}, Sacrifice this creature: Untap all Forests.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
