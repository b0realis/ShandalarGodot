extends CardScript
## Flash Flood — {U} — Instant — (leg, common)
## Oracle: Choose one —
##         • Destroy target red permanent.
##         • Return target Mountain to its owner's hand.
##
## Implementation: Active Volcano's blue mirror — see that file.


func build() -> CardData:
	var red_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target red permanent", _is_red_permanent)
	var mountain_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target Mountain", _is_mountain)
	return CardData.new("Flash Flood", "{U}", Mtg.CardType.INSTANT) \
		.mode("Destroy target red permanent", [DestroyEffect.new(red_spec)]) \
		.mode("Return target Mountain to its owner's hand",
			[ReturnToHandEffect.new(mountain_spec)]) \
		.oracle("Choose one —\n• Destroy target red permanent.\n• Return target Mountain to its owner's hand.")


static func _is_red_permanent(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.R) != 0


static func _is_mountain(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("mountain")
