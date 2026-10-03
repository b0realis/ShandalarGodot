extends CardScript
## Quirion Druid — {2}{G} — Creature — Elf Druid (rare, vis).
## Oracle: {G}, {T}: Target land becomes a 2/2 green creature that's still a land. (This effect lasts indefinitely.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quirion Druid", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["elf","druid"])
	c.oracle("{G}, {T}: Target land becomes a 2/2 green creature that's still a land. (This effect lasts indefinitely.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
