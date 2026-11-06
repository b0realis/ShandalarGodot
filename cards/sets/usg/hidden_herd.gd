extends CardScript
## Hidden Herd — {G} — Enchantment (rare, usg).
## Oracle: When an opponent plays a nonbasic land, if this permanent is an enchantment, it becomes a 3/3 Beast creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Herd", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent plays a nonbasic land, if this permanent is an enchantment, it becomes a 3/3 Beast creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
