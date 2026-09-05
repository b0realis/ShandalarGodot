extends CardScript
## Bartel Runeaxe — {3}{B}{R}{G} — Legendary Creature — Giant Warrior — 6/5 — (leg, rare)
## Oracle: Vigilance
##         Bartel Runeaxe can't be the target of Aura spells.
##
## Implementation: printed vigilance plus the "no aura targeting" flag —
## Paralyze, Weakness and Control Magic simply cannot be aimed at him.
## A 6/5 that attacks and blocks every turn and shrugs off the era's
## favourite removal.


func build() -> CardData:
	return CardData.new("Bartel Runeaxe", "{3}{B}{R}{G}", Mtg.CardType.CREATURE) \
		.pt(6, 5) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["giant", "warrior"]) \
		.with_keywords([Mtg.Keyword.VIGILANCE]) \
		.with_no_aura_targeting() \
		.oracle("Vigilance\nBartel Runeaxe can't be the target of Aura spells.")
