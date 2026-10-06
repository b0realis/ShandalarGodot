extends CardScript
## Death Stroke — {B}{B} — Sorcery (common, sth).
## Oracle: Destroy target tapped creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Death Stroke", "{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target tapped creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
