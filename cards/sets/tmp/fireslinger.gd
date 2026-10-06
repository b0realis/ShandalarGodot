extends CardScript
## Fireslinger — {1}{R} — Creature — Human Wizard (common, tmp).
## Oracle: {T}: This creature deals 1 damage to any target and 1 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fireslinger", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}: This creature deals 1 damage to any target and 1 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
