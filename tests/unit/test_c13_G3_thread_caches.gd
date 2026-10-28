extends GameTest
## THE STATICS THE DECK LAB'S THREADS SHARE (part C stage C3, h5-2). The
## Lab plays its games on a WorkerThreadPool, so a static a card or the AI
## writes is written by several games at once:
##  - [MirageTactics]' fragile cache, filled on the first "becomes the
##    target" creature — eight threads filling it crashed the process
##    (SIGSEGV, "double free or corruption") three runs in three; now under
##    its own lock, [EffectIntent]'s pattern;
##  - Coat of Arms' creature types, filled on the first ask — now built as
##    the script loads and read-only after;
##  - Reflecting Pool's census guard, one count for every thread — a Pool in
##    one game made nothing while another game's Pool took its census; now
##    kept by thread.

const MT := preload("res://engine/ai/mirage_tactics.gd")
const CA := preload("res://cards/sets/exo/_artifacts.gd")
const LM := preload("res://cards/sets/tmp/_lands_mana.gd")
const KEYS := 1500
const MARK := "G3-race #"

var _inside := Semaphore.new()
var _release := Semaphore.new()


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)
	for key in MT._fragile_cache.keys():
		if String(key).contains(MARK):
			MT._fragile_cache.erase(key)


# ------------------------------------------------------ the fragile cache --

## One thread's share: every key read (and so written) once, its answers
## checked against the reading; the wrong ones counted.
func _hammer(t: int) -> int:
	var wrong := 0
	for n in KEYS:
		var text := "When this creature becomes the target of a spell or ability, sacrifice it. %s%d" % [MARK, n]
		var on_aura := (n + t) % 2 == 0
		var expected := 0 if on_aura else MT.FRAGILE_DIES
		if MT._fragile_kind(text, on_aura) != expected:
			wrong += 1
	return wrong


func test_eight_threads_fill_the_fragile_cache_at_once() -> void:
	var threads: Array[Thread] = []
	for t in 8:
		var thread := Thread.new()
		thread.start(_hammer.bind(t))
		threads.append(thread)
	var wrong := 0
	for thread in threads:
		wrong += int(thread.wait_to_finish())
	assert_eq(wrong, 0, "every answer the text's own")
	var kept := 0
	for key in MT._fragile_cache:
		if String(key).contains(MARK):
			kept += 1
	assert_eq(kept, KEYS * 2, "every key kept once, a creature's and an Aura's")


# ---------------------------------------------------------- Coat of Arms --

func test_coat_of_arms_types_are_built_as_the_script_loads() -> void:
	assert_true(CA._creature_types.is_read_only(), "never written after the load, by any thread")
	assert_gt(CA._creature_types.size(), 200, "every creature type")
	assert_true(CA.is_creature_type("Goblin") and CA.is_creature_type("sliver"))
	assert_false(CA.is_creature_type("forest"), "a land type is no creature type (CR 205.3m)")
	put_battlefield(0, "Coat of Arms")
	var bears := put_battlefield(0, "Grizzly Bears")
	var others := put_battlefield(1, "Grizzly Bears")
	var raiders := put_battlefield(1, "Mons's Goblin Raiders")
	g.recalculate()
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 3], "+1/+1 for the other Bear")
	assert_eq([others.cur_power, others.cur_toughness], [3, 3])
	assert_eq([raiders.cur_power, raiders.cur_toughness], [1, 1], "no other Goblin")


# -------------------------------------------------------- Reflecting Pool --

## A land's colour choice that holds its census until the test lets go —
## another thread's Pool inside its census for as long as the test needs.
func _held_census(_g: MtgGame, _land: CardInstance) -> Array:
	_inside.post()
	_release.wait()
	return [Mtg.ManaColor.G]


func _census_on_thread(pool: CardInstance) -> Array:
	return LM._pool_types(g, pool)


func test_a_pool_takes_its_census_while_another_thread_takes_one() -> void:
	var mine := put_battlefield(0, "Reflecting Pool")
	put_battlefield(0, "Plains")
	var theirs := put_battlefield(1, "Reflecting Pool")
	var slow := put_battlefield(1, "Forest")
	slow.cur_mana_abilities.append(ManaAbility.new(Mtg.ManaColor.C).with_color_choice(_held_census))
	var thread := Thread.new()
	thread.start(_census_on_thread.bind(theirs))
	var waited := 0
	while not _inside.try_wait() and waited < 5000:
		OS.delay_msec(1)
		waited += 1
	assert_lt(waited, 5000, "the other thread is inside its census")
	var during := _colors(LM._pool_types(g, mine))
	_release.post()
	var other := _colors(thread.wait_to_finish())
	assert_eq(during, [Mtg.ManaColor.W], "this game's Pool reads its own Plains meanwhile")
	assert_eq(other, [Mtg.ManaColor.G], "and the other its Forest")
	assert_eq(_colors(LM._pool_types(g, mine)), [Mtg.ManaColor.W], "and again after")


func test_two_pools_still_feed_neither_on_one_thread() -> void:
	var pool := put_battlefield(0, "Reflecting Pool")
	put_battlefield(0, "Reflecting Pool")
	assert_eq(_colors(LM._pool_types(g, pool)), [], "a Pool asked inside a census answers nothing")
	put_battlefield(0, "Island")
	assert_eq(_colors(LM._pool_types(g, pool)), [Mtg.ManaColor.U])


## [param found] as a plain Array of ints, to compare.
func _colors(found: Variant) -> Array:
	var out := []
	for color in found as Array:
		out.append(int(color))
	return out
