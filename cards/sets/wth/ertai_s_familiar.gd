extends CardScript
## Ertai's Familiar — {1}{U} — Creature — Illusion (rare, wth).
## Oracle: Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         When this creature phases out or leaves the battlefield, mill three cards.
##         {U}: Until your next upkeep, this creature can't phase out.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ertai's Familiar", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["illusion"])
	c.oracle("Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nWhen this creature phases out or leaves the battlefield, mill three cards.\n{U}: Until your next upkeep, this creature can't phase out.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
