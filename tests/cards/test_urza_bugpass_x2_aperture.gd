extends GameTest
## The 0.60.19 bug pass (Pack 10), Temporal Aperture's revealed top.
##
## "Play with the top card of your library revealed ... for as long as that
## card remains on top": only THAT card is ever public, and only while it
## has stayed on top. The reveal used to be a flag the recalculation set, so
## a draw, a mill, a shuffle or a tutor INSIDE a resolution (no
## recalculation there) left it standing over the NEXT, hidden card — which
## the log then named to the table, MtgGame.revealed_top_card handed to the
## LAN view and the AI observation read (rule 8). Now the reveal names its
## card and the MtgPlayer.library_top_epoch it was made at, judged live.
## The second half: "remains on top" ends for good — a card covered and
## uncovered, milled and put back, or drawn and put back did not REMAIN
## there (CR 400.7; Forge's StillTopCheck), while a card leaving from
## deeper down, or one put under it, leaves it where it was.

const U := Mtg.ManaColor.U
const G := Mtg.ManaColor.G
const C := Mtg.ManaColor.C

const NAMES := ["Grizzly Bears", "Llanowar Elves", "Shivan Dragon", "Serra Angel", "Hill Giant",
	"Craw Wurm", "War Mammoth"]

## [the name revealed_top_card(0) gave, the AI observation's revealed top
## for seat 1, the top the LAN guest's view named] at every published state.
var published: Array = []
var referee: SgPracticeMatch = null


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	published = []
	g.state_changed.connect(_on_state)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _on_state() -> void:
	var top := g.revealed_top_card(0)
	var seen: Dictionary = AiObservation.capture(g, 1)["players"][0].get("revealed_top", {})
	var guest := String(referee.view(1).players[0].top) if referee != null else ""
	published.append([top.data.card_name if top != null else "", String(seen.get("name", "")), guest])


