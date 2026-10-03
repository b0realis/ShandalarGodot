extends CardScript
## Sidar Jabari — {3}{W} — Legendary Creature — Human Knight (rare, mir).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         Whenever Sidar Jabari attacks, tap target creature defending player controls.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sidar Jabari", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\nWhenever Sidar Jabari attacks, tap target creature defending player controls.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
