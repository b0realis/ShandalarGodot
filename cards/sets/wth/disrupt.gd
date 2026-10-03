extends CardScript
## Disrupt — {U} — Instant (common, wth).
## Oracle: Counter target instant or sorcery spell unless its controller pays {1}.
##         Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disrupt", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target instant or sorcery spell unless its controller pays {1}.\nDraw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
