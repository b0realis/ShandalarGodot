extends CardScript
## Ivy Seer — {3}{G} — Creature — Elf Wizard (uncommon, uds).
## Oracle: {2}{G}, {T}: Reveal any number of green cards in your hand. Target creature gets +X/+X until end of turn, where X is the number of cards revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ivy Seer", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","wizard"])
	c.oracle("{2}{G}, {T}: Reveal any number of green cards in your hand. Target creature gets +X/+X until end of turn, where X is the number of cards revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
