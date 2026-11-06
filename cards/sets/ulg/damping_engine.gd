extends CardScript
## Damping Engine — {4} — Artifact (rare, ulg).
## Oracle: A player who controls more permanents than each other player can't play lands or cast artifact, creature, or enchantment spells. That player may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Damping Engine", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("A player who controls more permanents than each other player can't play lands or cast artifact, creature, or enchantment spells. That player may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
