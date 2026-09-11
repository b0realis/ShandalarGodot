extends CardScript
## Kobold Drill Sergeant — {1}{R} — Creature — Kobold Soldier — 1/2 — (leg, uncommon)
## Oracle: Other Kobold creatures you control get +0/+1 and have trample.
##
## Implementation: the third Kher Keep chief — toughness and trample, so
## the pumped Kobolds punch through chump blocks instead of being eaten
## by them.


func build() -> CardData:
	return CardData.new("Kobold Drill Sergeant", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["kobold", "soldier"]) \
		.static_ability(StaticAbility.new(
			_apply, "Other Kobold creatures you control get +0/+1.")) \
		.static_ability(StaticAbility.new(
			_trample, "Other Kobold creatures you control have trample.") \
			.changing_abilities()) \
		.oracle("Other Kobold creatures you control get +0/+1 and have trample.")


## TWO STATICS, one per CR 613 layer (613.1): the +0/+1 is layer 7c and
## the trample is layer 6.
static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _is_our_other_kobold(inst, source):
			inst.cur_toughness += 1


static func _trample(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _is_our_other_kobold(inst, source) \
				and not inst.cur_keywords.has(Mtg.Keyword.TRAMPLE):
			inst.cur_keywords.append(Mtg.Keyword.TRAMPLE)


static func _is_our_other_kobold(inst: CardInstance, source: CardInstance) -> bool:
	return inst != source and inst.controller_id == source.controller_id \
		and inst.is_creature() and inst.has_subtype("kobold")
