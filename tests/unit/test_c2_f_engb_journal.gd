extends GameTest
## Campaign 2026-10-12 (b3-1) — an AI search that knocks an Aura off its
## creature must put BOTH halves of the attachment back.
##
## MtgGame.check_state_based_actions sheds an Aura from a host it can no
## longer enchant (CR 704.5m) and from a host with protection from it
## (CR 702.16d). Both branches erased the Aura from `host.attachments`
## before anything had journaled that list, so _detach_departing_aura then
## recorded the already-shortened list: unmaking the search left the Aura
## saying it was attached while its creature no longer listed it. Seen in
## random AI duels (the licid preview, Purelace / Touch of Darkness): the
## creature later phased out without its Aura, which went to the graveyard.

const PACKS := ["pack-8", "pack-9"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _enchant(aura_name: String, host: CardInstance, color: int, amount := 1) -> CardInstance:
	var aura := give_hand(0, aura_name)
	add_mana(0, color, amount)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_true(host.attachments.has(aura.id), "precondition: %s is on %s" % [aura_name, host.data.card_name])
	return aura


func _assert_attached(aura: CardInstance, host: CardInstance) -> void:
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "%s is back on the battlefield" % aura.data.card_name)
	assert_eq(aura.attached_to, host.id, "%s says it is attached to %s" % [aura.data.card_name, host.data.card_name])
	assert_true(host.attachments.has(aura.id),
		"%s lists %s again (the host lost the Aura from its attachments)" % [host.data.card_name, aura.data.card_name])


# The AI's own call — a Wizard's licid preview, made on every decision.
func test_the_licid_preview_keeps_the_hosts_attachments() -> void:
	var licid := put_battlefield(0, "Transmogrifying Licid")
	var bears := put_battlefield(0, "Grizzly Bears")
	var fear := _enchant("Fear", licid, Mtg.ManaColor.B, 2)
	var pilot := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, pilot)
	load("res://engine/ai/tempest_tactics.gd").attack_worth_dressed(g, pilot, licid, bears, 1)
	_assert_attached(fear, licid)


# The visible consequence: after the preview the licid phases out and its
# Fear rides along (CR 702.26g) instead of being put into the graveyard.
func test_after_the_preview_the_aura_still_phases_out_with_its_host() -> void:
	var licid := put_battlefield(0, "Transmogrifying Licid")
	var bears := put_battlefield(0, "Grizzly Bears")
	var fear := _enchant("Fear", licid, Mtg.ManaColor.B, 2)
	var m := g.make_mark()
	g.become_licid_aura(licid, bears)
	g.unmake_to(m)
	g.end_search()
	_assert_attached(fear, licid)
	assert_true(g.phase_out(licid))
	assert_true(fear.phased_out, "Fear phases out indirectly with its host")
	assert_eq(fear.zone, Mtg.Zone.BATTLEFIELD, "and is not put into the graveyard")


# The illegal-host branch: Mind Harness (enchant red or green creature)
# falls off a Grizzly Bears painted black inside a search.
func test_a_colour_change_inside_a_search_is_unmade_whole() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var harness := _enchant("Mind Harness", bears, Mtg.ManaColor.U)
	var m := g.make_mark()
	g.set_color(bears, Mtg.ManaColor.B)
	assert_eq(harness.zone, Mtg.Zone.GRAVEYARD, "inside the search it fell off")
	g.unmake_to(m)
	g.end_search()
	_assert_attached(harness, bears)


# The protection branch: the Bears gain protection from black inside a
# search (a grant that journals nothing about attachments), shedding Fear.
func test_a_protection_shed_inside_a_search_is_unmade_whole() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var fear := _enchant("Fear", bears, Mtg.ManaColor.B, 2)
	var m := g.make_mark()
	g.grant_protection_permanently(bears, Mtg.ManaColor.B)
	g.check_state_based_actions()
	assert_eq(fear.zone, Mtg.Zone.GRAVEYARD, "inside the search protection shed Fear")
	g.unmake_to(m)
	g.end_search()
	_assert_attached(fear, bears)
	assert_eq(bears.added_protection, 0, "and the grant is unmade")


# Black Ward's own protection never sheds the Ward, and sheds Fear for real.
func test_black_ward_sheds_fear_but_not_itself() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var fear := _enchant("Fear", bears, Mtg.ManaColor.B, 2)
	var ward := give_hand(0, "Black Ward")
	g.attach_aura_from_anywhere(ward, bears, 0)
	g.check_state_based_actions()
	assert_eq(fear.zone, Mtg.Zone.GRAVEYARD)
	assert_false(bears.attachments.has(fear.id))
	assert_true(bears.attachments.has(ward.id))


# Outside a search nothing changes: the shed Aura is gone from both sides.
func test_outside_a_search_the_shed_aura_is_detached_from_both_sides() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var harness := _enchant("Mind Harness", bears, Mtg.ManaColor.U)
	g.set_color(bears, Mtg.ManaColor.B)
	assert_eq(harness.zone, Mtg.Zone.GRAVEYARD)
	assert_false(bears.attachments.has(harness.id))
	assert_eq(harness.attached_to, -1)
