extends CardScript
## Sowing Salt — {2}{R}{R} — Sorcery (uncommon, uds).
## Oracle: Exile target nonbasic land. Search its controller's graveyard, hand, and library for all cards with the same name as that land and exile them. Then that player shuffles.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sowing Salt", "{2}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Exile target nonbasic land. Search its controller's graveyard, hand, and library for all cards with the same name as that land and exile them. Then that player shuffles.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
