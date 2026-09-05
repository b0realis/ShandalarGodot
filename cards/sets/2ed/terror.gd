extends CardScript
## Terror — {1}{B} — Instant (Alpha, common)
## Oracle: Destroy target nonartifact, nonblack creature. It can't be
##         regenerated.
##
## Implementation: DestroyEffect with a filtered creature spec. The filter
## is the card's own static predicate below — target legality (both at cast
## and at resolution) runs it via TargetSpec.filter. Regeneration doesn't
## exist in the engine yet; the can_regenerate=false flag documents the
## printed behavior and will bind once regeneration lands (docs/ROADMAP.md).


func build() -> CardData:
	var spec := TargetSpec.creature(
		"target nonartifact, nonblack creature", _valid_target)
	return CardData.new("Terror", "{1}{B}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(spec, false)) \
		.oracle("Destroy target nonartifact, nonblack creature. It can't be regenerated.")


static func _valid_target(inst: CardInstance) -> bool:
	if inst.is_type(Mtg.CardType.ARTIFACT):
		return false
	if inst.cur_colors & Mtg.ManaColor.B:
		return false
	return true
