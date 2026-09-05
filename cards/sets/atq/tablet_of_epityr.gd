extends CardScript
## Tablet of Epityr — {1} — Artifact — (atq, common)
## Oracle: Whenever an artifact you control is put into a graveyard from
##         the battlefield, you may pay {1}. If you do, you gain 1 life.
##
## Implementation: a LEAVES_BATTLEFIELD trigger gated on the departing
## permanent being an artifact its controller controlled AND on it having
## landed in a GRAVEYARD (the engine sets the new zone before dispatching,
## so bouncing — Hurkyl's Recall, Boomerang — and exiling both fail the
## gate, exactly as the printed "put into a graveyard from the
## battlefield" demands). The Tablet itself qualifies — "an artifact you
## control" includes the trigger's own source, and leave-the-battlefield
## triggers look back in time at the game as it was just before the
## artifact left (CR 603.6d, 603.10), so a Shatter on the Tablet still
## gains the life. Offers {1} through MtgGame.try_pay. One mana for a life
## whenever your Moxen die — Antiquities' idea of a payoff.


func build() -> CardData:
	return CardData.new("Tablet of Epityr", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _pay,
			"Whenever an artifact you control is put into a graveyard from the "
			+ "battlefield, you may pay {1}. If you do, you gain 1 life.",
			_your_artifact)) \
		.oracle("Whenever an artifact you control is put into a graveyard from the "
			+ "battlefield, you may pay {1}. If you do, you gain 1 life.")


static func _your_artifact(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var gone: CardInstance = event.data.get("instance")
	# No self-exclusion: the Tablet's own trip to the graveyard triggers it.
	# LAST KNOWN INFORMATION (CR 608.2h): the departing permanent's cur_* are
	# already back to printed values, so "an ARTIFACT you control" is read
	# off `last_types` — the same snapshot the engine's own dies bookkeeping
	# uses. A creature Ashnod's Transmogrant made an artifact died as one.
	return gone != null \
		and (gone.last_types & Mtg.CardType.ARTIFACT) != 0 \
		and gone.zone == Mtg.Zone.GRAVEYARD \
		and int(event.data.get("from_controller", -1)) == source.controller_id


static func _pay(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	var cost := ManaCost.parse("{1}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid, "Pay {1} to gain 1 life?", true) \
			and game.try_pay(pid, cost):
		game.adjust_life(pid, 1)
