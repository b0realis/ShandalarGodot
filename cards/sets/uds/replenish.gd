extends CardScript
## Replenish — {3}{W} — Sorcery (rare, uds).
## Oracle: Return all enchantment cards from your graveyard to the battlefield. (Auras with nothing to enchant remain in your graveyard.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Replenish", "{3}{W}", Mtg.CardType.SORCERY)
	c.oracle("Return all enchantment cards from your graveyard to the battlefield. (Auras with nothing to enchant remain in your graveyard.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
