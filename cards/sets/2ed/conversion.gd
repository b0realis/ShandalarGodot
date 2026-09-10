extends CardScript
## Conversion — {2}{W}{W} — Enchantment — (2ed, uncommon)
## Oracle: At the beginning of your upkeep, sacrifice this enchantment
##         unless you pay {W}{W}.
##         All Mountains are Plains.
##
## Implementation: a global static turning every Mountain into a Plains —
## live subtypes AND live mana abilities, so a red deck's lands start
## producing white — plus the "pay or sacrifice" upkeep rent. Against
## mono-red it is a hard lock; against anything else it is a four-mana
## do-nothing that keeps charging you {W}{W}.
##
## The static is marked `reading_land_types()`: it READS a land type to
## decide what it applies to, which makes it dependent (CR 613.8) on every
## layer-4 static that WRITES one. It is therefore applied after Blood
## Moon, Evil Presence, Phantasmal Terrain and Cyclopean Tomb whatever the
## timestamps say, and a Mishra's Factory under a Blood Moon is a Plains.


func build() -> CardData:
	return CardData.new("Conversion", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_apply, "All Mountains are Plains.") \
			.changing_land_types().reading_land_types()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of your upkeep, sacrifice Conversion unless you pay {W}{W}.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, sacrifice this enchantment unless "
			+ "you pay {W}{W}.\nAll Mountains are Plains.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and inst.has_subtype("mountain"):
			inst.become_basic_land_type("plains", Mtg.ManaColor.W)


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{W}{W}")
	if EffectBase.unless_paid(game, pid, cost, "Pay {W}{W} to keep Conversion?"):
		return
	game.sacrifice_permanent(source)
