extends CardScript
## Armorer Guildmage — {R} — Creature — Human Wizard (common, mir).
## Oracle: {B}, {T}: Target creature gets +1/+0 until end of turn.
##         {G}, {T}: Target creature gets +0/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Armorer Guildmage", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{B}, {T}: Target creature gets +1/+0 until end of turn.\n{G}, {T}: Target creature gets +0/+1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
