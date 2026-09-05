extends CardScript
## Castle — {3}{W} — Enchantment (2ed, uncommon)
## Oracle: Untapped creatures you control get +0/+2.
##
## Implementation: a CONDITIONAL global static — the boost reads live
## tapped state on every recalculation, and the engine recalculates when
## tap state changes (tap_for_mana → recalculate via state paths;
## tap_permanent/untap_permanent call it explicitly), so a creature that
## taps to attack immediately loses the bonus — exactly the card's famous
## catch (vigilance attackers keep it).


func build() -> CardData:
	return CardData.new("Castle", "{3}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_apply, "Untapped creatures you control get +0/+2.")) \
		.oracle("Untapped creatures you control get +0/+2.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature() and not inst.tapped:
			inst.cur_toughness += 2
