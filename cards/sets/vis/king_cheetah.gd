extends CardScript
## King Cheetah — {3}{G} — Creature — Cat (common, vis).
## Oracle: Flash
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("King Cheetah", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["cat"])
	c.oracle("Flash")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
