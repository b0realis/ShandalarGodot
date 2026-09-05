class_name TargetRef
extends RefCounted
## A chosen target: either a player or a card instance, referenced by id.
##
## TargetRef is a value object — it never holds a live CardInstance pointer,
## only the instance id. Resolution looks the instance up again through
## MtgGame.find_instance, which is what makes "target became illegal"
## (killed in response, changed zones...) naturally detectable.

## True when this ref names a PLAYER; false when it names a card instance,
## DAMAGE or an ABILITY. Exactly one of [member is_player],
## [member is_damage], [member is_ability] and "none of them, so a card" is
## true, and every consumer branches on these flags first.
var is_player: bool = false

## Player id (0/1) when [member is_player]; -1 otherwise.
var player_id: int = -1

## CardInstance id when this is a card ref; -1 otherwise. Deliberately an id
## and not a pointer — see the class note.
var instance_id: int = -1

## True when this ref names DAMAGE — one [DamagePacket] waiting in the
## damage-prevention window (docs/duel-todo.md §6.8, §6.20b). `Duel.hlp`,
## topic **Using Land**: *"If the effect is a targeted one (damage
## prevention, for example, WHICH TARGETS DAMAGE), you also need to choose
## a target. When you're prompted, click on any valid target — a card, A
## DAMAGE MARKER, or whatever."*
var is_damage: bool = false

## True when this ref names an ACTIVATED ABILITY on the stack ("counter
## target activated ability from an artifact source" — Rust, Ayesha
## Tanaka). An ability is not a card: several activations of one permanent
## can be on the stack at once, so the ref names the STACK ITEM.
var is_ability: bool = false

## [member StackItem.id] when [member is_ability]; -1 otherwise.
var ability_id: int = -1

## [member DamagePacket.id] when [member is_damage]; -1 otherwise. An id
## and not a pointer, for the same reason [member instance_id] is: a packet
## that has landed is gone from `MtgGame.damage_pending`, and that is how
## "the damage you aimed at is no longer there" becomes detectable.
var packet_id: int = -1

## For DIVIDED effects ("4 damage divided as you choose among any number of
## targets" — Pyrotechnics, Fireball): how much of the total this target
## was assigned. The division is locked in as the spell is cast (CR 601.2d)
## and each chosen target must get at least 1, which TargetPlan enforces.
## Ignored by every non-divided effect, so the default of 1 is harmless.
var amount: int = 1


## Target a player. [param p_amount] is the divided share (see [member amount]).
static func player(id: int, p_amount: int = 1) -> TargetRef:
	var ref := TargetRef.new()
	ref.is_player = true
	ref.player_id = id
	ref.amount = p_amount
	return ref


## Target a card instance. [param p_amount] is the divided share.
static func card(inst: CardInstance, p_amount: int = 1) -> TargetRef:
	var ref := TargetRef.new()
	ref.instance_id = inst.id
	ref.amount = p_amount
	return ref


## Target an ACTIVATED ABILITY on the stack (CR 113.3b — abilities on the
## stack are objects, and a mana ability never gets there to be targeted).
static func ability(item: StackItem, p_amount: int = 1) -> TargetRef:
	var ref := TargetRef.new()
	ref.is_ability = true
	ref.ability_id = item.id
	ref.amount = p_amount
	return ref


## Target DAMAGE — one packet waiting in the prevention window (§6.8).
static func damage(packet: DamagePacket, p_amount: int = 1) -> TargetRef:
	var ref := TargetRef.new()
	ref.is_damage = true
	ref.packet_id = packet.id
	ref.amount = p_amount
	return ref


## Same target, different divided share — used by TargetPlan when a single
## chosen target absorbs a divided effect's whole total.
func with_amount(p_amount: int) -> TargetRef:
	var ref := TargetRef.new()
	ref.is_player = is_player
	ref.player_id = player_id
	ref.instance_id = instance_id
	ref.is_damage = is_damage
	ref.packet_id = packet_id
	ref.is_ability = is_ability
	ref.ability_id = ability_id
	ref.amount = p_amount
	return ref


## Do these two refs name THE SAME OBJECT? The one place the whole union is
## compared, so a new arm can never be forgotten at a call site — and it was
## nearly forgotten at three: the no-duplicate-targets rule (TargetPlan),
## the AI's already-chosen filter and the duel screen's selection test all
## compared `instance_id` directly, which is -1 for EVERY damage ref, so two
## different packets read as the same target (found building §6.8's slice 3).
## The divided [member amount] is deliberately not part of identity.
func same_object(other: TargetRef) -> bool:
	if other == null:
		return false
	if is_player != other.is_player or is_damage != other.is_damage \
			or is_ability != other.is_ability:
		return false
	if is_player:
		return player_id == other.player_id
	if is_damage:
		return packet_id == other.packet_id
	if is_ability:
		return ability_id == other.ability_id
	return instance_id == other.instance_id


func _to_string() -> String:
	if is_player:
		return "player %d" % player_id
	if is_damage:
		return "damage #%d" % packet_id
	if is_ability:
		return "ability #%d" % ability_id
	return "instance #%d" % instance_id
