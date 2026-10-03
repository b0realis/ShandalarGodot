extends CardScript
## Energy Vortex — {3}{U}{U} — Enchantment (rare, mir).
## Oracle: As this enchantment enters, choose an opponent.
##         At the beginning of your upkeep, remove all vortex counters from this enchantment.
##         At the beginning of the chosen player's upkeep, this enchantment deals 3 damage to that player unless they pay {1} for each vortex counter on this enchantment.
##         {X}: Put X vortex counters on this enchantment. Activate only during your upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Energy Vortex", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("As this enchantment enters, choose an opponent.\nAt the beginning of your upkeep, remove all vortex counters from this enchantment.\nAt the beginning of the chosen player's upkeep, this enchantment deals 3 damage to that player unless they pay {1} for each vortex counter on this enchantment.\n{X}: Put X vortex counters on this enchantment. Activate only during your upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
