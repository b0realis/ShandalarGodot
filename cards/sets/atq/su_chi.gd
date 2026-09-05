extends CardScript
## Su-Chi — {4} — Artifact Creature — Construct — 4/4 (atq, uncommon)
## Oracle: When Su-Chi dies, add {C}{C}{C}{C}.
##
## Implementation: a DIES trigger feeding four colorless into its
## controller's pool — which then empties at end of step (CR 500.4), so
## the mana must be used in the moment, exactly the card's famous rhythm
## (and famous feel-bad). The first Antiquities rules card to graduate —
## the atq set folder starts here.


func build() -> CardData:
	return CardData.new("Su-Chi", "{4}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["construct"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _death_rattle,
			"When Su-Chi dies, add {C}{C}{C}{C}.",
			_is_me_dying)) \
		.oracle("When Su-Chi dies, add {C}{C}{C}{C}.")


static func _is_me_dying(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _death_rattle(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data["controller"]
	game.players[pid].mana_pool.add(Mtg.ManaColor.C, 4)
	game.log_line("Su-Chi's death adds {C}{C}{C}{C}")
