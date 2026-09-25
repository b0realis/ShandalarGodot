extends CardScript
## Apprentice Sorcerer — {2}{U} — Creature — Human Wizard Sorcerer — 1/1 (Portal Second Age, 1998).
## Oracle: {T}: This creature deals 1 damage to any target. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Apprentice Sorcerer", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard","sorcerer"])
	c.oracle("{T}: This creature deals 1 damage to any target. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
