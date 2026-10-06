extends CardScript
## Intruder Alarm — {2}{U} — Enchantment (rare, sth).
## Oracle: Creatures don't untap during their controllers' untap steps.
##         Whenever a creature enters, untap all creatures.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Intruder Alarm", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures don't untap during their controllers' untap steps.\nWhenever a creature enters, untap all creatures.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
