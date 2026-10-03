extends CardScript
## Agonizing Memories — {2}{B}{B} — Sorcery (uncommon, wth).
## Oracle: Look at target player's hand and choose two cards from it. Put them on top of that player's library in any order.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Agonizing Memories", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Look at target player's hand and choose two cards from it. Put them on top of that player's library in any order.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
