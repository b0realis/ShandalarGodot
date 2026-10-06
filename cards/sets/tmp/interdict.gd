extends CardScript
## Interdict — {1}{U} — Instant (uncommon, tmp).
## Oracle: Counter target activated ability from an artifact, creature, enchantment, or land. That permanent's activated abilities can't be activated this turn. (Mana abilities can't be targeted.)
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Interdict", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target activated ability from an artifact, creature, enchantment, or land. That permanent's activated abilities can't be activated this turn. (Mana abilities can't be targeted.)\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
