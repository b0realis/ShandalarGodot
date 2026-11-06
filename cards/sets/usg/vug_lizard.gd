extends CardScript
## Vug Lizard — {1}{R}{R} — Creature — Lizard (uncommon, usg).
## Oracle: Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)
##         Echo {1}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vug Lizard", "{1}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["lizard"])
	c.with_landwalk(["mountain"])
	c.oracle("Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)\nEcho {1}{R}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
