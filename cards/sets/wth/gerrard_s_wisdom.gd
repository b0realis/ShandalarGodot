extends CardScript
## Gerrard's Wisdom — {2}{W}{W} — Sorcery (uncommon, wth).
## Oracle: You gain 2 life for each card in your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gerrard's Wisdom", "{2}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("You gain 2 life for each card in your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
