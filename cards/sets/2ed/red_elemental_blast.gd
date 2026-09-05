extends CardScript
## Red Elemental Blast — {R} — Instant — (2ed, common)
## Oracle: Choose one —
##         • Counter target blue spell.
##         • Destroy target blue permanent.
##
## Implementation: Blue Elemental Blast's mirror — see that file for the
## modal/reactive mechanics. Red's only answer to Counterspell in the era,
## which is exactly why every red Shandalar deck sideboarded four.


func build() -> CardData:
	var destroy_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target blue permanent", _is_blue_permanent)
	return CardData.new("Red Elemental Blast", "{R}", Mtg.CardType.INSTANT) \
		.mode("Counter target blue spell",
			[CounterEffect.new("target blue spell", _is_blue_spell)]) \
		.mode("Destroy target blue permanent", [DestroyEffect.new(destroy_spec)]) \
		.with_ai_mode(_ai_mode) \
		.oracle("Choose one —\n• Counter target blue spell.\n• Destroy target blue permanent.")


static func _is_blue_spell(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.U) != 0


static func _is_blue_permanent(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.U) != 0


static func _ai_mode(_game: MtgGame, _pid: int) -> int:
	return 1   # proactive casts destroy; the counter mode is fired reactively
