extends CardScript
## Ventifact Bottle — {3} — Artifact (rare, mir).
## Oracle: {X}{1}, {T}: Put X charge counters on this artifact. Activate only as a sorcery.
##         At the beginning of your first main phase, if this artifact has a charge counter on it, tap it and remove all charge counters from it. Add {C} for each charge counter removed this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ventifact Bottle", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{X}{1}, {T}: Put X charge counters on this artifact. Activate only as a sorcery.\nAt the beginning of your first main phase, if this artifact has a charge counter on it, tap it and remove all charge counters from it. Add {C} for each charge counter removed this way.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
