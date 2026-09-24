extends CardScript
## Raging Goblin — {R} — Creature — Goblin Berserker (Portal, 1997).
## Oracle: Haste (This creature can attack and {T} as soon as it comes under your control.)

func build() -> CardData:
	var c := CardData.new("Raging Goblin", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin", "berserker"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste (This creature can attack and {T} as soon as it comes under your control.)")
	return c
