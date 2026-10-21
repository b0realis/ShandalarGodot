extends GameTest
## DIVIDED DAMAGE READ AS NONE (bug hunt 2026-10-21, ai).
##
## "Pyrotechnics deals 4 damage divided as you choose among any number of
## targets" is a [DamageEffect] whose 4 lives in the division
## ([member EffectBase.divided_total]), its `amount` 0 — and
## [method EffectIntent.read] read only `amount`. Pyrotechnics, Rolling
## Thunder's family and every "divided" burn were no damage to the pilot:
## with all four aimed at its Serra Angel and Giant Growth in hand, the
## Wizard passed and the Angel died.
##
## The intent reads the whole total now, flagged divided, and the readers
## that know the target take its announced share ([member TargetRef.amount],
## CR 601.2d — public as the spell is cast): a single point on the Angel
## is not answered with a Giant Growth (the control), and a share at our
## face is read as that share.


func after_each() -> void:
	g = null


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1


## Our Serra Angel, a Forest and Giant Growth; their Pyrotechnics on the
## stack at [param targets]; what [method AiPlayer._damage_at_us] reads off
## it; then seat 0 acts once.
func _pyrotechnics(targets: Callable) -> Array:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var angel := put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Forest")
	var growth := give_hand(0, "Giant Growth")
	_their_main()
	var pyro := give_hand(1, "Pyrotechnics")
	add_mana(1, Mtg.ManaColor.R, 1)
	add_mana(1, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(1, pyro, targets.call(angel)))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var top: StackItem = g.stack.back()
	var at_us := ai._damage_at_us(g, top, EffectIntent.read(top.effects, "Pyrotechnics"))
	var did := ai.act(g)
	return [angel, growth, did, at_us]


func test_all_four_at_the_angel_is_answered() -> void:
	var out := _pyrotechnics(func(angel: CardInstance) -> Array: return [TargetRef.card(angel)])
	assert_string_contains(String(out[2]), "Giant Growth")
	resolve_stack()
	assert_eq((out[0] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, "the Angel lives")


## THE CONTROL: one point on the Angel, three at our face — no card spent.
func test_one_point_on_the_angel_is_not_answered() -> void:
	var out := _pyrotechnics(func(angel: CardInstance) -> Array:
		return [TargetRef.card(angel).with_amount(1), TargetRef.player(0).with_amount(3)])
	assert_eq((out[1] as CardInstance).zone, Mtg.Zone.HAND, "a 4/4 lives through one")
	assert_eq(int(out[3]), 3, "our share is three")


func test_the_intent_reads_the_division() -> void:
	var intent := EffectIntent.read(CardRegistry.get_card("Pyrotechnics").spell_effects, "Pyrotechnics")
	assert_eq(intent.damage, 4)
	assert_true(intent.damage_divided)
	assert_true(intent.answers_creatures())
	assert_true(intent.divided_shares)
	assert_eq(intent.damage_on(TargetRef.player(1).with_amount(2), 0), 2, "a share is a share")
	var fireball := EffectIntent.read(CardRegistry.get_card("Fireball").spell_effects, "Fireball")
	assert_false(fireball.divided_shares, "Fireball splits evenly: no share on its targets")
	assert_eq(fireball.damage_on(TargetRef.player(1), 5), fireball.damage_at(5))
