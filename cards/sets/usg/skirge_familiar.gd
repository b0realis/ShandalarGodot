extends CardScript
## Skirge Familiar — {4}{B} — Creature — Phyrexian Imp (uncommon, usg).
## Oracle: Flying
##         Discard a card: Add {B}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skirge Familiar", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["phyrexian","imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nDiscard a card: Add {B}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
