extends CardScript
## Opal Titan — {2}{W}{W} — Enchantment (rare, usg).
## Oracle: When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 4/4 Giant creature with protection from each of that spell's colors.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.
## SIMPLIFIED (docs/simplified-cards.md, "Opal Titan"): a spell gone from the stack is read as it was cast. See cards/sets/usg/_opal.gd _that_spell.

func build() -> CardData:
	var c := CardData.new("Opal Titan", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 4/4 Giant creature with protection from each of that spell's colors.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
