extends CardScript
## Gaea's Avenger — {1}{G}{G} — Creature — Treefolk — 1+*/1+* — (atq, rare)
## Oracle: Gaea's Avenger's power and toughness are each equal to 1 plus
##         the number of artifacts your opponents control.
##
## Implementation: a dynamic-P/T static (Nightmare's pattern) that SETS
## both halves each recalculation. Printed 1/1 so it is never a 0/0 in
## an empty board; against an artifact deck it grows unanswerably.


func build() -> CardData:
	return CardData.new("Gaea's Avenger", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["treefolk"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Gaea's Avenger's power and toughness are each equal to 1 plus the "
			+ "number of artifacts your opponents control.").setting_base_pt()) \
		.oracle("Gaea's Avenger's power and toughness are each equal to 1 plus the "
			+ "number of artifacts your opponents control.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var count := 0
	for inst in game.all_battlefield():
		if inst.controller_id != source.controller_id \
				and inst.is_type(Mtg.CardType.ARTIFACT):
			count += 1
	source.cur_power = 1 + count
	source.cur_toughness = 1 + count
