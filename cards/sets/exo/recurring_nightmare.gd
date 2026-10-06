extends CardScript
## Recurring Nightmare — {2}{B} — Enchantment (rare, exo).
## Oracle: Sacrifice a creature, Return this enchantment to its owner's hand: Return target creature card from your graveyard to the battlefield. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Recurring Nightmare", "{2}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Sacrifice a creature, Return this enchantment to its owner's hand: Return target creature card from your graveyard to the battlefield. Activate only as a sorcery.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
