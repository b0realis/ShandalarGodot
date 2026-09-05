extends CardScript
## Argothian Pixies — {1}{G} — Creature — Faerie — 2/1 — (atq, common)
## Oracle: This creature can't be blocked by artifact creatures.
##         Prevent all damage that would be dealt to this creature by
##         artifact creatures.
##
## Implementation: a block RESTRICTION (only non-artifact creatures may
## block it) plus a SOURCE-FILTERED damage immunity against artifact
## creatures. In Antiquities' artifact-creature-heavy field a 2/1 for two
## that simply cannot be stopped or killed in combat.


func build() -> CardData:
	return CardData.new("Argothian Pixies", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["faerie"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Argothian Pixies can't be blocked by artifact creatures, and artifact "
			+ "creatures can't damage it.")) \
		.oracle("This creature can't be blocked by artifact creatures.\nPrevent all "
			+ "damage that would be dealt to this creature by artifact creatures.")


static func _not_an_artifact(blocker: CardInstance) -> bool:
	return not blocker.is_type(Mtg.CardType.ARTIFACT)


static func _is_artifact_creature(_game: MtgGame, damager: CardInstance) -> bool:
	return damager.is_creature() and damager.is_type(Mtg.CardType.ARTIFACT)


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_block_restrictions.append(
		{"desc": "non-artifact creatures", "filter": _not_an_artifact})
	source.cur_damage_immunity.append(
		{"desc": "artifact creatures", "filter": _is_artifact_creature})
