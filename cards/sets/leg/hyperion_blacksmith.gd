extends CardScript
## Hyperion Blacksmith — {1}{R}{R} — Creature — Human Artificer — 2/2 — (leg, uncommon)
## Oracle: {T}: You may tap or untap target artifact an opponent controls.
##
## Implementation: the printed "may tap or untap" is a choice, so the
## Blacksmith ships TWO abilities — index 0 taps, index 1 untaps — and
## the activating player picks by index (Urborg's pattern). Both target
## specs demand an artifact an OPPONENT controls, via a source-aware
## filter.


func build() -> CardData:
	return CardData.new("Hyperion Blacksmith", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "artificer"]) \
		.activated(ActivatedAbility.new(
			"", true, [TapEffect.new(_spec())],
			"{T}: Tap target artifact an opponent controls.")) \
		.activated(ActivatedAbility.new(
			"", true, [UntapEffect.new(_spec())],
			"{T}: Untap target artifact an opponent controls.")) \
		.oracle("{T}: You may tap or untap target artifact an opponent controls.")


static func _spec() -> TargetSpec:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact an opponent controls")
	spec.with_source_filter(_their_artifact)
	return spec


static func _their_artifact(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) \
		and inst.controller_id != source.controller_id
