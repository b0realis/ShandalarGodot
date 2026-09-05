extends CardScript
## Coal Golem — {5} — Artifact Creature — Golem — 3/3 — (drk, uncommon)
## Oracle: {3}, Sacrifice this creature: Add {R}{R}{R}.
##
## Implementation: a COSTED mana ability ({3} paid from the floating pool
## — mana abilities resolve mid-payment, no auto-tapping) with the
## Black Lotus sacrifice rider. The printed cost has NO {T}, so the
## ability is .without_tap(): CR 302.6's summoning-sickness gate applies
## only to {T} costs, and the Golem can therefore be cashed in the turn it
## arrives, after attacking, or while it sits tapped under an Icy.


func build() -> CardData:
	return CardData.new("Coal Golem", "{5}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["golem"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.R, 3) \
			.with_mana_cost("{3}").with_sacrifice().without_tap()) \
		.oracle("{3}, Sacrifice this creature: Add {R}{R}{R}.")
