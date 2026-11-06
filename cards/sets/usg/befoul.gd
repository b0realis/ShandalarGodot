extends CardScript
## Befoul — {2}{B}{B} — Sorcery (common, usg).
## Oracle: Destroy target land or nonblack creature. It can't be regenerated.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Befoul", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target land or nonblack creature. It can't be regenerated.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
