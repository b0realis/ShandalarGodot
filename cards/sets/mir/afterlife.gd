extends CardScript
## Afterlife — {2}{W} — Instant (uncommon, mir).
## Oracle: Destroy target creature. It can't be regenerated. Its controller creates a 1/1 white Spirit creature token with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Afterlife", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target creature. It can't be regenerated. Its controller creates a 1/1 white Spirit creature token with flying.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
