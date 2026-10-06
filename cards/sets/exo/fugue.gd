extends CardScript
## Fugue — {3}{B}{B} — Sorcery (uncommon, exo).
## Oracle: Target player discards three cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fugue", "{3}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target player discards three cards.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
