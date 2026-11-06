extends CardScript
## Hidden Guerrillas — {G} — Enchantment (uncommon, usg).
## Oracle: When an opponent casts an artifact spell, if this permanent is an enchantment, it becomes a 5/3 Soldier creature with trample.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Guerrillas", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts an artifact spell, if this permanent is an enchantment, it becomes a 5/3 Soldier creature with trample.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
