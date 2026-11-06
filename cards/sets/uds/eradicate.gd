extends CardScript
## Eradicate — {2}{B}{B} — Sorcery (uncommon, uds).
## Oracle: Exile target nonblack creature. Search its controller's graveyard, hand, and library for all cards with the same name as that creature and exile them. Then that player shuffles.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Eradicate", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Exile target nonblack creature. Search its controller's graveyard, hand, and library for all cards with the same name as that creature and exile them. Then that player shuffles.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
