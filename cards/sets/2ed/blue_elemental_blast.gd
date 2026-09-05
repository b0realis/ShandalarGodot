extends CardScript
## Blue Elemental Blast — {U} — Instant — (2ed, common)
## Oracle: Choose one —
##         • Counter target red spell.
##         • Destroy target red permanent.
##
## Implementation: modal with color-filtered targets (color = mana cost,
## CR 105.2). The AI treats any modal card with a counter mode as REACTIVE:
## it holds the Blast and _try_counter fires mode 0 at a qualifying red
## spell; the ai_mode_picker covers the rare proactive cast (mode 1 at a
## red permanent). The eternal sideboard card of the era, mirrored by Red
## Elemental Blast.


func build() -> CardData:
	var destroy_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target red permanent", _is_red_permanent)
	return CardData.new("Blue Elemental Blast", "{U}", Mtg.CardType.INSTANT) \
		.mode("Counter target red spell",
			[CounterEffect.new("target red spell", _is_red_spell)]) \
		.mode("Destroy target red permanent", [DestroyEffect.new(destroy_spec)]) \
		.with_ai_mode(_ai_mode) \
		.oracle("Choose one —\n• Counter target red spell.\n• Destroy target red permanent.")


static func _is_red_spell(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.R) != 0


static func _is_red_permanent(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.R) != 0


static func _ai_mode(_game: MtgGame, _pid: int) -> int:
	return 1   # proactive casts destroy; the counter mode is fired reactively
