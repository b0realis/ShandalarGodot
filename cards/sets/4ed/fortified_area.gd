extends CardScript
## Fortified Area — {1}{W}{W} — Enchantment — (4ed, common)
## Oracle: Wall creatures you control get +1/+0 and have banding.
##
## Implementation: a one-sided tribal anthem for Walls, granting power and
## the BANDING keyword — and the keyword does the printed work. Walls have
## defender and can never attack, so the only reason to band one is the
## DEFENSIVE half of CR 702.22f-h: with a banding Wall among the blockers,
## the Walls' controller divides the attacker's combat damage among them
## however they like. Two Walls gang-blocking a fattie now lose one of
## their number instead of both.


func build() -> CardData:
	return CardData.new("Fortified Area", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply, "Wall creatures you control get +1/+0 and have banding.")) \
		.oracle("Wall creatures you control get +1/+0 and have banding.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.controller_id != source.controller_id or not inst.is_creature():
			continue
		if not inst.has_subtype("wall"):
			continue
		inst.cur_power += 1
		if not inst.cur_keywords.has(Mtg.Keyword.BANDING):
			inst.cur_keywords.append(Mtg.Keyword.BANDING)
