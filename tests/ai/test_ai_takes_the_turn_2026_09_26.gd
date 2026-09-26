extends GameTest
## THE EXTRA TURN OFF THE TABLE (2026-09-26, [member
## AiProfile.takes_the_turn]). Time Vault's {T} fell into the scorer's
## last `else`, so an untapped Vault was never tapped; its "Skip this
## turn to untap?" was answered by the 1997 one-in-five roll. On, the
## ability is priced the way Time Walk is ([method
## AiPlayer._extra_turn_value]) at the sink's bar, and the question is
## answered off the board ([method AiPlayer._turn_is_dead]).


const VAULT_PROMPT := "Skip this turn to untap Time Vault?"
const VAULT_OPTIONS: Array[String] = ["Play this turn.", "Skip this turn to untap."]


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _vault() -> CardInstance:
	var vault := put_battlefield(0, "Time Vault")
	vault.tapped = false
	return vault


func test_the_reader_reads_the_vaults_turn() -> void:
	var vault := _vault()
	var read := EffectIntent.read(vault.cur_activated_abilities[0].effects, "Time Vault")
	assert_eq(read.extra_turns, 1)


func test_an_untapped_vault_is_tapped_for_its_turn() -> void:
	var ai := _wizard(0)
	var vault := _vault()
	for i in 4:
		put_battlefield(0, "Island")
	give_hand(0, "Island")
	var option := ai._ability_option(g, vault, 0, AiPlayer.Moment.SINK)
	assert_false(option.is_empty())
	assert_eq(float(option["value"]), ai._extra_turn_value(g, 1), "priced as the spell is")
	assert_gt(float(option["value"]), 0.0)
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK), "activated Time Vault")
	assert_true(vault.tapped)


func test_off_the_vault_is_never_tapped() -> void:
	var ai := _wizard(0)
	ai.profile.takes_the_turn = false
	var vault := _vault()
	for i in 4:
		put_battlefield(0, "Island")
	give_hand(0, "Island")
	assert_true(ai._ability_option(g, vault, 0, AiPlayer.Moment.SINK).is_empty())
	assert_eq(ai._try_activate(g, AiPlayer.Moment.SINK), "")
	assert_false(vault.tapped)


func test_a_live_turn_is_played() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Time Vault")
	put_battlefield(1, "Serra Angel")
	g.players[0].life = 2
	assert_true(ai._in_danger(g))
	assert_false(ai._turn_is_dead(g))
	assert_eq(ai.answer_option(g, 0, VAULT_PROMPT, VAULT_OPTIONS, 1), 0,
		"in danger, the turn is played whatever the roll said")
	g.players[0].life = 20
	give_hand(0, "Grizzly Bears")
	assert_false(ai._turn_is_dead(g), "a spell in hand is a turn worth taking")
	assert_eq(ai.answer_option(g, 0, VAULT_PROMPT, VAULT_OPTIONS, 1), 0)


func test_a_dead_turn_is_banked() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Time Vault")
	for i in 4:
		put_battlefield(0, "Island")
	give_hand(0, "Island")
	assert_true(ai._turn_is_dead(g), "a land in hand, no creature, no danger")
	assert_eq(ai.answer_option(g, 0, VAULT_PROMPT, VAULT_OPTIONS, 0), 1,
		"skipped for the Vault's untap whatever the roll said")
	put_battlefield(0, "Grizzly Bears")
	assert_false(ai._turn_is_dead(g), "a creature to attack with")
	assert_eq(ai.answer_option(g, 0, VAULT_PROMPT, VAULT_OPTIONS, 0), 0)


func test_off_the_question_keeps_the_roll() -> void:
	var ai := _wizard(0)
	ai.profile.takes_the_turn = false
	put_battlefield(0, "Time Vault")
	assert_eq(ai.answer_option(g, 0, VAULT_PROMPT, VAULT_OPTIONS, 1), 1)
	assert_eq(ai.answer_option(g, 0, VAULT_PROMPT, VAULT_OPTIONS, 0), 0)
