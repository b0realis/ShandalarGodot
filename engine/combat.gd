class_name CombatState
extends RefCounted
## The combat phase's working state: who attacks (and in which BANDS), who
## blocks whom, and the legality rules for both. Damage resolution lives in
## MtgGame's damage-step machinery so all life/damage mutation stays in one
## file; this class owns DECLARATIONS and grouping.
##
## Combat rules implemented (CR anchors):
## - Attack legality (508.1): untapped creature, controlled since the turn
##   began (or haste), no DEFENDER; Sea Serpent-style "can't attack unless
##   defender controls X" clauses.
## - Attacking taps unless VIGILANCE (508.1f).
## - Block legality (509.1): untapped defender's creature; FLYING blocked
##   only by FLYING/REACH; protection's B of DEBT; landwalk (LIVE types —
##   Goblin King grants mountainwalk — minus any nullifier, Gosta Dirk);
##   blocker-subtype bans (Juggernaut); FEAR (702.36); power thresholds in
##   both directions (Ironclaw Orcs, Amrou Kithkin); and the open-ended
##   "can't be blocked except by …" predicates (Invisibility, Elven Riders),
##   which is also where until-EOT block restrictions (Tower of Coireall)
##   arrive from the continuous pipeline.
## - MULTI-BLOCK: any number of blockers per attacker, and — since
##   2026-09-02 — any number of ATTACKERS per blocker where an effect
##   allows it (CR 509.1b, [member extra_blocks],
##   [member CardInstance.cur_extra_blocks]: Two-Headed Giant of Foriys,
##   Blaze of Glory). The ATTACKING PLAYER
##   announces the damage assignment order as blockers are declared
##   (CR 509.2, [member damage_order], filled from
##   DecisionAgent.order_blockers) and divides the damage at the damage step
##   (CR 510.1c, MtgGame.assign_combat_damage). The 1997 ruleset had no
##   order at all — RulesOptions.free_damage_assignment.
## - BANDING (702.22, simplified but honest): creatures with banding may be
##   declared in bands (all members banding, or all-but-one). A blocker
##   that blocks ANY band member fights the WHOLE band: every striking
##   member's damage pools against the band's blockers, and blocker damage
##   is spread across band members lethal-first in band order —
##   approximating the attacker-assigns rule (702.22j) with the
##   sacrificial-lamb line real players take. DEFENSIVE banding (the
##   defending player dividing an attacker's damage among its blockers,
##   CR 702.22f-h) is the `free_order` flag on a damage request.
## - TRAMPLE (702.19): excess over the blockers' lethal carries to the
##   defending player.

## instance_id of each attacker → true (declared this combat).
var attackers: Dictionary = {}

## Declared attack bands: Array of Arrays of attacker ids. Attackers not
## in any band fight as implicit solo bands.
var bands: Array = []

## instance_id of blocker → instance_id of the attacker it was declared
## against. Band expansion happens at damage time via [method band_of].
##
## ONE ENTRY PER BLOCKER, ALWAYS — a creature that blocks several
## attackers (see [member extra_blocks]) still has exactly one entry here,
## naming the FIRST attacker it was declared against. That is deliberate:
## `blocks.has(id)` is "is this creature blocking?", which two dozen cards
## ask and which must keep its meaning, and CR 509.1b describes a
## multi-block in the same shape — a creature blocks ONE attacker, and an
## effect may let it block ADDITIONAL ones. Ask [method is_blocking] rather
## than comparing this value when the question is "is X blocking Y".
var blocks: Dictionary = {}

## ONE-TO-MANY BLOCKS (CR 509.1b): blocker instance_id → the ADDITIONAL
## attacker ids it was declared against, beyond the one in [member blocks].
## Empty for every ordinary block, which is what keeps that map's shape.
##
## A creature may block only one attacker unless an effect says otherwise
## — [member CardInstance.cur_extra_blocks] is that permission, printed on
## Two-Headed Giant of Foriys (*"can block an additional creature each
## combat"*) and granted for the turn by Blaze of Glory (*"can block any
## number of creatures"*).
var extra_blocks: Dictionary = {}

