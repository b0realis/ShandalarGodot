extends CardScript
## Meltdown — {X}{R} — Sorcery (uncommon, usg).
## Oracle: Destroy each artifact with mana value X or less.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Meltdown", "{X}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy each artifact with mana value X or less.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
