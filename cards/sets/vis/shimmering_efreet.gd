extends CardScript
## Shimmering Efreet — {2}{U} — Creature — Efreet (uncommon, vis).
## Oracle: Flying
##         Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         Whenever this creature phases in, target creature phases out. (It phases in before its controller untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shimmering Efreet", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["efreet"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nPhasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nWhenever this creature phases in, target creature phases out. (It phases in before its controller untaps during their next untap step.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
