extends CharacterBody3D

# Inimigo usado pelas hordas. O tipo selecionado define atributos, aparência e ataque.
# A função configurar() precisa ser chamada antes de adicionar o zumbi à cena.
const ALTURA_ACERTO_PERNA := 0.72
const MULTIPLICADOR_CRITICO := 2.0
const DURACAO_LENTIDAO := 2.5

var tipo := "andante"
var onda := 1
var vida := 90
var velocidade := 3.2
var dano := 9
var intervalo_ataque := 0.95
var alcance := 1.55
var lentidao_restante := 0.0
var ataque_restante := 0.0
var morrendo := false
var vida_visivel_restante := 0.0
var alvo: Node3D
var materiais: Array[StandardMaterial3D] = []
var cores_base: Array[Color] = []
var tween_dano: Tween
var label_vida: Label3D

func configurar(novo_tipo: String, numero_onda: int) -> void:
	# A onda aumenta a resistência e o dano, com limites para evitar escalada infinita.
	tipo = novo_tipo
	onda = numero_onda
	var vida_base := 90
	var velocidade_base := 3.2
	var dano_base := 9
	var cadencia := 0.95
	match tipo:
		"corredor":
			vida_base = 58
			velocidade_base = 6.0
			dano_base = 7
			cadencia = 0.72
		"brutamontes":
			vida_base = 230
			velocidade_base = 2.05
			dano_base = 20
			cadencia = 1.15
		"cuspidor":
			vida_base = 88
			velocidade_base = 2.7
			dano_base = 10
			cadencia = 2.4
	vida = roundi(vida_base * (1.0 + maxf(numero_onda - 1, 0) * 0.12))
	velocidade = velocidade_base * minf(1.0 + maxf(numero_onda - 1, 0) * 0.025, 1.25)
	dano = roundi(dano_base * minf(1.0 + maxf(numero_onda - 1, 0) * 0.04, 1.6))
	intervalo_ataque = cadencia

func _ready() -> void:
	add_to_group("inimigos")
	alvo = get_tree().get_first_node_in_group("player") as Node3D
	_criar_corpo()

func _criar_corpo() -> void:
	# Malhas e colisores são gerados aqui para permitir variar tipo e escala sem cenas duplicadas.
	var cor_corpo := Color("66745a")
	var cor_cabeca := Color("87916c")
	var escala := 1.0
	match tipo:
		"corredor":
			cor_corpo = Color("8c533e")
			cor_cabeca = Color("b77759")
			escala = 0.82
		"brutamontes":
			cor_corpo = Color("494d43")
			cor_cabeca = Color("777b65")
			escala = 1.35
		"cuspidor":
			cor_corpo = Color("536f5d")
			cor_cabeca = Color("91a57a")
			escala = 0.96
	scale = Vector3.ONE * escala

	var corpo := MeshInstance3D.new()
	corpo.name = "Corpo"
	var malha_corpo := CapsuleMesh.new()
	malha_corpo.radius = 0.48
	malha_corpo.height = 1.5
	corpo.mesh = malha_corpo
	corpo.position.y = 1.2
	corpo.material_override = _material(cor_corpo)
	add_child(corpo)
	var forma_corpo := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.48
	capsula.height = 1.5
	forma_corpo.shape = capsula
	forma_corpo.position.y = 1.2
	add_child(forma_corpo)

	var cabeca := MeshInstance3D.new()
	cabeca.name = "Cabeca"
	var malha_cabeca := SphereMesh.new()
	malha_cabeca.radius = 0.42
	malha_cabeca.height = 0.84
	cabeca.mesh = malha_cabeca
	cabeca.position.y = 2.42
	cabeca.material_override = _material(cor_cabeca)
	add_child(cabeca)
	var forma_cabeca := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.42
	forma_cabeca.shape = esfera
	forma_cabeca.position.y = 2.42
	forma_cabeca.set_meta("zona_acerto", "cabeca")
	add_child(forma_cabeca)

	for lado in [-1.0, 1.0]:
		var braco := MeshInstance3D.new()
		var malha_braco := CapsuleMesh.new()
		malha_braco.radius = 0.19 if tipo != "brutamontes" else 0.27
		malha_braco.height = 0.95 if tipo != "brutamontes" else 1.25
		braco.mesh = malha_braco
		braco.position = Vector3(lado * 0.53, 1.32, 0.0)
		braco.rotation.z = lado * -0.22
		braco.material_override = _material(cor_corpo.darkened(0.18))
		add_child(braco)

	label_vida = Label3D.new()
	label_vida.position.y = 3.15
	label_vida.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_vida.pixel_size = 0.009
	label_vida.font_size = 38
	label_vida.modulate = Color("ffcc9a")
	label_vida.text = str(vida)
	label_vida.visible = false
	add_child(label_vida)

