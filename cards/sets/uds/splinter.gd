extends CardScript
## Splinter — {2}{G}{G} — Sorcery (uncommon, uds).
## Oracle: Exile target artifact. Search its controller's graveyard, hand, and library for all cards with the same name as that artifact and exile them. Then that player shuffles.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Splinter", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Exile target artifact. Search its controller's graveyard, hand, and library for all cards with the same name as that artifact and exile them. Then that player shuffles.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
