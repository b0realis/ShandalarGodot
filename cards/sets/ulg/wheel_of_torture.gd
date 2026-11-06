extends CardScript
## Wheel of Torture — {3} — Artifact (rare, ulg).
## Oracle: At the beginning of each opponent's upkeep, this artifact deals X damage to that player, where X is 3 minus the number of cards in their hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wheel of Torture", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each opponent's upkeep, this artifact deals X damage to that player, where X is 3 minus the number of cards in their hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
