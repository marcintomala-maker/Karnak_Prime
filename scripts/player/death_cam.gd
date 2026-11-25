extends RigidBody3D
## Tossed camera after death. A soft torque nudges it to end up looking at the sky.

var _t := 0.0

func _physics_process(delta: float) -> void:
	_t += delta
	var cam := get_child(get_child_count() - 1) as Camera3D
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	# torque that rotates the view direction toward +Y; grows once the toss settles
	var axis := fwd.cross(Vector3.UP)
	var strength := clampf(_t - 0.25, 0.0, 1.0) * 6.0
	apply_torque(axis * strength * mass)
