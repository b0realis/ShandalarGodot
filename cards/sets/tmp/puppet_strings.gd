extends CardScript
## Puppet Strings — {3} — Artifact (uncommon, tmp).
## Oracle: {2}, {T}: You may tap or untap target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Puppet Strings", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}: You may tap or untap target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
