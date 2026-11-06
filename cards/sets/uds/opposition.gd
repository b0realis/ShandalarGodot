extends CardScript
## Opposition — {2}{U}{U} — Enchantment (rare, uds).
## Oracle: Tap an untapped creature you control: Tap target artifact, creature, or land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opposition", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Tap an untapped creature you control: Tap target artifact, creature, or land.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
