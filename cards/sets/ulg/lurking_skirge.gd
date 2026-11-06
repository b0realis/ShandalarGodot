extends CardScript
## Lurking Skirge — {1}{B} — Enchantment (rare, ulg).
## Oracle: When a creature is put into an opponent's graveyard from the battlefield, if this permanent is an enchantment, it becomes a 3/2 Phyrexian Imp creature with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lurking Skirge", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When a creature is put into an opponent's graveyard from the battlefield, if this permanent is an enchantment, it becomes a 3/2 Phyrexian Imp creature with flying.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
