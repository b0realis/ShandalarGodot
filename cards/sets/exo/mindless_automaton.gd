extends CardScript
## Mindless Automaton — {4} — Artifact Creature — Construct (rare, exo).
## Oracle: This creature enters with two +1/+1 counters on it.
##         {1}, Discard a card: Put a +1/+1 counter on this creature.
##         Remove two +1/+1 counters from this creature: Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mindless Automaton", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 0)
	c.with_subtypes(["construct"])
	c.oracle("This creature enters with two +1/+1 counters on it.\n{1}, Discard a card: Put a +1/+1 counter on this creature.\nRemove two +1/+1 counters from this creature: Draw a card.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
