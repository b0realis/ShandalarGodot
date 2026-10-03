extends CardScript
## Paupers' Cage — {3} — Artifact (rare, mir).
## Oracle: At the beginning of each opponent's upkeep, if that player has two or fewer cards in hand, this artifact deals 2 damage to that player.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Paupers' Cage", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each opponent's upkeep, if that player has two or fewer cards in hand, this artifact deals 2 damage to that player.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
