extends CardScript
## Purgatory — {2}{W}{B} — Enchantment (rare, mir).
## Oracle: Whenever a nontoken creature is put into your graveyard from the battlefield, exile that card.
##         At the beginning of your upkeep, you may pay {4} and 2 life. If you do, return a card exiled with this enchantment to the battlefield.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Purgatory", "{2}{W}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a nontoken creature is put into your graveyard from the battlefield, exile that card.\nAt the beginning of your upkeep, you may pay {4} and 2 life. If you do, return a card exiled with this enchantment to the battlefield.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
