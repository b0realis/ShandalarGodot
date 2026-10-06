extends CardScript
## Excavator — {2} — Artifact (uncommon, tmp).
## Oracle: {T}, Sacrifice a basic land: Target creature gains landwalk of each of the land types of the sacrificed land until end of turn. (It can't be blocked as long as defending player controls a land of any of those types.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Excavator", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}, Sacrifice a basic land: Target creature gains landwalk of each of the land types of the sacrificed land until end of turn. (It can't be blocked as long as defending player controls a land of any of those types.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
