extends CardScript
## Teeka's Dragon — {9} — Artifact Creature — Dragon (rare, mir).
## Oracle: Flying; trample; rampage 4 (Whenever this creature becomes blocked, it gets +4/+4 until end of turn for each creature blocking it beyond the first.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teeka's Dragon", "{9}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(5, 5)
	c.with_subtypes(["dragon"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE])
	c.oracle("Flying; trample; rampage 4 (Whenever this creature becomes blocked, it gets +4/+4 until end of turn for each creature blocking it beyond the first.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
