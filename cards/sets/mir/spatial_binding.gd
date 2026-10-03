extends CardScript
## Spatial Binding — {U}{B} — Enchantment (uncommon, mir).
## Oracle: Pay 1 life: Until your next upkeep, target permanent can't phase out.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spatial Binding", "{U}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Pay 1 life: Until your next upkeep, target permanent can't phase out.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
