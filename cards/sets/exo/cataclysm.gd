extends CardScript
## Cataclysm — {2}{W}{W} — Sorcery (rare, exo).
## Oracle: Each player chooses from among the permanents they control an artifact, a creature, an enchantment, and a land, then sacrifices the rest.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cataclysm", "{2}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("Each player chooses from among the permanents they control an artifact, a creature, an enchantment, and a land, then sacrifices the rest.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
