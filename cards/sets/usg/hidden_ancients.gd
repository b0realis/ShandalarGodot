extends CardScript
## Hidden Ancients — {1}{G} — Enchantment (uncommon, usg).
## Oracle: When an opponent casts an enchantment spell, if this permanent is an enchantment, it becomes a 5/5 Treefolk creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Ancients", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts an enchantment spell, if this permanent is an enchantment, it becomes a 5/5 Treefolk creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
