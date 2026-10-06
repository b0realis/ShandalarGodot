extends CardScript
## Mogg Squad — {1}{R} — Creature — Goblin (uncommon, tmp).
## Oracle: This creature gets -1/-1 for each other creature on the battlefield.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Squad", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["goblin"])
	c.oracle("This creature gets -1/-1 for each other creature on the battlefield.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
