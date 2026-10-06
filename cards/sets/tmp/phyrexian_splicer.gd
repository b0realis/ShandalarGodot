extends CardScript
## Phyrexian Splicer — {2} — Artifact (uncommon, tmp).
## Oracle: {2}, {T}, Choose flying, first strike, trample, or shadow: Until end of turn, target creature with the chosen ability loses it and another target creature gains it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Splicer", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}, Choose flying, first strike, trample, or shadow: Until end of turn, target creature with the chosen ability loses it and another target creature gains it.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
