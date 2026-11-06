extends CardScript
## Scour — {2}{W}{W} — Instant (uncommon, uds).
## Oracle: Exile target enchantment. Search its controller's graveyard, hand, and library for all cards with the same name as that enchantment and exile them. Then that player shuffles.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scour", "{2}{W}{W}", Mtg.CardType.INSTANT)
	c.oracle("Exile target enchantment. Search its controller's graveyard, hand, and library for all cards with the same name as that enchantment and exile them. Then that player shuffles.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
