extends CardScript
## Active Volcano — {R} — Instant — (leg, common)
## Oracle: Choose one —
##         • Destroy target blue permanent.
##         • Return target Island to its owner's hand.
##
## Implementation: modal color hoser — mode 0 is Red Elemental Blast's
## destroy half, mode 1 bounces an Island (land subtype filter on a
## permanent spec). No counter mode, so the AI casts it proactively (the
## default mode 0 aims at the best blue permanent).


func build() -> CardData:
	var blue_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target blue permanent", _is_blue_permanent)
	var island_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target Island", _is_island)
	return CardData.new("Active Volcano", "{R}", Mtg.CardType.INSTANT) \
		.mode("Destroy target blue permanent", [DestroyEffect.new(blue_spec)]) \
		.mode("Return target Island to its owner's hand",
			[ReturnToHandEffect.new(island_spec)]) \
		.oracle("Choose one —\n• Destroy target blue permanent.\n• Return target Island to its owner's hand.")


static func _is_blue_permanent(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.U) != 0


static func _is_island(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("island")
