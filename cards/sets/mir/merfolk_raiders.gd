extends CardScript
## Merfolk Raiders — {1}{U} — Creature — Merfolk Soldier (common, mir).
## Oracle: Islandwalk (This creature can't be blocked as long as defending player controls an Island.)
##         Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Merfolk Raiders", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["merfolk","soldier"])
	c.with_landwalk(["island"])
	c.oracle("Islandwalk (This creature can't be blocked as long as defending player controls an Island.)\nPhasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
