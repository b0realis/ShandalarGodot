extends CardScript
## Ensnaring Bridge — {3} — Artifact (rare, sth).
## Oracle: Creatures with power greater than the number of cards in your hand can't attack.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ensnaring Bridge", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Creatures with power greater than the number of cards in your hand can't attack.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
