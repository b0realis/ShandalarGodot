extends CardScript
## Desert Nomads — {2}{R} — Creature — Human Nomad — 2/2 — (arn, common)
## Oracle: Desertwalk
##         Prevent all damage that would be dealt to this creature by
##         Deserts.
##
## Implementation: landwalk of the "desert" subtype (unblockable while the
## defender controls a Desert) plus a SOURCE-FILTERED damage immunity
## (CardInstance.cur_damage_immunity) whose predicate accepts any land
## with the Desert subtype. The predicate reads the source's LIVE types and
## subtypes (CONTRIBUTING.md rule 5, CR 109.5): a land retyped by Blood Moon or
## Evil Presence has stopped being a Desert, and anything that ever gains
## the subtype starts counting as one.


func build() -> CardData:
	return CardData.new("Desert Nomads", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "nomad"]) \
		.with_landwalk(["desert"]) \
		.static_ability(StaticAbility.new(
			_apply, "Prevent all damage that would be dealt to Desert Nomads by Deserts.")) \
		.oracle("Desertwalk\nPrevent all damage that would be dealt to this creature by Deserts.")


static func _is_a_desert(_game: MtgGame, damager: CardInstance) -> bool:
	# LIVE land type and subtypes (rule 5), not the printed ones.
	return damager.is_land() and damager.has_subtype("desert")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_damage_immunity.append(
		{"desc": "Deserts", "filter": _is_a_desert})
