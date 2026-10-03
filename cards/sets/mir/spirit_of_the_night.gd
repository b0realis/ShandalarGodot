extends CardScript
## Spirit of the Night — {6}{B}{B}{B} — Legendary Creature — Demon Spirit (rare, mir).
## Oracle: Flying, trample, haste, protection from black
##         Spirit of the Night has first strike as long as it's attacking.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spirit of the Night", "{6}{B}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(6, 5)
	c.with_subtypes(["demon","spirit"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE, Mtg.Keyword.HASTE])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Flying, trample, haste, protection from black\nSpirit of the Night has first strike as long as it's attacking.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
