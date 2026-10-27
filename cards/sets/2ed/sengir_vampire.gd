extends CardScript
## Sengir Vampire — {3}{B}{B} — Creature — Vampire — 4/4 (2ed, uncommon)
## Oracle: Flying
##         Whenever a creature dealt damage by Sengir Vampire this turn
##         dies, put a +1/+1 counter on Sengir Vampire.
##
## Implementation: the reference +1/+1 COUNTER card. The engine tracks
## which sources damaged each creature this turn
## (CardInstance.damage_origins_this_turn, snapshotted into the DIES event
## before battlefield state wipes — that ordering IS the card); the
## trigger checks itself against that list and grows. Black's apex
## predator of the pool: every kill makes it bigger.


func build() -> CardData:
	return CardData.new("Sengir Vampire", "{3}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["vampire"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _feed,
			"Whenever a creature dealt damage by Sengir Vampire this turn dies, put a +1/+1 counter on Sengir Vampire.",
			_did_i_wound_it).public_aftermath()) \
		.oracle("Flying\nWhenever a creature dealt damage by Sengir Vampire this turn dies, put a +1/+1 counter on Sengir Vampire.")


## Damaged by THIS Vampire — the object, id and timestamp (the bug campaign
## c12, h3-14): the event's `damage_origins` key each source as
## "id:timestamp", the shape Baron Sengir reads (hml/_basic.gd). By id alone
## a Vampire bounced and replayed was paid for a creature its earlier self
## had bitten (CR 400.7: it is a new object).
static func _did_i_wound_it(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("damage_origins", {}).has("%d:%d" % [source.id, source.layer_timestamp])


static func _feed(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.add_counters(source, "+1/+1", 1)
