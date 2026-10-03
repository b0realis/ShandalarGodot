extends CardScript
## Goblin Scouts — {3}{R}{R} — Sorcery (uncommon, mir).
## Oracle: Create three 1/1 red Goblin Scout creature tokens with mountainwalk. (They can't be blocked as long as defending player controls a Mountain.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Scouts", "{3}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Create three 1/1 red Goblin Scout creature tokens with mountainwalk. (They can't be blocked as long as defending player controls a Mountain.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
