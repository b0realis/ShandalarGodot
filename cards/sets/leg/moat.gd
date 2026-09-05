extends CardScript
## Moat — {2}{W}{W} — Enchantment — (leg, rare)
## Oracle: Creatures without flying can't attack.
##
## Implementation: a static that sets the new cur_cant_attack flag on
## every non-flying creature each recalculation (both players — Moat is
## symmetric); CombatState.attack_illegality refuses them. LIVE keywords,
## so a creature granted flying sails over the moat, and an animated
## Mishra's Factory is grounded. Legends' famous prison enchantment.


func build() -> CardData:
	return CardData.new("Moat", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply, "Creatures without flying can't attack.")) \
		.oracle("Creatures without flying can't attack.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and not inst.has_keyword(Mtg.Keyword.FLYING):
			inst.cur_cant_attack = true
