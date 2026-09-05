extends CardScript
## Sorceress Queen — {1}{B}{B} — Creature — Human Wizard Sorcerer — 1/1 — (4ed, rare)
## Oracle: {T}: Target creature other than this creature has base power
##         and toughness 0/2 until end of turn.
##
## Implementation: SetBasePowerToughnessEffect(0, 2) with a source-aware
## filter excluding the Queen herself. Base P/T is set in CR 613 layer
## 7b, so counters and pumps applied later still stack on top — a 0/2
## with a +1/+1 counter is a 1/3. Turns any fatty into chump-block bait
## for a turn, every turn.


func build() -> CardData:
	var spec := TargetSpec.creature("target creature other than Sorceress Queen")
	spec.with_source_filter(_not_self)
	return CardData.new("Sorceress Queen", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "wizard", "sorcerer"]) \
		.activated(ActivatedAbility.new(
			"", true, [SetBasePowerToughnessEffect.new(0, 2, spec)],
			"{T}: Target creature other than Sorceress Queen has base power and "
			+ "toughness 0/2 until end of turn.")) \
		.oracle("{T}: Target creature other than this creature has base power and "
			+ "toughness 0/2 until end of turn.")


static func _not_self(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst != source
