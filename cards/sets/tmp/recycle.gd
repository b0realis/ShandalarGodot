extends CardScript
## Recycle — {4}{G}{G} — Enchantment (rare, tmp).
## Oracle: Skip your draw step.
##         Whenever you play a card, draw a card.
##         Your maximum hand size is two.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Recycle", "{4}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Skip your draw step.\nWhenever you play a card, draw a card.\nYour maximum hand size is two.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
