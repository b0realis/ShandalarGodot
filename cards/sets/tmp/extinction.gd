extends CardScript
## Extinction — {4}{B} — Sorcery (rare, tmp).
## Oracle: Destroy all creatures of the creature type of your choice.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Extinction", "{4}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures of the creature type of your choice.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
