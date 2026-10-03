extends CardScript
## Mana Prism — {3} — Artifact (uncommon, mir).
## Oracle: {T}: Add {C}.
##         {1}, {T}: Add one mana of any color.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Prism", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Add {C}.\n{1}, {T}: Add one mana of any color.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
