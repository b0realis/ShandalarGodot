extends CardScript
## Capricious Sorcerer — {2}{U} — Creature — Human Wizard Sorcerer (Portal, 1997).
## Oracle: {T}: This creature deals 1 damage to any target. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Capricious Sorcerer", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human", "wizard", "sorcerer"])
	c.oracle("{T}: This creature deals 1 damage to any target. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
