extends CardScript
## Dragon Mask — {3} — Artifact (uncommon, vis).
## Oracle: {3}, {T}: Target creature you control gets +2/+2 until end of turn. Return it to its owner's hand at the beginning of the next end step. (Return it only if it's on the battlefield.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dragon Mask", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Target creature you control gets +2/+2 until end of turn. Return it to its owner's hand at the beginning of the next end step. (Return it only if it's on the battlefield.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
