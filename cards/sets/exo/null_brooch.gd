extends CardScript
## Null Brooch — {4} — Artifact (rare, exo).
## Oracle: {2}, {T}, Discard your hand: Counter target noncreature spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Null Brooch", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}, Discard your hand: Counter target noncreature spell.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
