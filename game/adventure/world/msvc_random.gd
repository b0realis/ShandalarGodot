class_name MsvcRandom
extends RefCounted
## THE ORIGINAL'S DICE — the C runtime's `rand()` the 1997 game was built
## with (Microsoft Visual C 4.20), and the game's own `internal_rand`.
##
## Everything random in the original goes through `internal_rand(n)`:
## `rand() % n` for n above 1, else 0 (1.3, `duel_ai_support.c`, 00522508),
## and `rand()` is the runtime's linear congruential generator — the state
## times 214013 plus 2531011, modulo 2^32, of which bits 16 to 30 are the
## result (0 to 32767). Reproducing a world exactly means reproducing these
## two to the bit, and drawing in the original's order.

## The generator's whole state, 32 bits.
var state := 1


func _init(seed_value := 1) -> void:
	reseed(seed_value)


## `srand(seed)`: the state IS the seed.
func reseed(seed_value: int) -> void:
	state = seed_value & 0xFFFFFFFF


## `rand()`: 0 to 32767.
func rand() -> int:
	state = (state * 214013 + 2531011) & 0xFFFFFFFF
	return (state >> 16) & 0x7FFF


## `internal_rand(maximum)`: 0 to maximum − 1, by `rand() % maximum`; 0
## for a maximum of 1 or less, without drawing.
func below(maximum: int) -> int:
	return rand() % maximum if maximum > 1 else 0


## The largest maximum [method below] reaches every number under: `rand()`
## gives 0 to 32767 and nothing more.
const REACH := 0x8000


## [Ours] 0 to [param maximum] − 1 for a maximum past `rand()`'s reach
## ([constant REACH]): two draws, 30 bits, `% maximum`. Up to the reach it
## is [method below] exactly (one draw).
func below_wide(maximum: int) -> int:
	if maximum <= REACH:
		return below(maximum)
	return ((rand() << 15) | rand()) % maximum


## THE PLACE IN A BAG OF [param bag] DRAWN AS 1997 DREW ONE: `rand(bag)`
## again and again until one of [param places] comes up (the meetings' and
## the room duels' stakes, the dungeon's dice; 1997's bag was 500) — −1
## when [param places] is empty. [Ours, the 0.50.65 bug campaign, k1-3:
## a bag past [constant REACH] (an unlimited card hold) — or a place past
## the bag — is drawn among [param places] at once ([method below_wide]):
## `rand()` never reaches a place past 32767, and a bag whose places all
## stood there was drawn forever. The odds are the same: the redraws pick
## any place of [param places] alike.]
func place_among(bag: int, places: Array[int]) -> int:
	if places.is_empty():
		return -1
	var wanted := {}
	var reached := bag <= REACH
	for at in places:
		wanted[at] = true
		reached = reached and at >= 0 and at < bag
	if not reached:
		return places[below_wide(places.size())]
	var drawn := below(bag)
	while not wanted.has(drawn):
		drawn = below(bag)
	return drawn
