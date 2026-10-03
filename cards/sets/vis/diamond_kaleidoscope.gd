extends CardScript
## Diamond Kaleidoscope — {4} — Artifact (rare, vis).
## Oracle: {3}, {T}: Create a 0/1 colorless Prism artifact creature token.
##         Sacrifice a Prism token: Add one mana of any color.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Diamond Kaleidoscope", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Create a 0/1 colorless Prism artifact creature token.\nSacrifice a Prism token: Add one mana of any color.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
