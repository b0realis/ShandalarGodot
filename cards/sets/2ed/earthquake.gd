extends CardScript
## Earthquake — {X}{R} — Sorcery (2ed, rare)
## Oracle: This spell deals X damage to each creature without flying and
##         each player.
##
## Implementation: DamageAllEffect with the non-flying filter, X mode, and
## and_each_player() — untargeted, so protection only applies through
## damage prevention. Note the filter reads LIVE keywords (has_keyword →
## cur_keywords), so a creature granted flying until end of turn ducks the
## quake, as it should. Symmetric: it hits its caster too — the classic
## red finisher-with-a-price, and (per the dos486 guide) the reason Mana
## Flare castles are the scary ones.


func build() -> CardData:
	return CardData.new("Earthquake", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageAllEffect.new(0, "each creature without flying", _grounded)
			.x_damage().and_each_player()) \
		.oracle("This spell deals X damage to each creature without flying and each player.")


static func _grounded(inst: CardInstance) -> bool:
	return not inst.has_keyword(Mtg.Keyword.FLYING)
