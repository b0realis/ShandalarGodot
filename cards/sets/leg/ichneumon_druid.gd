extends CardScript
## Ichneumon Druid — {1}{G}{G} — Creature — Human Druid — 1/1 — (leg, uncommon)
## Oracle: Whenever an opponent casts an instant spell other than the
##         first instant spell that player casts each turn, this creature
##         deals 4 damage to that player.
##
## Implementation: a SPELL_CAST trigger whose condition counts that
## player's instants cast THIS TURN (MtgGame.spells_cast_this_turn, which
## already includes the spell that just triggered it) — so the trigger
## fires from the SECOND instant onwards. Four damage a pop makes a
## counterspell deck think twice about holding up mana.


func build() -> CardData:
	return CardData.new("Ichneumon Druid", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "druid"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _sting,
			"Whenever an opponent casts an instant spell other than the first instant "
			+ "spell that player casts each turn, Ichneumon Druid deals 4 damage to "
			+ "that player.",
			_is_repeat_instant)) \
		.oracle("Whenever an opponent casts an instant spell other than the first "
			+ "instant spell that player casts each turn, this creature deals 4 damage "
			+ "to that player.")


static func _is_repeat_instant(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var caster := int(event.data["controller"])
	if caster == source.controller_id:
		return false
	var spell: CardInstance = event.data["instance"]
	if spell == null or not spell.data.is_type(Mtg.CardType.INSTANT):
		return false
	var instants := 0
	for data in game.spells_cast_this_turn[caster]:
		if data.is_type(Mtg.CardType.INSTANT):
			instants += 1
	return instants >= 2   # this one included: 1 = the free first instant


static func _sting(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(int(event.data["controller"])), 4)
