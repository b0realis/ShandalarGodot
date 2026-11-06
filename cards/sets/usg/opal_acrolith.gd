extends CardScript
## Opal Acrolith — {2}{W} — Enchantment (uncommon, usg).
## Oracle: Whenever an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/4 Soldier creature.
##         {0}: This permanent becomes an enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opal Acrolith", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/4 Soldier creature.\n{0}: This permanent becomes an enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
