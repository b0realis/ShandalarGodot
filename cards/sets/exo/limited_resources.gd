extends CardScript
## Limited Resources — {W} — Enchantment (rare, exo).
## Oracle: When this enchantment enters, each player chooses five lands they control and sacrifices the rest.
##         Players can't play lands as long as ten or more lands are on the battlefield.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Limited Resources", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When this enchantment enters, each player chooses five lands they control and sacrifices the rest.\nPlayers can't play lands as long as ten or more lands are on the battlefield.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
