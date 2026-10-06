extends RefCounted
## Exodus (_lands_mana, Pack 9). Nonbasic lands and mana abilities, including sacrifice and tapped-entry lands.
##
## City of Traitors: "When you play another land" hears LAND_PLAYED, which
## the engine raises only for a land PLAYED (MtgGame.play_land — CR 305.1;
## a land put onto the battlefield by an effect is not played), by this
## land's controller, other than this land. The sacrifice is of this very
## object, by the player who still controls it (CR 701.17a).
##
## Workhorse: "Remove a +1/+1 counter from this creature: Add {C}" is a
## mana ability with no {T} (ManaAbility.without_tap + with_counter_cost,
## Rasputin Dreamweaver's shape): usable the turn it arrives (CR 302.6),
## while tapped, once per counter; its size is recalculated as the counter
## comes off. The automatic mana planner does not
## spend its counters (each one is the creature's toughness); the player
## activates it by hand. Under the mana-burn presets unused {C} burns like
## any other mana.
##
## tests/cards/test_pack_9_B11_lands_basic.gd pins both.
const M := preload("res://cards/sets/mir/_triggers.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"City of Traitors":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LAND_PLAYED, M.sacrifice_source,
				"When you play another land, sacrifice this land.", _you_played_another_land))
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 2))
		"Workhorse":
			c.with_enters_counters("+1/+1", 4)
			c.mana(ManaAbility.new(Mtg.ManaColor.C).without_tap().with_counter_cost("+1/+1", 1))
		_: return false
	return true


static func _you_played_another_land(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return land != null and land != s and int(e.data.get("controller", -1)) == s.controller_id
