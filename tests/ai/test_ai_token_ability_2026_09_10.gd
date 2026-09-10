extends GameTest
## THE BODY THE SCORER COULD NOT SEE (2026-09-10, [member
## AiProfile.plays_engines]).
##
## Five permanents in this pool turn mana into a CREATURE TOKEN through an
## activated ability — The Hive, Boris Devilboon, Master of the Hunt,
## Serpent Generator and Necropolis of Azar — and not one of them had ever
## produced a token in this AI's life. The gate was not the cost: [method
## AiPlayer._ability_available] says yes to all five (the Necropolis's husk
## counter since [member AiProfile.spends_counters] landed the day before).
## The gate was the SCORER: [method AiPlayer._ability_option] had no arm
## for an effect whose whole payload is a permanent that did not exist a
## moment ago, so the option came back `{}` and the ability was never one
## of the choices.
##
## THE READING is the sixth card-local table, [constant
## EffectIntent.TOKEN_MAKERS], and it states what ONE activation
## GUARANTEES — the same rule [constant EffectIntent.CARD_LOCAL_PUMPS]
## states for a breath. Two cards are deliberately absent and both are
## pinned below:
##
##  * BOTTLE OF SULEIMAN, whose {1} and a sacrifice buys a coin flip — a
##    5/5 flier or five damage to our own face. What it GUARANTEES is
##    nothing, which is the ruling that keeps Rainbow Knights out of the
##    breath table and Camouflage out of the window table.
##  * Anything else the pool grows. The last test walks every activated
##    ability in the registry and fails on a token maker with no row.
##
## THE PRICE is the body, never a constant: [method AiPlayer._token_value]
## is [method Evaluator.permanent_value]'s creature branch read off the
## row, so a 1/1 flier beats a 1/1 and a swampwalker beats a vanilla.
##
## THE MOMENT is the mana sink at the opponent's end step, and that is the
## arm's own choice rather than an accident: a token is PERMANENT, so an
## ability that makes one has every later moment to be used at, and the
## main phase's bar — "is this worth the mana a spell might want" — is the
## right one to fail. An animation states its own bar because it expires;
## this does not.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.plays_engines = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.plays_engines = false
	return profile


## [param card_name] on our battlefield behind [param lands] copies of
## [param land], with [param husks] husk counters on it.
func _staged(card_name: String, land: String, lands: int, husks := 0) -> CardInstance:
	var src := put_battlefield(0, card_name)
	for i in lands:
		put_battlefield(0, land)
	if husks > 0:
		g.add_counters(src, "husk", husks)
	g.recalculate()
	return src


## How many tokens we control.
func _tokens() -> int:
	var many := 0
	for inst in g.players[0].battlefield:
		if inst.is_token:
			many += 1
	return many


# ------------------------------------------------- the report itself --

func test_the_necropolis_never_makes_a_spawn_with_the_knob_off() -> void:
	var ai := _ai(_off())
	var tomb := _staged("Necropolis of Azar", "Swamp", 6, 3)
	assert_true(ai._ability_available(g, tomb, 0, true),
		"the husk counter and the {5} are both payable")
	assert_true(ai._ability_option(g, tomb, 0, AiPlayer.Moment.SINK).is_empty(),
		"the scorer has nothing to say about a Spawn")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK), "",
		"so the Necropolis is never activated")
	assert_eq(_tokens(), 0, "and no Spawn is made")


func test_the_necropolis_makes_a_spawn_with_the_knob_on() -> void:
	var ai := _ai(_on())
	var tomb := _staged("Necropolis of Azar", "Swamp", 6, 3)
	var option := ai._ability_option(g, tomb, 0, AiPlayer.Moment.SINK)
	assert_false(option.is_empty(), "the Spawn is priced")
	assert_gt(float(option["value"]), AiPlayer.ABILITY_BAR_SINK,
		"and clears the sink's bar")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK),
		"activated Necropolis of Azar")
	resolve_stack()
	assert_eq(_tokens(), 1, "one Spawn of Azar")
	assert_eq(int(tomb.counters.get("husk", 0)), 2, "one husk counter spent")


