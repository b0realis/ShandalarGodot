extends CardScript
## Kyscu Drake — {3}{G} — Creature — Drake (uncommon, vis).
## Oracle: Flying
##         {G}: This creature gets +0/+1 until end of turn. Activate only once each turn.
##         Sacrifice this creature and a creature named Spitting Drake: Search your library for a card named Viashivan Dragon, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kyscu Drake", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{G}: This creature gets +0/+1 until end of turn. Activate only once each turn.\nSacrifice this creature and a creature named Spitting Drake: Search your library for a card named Viashivan Dragon, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
