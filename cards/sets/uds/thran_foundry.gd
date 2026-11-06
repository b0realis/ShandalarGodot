extends CardScript
## Thran Foundry — {1} — Artifact (uncommon, uds).
## Oracle: {1}, {T}, Exile this artifact: Target player shuffles their graveyard into their library.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Foundry", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, {T}, Exile this artifact: Target player shuffles their graveyard into their library.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
