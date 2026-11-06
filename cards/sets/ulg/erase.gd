extends CardScript
## Erase — {W} — Instant (common, ulg).
## Oracle: Exile target enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Erase", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Exile target enchantment.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
