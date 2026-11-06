extends CardScript
## Encroach — {B} — Sorcery (uncommon, uds).
## Oracle: Target player reveals their hand. You choose a nonbasic land card from it. That player discards that card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Encroach", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Target player reveals their hand. You choose a nonbasic land card from it. That player discards that card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
