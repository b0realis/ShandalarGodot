extends CardScript
## Fungusaur — {3}{G} — Creature — Fungus Dinosaur — 2/2 (2ed, rare)
## Oracle: Whenever Fungusaur is dealt damage, put a +1/+1 counter on it.
##
## Implementation: DAMAGE_DEALT trigger conditioned on the victim being
## itself; the resolve re-checks it's still on the battlefield (lethal
## damage kills it before the trigger resolves — a dead Fungusaur grows no
## mushrooms, exactly per the rules). The dos486 guide mocks the AI decks
## built around poking it; now ours can be poked properly.


func build() -> CardData:
	return CardData.new("Fungusaur", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["fungus", "dinosaur"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _grow,
			"Whenever Fungusaur is dealt damage, put a +1/+1 counter on it.",
			_hit_me)) \
		.oracle("Whenever Fungusaur is dealt damage, put a +1/+1 counter on it.")


static func _hit_me(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("to_instance") == source


static func _grow(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "+1/+1", 1)
