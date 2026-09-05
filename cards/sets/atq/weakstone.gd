extends CardScript
## Weakstone — {4} — Artifact — (atq, uncommon)
## Oracle: Attacking creatures get -1/-0.
##
## Implementation: Mightstone's mirror — the same live combat-declaration
## static, shrinking instead of pumping. Symmetric, so it belongs in a
## deck that wins by blocking (or by not attacking at all).


func build() -> CardData:
	return CardData.new("Weakstone", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_apply, "Attacking creatures get -1/-0.")) \
		.oracle("Attacking creatures get -1/-0.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and game.combat.attackers.has(inst.id):
			inst.cur_power -= 1
