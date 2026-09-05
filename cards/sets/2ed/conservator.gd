extends CardScript
## Conservator — {4} — Artifact — (2ed, uncommon)
## Oracle: {3}, {T}: Prevent the next 2 damage that would be dealt to you
##         this turn.
##
## Implementation: PreventDamageEffect's untargeted controller mode — the
## pool lands on the activator ("to you"), no target chosen. Colorless
## damage insurance any deck could run; expensive enough that nobody did
## twice.


func build() -> CardData:
	return CardData.new("Conservator", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true,
			[PreventDamageEffect.new(2).to_controller()],
			"{3}, {T}: Prevent the next 2 damage that would be dealt to you this turn.")) \
		.oracle("{3}, {T}: Prevent the next 2 damage that would be dealt to you this turn.")
