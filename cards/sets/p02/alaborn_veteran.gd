extends CardScript
## Alaborn Veteran — {2}{W} — Creature — Human Knight — 2/2 (Portal Second Age, 1998).
## Oracle: {T}: Target creature gets +2/+2 until end of turn. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Alaborn Veteran", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("{T}: Target creature gets +2/+2 until end of turn. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
