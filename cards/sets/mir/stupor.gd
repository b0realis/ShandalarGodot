extends CardScript
## Stupor — {2}{B} — Sorcery (uncommon, mir).
## Oracle: Target opponent discards a card at random, then discards a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Stupor", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target opponent discards a card at random, then discards a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
