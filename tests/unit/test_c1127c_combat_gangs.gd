extends GameTest
## ROUND 3 OF THE PLAYER REPORT 2026-11-26 (engine/ai/combat_reads.gd):
## the block ladder's pilots (the Apprentice, the Magician) and a gang
## block on a trampler when a swing is lethal — as the defender, where the
## bodies are stacked until the spill no longer kills, and as the attacker,
## where the lethal push counts the gang the defender can make. The
## Sorcerer and the Wizard search, and are pinned as they were.

const COMBAT_READS := preload("res://engine/ai/combat_reads.gd")


func before_each() -> void:
	# One rebuild of the registry for the file, not ten for each board
	# (a no-op once the packs are on); switched off again in after_all.
	CardPacks.set_enabled_many(CardPacks.available_ids(), true)
	super()


func after_each() -> void:
	g = null


func after_all() -> void:
	CardPacks.set_enabled_many(CardPacks.available_ids(), false)


func _rungs() -> Array:
	var out := [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]
	for p in out: p.mistake_chance = 0.0
	return out


func _off(p: AiProfile) -> AiProfile:
	p.mistake_chance = 0.0
	p.forecasts_tactics = false
	return p


func _ai(p: AiProfile) -> AiPlayer:
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## Our blocks against [param theirs] attacking at [param life]: "blocker>attacker".
func _blocks(p: AiProfile, ours: Array, theirs: Array, life: int) -> Array:
	before_each()
	var ai := _ai(p)
	g.players[0].life = life
	for n in ours: put_battlefield(0, n)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var ids: Array = []
	for n in theirs: ids.append(put_battlefield(1, n).id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, ids))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.awaiting_blockers)
	ai.act(g)
	var out: Array = []
	for b in g.combat.blocks:
		out.append("%s>%s" % [g.find_instance(b).data.card_name,
			g.find_instance(int(g.combat.blocks[b])).data.card_name])
	out.sort()
	return out


## The life we are left with once that combat is dealt.
func _life_after() -> int:
	var guard := 0
	while g.current_step() != Mtg.Step.MAIN2 and not g.game_over and guard < 60:
		g.pass_priority(g.priority_player)
		guard += 1
	return g.players[0].life


## Our attack declaration: the names sent, sorted.
func _attack(p: AiProfile, ours: Array, theirs: Array, their_life: int) -> Array:
	before_each()
	var ai := _ai(p)
	g.players[1].life = their_life
	for n in theirs: put_battlefield(1, n)
	for n in ours: put_battlefield(0, n)
	var guard := 0
	while not g.awaiting_attackers and guard < 50 and not g.game_over:
		if g.priority_player == 0: ai.act(g)
		else: g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.awaiting_attackers)
	ai.act(g)
	var out: Array = []
	for id in g.combat.attackers.keys(): out.append(g.find_instance(id).data.card_name)
	out.sort()
	return out


# --------------------------------------------- the defender: stack the gang --

func test_three_small_bodies_are_stacked_until_the_spill_is_survived() -> void:
	# Eight trampling at five life: one body is not enough, two are not
	# enough (1 + 2 stops three, five through), three are (four through).
	for p in _rungs():
		var blocks := _blocks(p, ["Scryb Sprites", "Grizzly Bears", "Llanowar Elves"], ["Force of Nature"], 5)
		assert_eq(blocks.size(), 3, "%s: %s" % [p.profile_name, blocks])
		assert_eq(_life_after(), 1, p.profile_name)


func test_two_are_enough_and_the_third_stays_home() -> void:
	# Eight trampling at six life: the two 2/2s stop four (alive at two).
	for p in _rungs():
		var blocks := _blocks(p, ["Grizzly Bears", "Grizzly Bears", "Scryb Sprites"], ["Force of Nature"], 6)
		assert_gt(blocks.size(), 1, "%s: %s" % [p.profile_name, blocks])
		assert_gt(_life_after(), 0, p.profile_name)
		assert_false(g.game_over, p.profile_name)


func test_the_gang_is_stacked_beside_a_second_attacker() -> void:
	# Eight trampling and a 2/2 at six life: the Bears attacking must be
	# stopped too, and the trampler's spill kept under six.
	for p in _rungs():
		var blocks := _blocks(p, ["Grizzly Bears", "Grizzly Bears", "Scryb Sprites", "Llanowar Elves"],
			["Force of Nature", "Grizzly Bears"], 5)
		_life_after()
		assert_false(g.game_over, "%s: %s" % [p.profile_name, blocks])


func test_when_the_gang_cannot_stop_it_the_block_is_as_before() -> void:
	for i in 2:
		var on := _blocks(_rungs()[i], ["Scryb Sprites", "Llanowar Elves"], ["Force of Nature"], 3)
		var off := _blocks(_off(_rungs()[i]), ["Scryb Sprites", "Llanowar Elves"], ["Force of Nature"], 3)
		assert_eq(on, off, _rungs()[i].profile_name)


# ---------------------------------------- the attacker: the push counts it --

func test_the_lethal_push_counts_the_gang_on_our_trampler() -> void:
	# Their life five, three Hill Giants untapped. One blocker each: a Giant
	# before the Force of Nature stops three, five through — "lethal", and
	# the Bears were sent along into a Giant. Two Giants before the Force
	# stop six: nothing here is lethal, and the Bears stay home.
	for i in 2:
		var p: AiProfile = _rungs()[i]
		var sent := _attack(p, ["Force of Nature", "Grizzly Bears"], ["Hill Giant", "Hill Giant", "Hill Giant"], 5)
		assert_false(sent.has("Grizzly Bears"), "%s: %s" % [p.profile_name, sent])
		var off := _attack(_off(_rungs()[i]), ["Force of Nature", "Grizzly Bears"],
			["Hill Giant", "Hill Giant", "Hill Giant"], 5)
		assert_true(off.has("Grizzly Bears"), "%s gate off: the push as it was: %s" % [p.profile_name, off])


func test_a_push_one_blocker_cannot_stop_is_still_made() -> void:
	# One Hill Giant: nothing gangs, five through is their life.
	for p in _rungs():
		var sent := _attack(p, ["Force of Nature", "Grizzly Bears"], ["Hill Giant"], 5)
		assert_true(sent.has("Force of Nature"), "%s: %s" % [p.profile_name, sent])


func test_the_searching_rungs_never_made_that_push() -> void:
	for i in [2, 3]:
		var p: AiProfile = _rungs()[i]
		var sent := _attack(p, ["Force of Nature", "Grizzly Bears"], ["Hill Giant", "Hill Giant", "Hill Giant"], 5)
		assert_false(sent.has("Grizzly Bears"), "%s: %s" % [p.profile_name, sent])
		var off := _attack(_off(_rungs()[i]), ["Force of Nature", "Grizzly Bears"],
			["Hill Giant", "Hill Giant", "Hill Giant"], 5)
		assert_eq(sent, off, "%s: unchanged by the gate" % p.profile_name)
