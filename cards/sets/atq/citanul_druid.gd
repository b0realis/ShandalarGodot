extends CardScript
## Citanul Druid — {1}{G} — Creature — Human Druid — 1/1 — (atq, uncommon)
## Oracle: Whenever an opponent casts an artifact spell, put a +1/+1
##         counter on this creature.
##
## Implementation: a SPELL_CAST trigger gated on the caster being an
## opponent and the card being an artifact. In Antiquities' artifact
## mirror it grows every turn; against a creature deck it is a 1/1.


func build() -> CardData:
	return CardData.new("Citanul Druid", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "druid"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _grow,
			"Whenever an opponent casts an artifact spell, put a +1/+1 counter on "
			+ "Citanul Druid.",
			_their_artifact)) \
		.oracle("Whenever an opponent casts an artifact spell, put a +1/+1 counter "
			+ "on this creature.")


static func _their_artifact(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if int(event.data["controller"]) == source.controller_id:
		return false
	var spell: CardInstance = event.data.get("instance")
	return spell != null and spell.data.is_type(Mtg.CardType.ARTIFACT)


static func _grow(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "+1/+1", 1)
