extends CardScript
## Elven Rite — {1}{G} — Sorcery (uncommon, sth).
## Oracle: Distribute two +1/+1 counters among one or two target creatures.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elven Rite", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("Distribute two +1/+1 counters among one or two target creatures.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
