extends CardScript
## Crashing Boars — {3}{G}{G} — Creature — Boar (uncommon, exo).
## Oracle: Whenever this creature attacks, defending player chooses an untapped creature they control. That creature blocks this creature this turn if able.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crashing Boars", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["boar"])
	c.oracle("Whenever this creature attacks, defending player chooses an untapped creature they control. That creature blocks this creature this turn if able.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
