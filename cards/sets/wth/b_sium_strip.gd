extends CardScript
## Bösium Strip — {3} — Artifact (rare, wth).
## Oracle: {3}, {T}: Until end of turn, you may cast instant and sorcery spells from the top of your graveyard. If a spell cast this way would be put into a graveyard, exile it instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bösium Strip", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Until end of turn, you may cast instant and sorcery spells from the top of your graveyard. If a spell cast this way would be put into a graveyard, exile it instead.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
