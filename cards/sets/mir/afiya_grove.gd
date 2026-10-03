extends CardScript
## Afiya Grove — {1}{G} — Enchantment (rare, mir).
## Oracle: This enchantment enters with three +1/+1 counters on it.
##         At the beginning of your upkeep, move a +1/+1 counter from this enchantment onto target creature.
##         When this enchantment has no +1/+1 counters on it, sacrifice it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Afiya Grove", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("This enchantment enters with three +1/+1 counters on it.\nAt the beginning of your upkeep, move a +1/+1 counter from this enchantment onto target creature.\nWhen this enchantment has no +1/+1 counters on it, sacrifice it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
