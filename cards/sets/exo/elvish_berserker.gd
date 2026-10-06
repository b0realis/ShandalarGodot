extends CardScript
## Elvish Berserker — {G} — Creature — Elf Berserker (common, exo).
## Oracle: Whenever this creature becomes blocked, it gets +1/+1 until end of turn for each creature blocking it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elvish Berserker", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","berserker"])
	c.oracle("Whenever this creature becomes blocked, it gets +1/+1 until end of turn for each creature blocking it.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
