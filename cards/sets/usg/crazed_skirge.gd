extends CardScript
## Crazed Skirge — {3}{B} — Creature — Phyrexian Imp (uncommon, usg).
## Oracle: Flying, haste
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crazed Skirge", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","imp"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.HASTE])
	c.oracle("Flying, haste")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
