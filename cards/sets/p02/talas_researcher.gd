extends CardScript
## Talas Researcher — {4}{U} — Creature — Human Pirate Wizard — 1/1 (Portal Second Age, 1998).
## Oracle: {T}: Draw a card. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Talas Researcher", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","pirate","wizard"])
	c.oracle("{T}: Draw a card. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
