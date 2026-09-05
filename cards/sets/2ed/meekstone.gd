extends CardScript
## Meekstone — {1} — Artifact (2ed, rare)
## Oracle: Creatures with power 3 or greater don't untap during their
##         controllers' untap steps.
##
## Implementation: the UNTAP-LOCK pattern — a global static setting
## cur_skips_untap on every qualifying creature each recalculation; the
## untap step honors the flag. Reads LIVE power, so a Giant-Growthed 2/2
## caught tapped at cleanup still untaps fine (the pump expired), while a
## Serra Angel stays locked — vigilance is the classic partner tech.


func build() -> CardData:
	return CardData.new("Meekstone", "{1}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_apply, "Creatures with power 3 or greater don't untap during their controllers' untap steps.")) \
		.oracle("Creatures with power 3 or greater don't untap during their controllers' untap steps.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.cur_power >= 3:
			inst.cur_skips_untap = true
