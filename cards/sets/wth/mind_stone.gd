extends CardScript
## Mind Stone — {2} — Artifact (common, wth).
## Oracle: {T}: Add {C}.
##         {1}, {T}, Sacrifice this artifact: Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mind Stone", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Add {C}.\n{1}, {T}, Sacrifice this artifact: Draw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
