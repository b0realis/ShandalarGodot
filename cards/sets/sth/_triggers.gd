extends RefCounted
## Stronghold (_triggers, Pack 9). Triggered abilities: enters, dies, upkeep, end step and other event triggers.
##
## Same conventions as the Mirage block and Tempest modules
## (cards/sets/mir/_triggers.gd — whose shared helpers this reuses as M —
## and cards/sets/tmp/_triggers.gd):
## - A triggered ability exists apart from its source (CR 603.6 / 608.2h):
##   it resolves even when the source has left, acting for the seat that
##   controlled it (M.pid_of) and dealing damage from the source as it last
##   existed. Only the clauses that name the source itself ("sacrifice this
##   enchantment", "put a counter on Crovax") check that the very same
##   object is still there (F._same_trigger_source / _trigger_source_present).
## - Per-occurrence facts (how much damage, the creature that was hit or
##   that blocked and its controller, the card that died and its graveyard
##   entry, the spell that was cast) are captured as the ability triggers,
##   never read back later off an object that may have changed.
## - "Whenever this creature deals damage" hears DAMAGE_DEALT once per
##   damage packet (the pool's convention for that wording); "is dealt
##   damage" hears WAS_DEALT_DAMAGE, one event per victim per damage event,
##   with `is_combat` for "combat damage".
## - Deterministic public damage/life aftermath with no choice (Lowland
##   Basilisk, Mogg Maniac, the two Walls, Warrior Angel) is marked
##   `public_aftermath` so the AI's combat forecast may resolve it.
## tests/cards/test_pack_9_B9_triggers.gd pins every card here.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Awakening":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _awakening,
				"At the beginning of each upkeep, untap all creatures and lands."))
		"Bottomless Pit":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _bottomless_pit,
				"At the beginning of each player's upkeep, that player discards a card at random."))
		"Burgeoning":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LAND_PLAYED, _burgeoning,
				"Whenever an opponent plays a land, you may put a land card from your hand onto the battlefield.",
				_opponent_played_land))
		"Contemplation":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, M._gain_life.bind(1),
				"Whenever you cast a spell, you gain 1 life.", _you_cast))
		"Crovax the Cursed":
			c.with_enters_counters("+1/+1", 4)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _crovax,
				"At the beginning of your upkeep, you may sacrifice a creature. If you do, put a +1/+1 counter on Crovax. If you don't, remove a +1/+1 counter from Crovax.",
				F._your_upkeep))
			# Role `self_keyword` (Manta Riders'): an attacker that lacks the
			# keyword buys it before blocks.
			c.activated(ActivatedAbility.new("{B}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff().with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.FLYING})],
				"{B}: Crovax gains flying until end of turn."))
		"Foul Imp":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, M.lose_life.bind(2),
				"When this creature enters, you lose 2 life.", F._self_enter))
		"Grave Pact":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _grave_pact,
				"Whenever a creature you control dies, each other player sacrifices a creature of their choice.",
				_your_creature_died))
		"Heat of Battle":
			# "Whenever a creature blocks" triggers once per blocking creature,
			# however many attackers it blocks (CR 509.3c): BECOMES_BLOCKER.
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _heat_of_battle,
				"Whenever a creature blocks, this enchantment deals 1 damage to that creature's controller.",
				_a_creature_blocks).capturing(_blocker_context))
		"Hesitation":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _hesitation,
				"When a player casts a spell, sacrifice this enchantment and counter that spell.",
				_a_spell_was_cast).capturing(_spell_context))
		"Lowland Basilisk":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _basilisk,
				"Whenever this creature deals damage to a creature, destroy that creature at end of combat.",
				_damages_a_creature).capturing(_victim_context).public_aftermath())
		"Megrim":
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DISCARDED, _megrim,
				"Whenever an opponent discards a card, this enchantment deals 2 damage to that player.",
				_opponent_discarded))
		"Mogg Bombers":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _bombers,
				"When another creature enters, sacrifice this creature and it deals 3 damage to target player or planeswalker.",
				_another_creature_enters).targeting(TargetSpec.player(), F._enemy_first,
					"Mogg Bombers: select target player."))
		"Mogg Maniac":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _that_much_to_target,
				"Whenever this creature is dealt damage, it deals that much damage to target opponent or planeswalker.",
				_dealt_damage_me).capturing(_amount_context).targeting(TargetSpec.opponent()).public_aftermath())
		"Mortuary":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _mortuary,
				"Whenever a creature is put into your graveyard from the battlefield, put that card on top of your library.",
				_creature_to_your_graveyard).capturing(M._dead_context))
		"Sacred Ground":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _sacred_ground,
				"Whenever a spell or ability an opponent controls causes a land to be put into your graveyard from the battlefield, return that card to the battlefield.",
				_opponent_buried_your_land).capturing(M._dead_context))
		"Spindrift Drake":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{U}"),
				"At the beginning of your upkeep, sacrifice this creature unless you pay {U}.", F._your_upkeep))
		"Wall of Blossoms":
			# The scaffold prints defender.
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _draw_one,
				"When this creature enters, draw a card.", F._self_enter))
		"Wall of Essence":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _gain_that_much,
				"Whenever this creature is dealt combat damage, you gain that much life.",
				_dealt_combat_damage_me).capturing(_amount_context).public_aftermath())
		"Wall of Souls":
			c.triggered(TriggeredAbility.new(Mtg.EventType.WAS_DEALT_DAMAGE, _that_much_to_target,
				"Whenever this creature is dealt combat damage, it deals that much damage to target opponent or planeswalker.",
				_dealt_combat_damage_me).capturing(_amount_context).targeting(TargetSpec.opponent()).public_aftermath())
		"Warrior Angel":
			# The scaffold prints flying.
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _gain_that_much,
				"Whenever this creature deals damage, you gain that much life.",
				M.deals_damage).capturing(_amount_context).public_aftermath())
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

