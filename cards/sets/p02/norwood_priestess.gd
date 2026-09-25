extends CardScript
## Norwood Priestess — {2}{G}{G} — Creature — Elf Druid — 1/1 (Portal Second Age, 1998).
## Oracle: {T}: You may put a green creature card from your hand onto the battlefield. Activate only during your turn, before attackers are declared.

func build() -> CardData:
	var c := CardData.new("Norwood Priestess", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","druid"])
	c.oracle("{T}: You may put a green creature card from your hand onto the battlefield. Activate only during your turn, before attackers are declared.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
