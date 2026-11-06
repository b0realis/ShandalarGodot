extends CardScript
## Goblin Offensive — {X}{1}{R}{R} — Sorcery (uncommon, usg).
## Oracle: Create X 1/1 red Goblin creature tokens.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Offensive", "{X}{1}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Create X 1/1 red Goblin creature tokens.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
