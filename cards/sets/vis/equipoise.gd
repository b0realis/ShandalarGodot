extends CardScript
## Equipoise — {2}{W} — Enchantment (rare, vis).
## Oracle: At the beginning of your upkeep, for each land target player controls in excess of the number you control, choose a land that player controls, then the chosen permanents phase out. Repeat this process for artifacts and creatures. (While they're phased out, they're treated as though they don't exist. They phase in before that player untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Equipoise", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, for each land target player controls in excess of the number you control, choose a land that player controls, then the chosen permanents phase out. Repeat this process for artifacts and creatures. (While they're phased out, they're treated as though they don't exist. They phase in before that player untaps during their next untap step.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
