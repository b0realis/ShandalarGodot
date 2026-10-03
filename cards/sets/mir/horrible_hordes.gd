extends CardScript
## Horrible Hordes — {3} — Artifact Creature — Spirit (uncommon, mir).
## Oracle: Rampage 1 (Whenever this creature becomes blocked, it gets +1/+1 until end of turn for each creature blocking it beyond the first.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Horrible Hordes", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 2)
	c.with_subtypes(["spirit"])
	c.oracle("Rampage 1 (Whenever this creature becomes blocked, it gets +1/+1 until end of turn for each creature blocking it beyond the first.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
