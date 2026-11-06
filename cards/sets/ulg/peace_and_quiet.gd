extends CardScript
## Peace and Quiet — {1}{W} — Instant (uncommon, ulg).
## Oracle: Destroy two target enchantments.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Peace and Quiet", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Destroy two target enchantments.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
