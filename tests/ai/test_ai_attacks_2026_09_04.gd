extends GameTest
## WHEN DOES THE AI ATTACK? (audit of 2026-09-04, from the owner's playtest
## note "it does not calculate when to attack — I have no defence".)
##
## The attack policy before this file existed was a per-creature risk
## filter with no reward term and no notion of how many blockers the
## defender actually has: every candidate was asked "could ANY untapped
## enemy creature block you and win?", independently of every other
## attacker. One 3/3 therefore held back an arbitrarily large team of
## 2/2s — it can only eat one of them, but each one asked the question
## alone and each one got the same answer.
##
## These tests state the SITUATION and the number of attackers a competent
## player would declare. They are deliberately about the DECLARATION, not
## about who wins the game: a win-rate delta cannot tell you which board
## the AI misread.


func _wizard() -> AiPlayer:
	return AiPlayer.new(0, AiProfile.wizard())


## How many attackers seat 0's AI declares in the situation now on the
## table. Advances to declare-attackers and lets the AI answer.
func _attack_count(ai: AiPlayer) -> int:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_false(g.awaiting_attackers, "the AI left the attack step open")
	return g.combat.attackers.size()


# ------------------------------------------------- the undefended board --

func test_swings_with_everything_into_an_empty_board() -> void:
	# The owner's headline claim. Three bears, nothing across the table:
	# every one of them is six free damage over two turns.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	assert_eq(_attack_count(ai), 3, "an empty board is attacked with everything")


func test_swings_when_every_enemy_creature_is_tapped() -> void:
	# The COMMON undefended board: they attacked last turn, so their team
	# is still tapped through ours. Nothing can block; everything goes.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	assert_eq(_attack_count(ai), 3, "a tapped Craw Wurm blocks nothing")


func test_a_wall_that_cannot_kill_anything_does_not_stop_the_team() -> void:
	# Wall of Stone is 0/8: it eats one bear's damage and kills nothing.
	# No attacker is at risk, so all three swing.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Wall of Stone")
	assert_eq(_attack_count(ai), 3, "a 0/8 threatens no attacker")


# ------------------------------------- one blocker against a whole team --

func test_one_big_blocker_does_not_blank_a_whole_team() -> void:
	# THE BUG. A single 3/3 against four 2/2s can eat exactly one of them.
	# Attacking with all four costs one bear and lands six damage; the old
	# per-creature filter asked each bear "does the giant beat you?",
	# heard yes four times, and declared nothing at all.
	var ai := _wizard()
	for _i in 4:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_gte(_attack_count(ai), 3,
		"one blocker can only stop one attacker — the surplus is free damage")


func test_blocker_count_is_what_decides_the_swarm() -> void:
	# The same two bears against the same 3/3 is a LOSING attack — one dies
	# for two damage. Nothing about the pair changed between this test and
	# the one above except how many friends they brought, which is the
	# whole point: the count is the deciding variable, not the matchup.
	var ai := _wizard()
	for _i in 2:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 0, "two bears do not out-number one 3/3")


func test_two_blockers_hold_back_a_three_bear_team() -> void:
	# And the arithmetic scales the other way: two 3/3s eat two of three
	# bears, so the whole attack buys two damage for two dead 2/2s. A
	# Wizard declines — the fix is a CALCULATION, not a licence to swing.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 0, "two damage does not buy two bears")


func test_a_swarm_past_two_blockers_goes_when_the_maths_works() -> void:
	# Eight bears into the same two 3/3s: two die, twelve damage lands.
	var ai := _wizard()
	for _i in 8:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Hill Giant")
	assert_gte(_attack_count(ai), 6, "twelve damage is worth two bears")


func test_a_lone_bear_still_stays_home_against_a_hill_giant() -> void:
	# The other half of the same rule, and the reason the fix is not
	# "attack with everything": one bear into one 3/3 is a pure loss with
	# no damage behind it. A Wizard keeps it.
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 0, "no suicide attack when nothing gets through")


func test_a_lone_bear_still_stays_home_against_two_hill_giants() -> void:
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 0, "outnumbered and outclassed: stay home")


func test_fliers_ignore_a_ground_blocker_count() -> void:
	# Blocker capacity is per-attacker LEGAL capacity, not a raw headcount:
	# a Hill Giant cannot block Scryb Sprites at all, so the sprites are
	# never part of the surplus arithmetic and simply attack.
	var ai := _wizard()
	for _i in 2:
		put_battlefield(0, "Scryb Sprites")   # 1/1 flying
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 2, "a ground 3/3 cannot block a flier")


# ---------------------------------------------------------- lethal push --

