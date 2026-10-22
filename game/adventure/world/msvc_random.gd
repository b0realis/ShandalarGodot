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
