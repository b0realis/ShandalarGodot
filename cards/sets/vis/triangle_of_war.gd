extends CardScript
## Triangle of War — {1} — Artifact (rare, vis).
## Oracle: {2}, Sacrifice this artifact: Target creature you control fights target creature an opponent controls. (Each deals damage equal to its power to the other.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Triangle of War", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, Sacrifice this artifact: Target creature you control fights target creature an opponent controls. (Each deals damage equal to its power to the other.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