## Attackers that BECAME BLOCKED this combat, whether or not a blocker is
## still there. CR 509.1h: once an attacker is blocked it stays blocked
## until it leaves combat or the phase ends — killing, bouncing or
## regenerating the blocker does not let it through (only trample does).
var blocked_attackers: Dictionary = {}

## THE DAMAGE ASSIGNMENT ORDER (CR 509.2): the attacking player announces,
## as blockers are declared, the order in which each attacker's blockers
## will be assigned damage. Keyed by the band's FIRST attacker id (a solo
## attacker is its own one-member band), value an Array of blocker ids.
## Absent = block-declaration order. Filled by MtgGame.declare_blockers
## from the attacking seat's DecisionAgent.order_blockers, and IGNORED
## outright under RulesOptions.free_damage_assignment — the 1997 ruleset
## had no such order (docs/duel-todo.md §1.4).
var damage_order: Dictionary = {}


## Forget every declaration. MtgGame calls this at the END of the combat
## phase (CR 506.4 — attacking status lasts the whole phase, so Desert's
## end-of-combat ping still sees its attacker) and again as the next
## declare-attackers step opens. All four collections must go together:
## leaving [member blocked_attackers] behind would make the next combat's
## attackers arrive pre-blocked and silently deal no damage.
func clear() -> void:
	attackers.clear()
	bands.clear()
	blocks.clear()
	extra_blocks.clear()
	blocked_attackers.clear()
	damage_order.clear()


## Did any member of [param band] become blocked this combat? The damage
## step asks this rather than "does it have a blocker right now", because a
## blocked attacker whose blockers all died still deals no damage to the
## player (CR 509.1h / 510.1c) — only trample punches through.
func was_blocked(band: Array) -> bool:
	for id in band:
		if blocked_attackers.has(id):
			return true
	return false


## Take [param attacker_id] out of every declared band (CR 506.4 — a
## creature removed from combat stops being an attacker, and [method
## all_bands] reads the band arrays directly, so leaving it there would keep
## it dealing and receiving band damage). Empty bands are dropped.
func remove_from_bands(attacker_id: int) -> void:
	for i in range(bands.size() - 1, -1, -1):
		var band: Array = bands[i]
		if band.has(attacker_id):
			band.erase(attacker_id)
			if band.is_empty():
				bands.remove_at(i)


## Take [param instance_id] out of EVERY combat collection: attacker,
## band member, blocked flag, blocker, and any announced damage order that
## still names it (CR 506.4 — a permanent removed from combat stops being
## an attacking, blocking, blocked or unblocked creature).
##
## MtgGame.remove_from_combat wraps this with the printed-card extra
## (False Orders' unblocking) and a recalculation; MtgGame calls it bare
## from the zone-change helpers, because an object that leaves — or
## arrives on — the battlefield is a NEW object (CR 400.7) that was never
## declared. Instance ids are never reused, but a card that leaves and
## comes straight back (Tawnos's Coffin releasing its prisoner mid-combat)
## keeps its id, and a stale entry would have it strike twice.
##
## DELIBERATELY LEFT STANDING: a BLOCKER's entry in [member blocks] whose
## value names the forgotten ATTACKER. A creature that blocked something
## which then left combat is still a blocking creature (CR 506.4 removes
## only the departing permanent; glossary, "Blocking Creature": until it
## is removed from combat or the phase ends) — `blocks.has(blocker)` is
## what Righteousness' "target blocking creature", Lady Caleria and the
## rest ask, and erasing the entry would make it wrong. It deals no
## combat damage either way (CR 510.1c: no creature it is blocking is
## still in combat; the damage step walks [method all_bands], which only
## knows current attackers). [method attackers_blocked_by] can therefore
## name an id that is no longer an attacker; every consumer looks the
## instance up and tolerates a miss.
func forget(instance_id: int) -> void:
	attackers.erase(instance_id)
	remove_from_bands(instance_id)
	blocked_attackers.erase(instance_id)
	blocks.erase(instance_id)
	extra_blocks.erase(instance_id)
	damage_order.erase(instance_id)
	for key in damage_order:
		var order: Array = damage_order[key]
		order.erase(instance_id)
	# The departing object may also be an ATTACKER that somebody was
	# blocking as their second or third block — the same reason
	# [method remove_from_bands] exists.
	for key in extra_blocks:
		var also: Array = extra_blocks[key]
		also.erase(instance_id)


