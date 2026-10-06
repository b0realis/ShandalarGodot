extends CardScript
## Torture Chamber — {3} — Artifact (rare, tmp).
## Oracle: At the beginning of your upkeep, put a pain counter on this artifact.
##         At the beginning of your end step, this artifact deals damage to you equal to the number of pain counters on it.
##         {1}, {T}, Remove all pain counters from this artifact: It deals damage to target creature equal to the number of pain counters removed this way.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Torture Chamber", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, put a pain counter on this artifact.\nAt the beginning of your end step, this artifact deals damage to you equal to the number of pain counters on it.\n{1}, {T}, Remove all pain counters from this artifact: It deals damage to target creature equal to the number of pain counters removed this way.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
