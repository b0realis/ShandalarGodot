extends CardScript
## Noetic Scales — {4} — Artifact (rare, usg).
## Oracle: At the beginning of each player's upkeep, return to its owner's hand each creature that player controls with power greater than the number of cards in their hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Noetic Scales", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each player's upkeep, return to its owner's hand each creature that player controls with power greater than the number of cards in their hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