## The band containing [param attacker_id] — [id] alone when unbanded.
func band_of(attacker_id: int) -> Array:
	for band in bands:
		if band.has(attacker_id):
			return band
	return [attacker_id]


## Every declared band plus implicit solo bands, covering all attackers.
func all_bands() -> Array:
	var covered := {}
	var out := []
	for band in bands:
		out.append(band)
		for id in band:
			covered[id] = true
	for id in attackers:
		if not covered.has(id):
			out.append([id])
	return out


## Every attacker [param blocker_id] was declared against — its one entry
## in [member blocks] plus anything in [member extra_blocks]. Empty when it
## is not blocking at all.
func attackers_blocked_by(blocker_id: int) -> Array[int]:
	var out: Array[int] = []
	if not blocks.has(blocker_id):
		return out
	out.append(int(blocks[blocker_id]))
	for id in extra_blocks.get(blocker_id, []):
		if not out.has(int(id)):
			out.append(int(id))
	return out


## Is [param blocker_id] blocking [param attacker_id]? THE QUESTION TO ASK
## — comparing `blocks[blocker]` to an attacker id answers it wrongly for a
## creature blocking more than one (Two-Headed Giant of Foriys, a creature
## under Blaze of Glory).
func is_blocking(blocker_id: int, attacker_id: int) -> bool:
	if int(blocks.get(blocker_id, -1)) == attacker_id:
		return true
	return (extra_blocks.get(blocker_id, []) as Array).has(attacker_id)


## Every attacker [param blocker_id] is FIGHTING: each attacker it blocks,
## plus the rest of that attacker's band — blocking one band member is
## blocking the whole band (CR 702.22j), and this engine's banding pools
## damage that way. The question Lesser Werewolf, Spitting Slug and Sewers
## of Estark ask; one-to-many blocks are why it can no longer be written as
## `band_of(blocks[id])` at the call site.
func opposing_attackers(blocker_id: int) -> Array[int]:
	var out: Array[int] = []
	for attacker_id in attackers_blocked_by(blocker_id):
		for id in band_of(attacker_id):
			if not out.has(int(id)):
				out.append(int(id))
	return out


## Blocker ids assigned against ANY member of [param band], in declaration
## order (Dictionary preserves insertion order in Godot).
func blockers_of_band(band: Array) -> Array[int]:
	var out: Array[int] = []
	for blocker_id in blocks:
		for attacker_id in band:
			if is_blocking(int(blocker_id), int(attacker_id)):
				out.append(int(blocker_id))
				break
	return out


## The blockers of [param band] in their announced DAMAGE ASSIGNMENT ORDER
## (CR 509.2), falling back to declaration order. Anything the announced
## order does not mention keeps its declaration place at the end, so a
## stale or partial order can never lose a blocker.
func ordered_blockers_of_band(band: Array) -> Array[int]:
	var declared := blockers_of_band(band)
	if band.is_empty() or not damage_order.has(band[0]):
		return declared
	var out: Array[int] = []
	for id in damage_order[band[0]]:
		if declared.has(id) and not out.has(id):
			out.append(int(id))
	for id in declared:
		if not out.has(id):
			out.append(id)
	return out


## Blocker ids assigned directly to one attacker (UI/test convenience).
func blockers_of(attacker_id: int) -> Array[int]:
	var out: Array[int] = []
	for blocker_id in blocks:
		if is_blocking(int(blocker_id), attacker_id):
			out.append(int(blocker_id))
	return out


