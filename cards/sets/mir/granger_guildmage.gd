extends CardScript
## Granger Guildmage — {G} — Creature — Human Wizard (common, mir).
## Oracle: {R}, {T}: This creature deals 1 damage to any target and 1 damage to you.
##         {W}, {T}: Target creature gains first strike until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Granger Guildmage", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{R}, {T}: This creature deals 1 damage to any target and 1 damage to you.\n{W}, {T}: Target creature gains first strike until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
