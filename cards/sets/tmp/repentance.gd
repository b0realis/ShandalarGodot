extends CardScript
## Repentance — {2}{W} — Sorcery (uncommon, tmp).
## Oracle: Target creature deals damage to itself equal to its power.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Repentance", "{2}{W}", Mtg.CardType.SORCERY)
	c.oracle("Target creature deals damage to itself equal to its power.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
