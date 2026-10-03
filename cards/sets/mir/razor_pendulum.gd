extends CardScript
## Razor Pendulum — {4} — Artifact (rare, mir).
## Oracle: At the beginning of each player's end step, if that player has 5 or less life, this artifact deals 2 damage to that player.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Razor Pendulum", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of each player's end step, if that player has 5 or less life, this artifact deals 2 damage to that player.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
