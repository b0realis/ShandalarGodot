extends GameTest
## THE PLAN THE PILOT BROKE ITSELF (2026-09-10, the fifth pass at
## [member AiProfile.pumps_to_attack]; the last thing the fourth pass left
## standing on [member AiPlayer._pump_plan] and in `docs/ai-difficulty.md`
## §5).
##
## WHAT WAS OPEN. The gang pass made the declaration and the recovery agree
## by construction — [method AiPlayer._owed_bonuses] prices a gang's mates
## at what the plan still owes them, and the trampler's residue ([method
## AiPlayer._absorbed_by]) reads the same number — with one exposure named
## at the site: *mana spent between the declaration and the recovery by
## something else leaves a body short of the reach its plan promised, and
## the residue then over-reads by that much.* That is the dangerous
## direction. The panic line reads less through than will land, the chump
## rung stays shut, and the pilot declines to chump and dies.
##
## SOMETHING CAN, AND IT IS THE PILOT ITSELF. Walking
## [method AiPlayer._respond_action] in order — the counterspell, the
## answer to removal on the stack, the pre-emptive regeneration shield, the
## combat breaths — the spender is the line directly above the recovery:
## [method AiPlayer._combat_regeneration] pays for a shield out of the same
## open mana the declaration had already allotted to the breaths. The two
## were double-booked at the declaration as well, because the block
## ladder's [method AiPlayer._dies_to] asks
## [method AiPlayer._shieldable] → [method AiPlayer._can_shield], which
## plans the shield's cost against the WHOLE open pool.
##
## REPRODUCED on the gang pass's own board plus one Drudge Skeletons: six
## Swamps, a Carrion Ants and a Scathe Zombies in front of a Force of
## Nature (8/8 trample), the Skeletons in front of a Hill Giant, us at 12.
## The plan allotted the swarm six breaths; the shield took a Swamp for the
## 1/1; the swarm could then reach only five; the gang question said no —
## correctly, of the mana that was left — and the recovery bought NOTHING.
## Both blockers died at 0/1 and 2/2, FIVE trampled through, the trampler
## walked away and five Swamps were still untapped. Remove the Skeletons
## from that board and the same pilot buys all six and kills the 8/8.
##
## FIXED by [method AiPlayer._combat_planned_pumps], which delivers the
## breaths the declaration was priced with before the pilot's own next
## discretionary purchase. The counterspell and the answer to removal still
## come first and always could: [method AiPlayer._pump_reserve] books
## [method AiPlayer._held_reserve] out of every share, so the plan never
## owned that mana.
##
## AND ONE THING RULED RATHER THAN BUILT, pinned below so it is not
## reopened: [method AiPlayer._owed_bonuses] still credits a mate with the
## PLAN's number and is not re-read against the mana on the table. What can
## still take that mana is an OPPONENT's tapper, and over-crediting a mate
## errs on the harmless side — the breaths it buys are toughness as well as
## power, so against a trampler (the case this reading exists for) they
## still absorb the assignment they were bought for, and on the opponent's
## turn that mana has nothing else to buy.
##
## Every behaviour is pinned with the knob ON and with it OFF. The fix
## cannot move the null: below Sorcerer [method
## AiPlayer._remember_pump_plan] is never called, and the new pass returns
## "" before it reads the board.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = false
	# AND THE OTHER KNOB THAT TOUCHES THIS DECLARATION IS PINNED WITH IT
	# (2026-09-10, [member AiProfile.reinforces_blocks]). The null this arm
	# states is the pilot BEFORE the pump plan, and on this board the block
	# reinforcement — a second body onto the Hill Giant the regenerator
	# holds but does not kill — would add a third block to it: two changes
	# read as one, which is what `docs/ai-difficulty.md` §5 forbids of any
	# knob that defaults on at Sorcerer.
	profile.reinforces_blocks = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _untapped_lands(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


func _mine(card_name: String) -> CardInstance:
	for inst in g.players[0].battlefield:
		if inst.data.card_name == card_name:
			return inst
	return null


func _cycle_to_attack(seat: int) -> void:
	var guard := 0
	while (not g.awaiting_attackers or g.active_player != seat) \
			and not g.game_over and guard < 200:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_attackers, "reached a declaration")
	assert_eq(g.active_player, seat, "and it is the right seat's")


func _reach_blockers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_DAMAGE \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			break
		guard += 1


## THE REPORT'S BOARD: [param bodies] and the lands on our side, the
## attackers on theirs, us at 12, stopped on our block declaration.
func _swing(ai: AiPlayer, lands: Dictionary, bodies: Array,
		attackers: Array) -> Array[CardInstance]:
	for card_name in bodies:
		put_battlefield(0, card_name)
	for land_name in lands:
		_lands(0, String(land_name), int(lands[land_name]))
	_cycle_to_attack(1)
	g.players[0].life = 12
	var theirs: Array[CardInstance] = []
	var ids: Array = []
	for card_name in attackers:
		var inst := put_battlefield(1, card_name)
		theirs.append(inst)
		ids.append(inst.id)
	assert_ok(g.declare_attackers(1, ids))
	_reach_blockers(ai)
	return theirs


# --------------------------------------- one: the plan is paid for first --

