extends CardScript
## Giant Badger — {1}{G}{G} — Creature — Badger — 2/2 — (phpr, rare)
## Oracle: Whenever this creature blocks, it gets +2/+2 until end of turn.
##
## Implementation: a BECOMES_BLOCKER trigger — dispatched ONCE per creature
## that starts blocking — gated on this creature, resolving into a self
## pump. A 2/2 that fights as a 4/4 on defense — the original "Pit Fight"
## promo, and a genuinely awkward attack for the opponent.
##
## Not BLOCKED (2026-10-03): that event is one per block PAIR, and a band
## makes one pair per member (CR 702.22 — blocking one member blocks the
## band), so a Badger blocking a band of two grew to 6/6. It blocks once.


func build() -> CardData:
	return CardData.new("Giant Badger", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["badger"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECOMES_BLOCKER, _bulk_up,
			"Whenever Giant Badger blocks, it gets +2/+2 until end of turn.",
			_is_the_blocker)) \
		.oracle("Whenever this creature blocks, it gets +2/+2 until end of turn.")


static func _is_the_blocker(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _bulk_up(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if not game.is_present(source):   # gone, or phased out (CR 702.26e)
		return
	game.continuous.add_until_eot_pump(source.id, 2, 2)
	game.recalculate()