func _library(names: Array) -> void:
	g.players[0].library.clear()
	for n in names:
		var inst := _make_instance(0, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(inst)


## Activate a Temporal Aperture of P0's; returns the revealed top card.
func _aperture() -> CardInstance:
	var aperture := put_battlefield(0, "Temporal Aperture")
	add_mana(0, U, 5)
	assert_ok(g.activate_ability(0, aperture, 0))
	resolve_stack()
	var top: CardInstance = g.players[0].library.back()
	assert_eq(g.revealed_top_card(0), top, "the Aperture's card is revealed")
	published.clear()
	return top


func _revealed_lines(from := 0) -> Array:
	var out: Array = []
	for i in range(from, g.log_lines.size()):
		if String(g.log_lines[i]).contains("library is revealed:"):
			out.append(String(g.log_lines[i]))
	return out


## No line, no published state and no AI observation named any card but
## [param top] (the Aperture's own, public since it was revealed).
func _no_leak(top: CardInstance, label: String) -> void:
	for line in _revealed_lines():
		assert_true(String(line).ends_with(top.data.card_name),
			"%s: a hidden library top was announced: %s" % [label, line])
	for row in published:
		assert_true(row[0] == "" or row[0] == top.data.card_name,
			"%s: revealed_top_card named a hidden card: %s" % [label, row[0]])
		assert_true(row[1] == "" or row[1] == top.data.card_name,
			"%s: the AI observation read a hidden card: %s" % [label, row[1]])
		assert_true(row[2] == "" or row[2] == top.data.card_name,
			"%s: the LAN guest was sent a hidden top: %s" % [label, row[2]])
	var hidden: CardInstance = g.players[0].library.back() if not g.players[0].library.is_empty() else null
	if hidden != null and hidden != top:
		assert_null(g.revealed_top_card(0), "%s: the new top is hidden" % label)


static func _cycler() -> CardData:
	return CardData.new("Test Cycler", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(GainLifeEffect.new(1)) \
		.with_cycling("{2}") \
		.oracle("You gain 1 life.\nCycling {2} ({2}, Discard this card: Draw a card.)")


# ----------------------------------------------- h3-1: no hidden top named --

func test_a_draw_inside_a_resolution_names_no_hidden_top() -> void:
	_library(NAMES)
	var top := _aperture()
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, U, 1)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(top.zone, Mtg.Zone.HAND)
	_no_leak(top, "Ancestral Recall")


func test_a_cycling_draw_names_no_hidden_top() -> void:
	_library(NAMES)
	var top := _aperture()
	var cycler := give_synthetic(0, _cycler())
	g.recalculate()
	var index := -1
	for i in cycler.cur_activated_abilities.size():
		if cycler.cur_activated_abilities[i].is_cycling: index = i
	assert_gt(index, -1)
	add_mana(0, C, 2)
	assert_ok(g.activate_ability(0, cycler, index))
	resolve_stack()
	assert_eq(top.zone, Mtg.Zone.HAND, "the cycle drew the revealed card")
	_no_leak(top, "cycling")


func test_the_opponents_millstone_names_no_hidden_top() -> void:
	_library(NAMES)
	var top := _aperture()
	var stone := put_battlefield(1, "Millstone")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_ok(g.pass_priority(0))
	add_mana(1, C, 2)
	assert_ok(g.activate_ability(1, stone, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(top.zone, Mtg.Zone.GRAVEYARD)
	_no_leak(top, "Millstone")


func test_a_tutors_shuffle_names_no_hidden_top() -> void:
	_library(NAMES + ["Forest", "Giant Growth"])
	var top := _aperture()
	put_battlefield(0, "Forest")
	var rotation := give_hand(0, "Crop Rotation")
	add_mana(0, G, 1)
	assert_ok(g.cast_spell(0, rotation))
	resolve_stack()
	_no_leak(top, "Crop Rotation")


func test_a_plain_shuffle_names_no_hidden_top() -> void:
	_library(NAMES)
	var top := _aperture()
	var mark := g.log_lines.size()
	g.shuffle_library(0)
	if g.players[0].library.back() == top:
		g.shuffle_library(0)   # the seed is fixed; make sure the top moved
	assert_ne(g.players[0].library.back(), top)
	assert_eq(_revealed_lines(mark), [], "a shuffle ends the reveal: no new top announced")
	assert_null(g.revealed_top_card(0), "ended before any recalculation")
	_no_leak(top, "shuffle")


func test_casting_the_revealed_card_names_no_hidden_top() -> void:
	_library(NAMES)
	var top := _aperture()
	var rows := g.payment_rows(0, top)
	var free := -1
	for i in rows.size():
		if bool(Dictionary(rows[i].get("payment", {})).get("zone_free", false)): free = i
	assert_gt(free, -1, "a free row")
	assert_ok(g.cast_spell(0, top, [], 0, free))
	resolve_stack()
	_no_leak(top, "the free cast")


func test_a_second_aperture_announces_only_its_own_card() -> void:
	_library(NAMES)
	var first := _aperture()
	var mark := g.log_lines.size()
	var second := put_battlefield(0, "Temporal Aperture")
	add_mana(0, U, 5)
	assert_ok(g.activate_ability(0, second, 0))
	resolve_stack()
	var now: CardInstance = g.players[0].library.back()
	for line in _revealed_lines(mark):
		assert_true(String(line).ends_with(now.data.card_name), "only the new reveal: %s" % line)
	assert_eq(g.revealed_top_card(0), now)
	assert_false(first != now and g.can_play_from_zone(0, first), "the first offer ended with its shuffle")


func test_the_lan_view_shows_no_hidden_top_after_the_draw() -> void:
	referee = SgPracticeMatch.new(42)
	referee.game = g
	_library(NAMES)
	var top := _aperture()
	assert_eq(String(referee.view(1).players[0].top), top.data.card_name, "public while it holds")
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, U, 1)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	resolve_stack()
	_no_leak(top, "the LAN view")
	var theirs := referee.view(1)
	assert_eq(String(theirs.players[0].top), "")
	assert_eq(theirs.players[0].library_top, [])
	assert_false(SgProtocol.encode(theirs).contains(g.players[0].library.back().data.card_name),
		"the new top is in no row of the guest's view")


## Abundance's "reveal until a land" each time (option 1), else the hint.
class LandSeeker extends DecisionAgent:
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		return 1 if prompt.begins_with("Abundance") else hint


func test_abundances_reveal_names_no_hidden_top() -> void:
	g.set_agent(0, LandSeeker.new())
	_library(["Forest", "Island"] + NAMES)
	put_battlefield(0, "Abundance")
	var top := _aperture()
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, U, 1)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	resolve_stack()
	assert_false(top.zone == Mtg.Zone.LIBRARY and g.players[0].library.back() == top,
		"Abundance moved the top card (to the hand or the bottom)")
	_no_leak(top, "Abundance")


const TOP_MOVES := ["draw", "mill", "exile top", "top to hand", "library card to hand",
	"library card exiled", "library card to graveyard", "library card onto the battlefield",
	"put on the bottom", "covered from the hand", "a deeper card moved to the top",
	"the top two reordered", "shuffle"]


## Move the top of P0's library ([param top] the Aperture's card) the way
## [param how] says, through the engine's own helper.
func _move_top(how: String, top: CardInstance) -> void:
	var lib := g.players[0].library
	match how:
		"draw": g.draw_cards(0, 1)
		"mill": g.mill(0, 1)
		"exile top": g.exile_top_of_library(0)
		"top to hand": g.top_of_library_to_hand(0)
		"library card to hand": g.library_card_to_hand(top)
		"library card exiled": g.exile_library_card(top)
		"library card to graveyard": g.put_library_card_into_graveyard(top)
		"library card onto the battlefield": g.put_library_card_onto_battlefield(top, 0)
		"put on the bottom": g.put_on_bottom_of_library(top)
		"covered from the hand": g.put_from_hand_on_top_of_library(give_hand(0, "Lightning Bolt"))
		"a deeper card moved to the top": g.move_library_card_to_top(lib[0])
		"the top two reordered":
			var order: Array[CardInstance] = [lib[lib.size() - 2], top]
			g.reorder_top_of_library(0, order)
		"shuffle":
			for _i in 6:
				g.shuffle_library(0)
				if lib.back() != top: return


## Every library helper that moves the top ends the reveal AT ONCE — with no
## recalculation, as inside a resolution — and announces nothing new.
func test_every_helper_that_moves_the_top_ends_the_reveal_at_once() -> void:
	for how in TOP_MOVES:
		g = null
		before_each()
		_library(["Craw Wurm", "War Mammoth", "Hill Giant", "Serra Angel", "Grizzly Bears"])
		var top := _aperture()
		var mark := g.log_lines.size()
		_move_top(how, top)
		assert_ne(g.players[0].library.back(), top, "%s: the top moved" % how)
		assert_null(g.revealed_top_card(0), "%s: the new top is hidden at once" % how)
		assert_eq(_revealed_lines(mark), [], "%s: no new top announced" % how)
		assert_false(g.can_play_from_zone(0, top), how)


# ---------------------------------------- h3-2 / h9-8: ends for good --

func test_a_covered_card_uncovered_again_did_not_remain_on_top() -> void:
	_library(NAMES)
	var top := _aperture()
	var lid := give_hand(0, "Lightning Bolt")
	g.put_from_hand_on_top_of_library(lid)
	assert_false(g.can_play_from_zone(0, top), "covered")
	g.draw_cards(0, 1)
	assert_eq(g.players[0].library.back(), top, "on top again")
	g.recalculate()
	assert_false(g.can_play_from_zone(0, top), "a card was put on it: the offer is over")
	assert_null(g.revealed_top_card(0), "and the top is hidden again")
	assert_false(g.playable_cards(0).has(top))


func test_a_card_milled_and_put_back_did_not_remain_on_top() -> void:
	_library(NAMES)
	var top := _aperture()
	g.mill(0, 1)
	g.return_from_graveyard_to_library_top(top)
	assert_eq(g.players[0].library.back(), top)
	g.recalculate()
	assert_false(g.can_play_from_zone(0, top), "a new object (CR 400.7)")
	assert_null(g.revealed_top_card(0))


func test_a_card_drawn_and_put_back_did_not_remain_on_top() -> void:
	_library(NAMES)
	var top := _aperture()
	g.draw_cards(0, 1)
	g.put_from_hand_on_top_of_library(top)
	g.recalculate()
	assert_false(g.can_play_from_zone(0, top))
	assert_null(g.revealed_top_card(0))


func test_a_card_leaving_from_deeper_down_keeps_the_offer() -> void:
	_library(NAMES)
	var top := _aperture()
	var deep: CardInstance = g.players[0].library[1]
	g.put_library_card_into_graveyard(deep)
	var bolt := give_hand(0, "Lightning Bolt")
	g.put_on_bottom_of_library(bolt)
	g.recalculate()
	assert_eq(g.players[0].library.back(), top)
	assert_true(g.can_play_from_zone(0, top), "the top card never moved")
	assert_eq(g.revealed_top_card(0), top)


func test_a_rewound_probe_that_drew_does_not_end_the_offer() -> void:
	_library(NAMES)
	var top := _aperture()
	var mark := g.make_mark()
	g.draw_cards(0, 1)
	g.put_from_hand_on_top_of_library(top)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].library.back(), top)
	assert_true(g.can_play_from_zone(0, top), "the probe never happened")
	assert_eq(g.revealed_top_card(0), top)
