extends CardScript
## Fevered Convulsions — {B}{B} — Enchantment (rare, tmp).
## Oracle: {2}{B}{B}: Put a -1/-1 counter on target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fevered Convulsions", "{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}{B}{B}: Put a -1/-1 counter on target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
