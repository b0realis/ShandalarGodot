extends CardScript
## Thran Turbine — {1} — Artifact (uncommon, usg).
## Oracle: At the beginning of your upkeep, you may add {C}{C}. This mana can't be spent to cast spells.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Turbine", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("At the beginning of your upkeep, you may add {C}{C}. This mana can't be spent to cast spells.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
