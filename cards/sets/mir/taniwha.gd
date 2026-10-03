extends CardScript
## Taniwha — {3}{U}{U} — Legendary Creature — Serpent (rare, mir).
## Oracle: Trample
##         Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         At the beginning of your upkeep, all lands you control phase out. (They phase in before you untap during your next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Taniwha", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["serpent"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nPhasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nAt the beginning of your upkeep, all lands you control phase out. (They phase in before you untap during your next untap step.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
