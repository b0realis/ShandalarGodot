extends GameTest
## The ENTERS-THE-BATTLEFIELD BAN — the refusal half of the arrival hooks
## (MtgGame.entry_refused, CardData.enters_ban_rule / entry_condition).
##
## The engine could already MODIFY an arrival (Kismet's
## `enters_tapped_rule`, CR 614.1c) but not DENY one, which is what the
## pool's two prohibitions need: "Lands can't enter the battlefield"
## (Worms of the Earth) radiated at everything, and "if you can't, put this
## creature into its owner's graveyard instead of onto the battlefield"
## (Frankenstein's Monster) aimed at the card's own arrival.
##
## The mechanism is pinned here on a SYNTHETIC permanent, so nothing below
## depends on how either card happens to be written; the two cards are
## pinned in tests/cards/test_fidelity_2026_09_02.gd. What matters about a
## refused arrival is that the object never entered — no
## enters-the-battlefield trigger, no leave- or dies-trigger, no body count
## — and that it is left somewhere sane.


## A permanent that refuses every BEAR entry. Deliberately not a card in
## the pool: this is the hook's contract, not a card's behaviour.
static func _bear_warden() -> CardData:
	return CardData.new("Test Bear Warden", "{1}", Mtg.CardType.ENCHANTMENT) \
		.bans_permanents_entering(_bans_bears)


static func _bans_bears(_game: MtgGame, _source: CardInstance,
		entering: CardInstance, _controller: int) -> bool:
	return entering.has_subtype("bear")


func _warden(pid: int) -> CardInstance:
	return put_synthetic(pid, _bear_warden())


# ------------------------------------------------------------- the refusal --

func test_a_banned_permanent_does_not_enter_at_all() -> void:
	_warden(0)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ne(bear.zone, Mtg.Zone.BATTLEFIELD, "it was refused")
	assert_null(g.find_on_battlefield(1, "Grizzly Bears"))


func test_a_ban_is_radiated_to_both_players() -> void:
	_warden(1)
	put_battlefield(0, "Grizzly Bears")
	assert_null(g.find_on_battlefield(0, "Grizzly Bears"),
		"the warden's own controller is not exempt from the other seat's ban")


func test_the_ban_only_stops_what_it_names() -> void:
	_warden(0)
	var giant := put_battlefield(1, "Hill Giant")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "not a Bear, so it enters")


func test_a_silenced_source_bans_nothing() -> void:
	# CR 613 layer 6: an ability that has been removed contributes nothing,
	# and MtgGame.entry_refused skips a silenced or tap-suspended source
	# exactly as _arrives_tapped does.
	var warden := _warden(0)
	warden.cur_abilities_silenced = true
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------- where the object goes --

func test_a_refused_spell_goes_to_its_owners_graveyard() -> void:
	# A permanent SPELL has nowhere to stay — the stack is not a resting
	# place — so it is put into its owner's graveyard as it resolves.
	_warden(1)
	var bear := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(bear))


func test_a_refused_card_stays_in_the_hand_it_was_offered_from() -> void:
	_warden(1)
	var bear := give_hand(0, "Grizzly Bears")
	g.put_from_hand_into_play(bear, 0)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(bear), "still in hand, and only once")
	assert_eq(g.players[0].hand.size(), 1)


func test_a_refused_card_stays_in_the_graveyard_it_was_raised_from() -> void:
	_warden(1)
	var bear := give_hand(0, "Grizzly Bears")
	g.players[0].hand.erase(bear)
	bear.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(bear)
	g.reanimate(bear, 0)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].graveyard.size(), 1)


func test_a_refused_token_ceases_to_exist() -> void:
	# CR 111.7 — a token that cannot enter is never created, and
	# create_token does not report it as made.
	_warden(1)
	var bears := g.create_token(0, CardData.new("Test Bear", "",
		Mtg.CardType.CREATURE).pt(1, 1).with_subtypes(["bear"]))
	assert_eq(bears.size(), 0, "nothing was created")
	assert_eq(g.players[0].battlefield.size(), 0)


# ---------------------------------------------- nothing sees a non-arrival --

## A permanent that refuses every ENCHANTMENT entry, so the test below can
## keep an Oubliette — whose whole behaviour is an arrival trigger — off
## the battlefield.
static func _enchantment_warden() -> CardData:
	return CardData.new("Test Ward of Wards", "{1}", Mtg.CardType.ARTIFACT) \
		.bans_permanents_entering(_bans_enchantments)


static func _bans_enchantments(_game: MtgGame, _source: CardInstance,
		entering: CardInstance, _controller: int) -> bool:
	return entering.is_type(Mtg.CardType.ENCHANTMENT)


func test_a_refused_arrival_fires_no_enters_trigger() -> void:
	# The whole point of refusing on the way IN rather than undoing an
	# arrival afterwards: nothing ever happened. Oubliette's arrival
	# trigger phases out the biggest creature an opponent controls, and a
	# refused Oubliette phases out nothing.
	put_synthetic(0, _enchantment_warden())
	var angel := put_battlefield(1, "Serra Angel")
	var oubliette := put_battlefield(0, "Oubliette")
	resolve_stack()
	assert_ne(oubliette.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(angel.phased_out, "no arrival, so no arrival trigger")
	assert_eq(g.stack.size(), 0, "and nothing was put on the stack")


func test_a_refused_arrival_is_not_a_death() -> void:
	# It never entered, so it cannot have left: no dies-trigger, and the
	# turn's body count (Scavenging Ghoul, Khabal Ghoul) is untouched.
	_warden(0)
	put_battlefield(1, "Grizzly Bears")
	resolve_stack()
	assert_eq(g.creatures_died_this_turn, 0)
	assert_eq(g.players[1].graveyard.size(), 0, "and nothing is in a graveyard")


# ------------------------------------------------------------- the own veto --

func test_a_cards_own_veto_keeps_it_off_the_battlefield() -> void:
	var shy := CardData.new("Test Shy Thing", "", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.enters_only_if(_never)
	assert_eq(g.create_token(0, shy).size(), 0)


static func _never(_game: MtgGame, _inst: CardInstance,
		_controller: int) -> String:
	return "it would rather not"
