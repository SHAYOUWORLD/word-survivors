extends Node
## Global run state: timer, phase (difficulty), kills, signals.

enum State { PLAYING, LEVELUP, GAMEOVER, RESULT }

const RUN_DURATION: float = 300.0  # 5 minutes

var state: int = State.PLAYING
var run_time: float = 0.0
var kills: int = 0

signal run_time_updated(t: float)
signal state_changed(s: int)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		run_time += delta
		run_time_updated.emit(run_time)
		if run_time >= RUN_DURATION:
			trigger_survive()

func start_run() -> void:
	run_time = 0.0
	kills = 0
	set_state(State.PLAYING)

func set_state(s: int) -> void:
	state = s
	state_changed.emit(s)

func register_kill() -> void:
	kills += 1

func trigger_game_over() -> void:
	set_state(State.GAMEOVER)

func trigger_survive() -> void:
	set_state(State.RESULT)

func format_time(t: float) -> String:
	var clamped: float = max(0.0, t)
	var m: int = int(clamped) / 60
	var s: int = int(clamped) % 60
	return "%02d:%02d" % [m, s]

func remaining() -> float:
	return max(0.0, RUN_DURATION - run_time)
