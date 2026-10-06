extends CardScript
## Earthcraft — {1}{G} — Enchantment (rare, tmp).
## Oracle: Tap an untapped creature you control: Untap target basic land.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Earthcraft", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Tap an untapped creature you control: Untap target basic land.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
