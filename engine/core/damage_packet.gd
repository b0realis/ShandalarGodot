class_name DamagePacket
extends RefCounted
## ONE damage event, reified — the object the 1997 game let you point at.
##
## `Duel.hlp`, topic **Using Land**: *"If the effect is a targeted one
## (damage prevention, for example, WHICH TARGETS DAMAGE), you also need to
## choose a target. When you're prompted, click on any valid target — a
## card, A DAMAGE MARKER, or whatever."* Damage in the original is not an
## integer that has already happened; it is a thing on the table with a
## source, a victim and an amount, and a damage-prevention effect targets
## it (docs/duel-todo.md §6.8).
##
## The Circle of Protection rulings name the unit: *"it targets PACKETS of
## the appropriate damage"*, and Manabarbs' — *"damage ... during a damage
## prevention step is added to an existing Manabarbs damage packet (if
## there is one), so a single use of the CoP would target and prevent all
## of that damage"* — is why [method matches] exists and why merging is by
## SOURCE and victim rather than by event.
##
## Lifecycle: [method MtgGame.deal_damage] is now two halves — a planning
## half that builds one of these, and a landing half that runs it through
## the prevention gates and applies what is left. With no damage-prevention
## window open the two run back to back and a packet lives for the length
## of one call. With a window open it waits in
## [member MtgGame.damage_pending] where the players can see it.
##
## Not a value object, unlike [TargetRef]: it holds the live [member source]
## rather than an id, because CR 609.7a fixes the source of damage at the
## moment the damage is dealt and CR 608.2b keeps it meaningful after it has
## left the battlefield. A token source is erased from `MtgGame._instances`
## when it dies, so an id would go stale exactly where the rules say the
## source must not.

## The permanent (or spell) dealing the damage. Live reference — see the
## class note for why this one is not an id.
var source: CardInstance = null

## Who or what is being dealt to. A player ref or a card ref; never a
## damage ref (damage does not damage damage).
var target: TargetRef = null

## How much damage this packet started as.
var amount: int = 0

## How much of [member amount] has been prevented. Prevention draws this up
## rather than drawing [member amount] down, so the packet still knows what
## it was — which is what lets a second prevention effect in the same window
## see how much is left to work on.
var prevented: int = 0

## How much of [member amount] has been DIVERTED point by point — "the
## next 1 damage that would be dealt to this creature this turn is dealt
## to its owner instead" (Personal Incarnation). A whole-event redirect
## (Jade Monolith) moves the packet itself; a metered one splits it, and
## this is the part that left as a new packet. Like [member prevented] it
## draws [member remaining] down without touching [member amount].
var redirected: int = 0

## COMBAT damage (set by the two combat-damage waves). Gaseous Form's
## "dealt to and dealt by" and the first-strike split both read it.
var is_combat: bool = false

## This packet was produced by REDIRECTION (Veteran Bodyguard, Jade
## Monolith, Martyrs of Korlis) rather than by an original damage event.
## `Duel.hlp`'s Veteran Bodyguard ruling — *"if a Bodyguard does redirect
## damage, this causes a SECOND damage-prevention step that follows the
## current one"* — is the rule this flag is for.
var from_redirect: bool = false

## Unique within one game, handed out by `MtgGame`. This is the id a
## [TargetRef] names when a spell targets the damage itself, so it must
## never be reused inside a duel.
var id: int = 0

## Callbacks `func(dealt: int) -> void` run when this packet finally lands
## — immediately with no window open, and at the END of the prevention
## step with one. This is how "you gain life equal to the damage dealt
## this way" (Drain Life, Syphon Soul) survives a window that moves the
## answer into the future; without it the card would read the amount it
## HOPED to deal. Fires on every path, with 0 when the damage was wholly
## prevented, because that is what the card's own `if dealt > 0` expects.
var after_landing: Array[Callable] = []


## The source's instance id, or -1 for a sourceless packet. DERIVED rather
## than stored — a second field could drift, and a computed property would
## be written back by [GameSnapshot]'s reflective restore, which sets every
## script variable it captured.
func source_id() -> int:
	return source.id if source != null else -1


## How much damage is still going to land: what is left after prevention.
func remaining() -> int:
	return maxi(amount - prevented - redirected, 0)


## Prevent up to [param n] points and report how many were actually
## prevented (a pool that offers more than the packet has left is only
## drawn down by what it covers — CR 615.4).
func prevent(n: int) -> int:
	var soaked: int = mini(maxi(n, 0), remaining())
	prevented += soaked
	return soaked


## Divert up to [param n] points elsewhere and report how many actually
## left (never more than is left to land). The caller plans the new packet
## for that many; this only books the split.
func divert(n: int) -> int:
	var moved: int = mini(maxi(n, 0), remaining())
	redirected += moved
	return moved


## Is [param other] the SAME damage as far as 1997 is concerned — same
## source, same victim? Two such packets merge into one (the Manabarbs
## ruling); everything else stays separate so a Circle targets exactly one
## of them.
func matches(other: DamagePacket) -> bool:
	if other == null or source_id() != other.source_id():
		return false
	if is_combat != other.is_combat:
		return false   # first-strike damage is not the normal wave's packet
	if target == null or other.target == null:
		return false
	if target.is_player != other.target.is_player:
		return false
	if target.is_player:
		return target.player_id == other.target.player_id
	return target.instance_id == other.target.instance_id


## Fold [param other] into this packet (see [method matches]). The merged
## packet keeps this one's id, so a target already chosen for it stays
## valid — which is the whole point of merging rather than queueing.
func absorb(other: DamagePacket) -> void:
	amount += other.amount
	prevented += other.prevented
	redirected += other.redirected
	after_landing.append_array(other.after_landing)


func _to_string() -> String:
	var who := "?" if source == null else source.data.card_name
	return "%d damage from %s to %s" % [remaining(), who, target]
