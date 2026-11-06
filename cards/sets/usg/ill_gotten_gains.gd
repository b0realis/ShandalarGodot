extends CardScript
## Ill-Gotten Gains — {2}{B}{B} — Sorcery (rare, usg).
## Oracle: Exile Ill-Gotten Gains. Each player discards their hand, then returns up to three cards from their graveyard to their hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ill-Gotten Gains", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Exile Ill-Gotten Gains. Each player discards their hand, then returns up to three cards from their graveyard to their hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
