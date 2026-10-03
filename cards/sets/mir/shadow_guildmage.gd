extends CardScript
## Shadow Guildmage — {B} — Creature — Human Wizard (common, mir).
## Oracle: {U}, {T}: Put target creature you control on top of its owner's library.
##         {R}, {T}: This creature deals 1 damage to any target and 1 damage to you.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shadow Guildmage", "{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{U}, {T}: Put target creature you control on top of its owner's library.\n{R}, {T}: This creature deals 1 damage to any target and 1 damage to you.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
