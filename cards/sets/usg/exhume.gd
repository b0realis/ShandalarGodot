extends CardScript
## Exhume — {1}{B} — Sorcery (common, usg).
## Oracle: Each player puts a creature card from their graveyard onto the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Exhume", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("Each player puts a creature card from their graveyard onto the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
