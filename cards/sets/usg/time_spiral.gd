extends CardScript
## Time Spiral — {4}{U}{U} — Sorcery (rare, usg).
## Oracle: Exile Time Spiral. Each player shuffles their hand and graveyard into their library, then draws seven cards. You untap up to six lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Time Spiral", "{4}{U}{U}", Mtg.CardType.SORCERY)
	c.oracle("Exile Time Spiral. Each player shuffles their hand and graveyard into their library, then draws seven cards. You untap up to six lands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
