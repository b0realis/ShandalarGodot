extends CardScript
## Wicked Reward — {1}{B} — Instant (common, vis).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Target creature gets +4/+2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wicked Reward", "{1}{B}", Mtg.CardType.INSTANT)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nTarget creature gets +4/+2 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
