extends RefCounted
## Stronghold (_misc, Pack 9). Everything else: global effects and one-off rules.
##
## - Amok's "Discard a card at random" and Tortured Existence's "Discard a
##   creature card" are COSTS (CR 601.2h): paid at activation with the rest
##   of the cost, after the target is chosen — Tortured Existence can't
##   return the card it discards.
## - Intruder Alarm: the untap lock is a static on every creature; the
##   untap-all trigger hears each creature that enters (one trigger each).
## - Primal Rage grants trample in layer 6 (changing_abilities, CR 613.7)
##   to the creatures its controller controls, live.
## - Pursuit of Knowledge: a draw replacement (CR 614.1a) of its
##   controller's draws, each one offered (the "may"); its counters are
##   removed as a COST with the sacrifice.
## - Volrath's Gardens: "Tap an untapped creature you control" is a cost
##   (a summoning-sick creature may pay it, CR 302.6 names only {T}).
## - Volrath's Shapeshifter (Pack 9 E5): CardData.with_graveyard_top_copy —
##   each recalculation the top card of its controller's graveyard, when a
##   creature card, gives it that card's full text plus "{2}: Discard a
##   card." (its own printed ability, kept in either form).
## tests/cards/test_pack_9_B10_misc.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Amok":
			c.activated(ActivatedAbility.new("{1}", false, [CounterMarkerEffect.new("+1/+1")],
				"{1}, Discard a card at random: Put a +1/+1 counter on target creature.").with_random_discard_cost(1))
		"Intruder Alarm":
			c.static_ability(StaticAbility.new(_alarm_lock,
				"Creatures don't untap during their controllers' untap steps."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _alarm,
				"Whenever a creature enters, untap all creatures.", _creature_entered))
		"Primal Rage":
			c.static_ability(StaticAbility.new(_primal_rage,
				"Creatures you control have trample.").changing_abilities())
		"Pursuit of Knowledge":
			c.replaces_draws(_pursuit_draw, _pursuit_applies)
			c.activated(ActivatedAbility.new("", false, [DrawEffect.new(7)],
				"Remove three study counters from this enchantment, Sacrifice this enchantment: Draw seven cards.") \
				.with_counter_cost("study", 3).with_sacrifice_cost())
		"Tortured Existence":
			var raise := ActivatedAbility.new("{B}", false, [ReturnFromGraveyardEffect.new()],
				"{B}, Discard a creature card: Return target creature card from your graveyard to your hand.").with_discard_cost(1)
			raise.discard_filter = _creature_card
			raise.discard_filter_desc = "creature card"
			c.activated(raise)
		"Volrath's Gardens":
			var garden := ActivatedAbility.new("{2}", false, [GainLifeEffect.new(2)],
				"{2}, Tap an untapped creature you control: You gain 2 life. Activate only as a sorcery.") \
				.only_if(MA.sorcery_speed)
			garden.tap_permanent_filter = _creature
			garden.tap_permanent_count = 1
			c.activated(garden)
		"Volrath's Shapeshifter":
			c.with_graveyard_top_copy(ActivatedAbility.new("{2}", false,
				[F.Action.new(_discard_one, "discard a card").with_ai_role(&"discard_self", {"count": 1})],
				"{2}: Discard a card."))
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()


# ------------------------------------------------------------ Intruder Alarm --

static func _alarm_lock(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_skips_untap = true

static func _creature_entered(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i.is_creature()

## "Untap all creatures": the creatures on the battlefield as it resolves.
static func _alarm(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.tapped: g.untap_permanent(i)


# --------------------------------------------------------------- Primal Rage --

static func _primal_rage(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and not i.cur_keywords.has(Mtg.Keyword.TRAMPLE):
			i.cur_keywords.append(Mtg.Keyword.TRAMPLE)


# ------------------------------------------------------ Pursuit of Knowledge --

## The pure half (CR 616.1): every draw of its controller, while it has its
## abilities.
static func _pursuit_applies(_g: MtgGame, s: CardInstance, pid: int, _ctx: Dictionary) -> bool:
	return pid == s.controller_id and not s.cur_abilities_silenced and not s.phased_out

## "You may put a study counter on this enchantment instead." Hint, own
## zones only: study while the hand holds two or more cards and the
## library can feed the seven, until the third counter is there.
static func _pursuit_draw(g: MtgGame, s: CardInstance, pid: int, ctx: Dictionary) -> bool:
	if not _pursuit_applies(g, s, pid, ctx):
		return false
	var p := g.players[pid]
	var hint := int(s.counters.get("study", 0)) < 3 and p.hand.size() >= 2 and p.library.size() >= 10
	if not g.agents[pid].choose_yes_no(g, pid,
			"Pursuit of Knowledge: put a study counter on it instead of drawing?", hint):
		return false
	g.add_counters(s, "study", 1)
	g.log_line("%s puts a study counter on Pursuit of Knowledge instead of drawing" % p.player_name)
	return true


# ------------------------------------------------------- Volrath's Shapeshifter --

## "Discard a card": the activating player chooses (CR 701.8a).
static func _discard_one(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var hand := g.players[pid].hand
	if hand.is_empty(): return
	var picked := g.agents[pid].choose_discard(g, pid, 1)
	if picked.is_empty() or not hand.has(picked[0]):
		picked = [hand[-1]]
	g.discard_cards(pid, [picked[0]])