## THE WHOLE CLASS, not one card: every token maker in the pool was dead
## for the same reason and all of them wake together.
func test_every_token_maker_in_the_pool_is_dead_with_the_knob_off() -> void:
	for row in _the_five():
		before_each()
		var ai := _ai(_off())
		var src := _staged(String(row["card"]), String(row["land"]),
			int(row["lands"]), int(row.get("husks", 0)))
		assert_true(ai._ability_option(g, src, 0, AiPlayer.Moment.SINK).is_empty(),
			"%s scores nothing with the knob off" % row["card"])
		assert_eq(_tokens(), 0, "%s makes nothing" % row["card"])


func test_every_token_maker_in_the_pool_makes_its_body_with_the_knob_on() -> void:
	for row in _the_five():
		before_each()
		var ai := _ai(_on())
		var src := _staged(String(row["card"]), String(row["land"]),
			int(row["lands"]), int(row.get("husks", 0)))
		assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK),
			"activated %s" % row["card"], "%s activates" % row["card"])
		resolve_stack()
		assert_eq(_tokens(), 1, "%s put one body on the table" % row["card"])


## The five, with the mana each of them wants.
func _the_five() -> Array:
	return [
		{"card": "The Hive", "land": "Island", "lands": 6},
		{"card": "Boris Devilboon", "land": "Badlands", "lands": 5},
		{"card": "Master of the Hunt", "land": "Forest", "lands": 5},
		{"card": "Serpent Generator", "land": "Island", "lands": 5},
		{"card": "Necropolis of Azar", "land": "Swamp", "lands": 6, "husks": 3},
	]


## THE PRICE IS THE BODY, never a constant. Three of the five make a 1/1
## and they are not the same purchase: the Wasp flies, the Spawn walks
## through Swamps and the Minor Demon does neither. What separates them is
## [method Evaluator.permanent_value]'s own arithmetic, read off the row —
## which is why the pricing is asked here rather than through the option,
## whose number also carries the mana each card happens to cost.
func test_the_token_is_priced_by_its_body_and_not_by_a_constant() -> void:
	var ai := _ai(_on())
	var wasp: float = ai._token_value(EffectIntent.TOKEN_MAKERS["The Hive"])
	var demon: float = ai._token_value(EffectIntent.TOKEN_MAKERS["Boris Devilboon"])
	var spawn: float = ai._token_value(EffectIntent.TOKEN_MAKERS["Necropolis of Azar"])
	assert_eq(demon, 2.0, "a 1/1 is its power plus its toughness")
	assert_gt(wasp, demon, "a 1/1 flier is worth more than a 1/1")
	assert_gt(spawn, demon, "a 1/1 swampwalker is worth more than a 1/1")
	assert_lt(spawn, wasp, "...and less than a 1/1 flier")
	# The option carries the same order once the mana is charged, for the
	# two cards whose abilities cost the same {5}.
	var hive := _staged("The Hive", "Island", 6)
	var hive_option := ai._ability_option(g, hive, 0, AiPlayer.Moment.SINK)
	before_each()
	ai = _ai(_on())
	var tomb := _staged("Necropolis of Azar", "Swamp", 6, 3)
	var tomb_option := ai._ability_option(g, tomb, 0, AiPlayer.Moment.SINK)
	assert_false(hive_option.is_empty())
	assert_false(tomb_option.is_empty())
	assert_gt(float(hive_option["value"]), float(tomb_option["value"]),
		"five mana for a flier beats five mana for a swampwalker")


## THE COIN FLIP IS NOT A BODY. Bottle of Suleiman promises a 5/5 flier
## half the time and five damage to our own face the other half; what one
## activation GUARANTEES is nothing, so it has no row and the scorer keeps
## passing it by on both arms.
func test_the_bottle_s_coin_flip_is_not_read() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var bottle := _staged("Bottle of Suleiman", "Island", 4)
		assert_true(ai._ability_option(g, bottle, 0, AiPlayer.Moment.SINK).is_empty(),
			"the flip is not priced with plays_engines %s" % knob)
		assert_eq(_tokens(), 0, "no Djinn is gambled for")


