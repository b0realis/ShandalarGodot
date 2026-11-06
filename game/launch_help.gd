class_name LaunchHelp
extends RefCounted
## WHETHER A LAUNCH ASKS FOR THE GAME'S OWN HELP (0.60.16, the owner's ask
## of 2026-11-04): `-- -h` or `-- --help`, beside no tool's switch. The
## title prints the list ([method MainScreen.launch_help]) and quits, and
## the CardPacks autoload builds no pool for it — the quit waits for a
## pool on its way, about 3 s on the desk with every pack.
##
## Only after the engine's `--`: a bare `-h`/`--help` is the engine's,
## which prints its own options and exits before any script runs (measured
## on the 4.7 release template). The release's `run.sh` passes a bare one
## on. No dependencies: an autoload reads it before anything is built.

const HELP_FLAGS: Array[String] = ["-h", "--help"]
## The tools' switches, whose `--help` is that tool's own manual
## ([constant MainScreen.DECK_LAB_FLAG] and the rest; a test keeps the two
## lists the same).
const TOOL_FLAGS: Array[String] = ["--deck-lab", "--auto-deck", "--lab-query",
	"--referee", "--verify-pack-1", "--verify-pack-2", "--verify-pack-3",
	"--verify-pack-4", "--verify-pack-5", "--verify-pack-8", "--verify-pack-9",
	"--verify-pack-10"]


## Whether [param args] (the user args) ask for the help.
static func asked(args: PackedStringArray) -> bool:
	for flag in TOOL_FLAGS:
		if args.has(flag):
			return false
	for flag in HELP_FLAGS:
		if args.has(flag):
			return true
	return false
