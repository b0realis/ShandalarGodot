extends CardScript
## Cannibalize — {1}{B} — Sorcery (common, sth).
## Oracle: Choose two target creatures controlled by the same player. Exile one of those creatures and put two +1/+1 counters on the other.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cannibalize", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("Choose two target creatures controlled by the same player. Exile one of those creatures and put two +1/+1 counters on the other.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
