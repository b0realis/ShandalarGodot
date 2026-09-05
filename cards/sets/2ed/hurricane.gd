extends CardScript
## Hurricane — {X}{G} — Sorcery (2ed, uncommon)
## Oracle: Hurricane deals X damage to each creature with flying and each
##         player.
##
## Implementation: DamageAllEffect, the exact mirror of Earthquake — the
## filter keeps only FLYING creatures (live keywords, so a Jumped creature
## gets caught). Green's answer to the skies, players included, caster
## included.


func build() -> CardData:
	return CardData.new("Hurricane", "{X}{G}", Mtg.CardType.SORCERY) \
		.spell(DamageAllEffect.new(0, "each creature with flying", _flies)
			.x_damage().and_each_player()) \
		.oracle("Hurricane deals X damage to each creature with flying and each player.")


static func _flies(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.FLYING)
