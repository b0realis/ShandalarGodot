extends CardScript
## Reckless Embermage — {3}{R} — Creature — Human Wizard (rare, mir).
## Oracle: {1}{R}: This creature deals 1 damage to any target and 1 damage to itself.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reckless Embermage", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{1}{R}: This creature deals 1 damage to any target and 1 damage to itself.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