func test_the_gang_buys_its_plan_before_the_pre_emptive_shield() -> void:
	# THE REPRODUCTION, and the whole of it. Before this pass the shield
	# went first, took the sixth Swamp, and the swarm — which needed all
	# six to make the gang's eight damage — bought nothing at all.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, {"Swamp": 6},
		["Carrion Ants", "Scathe Zombies", "Drudge Skeletons"],
		["Force of Nature", "Hill Giant"])
	assert_string_contains(ai.act(g), "declared 3 block(s)", "the gang is made")
	assert_eq(ai._pump_plan_for(g, _mine("Carrion Ants")), 6,
		"and the swarm is declared on six breaths")
	_play_out_combat(ai, foe)
	assert_eq(theirs[0].zone, Mtg.Zone.GRAVEYARD, "the trampler died")
	assert_eq(g.players[0].life, 12, "and nothing came through it")
	assert_eq(_untapped_lands(0), 0, "six Swamps bought the six breaths")
	var ants := _mine("Carrion Ants")
	assert_not_null(ants, "the swarm lived, at the size it was declared")
	assert_eq(ants.cur_power if ants != null else -1, 6,
		"a 6/7 in front of an 8/8")


func test_off_the_shield_comes_first_and_the_swarm_never_breathes() -> void:
	# THE NULL, on the same board. With no plan there is no early pass:
	# [method AiPlayer._combat_planned_pumps] returns "" before it reads
	# anything, the shield is bought exactly where it always was, and the
	# ladder — which sees a 0/1 and a 2/2, not a 6/7 — chumps instead of
	# ganging. This is the reading the pilot had before the fix, and it
	# must not have moved.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, {"Swamp": 6},
		["Carrion Ants", "Scathe Zombies", "Drudge Skeletons"],
		["Force of Nature", "Hill Giant"])
	assert_string_contains(ai.act(g), "declared 2 block(s)")
	assert_eq(ai._pump_plan, {}, "no plan is written down at all")
	_play_out_combat(ai, foe)
	assert_eq(theirs[0].zone, Mtg.Zone.BATTLEFIELD, "the trampler walks away")
	assert_eq(g.players[0].life, 5, "seven through")
	assert_eq(_untapped_lands(0), 5, "and one Swamp went on the shield")
	assert_eq(_mine("Drudge Skeletons").regeneration_shields, 0,
		"which the Giant then used up")


func test_the_shield_still_fires_when_the_plan_does_not_want_its_mana() -> void:
	# THE FIX IS AN ORDER AND NOT A REFUSAL. A Frozen Shade breathes on
	# {B} and cannot touch the Mountain, so the plan takes the six Swamps
	# and leaves the Troll its {R}: the gang kills the trampler AND the
	# regenerator comes back. Nothing is taken away from the shield that
	# the breaths were not already priced with.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, {"Swamp": 6, "Mountain": 1},
		["Frozen Shade", "Scathe Zombies", "Uthden Troll"],
		["Force of Nature", "Hill Giant"])
	assert_string_contains(ai.act(g), "block(s)")
	_play_out_combat(ai, foe)
	assert_eq(theirs[0].zone, Mtg.Zone.GRAVEYARD, "the trampler died")
	assert_not_null(_mine("Uthden Troll"), "and the Troll regenerated")
	assert_eq(_untapped_lands(0), 0, "every point of both colours was spent")


func test_the_planned_pass_is_silent_below_sorcerer_and_outside_the_step() -> void:
	# The two gates, asked directly, because they are what keeps the null
	# byte-identical: no knob, no pass; no declare-blockers step, no pass.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_lands(0, "Swamp", 6)
		put_battlefield(0, "Carrion Ants")
		assert_eq(ai._combat_planned_pumps(g), "",
			"nothing to buy outside the declare-blockers step")
	before_each()
	var off := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	_swing(off, {"Swamp": 6}, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"])
	off.act(g)
	assert_eq(off._combat_planned_pumps(g), "",
		"and nothing to buy below Sorcerer, plan or no plan")


# ------------------------------------- two: the mate's number, and why it --
#                                              is still the plan's

func test_the_recovery_still_credits_a_mate_at_the_plans_number() -> void:
	# THE RULING, pinned. An OPPONENT can still tap one of our lands
	# between the declaration and the recovery, and when that happens the
	# mate is credited with breaths it can no longer pay for. It is left
	# that way on purpose: the reading is only ever consulted to decide
	# whether the gang's breaths are worth buying, the mana it spends is
	# idle on their turn, and every point it buys is toughness as well as
	# power — so against the trampler the reading exists for, an
	# over-credited gang still absorbs what it paid for. Re-reading it
	# would make the pilot keep the mana and take the damage instead.
	var ai := _ai(_on())
	var theirs := _swing(ai, {"Swamp": 6}, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"])
	assert_string_contains(ai.act(g), "declared 2 block(s)")
	var ants := _mine("Carrion Ants")
	var zombies := _mine("Scathe Zombies")
	var band: Array[CardInstance] = [ants, zombies]
	assert_eq(ai._owed_bonuses(g, band, zombies), {ants.id: Vector2i(6, 6)},
		"the plan's whole allotment, before anything is taken")
	# Their Icy: one of our Swamps goes down with the block already made.
	for inst in g.players[0].battlefield:
		if inst.is_land() and not inst.tapped:
			inst.tapped = true
			break
	assert_eq(ai._owed_bonuses(g, band, zombies), {ants.id: Vector2i(6, 6)},
		"and still the plan's number, not what five Swamps can reach")
	assert_eq(theirs[0].zone, Mtg.Zone.BATTLEFIELD, "nothing has fought yet")
