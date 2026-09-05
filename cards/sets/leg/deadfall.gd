extends CardScript
## Deadfall — {2}{G} — Enchantment — (leg, uncommon)
## Oracle: Creatures with forestwalk can be blocked as though they
##         didn't have forestwalk.
##
## Implementation: a static that adds "forest" to
## MtgGame.nullified_landwalk, which CombatState consults when checking
## landwalk. The creatures KEEP the ability (a Fishliver Oil-style grant is
## still visible in cur_landwalk) — only the blocking rule changes, which
## is exactly what "as though" means.


func build() -> CardData:
	return CardData.new("Deadfall", "{2}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with forestwalk can be blocked as though they didn't have "
			+ "forestwalk.")) \
		.oracle("Creatures with forestwalk can be blocked as though they didn't "
			+ "have forestwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["forest"] = true
