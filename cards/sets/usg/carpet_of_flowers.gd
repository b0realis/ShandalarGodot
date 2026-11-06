extends CardScript
## Carpet of Flowers — {G} — Enchantment (uncommon, usg).
## Oracle: At the beginning of each of your main phases, if you haven't added mana with this ability this turn, you may add X mana of any one color, where X is the number of Islands target opponent controls.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carpet of Flowers", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of each of your main phases, if you haven't added mana with this ability this turn, you may add X mana of any one color, where X is the number of Islands target opponent controls.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
