extends CardScript
## Twitch — {2}{U} — Instant (common, tmp).
## Oracle: You may tap or untap target artifact, creature, or land.
##         Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Twitch", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("You may tap or untap target artifact, creature, or land.\nDraw a card.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
