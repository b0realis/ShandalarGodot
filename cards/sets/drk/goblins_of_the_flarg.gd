extends CardScript
## Goblins of the Flarg — {R} — Creature — Goblin Warrior — 1/1 — (drk, common)
## Oracle: Mountainwalk
##         When you control a Dwarf, sacrifice this creature.
##
## Implementation: printed mountainwalk plus the engine's
## with_sacrifice_if_you_control("dwarf") clause — a state-based check
## that fires the instant a Dwarf joins their controller's battlefield.
## The Dark's goblins-versus-dwarves flavour, enforced by the rules
## engine rather than by the honour system.


func build() -> CardData:
	return CardData.new("Goblins of the Flarg", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["goblin", "warrior"]) \
		.with_landwalk(["mountain"]) \
		.with_sacrifice_if_you_control("dwarf") \
		.oracle("Mountainwalk (This creature can't be blocked as long as defending "
			+ "player controls a Mountain.)\nWhen you control a Dwarf, sacrifice this "
			+ "creature.")
