extends CardScript
## Thumbscrews — {2} — Artifact (rare, tmp).
## Oracle: At the beginning of your upkeep, if you have five or more cards in hand, this artifact deals 1 damage to target opponent or planeswalker.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thumbscrews", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, if you have five or more cards in hand, this artifact deals 1 damage to target opponent or planeswalker.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
