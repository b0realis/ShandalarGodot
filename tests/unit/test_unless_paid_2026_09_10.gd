extends GameTest
## "[DO SOMETHING] UNLESS [A PLAYER PAYS]" — CR 118.12, one mechanism —
## 2026-09-10.
##
## *"Some spells, activated abilities, and triggered abilities read, '[Do
## something] unless [a player does something else].' This means the player
## has the option to take the specified action... If they don't, the first
## action is taken."*
##
## Forty-two cards in the pool print one (45 sites) and every one of them
## wrote the same three-clause chain by hand — afford, ask, pay.
## EffectBase.unless_paid is that chain, once, and the three clauses below
## are the ones a card that wrote its own kept getting subtly different.
##
## The nine sites moved onto it are Force of Nature, Phantasmal Forces,
## Sunken City, Hasran Ogress, Demonic Hordes, Stasis, Cyclone, Conversion
## and Power Sink — the "unless you pay {mana}" family docs/forge/rules.md
## §4.5 names. Their own card tests are the behaviour proof; these pin the
## helper's contract.


## Records the questions a seat is asked and answers them from a script.
class Payer extends DecisionAgent:
	var say := true
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return say


func test_a_payer_who_pays_gets_true_and_is_charged() -> void:
	var agent := Payer.new()
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_true(EffectBase.unless_paid(g, 0, ManaCost.parse("{G}{G}"), "Pay?"))
	assert_eq(agent.asked, ["Pay?"])
	assert_eq(g.players[0].mana_pool.total(), 0, "the cost really came out")


func test_a_payer_who_refuses_gets_false_and_keeps_the_mana() -> void:
	var agent := Payer.new()
	agent.say = false
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_false(EffectBase.unless_paid(g, 0, ManaCost.parse("{G}{G}"), "Pay?"))
	assert_eq(agent.asked, ["Pay?"])
	assert_eq(g.players[0].mana_pool.total(), 2, "nothing was spent")


## A seat that CANNOT pay is never asked — a question with no answer files a
## PlayerChoice and puts a dialog in front of a human seat for nothing.
func test_a_payer_who_cannot_afford_it_is_not_asked() -> void:
	var agent := Payer.new()
	g.set_agent(0, agent)
	assert_false(EffectBase.unless_paid(g, 0, ManaCost.parse("{G}{G}"), "Pay?"))
	assert_eq(agent.asked, [], "no mana, no question")


## The hint is the default answer and nothing more: a seat that answers for
## itself may say the opposite.
func test_the_hint_is_only_a_default() -> void:
	var agent := Payer.new()
	agent.say = false
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.G)
	assert_false(EffectBase.unless_paid(g, 0, ManaCost.parse("{G}"), "Pay?", true),
		"the seat refused a cost the hint recommended")


## The default agent takes the hint, both ways.
func test_the_default_agent_takes_the_hint() -> void:
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_true(EffectBase.unless_paid(g, 0, ManaCost.parse("{G}"), "Pay?", true))
	assert_false(EffectBase.unless_paid(g, 0, ManaCost.parse("{G}"), "Pay?", false))
	assert_eq(g.players[0].mana_pool.total(), 1, "only the accepted one was paid")


## THE POOL, through the helper: Force of Nature's upkeep, paid and unpaid.
func test_force_of_nature_pays_or_bleeds() -> void:
	var agent := Payer.new()
	g.set_agent(0, agent)
	put_battlefield(0, "Force of Nature")
	for _i in 4:
		put_battlefield(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 20, "four Forests appeased it")
	assert_eq(agent.asked.size(), 1)
	agent.say = false
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 12, "and refusing costs eight")


## And Power Sink, the one site of the nine that is an EffectBase rather
## than an upkeep trigger: refusing the toll counters the spell and strips
## the board.
func test_power_sink_refused_counters_and_strips() -> void:
	var agent := Payer.new()
	agent.say = false
	g.set_agent(1, agent)
	var island := put_battlefield(1, "Island")
	var bear := give_hand(1, "Grizzly Bears")
	var sink := give_hand(0, "Power Sink")
	advance_to_next_turn()      # P1's own main phase, for a sorcery-speed cast
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, bear, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, sink, [TargetRef.card(bear)], 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_true(island.tapped, "and every land with a mana ability is tapped")
