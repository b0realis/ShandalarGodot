extends CardScript
## Workhorse — {6} — Artifact Creature — Horse (rare, exo).
## Oracle: This creature enters with four +1/+1 counters on it.
##         Remove a +1/+1 counter from this creature: Add {C}.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Workhorse", "{6}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 0)
	c.with_subtypes(["horse"])
	c.oracle("This creature enters with four +1/+1 counters on it.\nRemove a +1/+1 counter from this creature: Add {C}.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
