extends CardScript
## Dark Ritual — {B} — Instant (2ed, common)
## Oracle: Add {B}{B}{B}.
##
## Implementation: AddManaEffect — a SPELL that resolves into mana (unlike
## a land's stackless ManaAbility, this is castable at instant speed and
## can be responded to). The three black mana land in the caster's pool and
## evaporate at end of step (CR 500.4), so the ritual must fuel something
## in the same step — exactly the real card's rhythm: turn-one Ritual into
## Hypnotic Specter.


func build() -> CardData:
	return CardData.new("Dark Ritual", "{B}", Mtg.CardType.INSTANT) \
		.spell(AddManaEffect.new(Mtg.ManaColor.B, 3)) \
		.oracle("Add {B}{B}{B}.")
