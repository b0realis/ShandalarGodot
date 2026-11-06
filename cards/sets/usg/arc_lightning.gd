extends CardScript
## Arc Lightning — {2}{R} — Sorcery (common, usg).
## Oracle: Arc Lightning deals 3 damage divided as you choose among one, two, or three targets.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Arc Lightning", "{2}{R}", Mtg.CardType.SORCERY)
	c.oracle("Arc Lightning deals 3 damage divided as you choose among one, two, or three targets.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
