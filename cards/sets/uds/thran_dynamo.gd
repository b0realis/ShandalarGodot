extends CardScript
## Thran Dynamo — {4} — Artifact (uncommon, uds).
## Oracle: {T}: Add {C}{C}{C}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran Dynamo", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Add {C}{C}{C}.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
