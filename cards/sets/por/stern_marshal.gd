extends CardScript
## Stern Marshal — {2}{W} — Creature — Human Soldier (Portal, 1997).
## Oracle: {T}: Target creature gets +2/+2 until end of turn. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Stern Marshal", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human", "soldier"])
	c.oracle("{T}: Target creature gets +2/+2 until end of turn. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
