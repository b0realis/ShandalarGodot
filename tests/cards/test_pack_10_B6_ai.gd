extends GameTest
## Pack 10 (the Urza block), batch B6: what the fair AI reads off the
## batch's enchantments. Torch Song's sacrifice line is the counter-blast
## shape Pack 8's reader already prices (engine/ai/mirage_tactics.gd
## `counter_damage`), gated on `AiProfile.forecasts_tactics` with a null
## arm. The card-authored hints — Abundance's land/nonland answer, the
## creature type Engineered Plague offers first, the creature Sneak Attack
## puts in — read the seat's own hand and the public board only: they do
## not move when the opponent's hidden hand or either library changes
## (docs/fair-play.md).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G
const E := preload("res://cards/sets/usg/_enchantments.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai

func _song(n: int) -> CardInstance:
	var song := put_battlefield(0, "Torch Song")
	g.add_counters(song, "verse", n)
	for k in 3: put_battlefield(0, "Mountain")
	return song


# ---------------------------------------------------------------- Torch Song --

func test_the_ai_cashes_a_lethal_torch_song() -> void:
	var ai := _ai()
	var song := _song(3)
	g.players[1].life = 3
	assert_eq(ai.act(g), "activated Torch Song")
	resolve_stack()
	assert_eq(song.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[1].life <= 0)

func test_the_ai_keeps_a_torch_song_that_kills_nothing() -> void:
	var ai := _ai()
	_song(1)
	put_battlefield(1, "Craw Wurm")
	assert_ne(ai.act(g), "activated Torch Song", "one counter kills nothing on this board")


# ------------------------------------------------------------ card-authored hints --

## The same seat's answer with the opponent's hand and both library orders
## changed: [param probe] returns what the hint chose.
func _stable(probe: Callable) -> void:
	var answers: Array = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		for k in 3: give_hand(1, filler)
		g.players[0].library.reverse()
		g.players[1].library.reverse()
		answers.append(probe.call())
	assert_eq(answers[0], answers[1], "the hidden zones do not move the hint")

func test_abundance_hint_reads_only_the_seats_own_hand_and_board() -> void:
	_stable(func() -> int:
		give_hand(0, "Craw Wurm")
		put_battlefield(0, "Forest")
		return E._abundance_hint(g, 0))
	before_each()
	give_hand(0, "Forest")
	assert_eq(E._abundance_hint(g, 0), 2, "a land in hand: reveal a spell")
	before_each()
	assert_eq(E._abundance_hint(g, 0), 1, "no land anywhere: reveal a land")

func test_engineered_plague_hint_reads_the_public_board() -> void:
	_stable(func() -> String:
		put_battlefield(1, "Llanowar Elves")
		var plague := give_hand(0, "Engineered Plague")
		add_mana(0, B, 3)
		assert_ok(g.cast_spell(0, plague))
		resolve_stack()
		return String(plague.memory.get("plague_type", "")))

func test_sneak_attack_hint_reads_the_seats_own_hand() -> void:
	_stable(func() -> String:
		var sneak := put_battlefield(0, "Sneak Attack")
		give_hand(0, "Grizzly Bears")
		give_hand(0, "Craw Wurm")
		add_mana(0, R)
		assert_ok(g.activate_ability(0, sneak, 0, []))
		resolve_stack()
		for i in g.players[0].battlefield:
			if i.is_creature(): return i.data.card_name
		return "")
