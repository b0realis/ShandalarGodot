extends CardScript
## Civic Guildmage — {W} — Creature — Human Wizard (common, mir).
## Oracle: {G}, {T}: Target creature gets +0/+1 until end of turn.
##         {U}, {T}: Put target creature you control on top of its owner's library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Civic Guildmage", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{G}, {T}: Target creature gets +0/+1 until end of turn.\n{U}, {T}: Put target creature you control on top of its owner's library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
