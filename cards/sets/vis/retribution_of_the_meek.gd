extends CardScript
## Retribution of the Meek — {2}{W} — Sorcery (rare, vis).
## Oracle: Destroy all creatures with power 4 or greater. They can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Retribution of the Meek", "{2}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures with power 4 or greater. They can't be regenerated.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
