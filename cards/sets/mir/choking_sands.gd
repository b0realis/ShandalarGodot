extends CardScript
## Choking Sands — {1}{B}{B} — Sorcery (common, mir).
## Oracle: Destroy target non-Swamp land. If that land was nonbasic, Choking Sands deals 2 damage to the land's controller.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Choking Sands", "{1}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target non-Swamp land. If that land was nonbasic, Choking Sands deals 2 damage to the land's controller.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
