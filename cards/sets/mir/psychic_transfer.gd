extends CardScript
## Psychic Transfer — {4}{U} — Sorcery (rare, mir).
## Oracle: If the difference between your life total and target player's life total is 5 or less, exchange life totals with that player.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Psychic Transfer", "{4}{U}", Mtg.CardType.SORCERY)
	c.oracle("If the difference between your life total and target player's life total is 5 or less, exchange life totals with that player.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
