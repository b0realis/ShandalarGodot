extends GameTest
## Pack 10 engine package E3 — A DURATION THAT ENDS ON AN EVENT
## ([constant ContinuousEffects.Duration.UNTIL_EVENT]).
##
## Soul Sculptor: "Target creature becomes an enchantment and loses all
## abilities until a player casts a creature spell." The effect ends as the
## creature spell BECOMES CAST (CR 601.2i) — not when it resolves — and it is
## over before anything triggered by that cast is looked at (CR 603.10:
## the continuous effects that exist immediately after the event decide
## what the triggers see). Any player's creature spell ends it, the
## Sculptor's controller's too; nothing else does — not the cleanup step,
## not a noncreature spell, not a creature spell already on the stack when
## the effect began. The target leaving ends it (CR 400.7).
##
## The effect is built here exactly as the card builds it: a type change
## and a floating "loses all abilities" bound to the target, both ending on
## [method ContinuousEffects.until_spell_cast].

const D := ContinuousEffects.Duration


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


static func _only(_g: MtgGame, _s: CardInstance, inst: CardInstance, id: int) -> bool:
	return inst.id == id


## Soul Sculptor's resolution, through the E3 API.
func _sculpt(target: CardInstance) -> void:
	var ends := ContinuousEffects.until_spell_cast(Mtg.CardType.CREATURE)
	g.continuous.add_type_change(target.id, {"set_types": Mtg.CardType.ENCHANTMENT},
		D.UNTIL_EVENT, -1, ends)
	g.continuous.add_floating_static(target,
		StaticAbility.removing_all_abilities(_only.bind(target.id), "Loses all abilities."),
		D.UNTIL_EVENT, -1, false, target.id, ends)
	g.recalculate()


static func _creature_cast(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return (e.data["instance"] as CardInstance).is_creature()


static func _gain_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.adjust_life(s.controller_id, 1)


## "Whenever a player casts a creature spell, you gain 1 life."
static func _watcher() -> CardData:
	return CardData.new("Test Watcher", "{1}{W}", Mtg.CardType.CREATURE).pt(1, 1) \
		.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _gain_one,
			"Whenever a player casts a creature spell, you gain 1 life.", _creature_cast))


static func _animated_by(source: CardInstance, inst: CardInstance) -> bool:
	return inst != source and inst.is_type(Mtg.CardType.ENCHANTMENT) \
		and not inst.has_subtype("aura")


static func _opal_types(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _animated_by(source, inst):
			inst.cur_types |= Mtg.CardType.CREATURE


static func _opal_size(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _animated_by(source, inst):
			inst.cur_power = inst.data.cost.mana_value()
			inst.cur_toughness = inst.data.cost.mana_value()


static func _opalescence() -> CardData:
	return CardData.new("Test Opalescence", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_opal_types, "Each other non-Aura enchantment is a creature.") \
			.reading_card_types().part_of(&"opalescence")) \
		.static_ability(StaticAbility.new(_opal_size, "... its mana value.") \
			.setting_base_pt().part_of(&"opalescence"))


func _cast_bears(pid: int) -> CardInstance:
	var bears := give_hand(pid, "Grizzly Bears")
	add_mana(pid, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(pid, bears, []))
	return bears


# ------------------------------------------------------------- the shape --

func test_the_target_is_an_enchantment_without_abilities() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(angel)
	assert_false(angel.is_creature())
	assert_true(angel.is_type(Mtg.CardType.ENCHANTMENT))
	assert_true(angel.cur_subtypes.is_empty(), "no Angel without the creature type")
	assert_true(angel.cur_abilities_silenced)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))


func test_a_quiet_board_pays_one_test() -> void:
	assert_eq(g.continuous._event_watch, 0)
	assert_false(g.continuous.expire_on_event(g, Mtg.EventType.SPELL_CAST, {}))


# --------------------------------------------------------- what ends it --

func test_a_creature_spell_ends_it_as_it_is_cast() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(angel)
	advance_to_step(Mtg.Step.MAIN1)
	var bears := _cast_bears(0)
	assert_eq(bears.zone, Mtg.Zone.STACK, "not resolved yet")
	assert_true(angel.is_creature(), "over at CR 601.2i, the Sculptor's own side casting")
	assert_false(angel.cur_abilities_silenced)
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_true(g.continuous._type_changes.is_empty())


