extends CardScript
## Discordant Dirge — {3}{B}{B} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         {B}, Sacrifice this enchantment: Look at target opponent's hand and choose up to X cards from it, where X is the number of verse counters on this enchantment. That player discards those cards.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Discordant Dirge", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\n{B}, Sacrifice this enchantment: Look at target opponent's hand and choose up to X cards from it, where X is the number of verse counters on this enchantment. That player discards those cards.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
