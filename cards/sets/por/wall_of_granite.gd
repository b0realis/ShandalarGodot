extends CardScript
## Wall of Granite — {2}{R} — Creature — Wall (Portal, 1997).
## Oracle: Defender (This creature can't attack.)

func build() -> CardData:
	var c := CardData.new("Wall of Granite", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 7)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)")
	return c
