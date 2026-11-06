extends CardScript
## Quash — {2}{U}{U} — Instant (uncommon, uds).
## Oracle: Counter target instant or sorcery spell. Search its controller's graveyard, hand, and library for all cards with the same name as that spell and exile them. Then that player shuffles.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quash", "{2}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target instant or sorcery spell. Search its controller's graveyard, hand, and library for all cards with the same name as that spell and exile them. Then that player shuffles.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
