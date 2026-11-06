extends CardScript
## Hidden Gibbons — {G} — Enchantment (rare, ulg).
## Oracle: When an opponent casts an instant spell, if this permanent is an enchantment, it becomes a 4/4 Ape creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hidden Gibbons", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts an instant spell, if this permanent is an enchantment, it becomes a 4/4 Ape creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
