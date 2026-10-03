extends CardScript
## Gossamer Chains — {W}{W} — Enchantment (common, vis).
## Oracle: Return this enchantment to its owner's hand: Prevent all combat damage that would be dealt by target unblocked creature this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gossamer Chains", "{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Return this enchantment to its owner's hand: Prevent all combat damage that would be dealt by target unblocked creature this turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
