extends CardScript
## Breezekeeper — {3}{U} — Creature — Djinn (common, vis).
## Oracle: Flying
##         Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Breezekeeper", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["djinn"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nPhasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
