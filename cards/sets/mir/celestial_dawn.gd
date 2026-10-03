extends CardScript
## Celestial Dawn — {1}{W}{W} — Enchantment (rare, mir).
## Oracle: Lands you control are Plains.
##         Nonland permanents you control are white. The same is true for spells you control and nonland cards you own that aren't on the battlefield.
##         You may spend white mana as though it were mana of any color. You may spend other mana only as though it were colorless mana.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Celestial Dawn", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Lands you control are Plains.\nNonland permanents you control are white. The same is true for spells you control and nonland cards you own that aren't on the battlefield.\nYou may spend white mana as though it were mana of any color. You may spend other mana only as though it were colorless mana.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
