extends CardScript
## Festering Wound — {1}{B} — Enchantment — Aura (uncommon, uds).
## Oracle: Enchant creature
##         At the beginning of your upkeep, you may put an infection counter on this Aura.
##         At the beginning of the upkeep of enchanted creature's controller, this Aura deals X damage to that player, where X is the number of infection counters on this Aura.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Festering Wound", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of your upkeep, you may put an infection counter on this Aura.\nAt the beginning of the upkeep of enchanted creature's controller, this Aura deals X damage to that player, where X is the number of infection counters on this Aura.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
