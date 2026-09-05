extends CardScript
## Word of Binding — {X}{B}{B} — Sorcery — (4ed, common)
## Oracle: Tap X target creatures.
##
## Implementation: an "X target creatures" spell — TargetPlan hands the tap
## effect the whole group and EffectBase.resolve_multi taps each in turn.


func build() -> CardData:
	return CardData.new("Word of Binding", "{X}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(TapEffect.new(TargetSpec.creature()).x_targets()) \
		.oracle("Tap X target creatures.")
