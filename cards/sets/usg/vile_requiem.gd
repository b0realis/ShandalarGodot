extends CardScript
## Vile Requiem — {2}{B}{B} — Enchantment (uncommon, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         {1}{B}, Sacrifice this enchantment: Destroy up to X target nonblack creatures, where X is the number of verse counters on this enchantment. They can't be regenerated.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vile Requiem", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\n{1}{B}, Sacrifice this enchantment: Destroy up to X target nonblack creatures, where X is the number of verse counters on this enchantment. They can't be regenerated.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