## Can [param inst] be declared as an attacker against [param defender_pid]?
## "" when legal, else a human-readable refusal.
static func attack_illegality(game: MtgGame, inst: CardInstance, defender_pid: int) -> String:
	if not inst.is_creature():
		return "not a creature"
	if inst.tapped:
		return "tapped creatures can't attack"
	# HASTE, or "can attack as though it had haste" (Instill Energy) — the
	# latter lifts only this gate, never the {T}-cost one (CR 302.6).
	if inst.summoning_sick and not inst.has_keyword(Mtg.Keyword.HASTE) \
			and not inst.cur_attacks_as_if_hasty:
		return "summoning sickness"
	if inst.has_keyword(Mtg.Keyword.DEFENDER):
		return "has defender"
	if inst.cur_cant_attack:
		return "can't attack"
	if inst.cant_attack_this_turn:
		return "can't attack this turn (Wall of Dust-style ban)"
	var needs := inst.data.attack_needs_defender_land
	if needs != "" and not _controls_land_of_type(game, defender_pid, needs):
		return "can't attack unless the defending player controls a %s" % needs.capitalize()
	return ""


## Validate a band declaration (all ids already validated as attackers)
## against the two forms of CR 702.22c: "one or more attacking creatures
## with banding and up to one attacking creature without banding (even if
## it has 'bands with other')", or "one or more attacking [quality]
## creatures with 'bands with other [quality]' and any number of other
## attacking [quality] creatures". "" when legal.
static func band_illegality(game: MtgGame, band: Array) -> String:
	if band.size() < 2:
		return "a band needs at least two creatures"
	var members: Array = []
	var non_banding := 0
	for id in band:
		var inst := game.find_instance(id)
		if inst == null:
			return "unknown creature in band"
		members.append(inst)
		if not inst.has_keyword(Mtg.Keyword.BANDING):
			non_banding += 1
	if non_banding <= 1:
		return ""
	if shared_bands_with(members) != "":
		return ""
	var offered := bands_with_offered(members)
	if offered != "":
		return "at most one creature in a band can lack banding, and not every member is one of the %s the band's \"bands with other\" allows" % offered
	return "at most one creature in a band can lack banding"


## The "bands with other [quality]" that makes [param members] a band
## (CR 702.22c, second sentence): the description of a quality some member
## has "bands with other" for that EVERY member has — "" when there is
## none.
static func shared_bands_with(members: Array) -> String:
	for holder in members:
		for entry in holder.cur_bands_with:
			var filter: Callable = entry["filter"]
			var all := true
			for other in members:
				if not filter.call(other):
					all = false
					break
			if all:
				return String(entry["desc"])
	return ""


## The qualities any member of [param members] has "bands with other" for,
## joined for a refusal — "" when nobody has one.
static func bands_with_offered(members: Array) -> String:
	var descs: Array[String] = []
	for holder in members:
		for entry in holder.cur_bands_with:
			if not descs.has(String(entry["desc"])):
				descs.append(String(entry["desc"]))
	return " / ".join(descs)


## Do [param blockers] block "with" a "bands with other" (CR 702.22j-k:
## "both a [quality] creature with 'bands with other [quality]' and
## another [quality] creature")? The holder must have the quality itself
## and one OTHER blocker must too; the rest need not.
static func bands_with_among(blockers: Array) -> bool:
	for holder in blockers:
		for entry in holder.cur_bands_with:
			var filter: Callable = entry["filter"]
			if not filter.call(holder):
				continue
			for other in blockers:
				if other != holder and filter.call(other):
					return true
	return false


