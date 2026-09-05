extends CardScript
## Argothian Treefolk — {3}{G}{G} — Creature — Treefolk — 3/5 — (atq, common)
## Oracle: Prevent all damage that would be dealt to this creature by
##         artifact sources.
##
## Implementation: a SOURCE-FILTERED damage immunity against ANY artifact
## source — artifact creatures in combat, but also a Rod of Ruin ping or
## a Triskelion counter. A 3/5 that an artifact deck simply cannot remove
## with damage. The filter reads the source's LIVE card types
## (CardInstance.is_type, CONTRIBUTING.md rule 5), so a creature that Ashnod's
## Transmogrant or Titania's Song turned into an artifact is judged an
## artifact source too — CR 109.5: what an object IS is its current
## characteristics, not its printed ones.


func build() -> CardData:
	return CardData.new("Argothian Treefolk", "{3}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 5) \
		.with_subtypes(["treefolk"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Prevent all damage that would be dealt to Argothian Treefolk by "
			+ "artifact sources.")) \
		.oracle("Prevent all damage that would be dealt to this creature by artifact "
			+ "sources.")


static func _is_artifact_source(_game: MtgGame, damager: CardInstance) -> bool:
	return damager.is_type(Mtg.CardType.ARTIFACT)   # LIVE types (rule 5)


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_damage_immunity.append(
		{"desc": "artifact sources", "filter": _is_artifact_source})
