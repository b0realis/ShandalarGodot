extends CardScript
## Goblin Spelunkers — {2}{R} — Creature — Goblin Warrior (common, usg).
## Oracle: Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Spelunkers", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin","warrior"])
	c.with_landwalk(["mountain"])
	c.oracle("Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
