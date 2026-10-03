extends CardScript
## Dream Tides — {2}{U}{U} — Enchantment (uncommon, vis).
## Oracle: Creatures don't untap during their controllers' untap steps.
##         At the beginning of each player's upkeep, that player may choose any number of tapped nongreen creatures they control and pay {2} for each creature chosen this way. If the player does, untap those creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dream Tides", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures don't untap during their controllers' untap steps.\nAt the beginning of each player's upkeep, that player may choose any number of tapped nongreen creatures they control and pay {2} for each creature chosen this way. If the player does, untap those creatures.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
