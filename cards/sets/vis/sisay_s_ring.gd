extends CardScript
## Sisay's Ring — {4} — Artifact (common, vis).
## Oracle: {T}: Add {C}{C}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sisay's Ring", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Add {C}{C}.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
