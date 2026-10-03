extends CardScript
## Fallow Earth — {2}{G} — Sorcery (uncommon, mir).
## Oracle: Put target land on top of its owner's library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fallow Earth", "{2}{G}", Mtg.CardType.SORCERY)
	c.oracle("Put target land on top of its owner's library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
