extends CardScript
## Corrosion — {1}{B}{R} — Enchantment (rare, vis).
## Oracle: Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         At the beginning of your upkeep, put a rust counter on each artifact target opponent controls. Then destroy each artifact with mana value less than or equal to the number of rust counters on it. Artifacts destroyed this way can't be regenerated.
##         When this enchantment leaves the battlefield, remove all rust counters from all permanents.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Corrosion", "{1}{B}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nAt the beginning of your upkeep, put a rust counter on each artifact target opponent controls. Then destroy each artifact with mana value less than or equal to the number of rust counters on it. Artifacts destroyed this way can't be regenerated.\nWhen this enchantment leaves the battlefield, remove all rust counters from all permanents.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
