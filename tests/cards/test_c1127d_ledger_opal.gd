extends GameTest
## The fidelity ledger's Opal Titan row, lifted: "protection from each of
## that spell's colors" reads the spell as it LAST EXISTED on the stack
## (CR 608.2h) when it has left the stack before the trigger resolves —
## [member CardInstance.last_stack_colors], captured as a spell is
## countered, exiled from the stack or put into a graveyard from it.

const W := Mtg.ManaColor.W
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)


## P0 casts Grizzly Bears into P1's Opal Titan and Purelaces the spell;
## the Purelace resolves, the Titan's trigger still waits above the Bears.
func _laced_bears_under_a_waiting_trigger() -> Array:
	var titan := put_battlefield(1, "Opal Titan")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	var lace := give_hand(0, "Purelace")
	add_mana(0, W)
	_priority_to(0)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bears)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(lace.zone, Mtg.Zone.GRAVEYARD, "the Purelace has resolved")
	assert_eq(bears.zone, Mtg.Zone.STACK)
	assert_eq(bears.cur_colors, W, "the Bears spell is white")
	assert_eq(g.stack.size(), 2, "the Titan's trigger waits above the Bears")
	assert_false(titan.is_creature())
	return [titan, bears]


func test_opal_titan_remembers_a_countered_spells_last_colors() -> void:
	var pair := _laced_bears_under_a_waiting_trigger()
	var titan: CardInstance = pair[0]
	var bears: CardInstance = pair[1]
	g.counter_spell(bears)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(titan.is_creature())
	assert_eq(titan.cur_protection, W, "protection from white, the color it last had on the stack")


func test_opal_titan_remembers_a_spell_exiled_from_the_stack() -> void:
	var pair := _laced_bears_under_a_waiting_trigger()
	var titan: CardInstance = pair[0]
	var bears: CardInstance = pair[1]
	g.exile_spell_from_stack(bears)
	assert_ne(bears.zone, Mtg.Zone.STACK)
	resolve_stack()
	assert_true(titan.is_creature())
	assert_eq(titan.cur_protection, W)


func test_opal_titan_remembers_a_spell_put_into_the_graveyard_from_the_stack() -> void:
	var pair := _laced_bears_under_a_waiting_trigger()
	var titan: CardInstance = pair[0]
	var bears: CardInstance = pair[1]
	g.card_to_graveyard_from_anywhere(bears)
	resolve_stack()
	assert_true(titan.is_creature())
	assert_eq(titan.cur_protection, W)


func test_an_unchanged_countered_spell_still_reads_as_cast() -> void:
	var titan := put_battlefield(1, "Opal Titan")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	g.counter_spell(bears)
	resolve_stack()
	assert_eq(titan.cur_protection, G)


func test_the_search_journal_forgets_the_remembered_colors() -> void:
	var pair := _laced_bears_under_a_waiting_trigger()
	var bears: CardInstance = pair[1]
	var mark := g.make_mark()
	g.counter_spell(bears)
	assert_eq(bears.last_stack_colors, W)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bears.zone, Mtg.Zone.STACK)
	assert_eq(bears.last_stack_colors, 0)
	assert_eq(bears.last_stack_item, -1)
