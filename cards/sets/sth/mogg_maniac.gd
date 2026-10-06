extends CardScript
## Mogg Maniac — {1}{R} — Creature — Goblin (uncommon, sth).
## Oracle: Whenever this creature is dealt damage, it deals that much damage to target opponent or planeswalker.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Maniac", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Whenever this creature is dealt damage, it deals that much damage to target opponent or planeswalker.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
