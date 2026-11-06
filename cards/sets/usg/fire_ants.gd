extends CardScript
## Fire Ants — {2}{R} — Creature — Insect (uncommon, usg).
## Oracle: {T}: This creature deals 1 damage to each other creature without flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fire Ants", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["insect"])
	c.oracle("{T}: This creature deals 1 damage to each other creature without flying.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
