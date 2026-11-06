extends CardScript
## Phyrexian Reclamation — {B} — Enchantment (uncommon, ulg).
## Oracle: {1}{B}, Pay 2 life: Return target creature card from your graveyard to your hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Reclamation", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}{B}, Pay 2 life: Return target creature card from your graveyard to your hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
