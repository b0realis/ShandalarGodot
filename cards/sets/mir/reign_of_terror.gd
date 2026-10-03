extends CardScript
## Reign of Terror — {3}{B}{B} — Sorcery (uncommon, mir).
## Oracle: Destroy all green creatures or all white creatures. They can't be regenerated. You lose 2 life for each creature that died this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reign of Terror", "{3}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all green creatures or all white creatures. They can't be regenerated. You lose 2 life for each creature that died this way.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
