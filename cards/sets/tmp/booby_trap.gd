extends CardScript
## Booby Trap — {6} — Artifact (rare, tmp).
## Oracle: As this artifact enters, choose an opponent and a card name other than a basic land card name.
##         The chosen player reveals each card they draw.
##         When the chosen player draws a card with the chosen name, sacrifice this artifact. If you do, this artifact deals 10 damage to that player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Booby Trap", "{6}", Mtg.CardType.ARTIFACT)
	c.oracle("As this artifact enters, choose an opponent and a card name other than a basic land card name.\nThe chosen player reveals each card they draw.\nWhen the chosen player draws a card with the chosen name, sacrifice this artifact. If you do, this artifact deals 10 damage to that player.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
