extends CardScript
## Foreshadow — {1}{U} — Instant (uncommon, vis).
## Oracle: Choose a card name, then target opponent mills a card. If a card with the chosen name was milled this way, you draw a card.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Foreshadow", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("Choose a card name, then target opponent mills a card. If a card with the chosen name was milled this way, you draw a card.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
