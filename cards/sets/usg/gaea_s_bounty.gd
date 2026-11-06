extends CardScript
## Gaea's Bounty — {2}{G} — Sorcery (common, usg).
## Oracle: Search your library for up to two Forest cards, reveal those cards, put them into your hand, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gaea's Bounty", "{2}{G}", Mtg.CardType.SORCERY)
	c.oracle("Search your library for up to two Forest cards, reveal those cards, put them into your hand, then shuffle.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
