extends CardScript
## Resuscitate — {1}{G} — Instant (uncommon, exo).
## Oracle: Until end of turn, creatures you control gain "{1}: Regenerate this creature."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Resuscitate", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Until end of turn, creatures you control gain \"{1}: Regenerate this creature.\"")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