## Was [param i] a creature — live on the battlefield, last known once it
## has left (CR 608.2h).
static func _was_creature(i: CardInstance) -> bool:
	if i.zone == Mtg.Zone.BATTLEFIELD: return i.is_creature()
	return (i.last_types & Mtg.CardType.CREATURE) != 0

## The object a trigger captured under [param key], if it is still that
## object on the battlefield (CR 400.7).
static func _captured(g: MtgGame, s: CardInstance, key: String) -> CardInstance:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get(key, -1)))
	return i if g.is_present(i) and i.layer_timestamp == int(ctx.get(key + "_stamp", -2)) else null

## The card a dies-trigger captured ([method M._dead_context]), if it is
## still in the graveyard it went to (CR 400.7: a later visit is a new
## object).
static func _the_dead_card(g: MtgGame, s: CardInstance) -> CardInstance:
	var ctx := g.trigger_context(s)
	var card := g.find_instance(int(ctx.get("id", -1)))
	if card == null or card.zone != Mtg.Zone.GRAVEYARD or card.graveyard_entry != int(ctx.get("entry", -2)):
		return null
	return card

## How much damage one damage event carried, captured as it triggers.
static func _amount_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	ctx["amount"] = int(e.data.get("amount", 0))
	return ctx

## The creature one damage packet hit, and how much (DAMAGE_DEALT names it
## `to_instance`).
static func _victim_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := _amount_context(g, s, e)
	var hit: CardInstance = e.data.get("to_instance")
	if hit != null:
		ctx["hit"] = hit.id
		ctx["hit_stamp"] = hit.layer_timestamp
	return ctx

static func _draw_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(M.pid_of(g, s), 1)

