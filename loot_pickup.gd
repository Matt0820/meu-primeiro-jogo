extends Node3D

# Item de campo criado pelo World quando um zumbi morre.
# Os tipos aceitos são "medkit" e "ammo"; ambos são coletados por proximidade.
var tipo := "ammo"
var coletado := false

func configurar(novo_tipo: String) -> void:
	tipo = novo_tipo

func _ready() -> void:
	# A animação flutuante e a área de proximidade dão leitura sem exigir tecla de interação.
	_criar_visual()
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera_colisao := SphereShape3D.new()
	esfera_colisao.radius = 1.35
	forma.shape = esfera_colisao
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(_ao_encostar)
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y + 0.22, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y, 0.7).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "rotation:y", rotation.y + TAU, 1.4)

func _criar_visual() -> void:
	# Núcleo, aro e etiqueta são a representação visual simples dos drops.
	var cor := Color("78e6ad") if tipo == "medkit" else Color("f4c76b")
	var nucleo := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = Vector3(0.52, 0.52, 0.52)
	nucleo.mesh = malha
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.emission_enabled = true
	material.emission = cor.darkened(0.15)
	material.emission_energy_multiplier = 1.4
	material.roughness = 0.35
	nucleo.material_override = material
	nucleo.position.y = 0.55
	add_child(nucleo)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.48
	toro.outer_radius = 0.55
	aro.mesh = toro
	aro.material_override = material
	aro.rotation.x = deg_to_rad(90.0)
	aro.position.y = 0.55
	add_child(aro)
	var label := Label3D.new()
	label.text = "MEDKIT" if tipo == "medkit" else "MUNICAO"
	label.position.y = 1.15
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26
	label.pixel_size = 0.008
	label.modulate = cor
	add_child(label)

func _ao_encostar(corpo: Node3D) -> void:
	# Itens cheios ou vida no máximo ficam no chão para serem usados mais tarde.
	if coletado or not corpo.is_in_group("player"):
		return
	if tipo == "medkit":
		if corpo.has_method("curar") and int(corpo.get("vida_atual")) < int(corpo.get("vida_maxima")):
			corpo.curar(30)
		else:
			return
	else:
		if corpo.has_method("receber_municao"):
			var reserva := int(corpo.get("municao_reserva"))
			var reserva_maxima := int(corpo.get("reserva_maxima"))
			if reserva >= reserva_maxima:
				return
			var capacidade_pente := int(corpo.get("capacidade_municao"))
			corpo.receber_municao(maxi(roundi(capacidade_pente * 0.35), 8))
	coletado = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
