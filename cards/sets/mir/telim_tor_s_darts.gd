extends CardScript
## Telim'Tor's Darts — {2} — Artifact (uncommon, mir).
## Oracle: {2}, {T}: This artifact deals 1 damage to target player or planeswalker.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Telim'Tor's Darts", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}: This artifact deals 1 damage to target player or planeswalker.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
