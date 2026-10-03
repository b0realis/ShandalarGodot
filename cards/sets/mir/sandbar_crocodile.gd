extends CardScript
## Sandbar Crocodile — {4}{U} — Creature — Crocodile (common, mir).
## Oracle: Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sandbar Crocodile", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(6, 5)
	c.with_subtypes(["crocodile"])
	c.oracle("Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
