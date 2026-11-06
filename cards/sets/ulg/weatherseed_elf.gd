extends CardScript
## Weatherseed Elf — {G} — Creature — Elf (common, ulg).
## Oracle: {T}: Target creature gains forestwalk until end of turn. (It can't be blocked as long as defending player controls a Forest.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Weatherseed Elf", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf"])
	c.oracle("{T}: Target creature gains forestwalk until end of turn. (It can't be blocked as long as defending player controls a Forest.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
