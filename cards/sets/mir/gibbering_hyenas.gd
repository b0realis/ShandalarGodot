extends CardScript
## Gibbering Hyenas — {2}{G} — Creature — Hyena (common, mir).
## Oracle: This creature can't block black creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gibbering Hyenas", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["hyena"])
	c.oracle("This creature can't block black creatures.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