func _material(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 0.92
	materiais.append(material)
	cores_base.append(cor)
	return material

func _process(delta: float) -> void:
	if vida_visivel_restante > 0.0:
		vida_visivel_restante = maxf(vida_visivel_restante - delta, 0.0)
		label_vida.visible = vida_visivel_restante > 0.0
		if label_vida.visible:
			label_vida.text = str(vida) + ("  LENTO" if lentidao_restante > 0.0 else "")

func receber_dano(quantidade: int) -> void:
	_aplicar_dano(quantidade)

func receber_tiro(quantidade: int, posicao_impacto: Vector3, indice_forma: int = -1) -> String:
	# Retorna a zona do acerto para o feedback visual da mira no HUD.
	var zona := ""
	if indice_forma >= 0:
		var id_dono := shape_find_owner(indice_forma)
		var dono := shape_owner_get_owner(id_dono)
		if dono is CollisionShape3D and dono.has_meta("zona_acerto"):
			zona = str(dono.get_meta("zona_acerto"))
	var dano_final := quantidade
	var tipo_acerto := "corpo"
	if zona == "cabeca":
		tipo_acerto = "cabeca"
		dano_final = roundi(quantidade * MULTIPLICADOR_CRITICO)
	elif to_local(posicao_impacto).y <= ALTURA_ACERTO_PERNA:
		tipo_acerto = "perna"
		lentidao_restante = DURACAO_LENTIDAO
	vida_visivel_restante = 1.6
	label_vida.visible = true
	_aplicar_dano(dano_final)
	return tipo_acerto

func _aplicar_dano(quantidade: int) -> void:
	# Centraliza efeitos de dano, recuo, drop e animação de morte.
	if morrendo:
		return
	vida -= quantidade
	vida_visivel_restante = 1.6
	label_vida.visible = true
	label_vida.text = str(maxi(vida, 0))
	_animar_dano()
	if is_instance_valid(alvo):
		var recuo := Vector3(global_position.x - alvo.global_position.x, 0.0, global_position.z - alvo.global_position.z).normalized()
		velocity += recuo * (1.2 if tipo == "brutamontes" else 2.0)
	if vida <= 0:
		morrendo = true
		remove_from_group("inimigos")
		_sortear_drop()
		if is_instance_valid(alvo) and alvo.has_method("ao_abater_zumbi"):
			alvo.ao_abater_zumbi()
		collision_layer = 0
		collision_mask = 0
		for forma in find_children("*", "CollisionShape3D", true, false):
			(forma as CollisionShape3D).set_deferred("disabled", true)
		var tween_morte := create_tween()
		tween_morte.tween_property(self, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween_morte.finished.connect(queue_free)

func _sortear_drop() -> void:
	# Drops são criados pelo World; o jogador pode aumentar apenas a chance de munição.
	var chance_municao := 0.25
	var jogador := get_tree().get_first_node_in_group("player")
	if is_instance_valid(jogador):
		chance_municao += float(jogador.get("chance_drop_municao"))
	var rolagem := randf()
	var tipo_drop := ""
	if rolagem < 0.10:
		tipo_drop = "medkit"
	elif rolagem < chance_municao:
		tipo_drop = "ammo"
	if not tipo_drop.is_empty() and get_tree().current_scene.has_method("criar_drop"):
		get_tree().current_scene.call("criar_drop", global_position, tipo_drop)

func _animar_dano() -> void:
	if tween_dano and tween_dano.is_running():
		tween_dano.kill()
	tween_dano = create_tween().set_parallel(true)
	for indice in range(materiais.size()):
		tween_dano.tween_property(materiais[indice], "albedo_color", Color(1.0, 0.26, 0.18), 0.055)
		tween_dano.tween_property(materiais[indice], "albedo_color", cores_base[indice], 0.2).set_delay(0.055)

func _physics_process(delta: float) -> void:
	# Corredores perseguem, brutamontes pressionam e cuspidores mantêm distância.
	if morrendo:
		return
	ataque_restante = maxf(ataque_restante - delta, 0.0)
	lentidao_restante = maxf(lentidao_restante - delta, 0.0)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not is_instance_valid(alvo) or alvo.get("vida_atual") <= 0:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		move_and_slide()
		return

	var vetor_alvo := alvo.global_position - global_position
	var distancia := Vector2(vetor_alvo.x, vetor_alvo.z).length()
	var direcao := Vector3(vetor_alvo.x, 0.0, vetor_alvo.z).normalized()
	var fator_lento := 0.5 if lentidao_restante > 0.0 else 1.0
	if tipo == "cuspidor":
		if distancia > 10.0:
			velocity.x = move_toward(velocity.x, direcao.x * velocidade * fator_lento, delta * 8.0)
			velocity.z = move_toward(velocity.z, direcao.z * velocidade * fator_lento, delta * 8.0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
			if distancia <= 15.0 and ataque_restante <= 0.0:
				_cuspir_acido()
				ataque_restante = intervalo_ataque
	else:
		direcao = _direcao_com_separacao(direcao)
		velocity.x = move_toward(velocity.x, direcao.x * velocidade * fator_lento, delta * 9.0)
		velocity.z = move_toward(velocity.z, direcao.z * velocidade * fator_lento, delta * 9.0)
		if distancia <= alcance and ataque_restante <= 0.0 and alvo.has_method("receber_dano"):
			alvo.receber_dano(dano)
			ataque_restante = intervalo_ataque

	if direcao.length_squared() > 0.01:
		look_at(Vector3(alvo.global_position.x, global_position.y, alvo.global_position.z), Vector3.UP)
	move_and_slide()

func _direcao_com_separacao(direcao_alvo: Vector3) -> Vector3:
	var repulsao := Vector3.ZERO
	for outro in get_tree().get_nodes_in_group("inimigos"):
		if outro == self or not outro is Node3D:
			continue
		var outro_node: Node3D = outro as Node3D
		var afastamento: Vector3 = global_position - outro_node.global_position
		afastamento.y = 0.0
		var distancia := afastamento.length()
		if distancia > 0.001 and distancia < 1.45:
			repulsao += afastamento.normalized() * (1.45 - distancia)
	if repulsao.length_squared() > 0.0:
		return (direcao_alvo + repulsao * 1.2).normalized()
	return direcao_alvo

func _cuspir_acido() -> void:
	if not is_instance_valid(alvo):
		return
	var projetil := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.2
	esfera.height = 0.4
	projetil.mesh = esfera
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8eff58")
	material.emission_enabled = true
	material.emission = Color("4cff27")
	material.emission_energy_multiplier = 1.4
	projetil.material_override = material
	get_tree().current_scene.add_child(projetil)
	projetil.global_position = global_position + Vector3(0.0, 2.15, 0.0)
	var destino := alvo.global_position + Vector3(0.0, 1.0, 0.0)
	var tween := projetil.create_tween()
	tween.tween_property(projetil, "global_position", destino, 0.5)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(projetil):
			return
		projetil.queue_free()
		if is_instance_valid(alvo) and alvo.global_position.distance_to(destino) <= 1.4 and alvo.has_method("receber_dano"):
			alvo.receber_dano(dano)
	)
