extends CardScript
## Coastal Wizard — {2}{U}{U} — Creature — Human Wizard — 1/1 (Portal Second Age, 1998).
## Oracle: {T}: Return this creature and another target creature to their owners' hands. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Coastal Wizard", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}: Return this creature and another target creature to their owners' hands. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
