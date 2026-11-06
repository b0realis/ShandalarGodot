extends CardScript
## Angel's Trumpet — {3} — Artifact (uncommon, ulg).
## Oracle: All creatures have vigilance.
##         At the beginning of each player's end step, tap all untapped creatures that player controls that didn't attack this turn. This artifact deals damage to the player equal to the number of creatures tapped this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Angel's Trumpet", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("All creatures have vigilance.\nAt the beginning of each player's end step, tap all untapped creatures that player controls that didn't attack this turn. This artifact deals damage to the player equal to the number of creatures tapped this way.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
