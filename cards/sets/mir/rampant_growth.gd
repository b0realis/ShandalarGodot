extends CardScript
## Rampant Growth — {1}{G} — Sorcery (common, mir).
## Oracle: Search your library for a basic land card, put that card onto the battlefield tapped, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rampant Growth", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for a basic land card, put that card onto the battlefield tapped, then shuffle.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
