extends CardScript
## Lion's Eye Diamond — {0} — Artifact (rare, mir).
## Oracle: Discard your hand, Sacrifice this artifact: Add three mana of any one color. Activate only as an instant.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lion's Eye Diamond", "{0}", Mtg.CardType.ARTIFACT)
	c.oracle("Discard your hand, Sacrifice this artifact: Add three mana of any one color. Activate only as an instant.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
