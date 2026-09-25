extends CardScript
## Lurking Nightstalker — {B}{B} — Creature — Nightstalker — 1/1 (Portal Second Age, 1998).
## Oracle: Whenever this creature attacks, it gets +2/+0 until end of turn.

func build() -> CardData:
	var c := CardData.new("Lurking Nightstalker", "{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["nightstalker"])
	c.oracle("Whenever this creature attacks, it gets +2/+0 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
