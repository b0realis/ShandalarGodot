extends CardScript
## Plague Beetle — {B} — Creature — Insect (common, ulg).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Plague Beetle", "{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
