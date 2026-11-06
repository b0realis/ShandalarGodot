extends CardScript
## Power Taint — {1}{U} — Enchantment — Aura (common, usg).
## Oracle: Enchant enchantment
##         At the beginning of the upkeep of enchanted enchantment's controller, that player loses 2 life unless they pay {2}.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Power Taint", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant enchantment\nAt the beginning of the upkeep of enchanted enchantment's controller, that player loses 2 life unless they pay {2}.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
