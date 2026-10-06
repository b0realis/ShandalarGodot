extends CardScript
## Scapegoat — {W} — Instant (uncommon, sth).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Return any number of target creatures you control to their owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scapegoat", "{W}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nReturn any number of target creatures you control to their owner's hand.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
