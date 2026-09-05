extends CardScript
## Ley Druid — {2}{G} — Creature — Human Druid — 1/1 (2ed, uncommon)
## Oracle: {T}: Untap target land.
##
## Implementation: tap-activated UntapEffect with a land filter. NOTE this
## is a normal activated ability, not a mana ability (it untaps the land —
## the land's controller still taps it themselves for the actual mana), so
## it uses the stack and respects summoning sickness.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Ley Druid", "{2}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "druid"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[UntapEffect.new(land_spec)],
			"{T}: Untap target land.")) \
		.oracle("{T}: Untap target land.")
