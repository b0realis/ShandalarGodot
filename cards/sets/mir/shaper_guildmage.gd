extends CardScript
## Shaper Guildmage — {U} — Creature — Human Wizard (common, mir).
## Oracle: {W}, {T}: Target creature gains first strike until end of turn.
##         {B}, {T}: Target creature gets +1/+0 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shaper Guildmage", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{W}, {T}: Target creature gains first strike until end of turn.\n{B}, {T}: Target creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
