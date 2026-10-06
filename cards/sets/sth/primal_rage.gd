extends CardScript
## Primal Rage — {1}{G} — Enchantment (uncommon, sth).
## Oracle: Creatures you control have trample. (A creature with trample can deal excess combat damage to the player or planeswalker it's attacking.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Primal Rage", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control have trample. (A creature with trample can deal excess combat damage to the player or planeswalker it's attacking.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
