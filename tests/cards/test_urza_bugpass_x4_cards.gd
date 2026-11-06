extends GameTest
## The 0.60.19 bug pass over the Pack 10 card modules: last known
## information and live reads on resolution (CR 608.2h) — Remembrance,
## Opal Titan, Disappear — and "Sacrifice a creature" costs that may eat
## their own source once something makes it a creature (Attrition, Fodder
## Cannon, Phyrexian Tower).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const G := Mtg.ManaColor.G
const C := Mtg.ManaColor.C


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _to_library(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	_priority_to(pid)
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id, aura_name + " is attached")
	return aura


# ---------------------------------------------------------------- Remembrance --

## "A card with the same name as that creature" — the name it died with
## (CR 608.2h): a Clone that copied Grizzly Bears died as "Grizzly Bears",
## though it is a card named Clone again in the graveyard (CR 707.2).
func test_remembrance_searches_for_the_name_the_clone_died_with() -> void:
	put_battlefield(0, "Remembrance")
	put_battlefield(1, "Grizzly Bears")
	var clone := put_battlefield(0, "Clone")
	assert_eq(clone.data.card_name, "Grizzly Bears", "the Clone copies the Bears")
	var wanted := _to_library(0, "Grizzly Bears")
	var other_clone := _to_library(0, "Clone")
	g.destroy(clone)
	assert_eq(clone.data.card_name, "Clone", "back to its printed self in the graveyard")
	resolve_stack()
	assert_eq(wanted.zone, Mtg.Zone.HAND, "searched for a card named Grizzly Bears")
	assert_eq(other_clone.zone, Mtg.Zone.LIBRARY, "not for a card named Clone")


# ----------------------------------------------------------------- Opal Titan --

## "Protection from each of that spell's colors" — the spell's colors as
## the ability resolves while it is still on the stack (CR 608.2h): a
## Purelace in response makes the Bears spell white.
func test_opal_titan_reads_the_spells_colors_as_it_resolves() -> void:
	var titan := put_battlefield(1, "Opal Titan")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	# The Titan's trigger waits above the Bears; P0 answers with Purelace.
	var lace := give_hand(0, "Purelace")
	add_mana(0, W)
	_priority_to(0)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.cur_colors, W, "Purelace made the Bears spell white first")
	assert_true(titan.is_creature(), "the Titan became a creature")
	assert_eq(titan.cur_protection, W, "protection from white only — not from green")


## A spell gone from the stack before the trigger resolves is still
## described: its colors as it was cast.
func test_opal_titan_reads_a_countered_spell_as_it_was_cast() -> void:
	var titan := put_battlefield(1, "Opal Titan")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	g.counter_spell(bears)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(titan.is_creature())
	assert_eq(titan.cur_protection, G, "protection from green, the color it was cast with")


# ------------------------------------------------------------------ Disappear --

## "Return enchanted creature" — the creature the Aura enchants as the
## ability resolves (CR 608.2h): an Enchantment Alteration in response
## moves it onto the Hill Giant, and the Giant goes back, not the Bears.
func test_disappear_returns_the_creature_it_enchants_as_it_resolves() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var aura := _enchant(0, "Disappear", bears, [U, U, C, C])
	add_mana(0, U)
	assert_ok(g.activate_ability(0, aura, 0, []))
	assert_ok(g.pass_priority(0))
	var alteration := give_hand(1, "Enchantment Alteration")
	add_mana(1, U)
	assert_ok(g.cast_spell(1, alteration, [TargetRef.card(aura)]))
	resolve_stack()
	assert_true(g.players[0].hand.has(giant), "the creature it enchanted on resolution")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the old host stays")
	assert_true(g.players[0].hand.has(aura), "and the Aura itself")


## Moved, then gone before the ability resolves: "enchanted creature" is
## the one it enchanted as it last existed on the battlefield.
func test_disappear_gone_after_a_move_returns_its_last_host() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var aura := _enchant(0, "Disappear", bears, [U, U, C, C])
	add_mana(0, U)
	assert_ok(g.activate_ability(0, aura, 0, []))
	g.move_aura(aura, giant)
	g.destroy(aura)
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_true(g.players[0].hand.has(giant), "the host it last had")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "not the host it had when activated")
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "the Aura is a new object there: it stays")


# ------------------------------------------------------------------- Attrition --

## Under Opalescence Attrition is a creature: "Sacrifice a creature" may be
## paid with Attrition itself, and the ability still resolves (CR 113.7a).
func test_attrition_under_opalescence_may_sacrifice_itself() -> void:
	put_battlefield(0, "Opalescence")
	var attrition := put_battlefield(0, "Attrition")
	assert_true(attrition.is_creature(), "an enchantment creature under Opalescence")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, B)
	assert_ok(g.activate_ability(0, attrition, 0, [TargetRef.card(giant)]))
	assert_eq(attrition.zone, Mtg.Zone.GRAVEYARD, "sacrificed itself as the cost")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the target is destroyed")


# --------------------------------------------------------------- Fodder Cannon --

## An animated Fodder Cannon is "a creature": tapped and sacrificed for
## its own cost, its 4 damage is still dealt.
func test_animated_fodder_cannon_may_sacrifice_itself() -> void:
	var cannon := put_battlefield(0, "Fodder Cannon")
	var animate := give_hand(0, "Animate Artifact")
	add_mana(0, U)
	add_mana(0, C, 3)
	assert_ok(g.cast_spell(0, animate, [TargetRef.card(cannon)]))
	resolve_stack()
	assert_true(cannon.is_creature(), "Animate Artifact makes it a creature")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, C, 4)
	assert_ok(g.activate_ability(0, cannon, 0, [TargetRef.card(giant)]))
	assert_eq(cannon.zone, Mtg.Zone.GRAVEYARD, "sacrificed itself as the cost")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "4 damage to the Hill Giant")


# ------------------------------------------------------------ Phyrexian Tower --

## Under Living Plane the Tower is a creature: "{T}, Sacrifice a creature:
## Add {B}{B}" may be paid with the Tower itself.
func test_animated_phyrexian_tower_may_sacrifice_itself() -> void:
	put_battlefield(0, "Living Plane")
	var tower := put_battlefield(0, "Phyrexian Tower")
	assert_true(tower.is_creature(), "a 1/1 land creature under Living Plane")
	assert_ok(g.tap_for_mana(0, tower, 1))
	assert_eq(tower.zone, Mtg.Zone.GRAVEYARD, "sacrificed itself as the cost")
	assert_eq(g.players[0].mana_pool.amount_of(B), 2)
