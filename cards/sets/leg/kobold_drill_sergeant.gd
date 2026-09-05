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
			_apply, "Other Kobold creatures you control get +0/+1 and have trample.")) \
		.oracle("Other Kobold creatures you control get +0/+1 and have trample.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.controller_id == source.controller_id \
				and inst.is_creature() and inst.has_subtype("kobold"):
			inst.cur_toughness += 1
			if not inst.cur_keywords.has(Mtg.Keyword.TRAMPLE):
				inst.cur_keywords.append(Mtg.Keyword.TRAMPLE)
