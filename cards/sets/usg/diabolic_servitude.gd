extends CardScript
## Diabolic Servitude — {3}{B} — Enchantment (uncommon, usg).
## Oracle: When this enchantment enters, return target creature card from your graveyard to the battlefield.
##         When the creature put onto the battlefield with this enchantment dies, exile it and return this enchantment to its owner's hand.
##         When this enchantment leaves the battlefield, exile the creature put onto the battlefield with this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Diabolic Servitude", "{3}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When this enchantment enters, return target creature card from your graveyard to the battlefield.\nWhen the creature put onto the battlefield with this enchantment dies, exile it and return this enchantment to its owner's hand.\nWhen this enchantment leaves the battlefield, exile the creature put onto the battlefield with this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
