extends CardScript
## Perish — {2}{B} — Sorcery (uncommon, tmp).
## Oracle: Destroy all green creatures. They can't be regenerated.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Perish", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all green creatures. They can't be regenerated.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
