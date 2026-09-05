extends CardScript
## Urza's Miter — {3} — Artifact — (atq, rare)
## Oracle: Whenever an artifact you control is put into a graveyard from
##         the battlefield, if it wasn't sacrificed, you may pay {3}. If
##         you do, draw a card.
##
## Implementation: Tablet of Epityr's trigger with a bigger toll and a
## card instead of a life — including its GRAVEYARD gate, so Hurkyl's
## Recall bouncing your board draws nothing. The Miter itself qualifies:
## "an artifact you control" includes the trigger's own source, and
## leave-the-battlefield triggers look back in time at the game as it was
## just before the artifact left (CR 603.6d, 603.10).
##
## "If it wasn't sacrificed" is an intervening-if on the trigger's own
## CONDITION, read off the `sacrificed` flag MtgGame now puts in the
## LEAVES_BATTLEFIELD payload. So Energy Flux's tax, Ashnod's Transmogrant,
## Coal Golem and every other sacrifice outlet draw nothing, while a
## Shatter or a Nevinyrral's Disk still pays out.


func build() -> CardData:
	return CardData.new("Urza's Miter", "{3}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _pay,
			"Whenever an artifact you control is put into a graveyard from the "
			+ "battlefield, if it wasn't sacrificed, you may pay {3} to draw a card.",
			_your_artifact)) \
		.oracle("Whenever an artifact you control is put into a graveyard from the "
			+ "battlefield, if it wasn't sacrificed, you may pay {3}. If you do, draw "
			+ "a card.")


static func _your_artifact(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var gone: CardInstance = event.data.get("instance")
	# No self-exclusion: the Miter's own trip to the graveyard triggers it
	# (CR 603.6d — the ability looks back in time).
	if bool(event.data.get("sacrificed", false)):
		return false      # "if it wasn't sacrificed"
	# LAST KNOWN INFORMATION (CR 608.2h): a permanent left as whatever it
	# WAS, which is `last_types` — the same snapshot Tablet of Epityr
	# reads. NOTHING in the 1997 pool can add or remove the artifact type,
	# so this is defensive rather than observable; it is here because
	# reading `data.*` for a permanent that has already gone is the mistake
	# docs/adding-cards.md warns about, not because a test can catch it.
	return gone != null \
		and (gone.last_types & Mtg.CardType.ARTIFACT) != 0 \
		and gone.zone == Mtg.Zone.GRAVEYARD \
		and int(event.data.get("from_controller", -1)) == source.controller_id


static func _pay(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	var cost := ManaCost.parse("{3}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid, "Pay {3} to draw a card?", true) \
			and game.try_pay(pid, cost):
		game.draw_cards(pid, 1)
