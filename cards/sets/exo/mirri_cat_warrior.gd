extends CardScript
## Mirri, Cat Warrior — {1}{G}{G} — Legendary Creature — Cat Warrior (rare, exo).
## Oracle: First strike, forestwalk, vigilance (This creature deals combat damage before creatures without first strike, it can't be blocked as long as defending player controls a Forest, and attacking doesn't cause this creature to tap.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mirri, Cat Warrior", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["cat","warrior"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.VIGILANCE])
	c.with_landwalk(["forest"])
	c.oracle("First strike, forestwalk, vigilance (This creature deals combat damage before creatures without first strike, it can't be blocked as long as defending player controls a Forest, and attacking doesn't cause this creature to tap.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
