extends CardScript
## Cyclopean Mummy — {1}{B} — Creature — Zombie — 2/1 — (4ed, common)
## Oracle: When this creature dies, exile it.
##
## Implementation: a self DIES trigger that lifts the corpse from the
## graveyard into exile (MtgGame.exile_from_graveyard) — no Raise Dead,
## no Animate Dead for the mummy. If something else already moved the
## card out of the graveyard before the trigger resolves, it stays there.


func build() -> CardData:
	return CardData.new("Cyclopean Mummy", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["zombie"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _entomb,
			"When this creature dies, exile it.",
			_is_self)) \
		.oracle("When this creature dies, exile it.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["instance"] == source


static func _entomb(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.exile_from_graveyard(source)
