extends CardScript
## Radjan Spirit — {3}{G} — Creature — Spirit — 3/2 — (4ed, uncommon)
## Oracle: {T}: Target creature loses flying until end of turn.
##
## Implementation: LoseAbilityEffect stripping FLYING for the turn — the
## continuous pipeline applies losses after every granting pass, so a
## Flight aura is neutralized too. Green's repeatable answer to a Serra
## Angel: ground it, then block it.


func build() -> CardData:
	return CardData.new("Radjan Spirit", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 2) \
		.with_subtypes(["spirit"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([Mtg.Keyword.FLYING], "flying")],
			"{T}: Target creature loses flying until end of turn.")) \
		.oracle("{T}: Target creature loses flying until end of turn.")
