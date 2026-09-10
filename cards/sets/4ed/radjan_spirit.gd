extends CardScript
## Radjan Spirit — {3}{G} — Creature — Spirit — 3/2 — (4ed, uncommon)
## Oracle: {T}: Target creature loses flying until end of turn.
##
## Implementation: LoseAbilityEffect stripping FLYING for the turn. Since
## 2026-09-10 the continuous pipeline applies layer-6 grants and losses in
## TIMESTAMP order (CR 613.7), so this grounds a Flight aura and every
## earlier Jump — and a Jump cast AFTER it puts the wings back. Green's
## repeatable answer to a Serra Angel: ground it, then block it, and hold
## the block until their blue mana is spent.


func build() -> CardData:
	return CardData.new("Radjan Spirit", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 2) \
		.with_subtypes(["spirit"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([Mtg.Keyword.FLYING], "flying")],
			"{T}: Target creature loses flying until end of turn.")) \
		.oracle("{T}: Target creature loses flying until end of turn.")