func test_a_noncreature_spell_does_not_end_it() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(angel)
	advance_to_step(Mtg.Step.MAIN1)
	var mine := give_hand(0, "Howling Mine")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, mine, []))
	resolve_stack()
	assert_false(angel.is_creature())
	assert_true(angel.cur_abilities_silenced)


func test_it_outlasts_the_turn_and_the_opponent_ends_it() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	_sculpt(angel)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_false(angel.is_creature(), "cleanup does not end it")
	_cast_bears(1)
	assert_true(angel.is_creature(), "any player's creature spell")


func test_a_trigger_on_that_cast_sees_the_permanent_restored() -> void:
	var watcher := put_synthetic(1, _watcher())
	_sculpt(watcher)
	advance_to_step(Mtg.Step.MAIN1)
	var before := g.players[1].life
	_cast_bears(0)
	resolve_stack()
	assert_eq(g.players[1].life, before + 1,
		"its ability exists immediately after the event (CR 603.10)")


func test_a_creature_spell_already_cast_does_not_end_it() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	_cast_bears(0)
	_sculpt(angel)   # in response, with the Bears on the stack
	resolve_stack()
	assert_false(angel.is_creature(), "resolving is not casting")
	_cast_bears(0)
	assert_true(angel.is_creature())


func test_a_cast_narrowed_to_one_seat() -> void:
	var opal := put_synthetic(1, CardData.new("Test Opal", "{W}", Mtg.CardType.ENCHANTMENT))
	var ends := ContinuousEffects.until_spell_cast(Mtg.CardType.CREATURE, 1)
	g.continuous.add_type_change(opal.id, {"set_types": Mtg.CardType.CREATURE},
		D.UNTIL_EVENT, -1, ends)
	g.continuous.add_until_eot_base_pt(opal.id, 2, 2, false, D.UNTIL_EVENT, -1, -1, false, ends)
	g.recalculate()
	assert_true(opal.is_creature())
	assert_eq([opal.cur_power, opal.cur_toughness], [2, 2])
	advance_to_step(Mtg.Step.MAIN1)
	_cast_bears(0)
	assert_true(opal.is_creature(), "\"until YOU cast\": the other seat's spell does not end it")
	advance_to_next_turn()
	_cast_bears(1)
	assert_false(opal.is_creature(), "its own seat's does")
	assert_true(g.continuous._base_pt.is_empty(), "both halves end together")


# ---------------------------------------------------- leaving, undo, layers --

func test_the_target_leaving_ends_both_halves() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(angel)
	g.return_to_hand(angel)
	assert_true(g.continuous._type_changes.is_empty())
	for entry in g.continuous._floating_statics:
		assert_ne(int(entry["instance_id"]), angel.id, "a new object (CR 400.7)")


func test_the_expiry_is_journaled() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_sculpt(angel)
	var mark := g.make_mark()
	var bears := give_hand(0, "Grizzly Bears")
	assert_true(g.continuous.expire_on_event(g, Mtg.EventType.SPELL_CAST,
		{"instance": bears, "controller": 0}))
	g.recalculate()
	assert_true(angel.is_creature())
	g.unmake_to(mark)
	g.end_search()
	g.recalculate()
	assert_false(angel.is_creature(), "the rewind brings the effect back")
	assert_true(angel.cur_abilities_silenced)


func test_under_opalescence_it_is_an_enchantment_creature_until_it_ends() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	put_synthetic(0, _opalescence())
	_sculpt(angel)
	assert_true(angel.is_creature() and angel.is_type(Mtg.CardType.ENCHANTMENT),
		"Opalescence applies after the type change (CR 613.8a)")
	assert_eq([angel.cur_power, angel.cur_toughness], [5, 5], "its mana value")
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	_cast_bears(0)
	assert_false(angel.is_type(Mtg.CardType.ENCHANTMENT))
	assert_eq([angel.cur_power, angel.cur_toughness], [4, 4])
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))


func test_a_floating_silencer_stops_a_humility_it_reaches() -> void:
	# CR 613.8a-b: Humility (made a creature by Opalescence) loses its
	# ability to a floating "loses all abilities" that can never lose its
	# own, whatever the timestamps — so Humility's effect never starts.
	CardPacks.set_enabled("pack-9", true)
	var angel := put_battlefield(0, "Serra Angel")
	put_synthetic(0, _opalescence())
	var humility := put_battlefield(1, "Humility")
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "precondition: humbled")
	_sculpt(humility)
	assert_true(humility.cur_abilities_silenced)
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING), "Humility does nothing now")
	assert_eq([angel.cur_power, angel.cur_toughness], [4, 4])
