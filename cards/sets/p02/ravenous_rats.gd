extends CardScript
## Ravenous Rats — {1}{B} — Creature — Rat — 1/1 (Portal Second Age, 1998).
## Oracle: When this creature enters, target opponent discards a card.

func build() -> CardData:
	var c := CardData.new("Ravenous Rats", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["rat"])
	c.oracle("When this creature enters, target opponent discards a card.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
