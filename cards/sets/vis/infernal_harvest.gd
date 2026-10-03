extends CardScript
## Infernal Harvest — {1}{B} — Sorcery (common, vis).
## Oracle: As an additional cost to cast this spell, return X Swamps you control to their owner's hand.
##         Infernal Harvest deals X damage divided as you choose among any number of target creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Infernal Harvest", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, return X Swamps you control to their owner's hand.\nInfernal Harvest deals X damage divided as you choose among any number of target creatures.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
