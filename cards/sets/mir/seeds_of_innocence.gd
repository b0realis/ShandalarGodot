extends CardScript
## Seeds of Innocence — {1}{G}{G} — Sorcery (rare, mir).
## Oracle: Destroy all artifacts. They can't be regenerated. The controller of each of those artifacts gains life equal to its mana value.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Seeds of Innocence", "{1}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all artifacts. They can't be regenerated. The controller of each of those artifacts gains life equal to its mana value.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