## Can [param blocker] block [param attacker]? "" when legal, else reason.
static func block_illegality(game: MtgGame, blocker: CardInstance,
		attacker: CardInstance, defender_pid: int) -> String:
	if not blocker.is_creature():
		return "not a creature"
	# CR 509.1a: a blocking creature is one the defending player controls
	# ON THE BATTLEFIELD. [method MtgGame.declare_blockers] checks the zone
	# itself, so this is not what makes an illegal declaration illegal —
	# it makes the PREDICATE honest for the callers that ask "could this
	# block?" BEFORE any declaration: the AI's block planning and the duel
	# screen's pick-up gate. Without it a creature card in the defending
	# player's HAND answered "yes" (2026-09-04) and the screen would lift
	# it into the blocker lane, where it could only ever produce a
	# declaration the engine refused as a whole — taking the player's real
	# blocks down with it.
	if blocker.zone != Mtg.Zone.BATTLEFIELD:
		return "%s is not on the battlefield" % blocker.data.card_name
	# CR 506.4: a permanent that has LEFT the battlefield is no longer an
	# attacker. Its combat entry is deliberately left standing until its
	# own leave/dies trigger has resolved (Abu Ja'far destroys everything
	# blocking or blocked by it, and reads that state as it dies), so the
	# check belongs here — otherwise a blocker could be spent on a
	# creature that is already in the graveyard.
	if attacker.zone != Mtg.Zone.BATTLEFIELD:
		return "%s is no longer on the battlefield" % attacker.data.card_name
	if blocker.tapped:
		return "tapped creatures can't block"
	if attacker.has_keyword(Mtg.Keyword.UNBLOCKABLE):
		return "can't be blocked"
	if attacker.has_keyword(Mtg.Keyword.FLYING) \
			and not (blocker.has_keyword(Mtg.Keyword.FLYING)
				or blocker.has_keyword(Mtg.Keyword.REACH)):
		return "can't block flying"
	# Protection's B of DEBT (CR 702.16): can't be Blocked by that color.
	if (attacker.cur_protection & blocker.cur_colors) != 0:
		return "protection: can't be blocked by that color"
	# Landwalk (CR 702.14) — LIVE types, so granted walks count. A
	# nullifier on the battlefield (Undertow, Gosta Dirk) makes one type
	# blockable "as though it didn't have it" WITHOUT removing the
	# ability, which is why this is a blocking-rule check and not a
	# characteristic change.
	for land_type in attacker.cur_landwalk:
		if game.nullified_landwalk.has(land_type):
			continue
		if _controls_land_of_type(game, defender_pid, land_type):
			return "%swalk: can't be blocked" % land_type
	# Explicit blocker-subtype bans (Juggernaut's "can't be blocked by
	# Walls"). LIVE, not printed: a face-down permanent has no abilities
	# (CR 708.2), and these three used to be read off `data` — the last
	# combat characteristics in the engine that were.
	for banned in attacker.cur_cant_be_blocked_by:
		if blocker.has_subtype(banned):
			return "can't be blocked by %ss" % banned
	# Power-threshold restrictions, both directions (live power values):
	# "can't block creatures with power N+" (Ironclaw Orcs) and "can't be
	# blocked by creatures with power N+" (Amrou Kithkin).
	if blocker.cur_cant_block_power_ge > 0 \
			and attacker.cur_power >= blocker.cur_cant_block_power_ge:
		return "can't block creatures with power %d or greater" % \
			blocker.cur_cant_block_power_ge
	if attacker.cur_cant_be_blocked_by_power_ge > 0 \
			and blocker.cur_power >= attacker.cur_cant_be_blocked_by_power_ge:
		return "can't be blocked by creatures with power %d or greater" % \
			attacker.cur_cant_be_blocked_by_power_ge
	# FEAR (CR 702.36): only artifact creatures and/or black creatures may
	# block. Reads the LIVE colour mask, so a blocker that Touch of Darkness
	# or Deathlace just painted black really can block the Fear creature.
	if attacker.has_keyword(Mtg.Keyword.FEAR) \
			and not blocker.is_type(Mtg.CardType.ARTIFACT) \
			and (blocker.cur_colors & Mtg.ManaColor.B) == 0:
		return "fear: only artifact and/or black creatures may block"
	# Block restrictions ("can't be blocked except by …" — Invisibility,
	# Elven Riders, Seeker): every restriction's predicate must accept
	# the blocker (multiple restrictions intersect).
	for restriction in attacker.cur_block_restrictions:
		var cb: Callable = restriction["filter"]
		if not cb.call(blocker):
			return "can't be blocked except by: %s" % String(restriction["desc"])
	return ""


## Does [param pid] control a land of [param land_type]? The pseudo-type
## "legendary" matches any LEGENDARY land (Livonya Silone's legendary
## landwalk), which is a supertype rather than a subtype.
static func _controls_land_of_type(game: MtgGame, pid: int, land_type: String) -> bool:
	for inst in game.players[pid].battlefield:
		if not inst.is_land():
			continue
		if land_type == "legendary":
			if (inst.data.supertypes & Mtg.Supertype.LEGENDARY) != 0:
				return true
		elif inst.has_subtype(land_type):
			return true
	return false
