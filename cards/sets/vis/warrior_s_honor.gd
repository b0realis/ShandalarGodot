extends CardScript
## Warrior's Honor — {2}{W} — Instant (common, vis).
## Oracle: Creatures you control get +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Warrior's Honor", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Creatures you control get +1/+1 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
