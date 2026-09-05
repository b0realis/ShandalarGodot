extends CardScript
## Kobold Taskmaster — {1}{R} — Creature — Kobold — 1/2 — (leg, uncommon)
## Oracle: Other Kobold creatures you control get +1/+0.
##
## Implementation: a tribal lord for the Kobolds of Kher Keep deck — free
## 0/1 bodies that the three Kobold chiefs turn into a real army. "Other"
## and "you control" are both enforced; the Taskmaster never boosts itself.


func build() -> CardData:
	return CardData.new("Kobold Taskmaster", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["kobold"]) \
		.static_ability(StaticAbility.new(
			_apply, "Other Kobold creatures you control get +1/+0.")) \
		.oracle("Other Kobold creatures you control get +1/+0.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.controller_id == source.controller_id \
				and inst.is_creature() and inst.has_subtype("kobold"):
			inst.cur_power += 1
