extends CardScript
## Bone Harvest — {2}{B} — Instant (common, mir).
## Oracle: Put any number of target creature cards from your graveyard on top of your library.
##         Draw a card at the beginning of the next turn's upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bone Harvest", "{2}{B}", Mtg.CardType.INSTANT)
	c.oracle("Put any number of target creature cards from your graveyard on top of your library.\nDraw a card at the beginning of the next turn's upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
