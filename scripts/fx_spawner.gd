extends RefCounted
## Helper for spawning short-lived visual FX. All methods are static and
## safe to call from any node.

static func spawn_burst(parent: Node, pos: Vector2, color: Color, count: int = 14, scale_factor: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.amount = count
	p.one_shot = true
	p.emitting = true
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0 * scale_factor
	p.initial_velocity_max = 220.0 * scale_factor
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 2.0 * scale_factor
	p.scale_amount_max = 4.0 * scale_factor
	p.color = color
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.global_position = pos
	parent.add_child(p)
	var timer := parent.get_tree().create_timer(1.0)
	timer.timeout.connect(p.queue_free)

static func spawn_mega_burst(parent: Node, pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.amount = 60
	p.one_shot = true
	p.emitting = true
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 520.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.global_position = pos
	parent.add_child(p)
	var timer := parent.get_tree().create_timer(1.6)
	timer.timeout.connect(p.queue_free)

static func spawn_sparkles(parent: Node, pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.amount = 24
	p.one_shot = true
	p.emitting = true
	p.lifetime = 0.8
	p.explosiveness = 0.6
	p.direction = Vector2.UP
	p.spread = 120.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, -40)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.global_position = pos
	parent.add_child(p)
	var timer := parent.get_tree().create_timer(1.4)
	timer.timeout.connect(p.queue_free)

static func spawn_levelup_beam(parent: Node, pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 50
	p.one_shot = true
	p.emitting = true
	p.lifetime = 1.0
	p.explosiveness = 0.6
	p.direction = Vector2.UP
	p.spread = 25.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, -80)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.9, 0.4, 1.0)
	p.global_position = pos
	parent.add_child(p)
	var timer := parent.get_tree().create_timer(1.6)
	timer.timeout.connect(p.queue_free)
