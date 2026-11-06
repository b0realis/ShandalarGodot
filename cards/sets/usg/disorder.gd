extends CardScript
## Disorder — {1}{R} — Sorcery (uncommon, usg).
## Oracle: Disorder deals 2 damage to each white creature and each player who controls a white creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disorder", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Disorder deals 2 damage to each white creature and each player who controls a white creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
