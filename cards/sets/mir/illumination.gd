extends CardScript
## Illumination — {W}{W} — Instant (uncommon, mir).
## Oracle: Counter target artifact or enchantment spell. Its controller gains life equal to its mana value.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Illumination", "{W}{W}", Mtg.CardType.INSTANT)
	c.oracle("Counter target artifact or enchantment spell. Its controller gains life equal to its mana value.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
