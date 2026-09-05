extends CardScript
## Mightstone — {4} — Artifact — (atq, uncommon)
## Oracle: Attacking creatures get +1/+0.
##
## Implementation: a static reading the LIVE combat declarations
## (game.combat.attackers), re-applied on every recalculation — the boost
## appears the moment attackers are declared and vanishes when combat
## clears. Symmetric: it arms the opponent's attacks too, which is why
## Weakstone is its natural partner rather than its opposite.


func build() -> CardData:
	return CardData.new("Mightstone", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_apply, "Attacking creatures get +1/+0.")) \
		.oracle("Attacking creatures get +1/+0.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and game.combat.attackers.has(inst.id):
			inst.cur_power += 1
