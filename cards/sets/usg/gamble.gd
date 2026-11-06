extends CardScript
## Gamble — {R} — Sorcery (rare, usg).
## Oracle: Search your library for a card, put that card into your hand, discard a card at random, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gamble", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for a card, put that card into your hand, discard a card at random, then shuffle.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
