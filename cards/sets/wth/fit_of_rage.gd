extends CardScript
## Fit of Rage — {1}{R} — Sorcery (common, wth).
## Oracle: Target creature gets +3/+3 and gains first strike until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fit of Rage", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gets +3/+3 and gains first strike until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
