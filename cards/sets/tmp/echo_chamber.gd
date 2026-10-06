extends CardScript
## Echo Chamber — {4} — Artifact (rare, tmp).
## Oracle: {4}, {T}: An opponent chooses target creature they control. Create a token that's a copy of that creature. That token gains haste until end of turn. Exile the token at the beginning of the next end step. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Echo Chamber", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{4}, {T}: An opponent chooses target creature they control. Create a token that's a copy of that creature. That token gains haste until end of turn. Exile the token at the beginning of the next end step. Activate only as a sorcery.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
