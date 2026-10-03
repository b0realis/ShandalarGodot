extends CardScript
## Kaervek's Torch — {X}{R} — Sorcery (common, mir).
## Oracle: As long as Kaervek's Torch is on the stack, spells that target it cost {2} more to cast.
##         Kaervek's Torch deals X damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kaervek's Torch", "{X}{R}", Mtg.CardType.SORCERY)
	c.oracle("As long as Kaervek's Torch is on the stack, spells that target it cost {2} more to cast.\nKaervek's Torch deals X damage to any target.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
