extends CardScript
## Voltaic Key — {1} — Artifact (uncommon, usg).
## Oracle: {1}, {T}: Untap target artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Voltaic Key", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, {T}: Untap target artifact.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
