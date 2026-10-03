extends CardScript
## Teferi's Imp — {2}{U} — Creature — Imp (rare, mir).
## Oracle: Flying
##         Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         Whenever this creature phases out, discard a card.
##         Whenever this creature phases in, draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teferi's Imp", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nPhasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nWhenever this creature phases out, discard a card.\nWhenever this creature phases in, draw a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
