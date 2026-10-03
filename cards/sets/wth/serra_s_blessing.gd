extends CardScript
## Serra's Blessing — {1}{W} — Enchantment (uncommon, wth).
## Oracle: Creatures you control have vigilance. (Attacking doesn't cause them to tap.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra's Blessing", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control have vigilance. (Attacking doesn't cause them to tap.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
