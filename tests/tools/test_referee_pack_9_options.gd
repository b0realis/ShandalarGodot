extends GameTest
## PACK 9 IN THE REFEREE'S OPTIONS (DeckLab/referee.gd `options_for`) — what
## a program at the pipe, the MCP door and the decision menus read: the
## Tempest block's payment rows and special actions arrive through the
## SAME keys as every older one, worded by the engine, usable only.
##
##  * a BUYBACK spell's cast lists both rows in `modes` ("Buyback: ..."),
##    and `usable_modes` names the ones the seat can pay;
##  * a row a permanent GRANTS (Dream Halls) is a mode of a plain spell,
##    listed usable when it alone can be paid;
##  * a licid's end and Volrath's Curse's ignore are `special` entries
##    while they can be taken, and taking one through `special` works;
##  * a target count an earlier target sets (Reap) reaches the program in
##    the announcement's `counts`.

const REFEREE := "res://DeckLab/referee.gd"
const OC := preload("res://engine/additional_object_costs.gd")

var referee: SgPracticeMatch
var Referee: Script


func before_each() -> void:
	super.before_each()
	Referee = load(REFEREE)
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null


func _options(seat := 0) -> Dictionary:
	return Referee.options_for(referee.view(seat), seat)


func _cast(card: CardInstance) -> Dictionary:
	for entry in _options().get("prepare", {}).get("casts", []):
		if entry.card == referee._handle(0, card): return entry
	return {}


func _special(prefix: String) -> Dictionary:
	for entry in _options().get("special", {}).get("specials", []):
		if String(entry.label).begins_with(prefix): return entry
	return {}


static func _capsize() -> CardData:
	return CardData.new("Test Capsize", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1)).with_buyback({"mana": "{3}"})


static func _halls() -> CardData:
	return CardData.new("Test Halls", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_halls_rows)


static func _shares_color(_g: MtgGame, card: CardInstance, spell: CardInstance) -> bool:
	return spell != null and (card.cur_colors & spell.cur_colors) != 0


static func _halls_rows(_g: MtgGame, _pid: int, spell: CardInstance, _src: CardInstance) -> Array:
	if spell.cur_colors == 0:
		return []
	var group := OC.discarding("card that shares a color with it")
	group["source_filter"] = _shares_color
	return [{"label": "Discard a card that shares a color with it", "object_costs": [group]}]


static func _insight() -> CardData:
	return CardData.new("Test Insight", "{2}{U}", Mtg.CardType.SORCERY).spell(DrawEffect.new(1))


static func _licid() -> CardData:
	return CardData.new("Test Licid", "{1}{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{R}", "{R}")


static func _curse() -> CardData:
	return CardData.new("Test Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()).ignorable_by_sacrifice("permanent")


class OpponentSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass


static func _black_permanents(game: MtgGame, _source: CardInstance, earlier: Array) -> Vector2i:
	if earlier.is_empty() or not (earlier[0] as TargetRef).is_player:
		return Vector2i(0, 0)
	var n := 0
	for perm in game.players[(earlier[0] as TargetRef).player_id].battlefield:
		if (perm.cur_colors & Mtg.ManaColor.B) != 0:
			n += 1
	return Vector2i(0, n)


static func _reap() -> CardData:
	var cards := ReturnFromGraveyardEffect.new().any_card()
	cards.targets_counted_by(_black_permanents)
	return CardData.new("Test Reap", "{1}{G}", Mtg.CardType.INSTANT) \
		.spell(OpponentSlot.new()).spell(cards)


# ---------------------------------------------------------------- rows --

func test_a_buyback_cast_lists_both_rows_and_the_payable_ones() -> void:
	var capsize := give_synthetic(0, _capsize())
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 1)
	var entry := _cast(capsize)
	assert_eq(entry.get("modes", []), ["Pay {1}{U}{U}", "Buyback: Pay {1}{U}{U} plus {3} (returns to your hand)"])
	assert_eq(entry.get("usable_modes", []), [0], "three mana: the printed row only")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_eq(_cast(capsize).get("usable_modes", []), [0, 1], "six: the buyback row too")


func test_a_granted_row_is_a_mode_of_a_plain_spell() -> void:
	put_synthetic(0, _halls())
	var insight := give_synthetic(0, _insight())
	assert_eq(_cast(insight), {}, "no mana, nothing to discard: no cast is listed")
	give_synthetic(0, _insight())
	var entry := _cast(insight)
	assert_eq(entry.get("modes", []).size(), 2)
	assert_string_contains(String(entry.modes[1]), "Discard a card that shares a color with it")
	assert_eq(entry.get("usable_modes", []), [1], "only the granted row can be paid")


# ------------------------------------------------------------ specials --

func test_a_licid_end_is_a_special_entry_while_it_can_be_taken() -> void:
	var licid := put_synthetic(0, _licid())
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.priority_player = 0
	assert_eq(_special("Pay {R}: end Test Licid's effect"), {}, "no red mana: usable only")
	put_battlefield(0, "Mountain")
	var entry := _special("Pay {R}: end Test Licid's effect")
	assert_ne(entry, {})
	assert_ok(referee.act(0, {"op": "special", "index": int(entry.index)}))
	assert_false(g.is_licid_aura(licid))


func test_a_curse_ignore_is_a_special_entry_and_its_sacrifice_a_choice() -> void:
	var curse := give_synthetic(1, _curse())
	var bear := put_battlefield(0, "Grizzly Bears")
	g.priority_player = 1
	g.attach_aura_from_anywhere(curse, bear, 1)
	g.priority_player = 0
	var entry := _special("Sacrifice a permanent: ignore Test Curse this turn")
	assert_ne(entry, {})
	assert_ok(referee.act(0, {"op": "special", "index": int(entry.index)}))
	var asked := _options()
	assert_eq(asked.mode, "choice")
	assert_true(asked.has("cancel"), "the sacrifice is a cost: it may be withdrawn")
	assert_ok(referee.act(0, {"op": "cancel"}))
	assert_false(g.effect_ignored_by(curse, 0))


# ------------------------------------------------------------- targets --

func test_reaps_counts_reach_the_program() -> void:
	var reap := give_synthetic(0, _reap())
	put_battlefield(1, "Black Knight")
	for card_name in ["Grizzly Bears", "Hill Giant"]:
		var dead := give_hand(0, card_name)
		g.players[0].hand.erase(dead)
		dead.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(dead)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, reap), "kind": "spell",
		"index": 0, "x": 0, "mode": 0}))
	var slots: Array = _options().announcement.slots
	assert_eq(slots.size(), 2)
	assert_eq(slots[1].counts, [[slots[0].targets[0].id, 0, 1]],
		"one black permanent: up to one of the two cards")
	assert_eq(int(slots[1].max), 1)