func test_pushes_lethal_through_a_blocker() -> void:
	# Two bears into one Hill Giant with the defender at 2: one bear dies,
	# the other one wins the game. Both go.
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	g.players[1].life = 2
	assert_eq(_attack_count(ai), 2, "lethal through the blocks: send everything")


func test_a_dying_attacker_still_goes_when_its_damage_wins() -> void:
	# One bear, no blockers, defender at 1: the bear connects and wins even
	# though a trick could kill it. Nothing may be left home.
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	g.players[1].life = 1
	assert_eq(_attack_count(ai), 1)


func test_low_life_makes_a_trade_worth_making() -> void:
	# Defender at 4 behind one Hill Giant, three bears on our side. The
	# giant eats one; four damage puts them on lethal-next-turn. A pure
	# board-value read says "you lose a 2/2 for two life" and holds; a
	# player counting the CLOCK swings.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	g.players[1].life = 4
	assert_gte(_attack_count(ai), 2, "the last points of life are the game")


# ---------------------------------------------------- requirements/legality --

func test_a_summoning_sick_creature_is_never_declared() -> void:
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears", true)   # sick
	assert_eq(_attack_count(ai), 1, "the sick bear cannot attack")


func test_a_must_attacker_goes_into_a_hopeless_board() -> void:
	# Juggernaut "attacks each combat if able" — a requirement, not an
	# opinion, whatever the analysis thinks of the Craw Wurm opposite it.
	var ai := _wizard()
	var jugg := put_battlefield(0, "Juggernaut")
	put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Craw Wurm")
	assert_gte(_attack_count(ai), 1)
	assert_true(g.combat.attackers.has(jugg.id), "the requirement was honoured")


# -------------------------------------------------------- our own tricks --

func test_counts_a_giant_growth_in_hand() -> void:
	# The AI knows what it holds: with {G} open and a Giant Growth in hand
	# the bear is a 5/5 in combat, which beats the 3/3 and survives.
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	give_hand(0, "Giant Growth")
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 1, "the trick in hand makes the attack sound")


func test_does_not_count_a_trick_it_cannot_pay_for() -> void:
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Giant Growth")   # no land: unpayable
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 0, "an unpayable trick is not a plan")


func test_their_open_mana_does_not_freeze_the_attack() -> void:
	# The AI must not invent a blocker out of the defender's untapped
	# lands: five Islands and a full hand still block nothing.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	for _i in 5:
		put_battlefield(1, "Island")
	for _i in 4:
		give_hand(1, "Lightning Bolt")
	assert_eq(_attack_count(ai), 3, "lands and a hand are not blockers")


# ----------------------------------------------------- the profile ladder --

func test_the_apprentice_is_no_less_willing_than_the_wizard() -> void:
	# Difficulty is mistake rate and risk appetite, not a different rule
	# book: with mistakes switched off the reckless profile must never
	# declare FEWER attackers than the careful one on the same board.
	var reckless := AiPlayer.new(0, AiProfile.new("reckless", 0.0, 0.75, 3, false))
	for _i in 4:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var loose := _attack_count(reckless)

	before_each()
	var careful := AiPlayer.new(0, AiProfile.new("careful", 0.0, 0.5, 6, true))
	for _i in 4:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var tight := _attack_count(careful)

	assert_gte(loose, tight, "aggression may only loosen the filter")


func test_a_fumbling_profile_leaves_a_body_home() -> void:
	# Mistake injection still bites: at mistake_chance 1.0 exactly one
	# optional attacker is dropped from the declaration.
	var fumbler := AiPlayer.new(0, AiProfile.new("AllThumbs", 1.0, 0.5))
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	assert_eq(_attack_count(fumbler), 2, "one good attacker stayed home")


# ------------------------------------------------ boards from the playtest --

func test_a_mixed_team_all_goes_past_one_blocker() -> void:
	# A Craw Wurm and three bears against one Hill Giant. The wurm alone
	# was the whole old declaration: the giant can only block one thing,
	# so the bears behind it are six more damage for at most one bear.
	var ai := _wizard()
	put_battlefield(0, "Craw Wurm")
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_eq(_attack_count(ai), 4, "the whole team goes past one blocker")


func test_five_bears_go_past_a_serra_angel() -> void:
	# The playtest board: a lone 4/4 flier holding the fort against a
	# ground team. It eats one bear; eight damage lands.
	var ai := _wizard()
	for _i in 5:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	assert_gte(_attack_count(ai), 4, "one angel is not a defence against five")


func test_pressure_rises_as_the_defender_falls() -> void:
	# Three bears against one Hill Giant: a losing attack at 20 life (one
	# bear for four damage), a winning one at 8, because the last points
	# of a life total are worth more than the first. Same board, same
	# creatures — only the number on the defender changed.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	g.players[1].life = 8
	assert_eq(_attack_count(ai), 3, "at 8 life the clock is worth a bear")
