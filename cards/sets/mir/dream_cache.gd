extends CardScript
## Dream Cache — {2}{U} — Sorcery (common, mir).
## Oracle: Draw three cards, then put two cards from your hand both on top of your library or both on the bottom of your library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dream Cache", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Draw three cards, then put two cards from your hand both on top of your library or both on the bottom of your library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
