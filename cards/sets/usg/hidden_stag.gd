extends CardScript
## Hidden Stag — {1}{G} — Enchantment (rare, usg).
## Oracle: Whenever an opponent plays a land, if this permanent is an enchantment, it becomes a 3/2 Elk Beast creature.
##         Whenever you play a land, if this permanent is a creature, it becomes an enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Stag", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent plays a land, if this permanent is an enchantment, it becomes a 3/2 Elk Beast creature.\nWhenever you play a land, if this permanent is a creature, it becomes an enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
