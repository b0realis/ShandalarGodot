extends CardScript
## Argivian Find — {W} — Instant (uncommon, wth).
## Oracle: Return target artifact or enchantment card from your graveyard to your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Argivian Find", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Return target artifact or enchantment card from your graveyard to your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