## "You gain that much life."
static func _gain_that_much(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var amount := int(g.trigger_context(s).get("amount", 0))
	if amount > 0:
		g.adjust_life(M.pid_of(g, s), amount)

## "It deals that much damage to target opponent" — from the creature as it
## last existed if the damage killed it (CR 608.2h).
static func _that_much_to_target(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var amount := int(g.trigger_context(s).get("amount", 0))
	if amount <= 0: return
	for t in g.current_targets():
		var ref: TargetRef = t
		if ref.is_player:
			g.deal_damage(s, ref, amount)

static func _dealt_damage_me(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("to_instance") == s and int(e.data.get("amount", 0)) > 0

static func _dealt_combat_damage_me(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return _dealt_damage_me(g, s, e) and bool(e.data.get("is_combat", false))


# ---------------------------------------------------------------- Awakening --

## Every creature and land on the battlefield, either player's; a
## phased-out permanent is treated as though it doesn't exist (CR 702.26b).
static func _awakening(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		if i.tapped and g.is_present(i) and (i.is_creature() or i.is_land()):
			g.untap_permanent(i)


# ----------------------------------------------------------- Bottomless Pit --

## "That player": the upkeep's player, whoever controls the Pit.
static func _bottomless_pit(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who >= 0:
		g.discard_random(who, 1)


# --------------------------------------------------------------- Burgeoning --

static func _opponent_played_land(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("controller", -1))
	return who >= 0 and who != s.controller_id

## Putting a land onto the battlefield is not playing one: no land drop is
## used (CR 305.4), so a Burgeoning on the other side does not answer it.
static func _burgeoning(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var lands: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_land():
			lands.append(card)
	if lands.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, lands,
		"Burgeoning: you may put a land card from your hand onto the battlefield", true)
	if pick != null and lands.has(pick):
		g.put_from_hand_into_play(pick, pid)


# ------------------------------------------------------------ Contemplation --

static func _you_cast(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("controller", -1)) == s.controller_id


# -------------------------------------------------------- Crovax the Cursed --

## "You may sacrifice a creature" — any creature you control, Crovax
## included (offered last; a sacrificed Crovax takes no counter). An
## instruction on resolution, not a cost. The hint sacrifices a token or a
## small body, and anything at all once a removed counter would kill Crovax.
static func _crovax(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var here := F._same_trigger_source(g, s)
	var mine := M.creatures_of(g, pid, func(i: CardInstance) -> bool: return not i.phased_out)
	M.least_valuable_first(mine, s)
	var counters := int(s.counters.get("+1/+1", 0)) if here else 0
	var hint := false
	for i in mine:
		if i == s: continue
		if i.is_token or i.cur_power + i.cur_toughness <= 2 or (here and counters <= 1):
			hint = true
			break
	if not mine.is_empty() and g.agents[pid].choose_yes_no(g, pid,
			"Crovax the Cursed: sacrifice a creature? (If you do, put a +1/+1 counter on Crovax. If you don't, remove a +1/+1 counter from Crovax.)",
			hint):
		g.sacrifice_permanent(M.pick(g, pid, mine, "Crovax the Cursed: sacrifice a creature"))
		if F._same_trigger_source(g, s):
			g.add_counters(s, "+1/+1")
		return
	if here and int(s.counters.get("+1/+1", 0)) > 0:
		g.remove_counters(s, "+1/+1", 1)


# --------------------------------------------------------------- Grave Pact --

## "A creature you control" — its controller as it died (the DIES event's
## `controller`), a token included.
static func _your_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and int(e.data.get("controller", -1)) == s.controller_id

## Each other player chooses one of their own creatures (offered
## cheapest-to-lose first), then all are sacrificed together (one event).
static func _grave_pact(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var picks: Array[CardInstance] = []
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		if who == pid: continue
		var theirs := M.creatures_of(g, who, func(i: CardInstance) -> bool: return not i.phased_out)
		if theirs.is_empty(): continue
		M.least_valuable_first(theirs)
		picks.append(M.pick(g, who, theirs, "Grave Pact: sacrifice a creature"))
	if picks.is_empty(): return
	g.begin_simultaneous()
	for i in picks:
		g.sacrifice_permanent(i)
	g.end_simultaneous()


# ----------------------------------------------------------- Heat of Battle --

static func _a_creature_blocks(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var blocker: CardInstance = e.data.get("instance")
	return blocker != null and blocker.is_creature()

static func _blocker_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var blocker: CardInstance = e.data.get("instance")
	ctx["blocker"] = blocker.id
	ctx["blocker_stamp"] = blocker.layer_timestamp
	ctx["blocker_controller"] = int(e.data.get("controller", blocker.controller_id))
	return ctx

## "That creature's controller": its controller now while it is the same
## creature, else as it last existed. The damage is the enchantment's, as
## it last existed if it has left.
static func _heat_of_battle(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).get("blocker_controller", -1))
	var blocker := _captured(g, s, "blocker")
	if blocker != null:
		who = blocker.controller_id
	if who >= 0:
		g.deal_damage(s, TargetRef.player(who), 1)


# --------------------------------------------------------------- Hesitation --

static func _a_spell_was_cast(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") is CardInstance

## The spell and its stack object, as it was cast.
static func _spell_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var spell: CardInstance = e.data.get("instance")
	var item := g.find_stack_item(spell)
	ctx["spell"] = spell.id
	ctx["item"] = item.id if item != null else -1
	return ctx

## Both instructions, each as far as it can go (CR 608.2c): the sacrifice
## needs this very Hesitation, still its controller's; the counter needs
## that spell still on the stack as the object that was cast.
static func _hesitation(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if F._trigger_source_present(g, s) and s.controller_id == pid:
		g.sacrifice_permanent(s)
	var ctx := g.trigger_context(s)
	var spell := g.find_instance(int(ctx.get("spell", -1)))
	if spell == null or spell.zone != Mtg.Zone.STACK: return
	var item := g.find_stack_item(spell)
	if item != null and item.id == int(ctx.get("item", -2)):
		g.counter_spell(spell)


# --------------------------------------------------------- Lowland Basilisk --

## "Deals damage to a creature" — one trigger per damage packet.
static func _damages_a_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if e.data.get("source") != s or int(e.data.get("amount", 0)) <= 0: return false
	var hit: CardInstance = e.data.get("to_instance")
	return hit != null and _was_creature(hit)

## The creature is condemned to the next end-of-combat step (a delayed
## destruction, CR 603.7 — Thicket Basilisk's list; regeneration applies),
## only while it is still the creature that was hit.
static func _basilisk(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var hit := _captured(g, s, "hit")
	if hit != null:
		g.doom_at_end_of_combat(hit)


# ------------------------------------------------------------------- Megrim --

## Any discard by an opponent — an effect's, a cost's or the cleanup step's
## (CARD_DISCARDED; Library of Leng's "instead" is still a discard).
static func _opponent_discarded(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("player", -1))
	return who >= 0 and who != s.controller_id

static func _megrim(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who >= 0:
		g.deal_damage(s, TargetRef.player(who), 2)


# ------------------------------------------------------------- Mogg Bombers --

static func _another_creature_enters(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i != s and i.is_creature()

## "Sacrifice this creature and it deals 3 damage": the sacrifice needs this
## very Bombers, still its controller's; the damage does not wait on it
## (CR 608.2c) and comes from the Bombers as it last existed (CR 608.2h) —
## a second trigger after the first has sacrificed it still deals its 3.
static func _bombers(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if F._trigger_source_present(g, s) and s.controller_id == pid:
		g.sacrifice_permanent(s)
	for t in g.current_targets():
		var ref: TargetRef = t
		if ref.is_player:
			g.deal_damage(s, ref, 3)


# ----------------------------------------------------------------- Mortuary --

## "Put into YOUR graveyard": a card goes to its OWNER's graveyard, so the
## dead creature's owner must be this controller (a token reaches the
## graveyard before it ceases to exist, CR 111.7 — and then there is no
## card to move).
static func _creature_to_your_graveyard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0 and dead.owner_id == s.controller_id

static func _mortuary(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var card := _the_dead_card(g, s)
	if card != null and not card.is_token:
		g.return_from_graveyard_to_library_top(card)


# ------------------------------------------------------------ Sacred Ground --

## A land of this controller's put into their graveyard WHILE a spell or
## ability an opponent controls is resolving (MtgGame.
## current_resolution_controller — Psychic Purge's reader): that object
## caused it. A cost the land's controller paid, a state-based action and
## that player's own spells do not.
static func _opponent_buried_your_land(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	if dead == null or (dead.last_types & Mtg.CardType.LAND) == 0 or dead.owner_id != s.controller_id:
		return false
	var cause := g.current_resolution_controller()
	return cause >= 0 and cause != s.controller_id

## "Return that card to the battlefield" — under its owner's control
## (CR 110.2a), only the card that went there this time.
static func _sacred_ground(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var card := _the_dead_card(g, s)
	if card != null:
		g.reanimate(card, card.owner_id)
