extends CardScript
## Elvish Piper — {3}{G} — Creature — Elf Shaman (rare, uds).
## Oracle: {G}, {T}: You may put a creature card from your hand onto the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elvish Piper", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","shaman"])
	c.oracle("{G}, {T}: You may put a creature card from your hand onto the battlefield.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
