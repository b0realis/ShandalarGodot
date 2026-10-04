extends CardScript
## Fungusaur — {3}{G} — Creature — Fungus Dinosaur — 2/2 (2ed, rare)
## Oracle: Whenever Fungusaur is dealt damage, put a +1/+1 counter on it.
##
## Implementation: WAS_DEALT_DAMAGE trigger conditioned on the victim being
## itself — the victim's event, ONE per damage event whatever the number of
## sources (CR 510.2: two blockers grow it one counter, not two; Mirage bug
## pass 0.50.11); the resolve re-checks it's still on the battlefield (lethal
## damage kills it before the trigger resolves — a dead Fungusaur grows no
## mushrooms, exactly per the rules). The dos486 guide mocks the AI decks
## built around poking it; now ours can be poked properly.


func build() -> CardData:
	return CardData.new("Fungusaur", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["fungus", "dinosaur"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.WAS_DEALT_DAMAGE, _grow,
			"Whenever Fungusaur is dealt damage, put a +1/+1 counter on it.",
			_hit_me).public_aftermath()) \
		.oracle("Whenever Fungusaur is dealt damage, put a +1/+1 counter on it.")


static func _hit_me(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("to_instance") == source


static func _grow(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "+1/+1", 1)
