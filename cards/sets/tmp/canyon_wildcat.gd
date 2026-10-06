extends CardScript
## Canyon Wildcat — {1}{R} — Creature — Cat (common, tmp).
## Oracle: Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Canyon Wildcat", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["cat"])
	c.with_landwalk(["mountain"])
	c.oracle("Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
