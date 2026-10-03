extends CardScript
## Juju Bubble — {1} — Artifact (uncommon, vis).
## Oracle: Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         When you play a card, sacrifice this artifact.
##         {2}: You gain 1 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Juju Bubble", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nWhen you play a card, sacrifice this artifact.\n{2}: You gain 1 life.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