## THE COUNTER IS STILL THE SORCERER'S COST. The Necropolis needs BOTH
## knobs — the husk counter is [member AiProfile.spends_counters]'s and
## the Spawn is this one's — and the two happen to sit on the same two
## rungs, so the card either works or does not; neither knob alone wakes it.
func test_the_husk_counter_is_still_its_own_gate() -> void:
	var profile := _on()
	profile.spends_counters = false
	var ai := _ai(profile)
	var tomb := _staged("Necropolis of Azar", "Swamp", 6, 3)
	assert_false(ai._ability_available(g, tomb, 0, true),
		"no husk may be spent, so the ability is not even offered")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK), "")
	assert_eq(_tokens(), 0)


## THE MOMENT. A token is permanent, so the ability that makes one has
## every later moment to be used at and answers to the main phase's own
## bar — "is this worth the mana a spell might want". It fails that bar
## and is bought at the opponent's end step instead, where the mana would
## be lost anyway. (An animation states its own bar because it expires at
## end of turn; this one must not.)
func test_the_token_is_bought_where_the_mana_would_be_wasted() -> void:
	var ai := _ai(_on())
	var hive := _staged("The Hive", "Island", 6)
	var main := ai._ability_option(g, hive, 0, AiPlayer.Moment.MAIN)
	assert_false(main.is_empty(), "the Wasp is priced in the main phase too")
	assert_false(main.has("bar"), "but the arm states no bar of its own")
	assert_lt(float(main["value"]), AiPlayer.ABILITY_BAR_MAIN,
		"and a 1/1 flier for five mana does not clear the main phase's bar")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.MAIN), "",
		"so nothing is bought in our own main phase")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK),
		"activated The Hive", "and everything is bought at their end step")


## THE TWO THE RULING REFUSES, both for the coin flip and both named here
## so that neither can be added to the table by accident. Bottle of
## Suleiman's {1} buys a 5/5 flier OR five damage to our own face;
## Pandora's Box's {3} rolls one creature out of BOTH libraries and then
## flips for EACH player, so a winning activation can hand the opponent
## the copy and a losing one buys nothing at all.
const REFUSED_FOR_THE_FLIP: Array[String] = [
	"Bottle of Suleiman", "Pandora's Box",
]


## THE TABLE AND THE POOL, pinned to each other the way the counter
## ruling is (`grep -rn create_token cards/`): a sixth card whose
## activated ability makes a token either gets a row here or fails this
## file. The scan reads the ability's own printed LINE, and "nontoken" —
## Bronze Tablet's and Golgothian Sylex's word — is deleted first, which
## is the normalisation [method AiSideboard._strip_negations] exists for.
##
## Its one blind spot is the test above it: Bottle of Suleiman's line says
## "flip a coin", not "token", so the scan cannot see it and the refusal
## is pinned by hand instead.
func test_the_pool_has_no_unlisted_token_ability() -> void:
	var unlisted: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(String(card_name))
		if data == null:
			continue
		for ability in data.activated_abilities:
			var line := ability.text.to_lower().replace("nontoken", "")
			if not line.contains("token"):
				continue
			if EffectIntent.TOKEN_MAKERS.has(String(card_name)) \
					or REFUSED_FOR_THE_FLIP.has(String(card_name)):
				continue
			unlisted.append(String(card_name))
	assert_eq(unlisted, [] as Array[String],
		"an activated ability makes a token with no EffectIntent.TOKEN_MAKERS row")
	# ...and no row names a card the pool does not have.
	for listed in EffectIntent.TOKEN_MAKERS:
		assert_true(CardRegistry.has_card(String(listed)),
			"TOKEN_MAKERS names %s, which is not in the pool" % listed)
	assert_eq(EffectIntent.TOKEN_MAKERS.size(), 5, "five, and the two refused")


## PANDORA'S BOX is the second refusal and wants its own board: with the
## knob on and the mana up, the scorer still passes it by.
func test_pandora_s_box_is_not_read_either() -> void:
	var ai := _ai(_on())
	var box := _staged("Pandora's Box", "Island", 5)
	assert_true(ai._ability_option(g, box, 0, AiPlayer.Moment.SINK).is_empty(),
		"a flip per player is not a body this pilot can price")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK), "")
	assert_eq(_tokens(), 0)
