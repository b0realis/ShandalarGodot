extends CardScript
## Infernal Contract — {B}{B}{B} — Sorcery (rare, mir).
## Oracle: Draw four cards. You lose half your life, rounded up.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Infernal Contract", "{B}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Draw four cards. You lose half your life, rounded up.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
