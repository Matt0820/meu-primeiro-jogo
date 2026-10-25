extends CharacterBody3D

# Controla movimento em primeira pessoa, arma, vida e efeitos permanentes da run.
# A interface é acessada pelo caminho player/Aim/HUD, definido em world.tscn.
const VELOCIDADE_BASE := 8.0
const JUMP_VELOCITY := 6.5
const SENSIBILITY := 0.003
const VELOCIDADE_CORRIDA := 1.35
const DURACAO_SLIDE := 0.68
const RECARGA_SLIDE := 1.15
const VELOCIDADE_INICIAL_SLIDE := 13.5
const ALCANCE_FACA := 2.35
const DANO_FACA := 58
const INTERVALO_FACA := 0.48

@onready var camera: Camera3D = $player_camera
@onready var hud: Variant = $Aim/HUD
@onready var modelo_pistola: MeshInstance3D = $player_camera/MeshInstance3D

var vida_maxima := 100
var vida_atual := 100
var dano_arma := 50
var velocidade_maxima := VELOCIDADE_BASE
var capacidade_municao := 30
var municao_atual := 30
var municao_reserva := 90
var reserva_maxima := 150
var tempo_recarregar := 1.2
var dispersao_maxima_graus := 7.0
var melhorias_instaladas := 0
var recarregando := false
var dispersao_atual := 0.0
var intervalo_dano_restante := 0.0
var reducao_dano := 0.0
var multiplicador_dano_recebido := 1.0
var cura_por_abate := 0
var chance_drop_municao := 0.0
var phoenix_disponivel := false
var arma_atual := "pistola"
var tempo_ataque_faca := 0.0
var tempo_slide_restante := 0.0
var recarga_slide_restante := 0.0
var direcao_slide := Vector3.ZERO
var alvos_atingidos_no_slide: Array[int] = []
var altura_camera_base := 0.0
var modelo_faca: Node3D

func _ready() -> void:
	# A captura fica para o botão Iniciar; no menu principal o cursor permanece livre.
	if get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	altura_camera_base = camera.position.y
	_criar_modelo_faca()
	hud.atualizar(vida_atual, vida_maxima, municao_atual, capacidade_municao, dispersao_atual, municao_reserva)
	hud.atualizar_arma("PISTOLA", "1 PISTOLA  //  2 FACA  //  Q ALTERNAR")

# Entradas de mira, tiro e recarga. O HUD usa _input para capturar ESC antes daqui.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSIBILITY)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_disparar_tiro()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_recarregar()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1:
		_trocar_arma("pistola")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2:
		_trocar_arma("faca")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		_trocar_arma("faca" if arma_atual == "pistola" else "pistola")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_iniciar_slide()

# Dispara um raio com dispersão calculada a partir do movimento atual.
func _disparar_tiro() -> void:
	if arma_atual == "faca":
		_atacar_com_faca()
		return
	if recarregando:
		return
	if municao_atual <= 0:
		_recarregar()
		return

	municao_atual -= 1
	var velocidade := Vector2(velocity.x, velocity.z).length()
	var fator_movimento := clampf(velocidade / velocidade_maxima, 0.0, 1.0)
	# A dispersão aumenta com o movimento e diminui gradualmente ao parar.
	dispersao_atual = lerpf(dispersao_atual, dispersao_maxima_graus * fator_movimento, 0.45)
	var direcao := _direcao_com_dispersao(dispersao_atual)
	var inicio := camera.global_position
	var consulta := PhysicsRayQueryParameters3D.create(inicio, inicio + direcao * 50.0)
	consulta.exclude = [get_rid()]
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	var tipo_acerto := "normal"
	if not resultado.is_empty():
		var alvo: Object = resultado.collider
		if alvo.has_method("receber_tiro"):
			tipo_acerto = alvo.receber_tiro(dano_arma, resultado.position, resultado.shape)
		elif alvo.has_method("receber_dano"):
			alvo.receber_dano(dano_arma)
	if not resultado.is_empty():
		hud.mostrar_acerto(tipo_acerto)
	_atualizar_hud()

# Gera um vetor aleatório dentro do cone de precisão da arma.
func _direcao_com_dispersao(angulo_graus: float) -> Vector3:
	var camera_basis := camera.global_transform.basis
	var frente := -camera_basis.z
	if angulo_graus <= 0.01:
		return frente.normalized()
	var raio := tan(deg_to_rad(angulo_graus)) * sqrt(randf())
	var rotacao := randf() * TAU
	var deslocamento := camera_basis.x * cos(rotacao) * raio + camera_basis.y * sin(rotacao) * raio
	return (frente + deslocamento).normalized()

# Recarrega o pente e atualiza os indicadores de munição do HUD.
func _recarregar() -> void:
	if arma_atual == "faca":
		return
	if recarregando or municao_atual >= capacidade_municao:
		return
	if municao_reserva <= 0:
		hud.mostrar_mensagem("SEM MUNICAO NA RESERVA")
		return
	recarregando = true
	hud.mostrar_mensagem("RECARREGANDO...")
	await get_tree().create_timer(tempo_recarregar, false).timeout
	var espaco_no_pente := capacidade_municao - municao_atual
	var transferida := mini(espaco_no_pente, municao_reserva)
	municao_atual += transferida
	municao_reserva -= transferida
	recarregando = false
	_atualizar_hud()

# Aplica dano recebido, mitigação, invulnerabilidade curta e a segunda chance.
func receber_dano(quantidade: int) -> void:
	if vida_atual <= 0 or intervalo_dano_restante > 0.0:
		return
	var dano_efetivo := maxi(roundi(quantidade * multiplicador_dano_recebido * (1.0 - reducao_dano)), 1)
	vida_atual = maxi(vida_atual - dano_efetivo, 0)
	if vida_atual == 0 and phoenix_disponivel:
		phoenix_disponivel = false
		vida_atual = mini(35, vida_maxima)
		hud.mostrar_mensagem("PROTOCOLO PHOENIX ATIVADO")
	intervalo_dano_restante = 0.65
	_atualizar_hud()
	hud.animar_dano_jogador()
	hud.mostrar_mensagem("DANO RECEBIDO")
	if vida_atual == 0:
		hud.mostrar_mensagem("VOCÊ FOI DERROTADO")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_physics_process(false)
		set_process_unhandled_input(false)

# Física do jogador: gravidade, pulo, WASD e dispersão dependente da velocidade.
func _physics_process(delta: float) -> void:
	intervalo_dano_restante = maxf(intervalo_dano_restante - delta, 0.0)
	tempo_ataque_faca = maxf(tempo_ataque_faca - delta, 0.0)
	recarga_slide_restante = maxf(recarga_slide_restante - delta, 0.0)
	if tempo_slide_restante > 0.0:
		tempo_slide_restante = maxf(tempo_slide_restante - delta, 0.0)
		velocity.x = move_toward(velocity.x, direcao_slide.x * VELOCIDADE_INICIAL_SLIDE * 0.48, delta * 15.0)
		velocity.z = move_toward(velocity.z, direcao_slide.z * VELOCIDADE_INICIAL_SLIDE * 0.48, delta * 15.0)
	else:
		if camera.position.y < altura_camera_base:
			camera.position.y = move_toward(camera.position.y, altura_camera_base, delta * 2.6)
	var fov_alvo := 88.0 if tempo_slide_restante > 0.0 else (82.0 if Input.is_action_pressed("shift") else 75.0)
	camera.fov = move_toward(camera.fov, fov_alvo, delta * 70.0)
	if not is_on_floor():
		velocity += get_gravity() * (delta * 1.6)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("keyboard_A", "keyboard_D", "keyboard_W", "keyboard_S")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if tempo_slide_restante <= 0.0:
		var multiplicador_corrida := VELOCIDADE_CORRIDA if Input.is_action_pressed("shift") else 1.0
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * velocidade_maxima * multiplicador_corrida, delta * 25.0)
			velocity.z = move_toward(velocity.z, direction.z * velocidade_maxima * multiplicador_corrida, delta * 25.0)
		else:
			velocity.x = move_toward(velocity.x, 0, delta * 20.0)
			velocity.z = move_toward(velocity.z, 0, delta * 20.0)
	move_and_slide()
	if tempo_slide_restante > 0.0:
		_processar_impactos_slide()
	var velocidade := Vector2(velocity.x, velocity.z).length()
	var alvo_dispersao := dispersao_maxima_graus * clampf(velocidade / velocidade_maxima, 0.0, 1.0)
	dispersao_atual = move_toward(dispersao_atual, alvo_dispersao, delta * 5.0)
	hud.atualizar(vida_atual, vida_maxima, municao_atual, capacidade_municao, dispersao_atual, municao_reserva)
	hud.atualizar_movimento(tempo_slide_restante, recarga_slide_restante, Input.is_action_pressed("shift"))

# Alterna entre a pistola e a faca e atualiza a indicação da arma na HUD.
func _trocar_arma(nova_arma: String) -> void:
	if arma_atual == nova_arma:
		return
	arma_atual = nova_arma
	modelo_pistola.visible = arma_atual == "pistola"
	modelo_faca.visible = arma_atual == "faca"
	var nome := "PISTOLA" if arma_atual == "pistola" else "FACA"
	hud.atualizar_arma(nome, "1 PISTOLA  //  2 FACA  //  Q ALTERNAR")
	hud.mostrar_mensagem("ARMA EQUIPADA  //  " + nome)

# Monta um modelo simples de faca no espaço da câmera para a arma ter presença visual.
func _criar_modelo_faca() -> void:
	modelo_faca = Node3D.new()
	modelo_faca.name = "ModeloFaca"
	modelo_faca.position = Vector3(0.58, -0.48, -0.62)
	modelo_faca.visible = false
	camera.add_child(modelo_faca)
	var lamina := MeshInstance3D.new()
	var malha_lamina := BoxMesh.new()
	malha_lamina.size = Vector3(0.12, 0.055, 0.62)
	lamina.mesh = malha_lamina
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("b9d1cf")
	metal.metallic = 0.72
	metal.roughness = 0.24
	lamina.material_override = metal
	lamina.position.z = -0.28
	modelo_faca.add_child(lamina)
	var cabo := MeshInstance3D.new()
	var malha_cabo := BoxMesh.new()
	malha_cabo.size = Vector3(0.16, 0.09, 0.28)
	cabo.mesh = malha_cabo
	var material_cabo := StandardMaterial3D.new()
	material_cabo.albedo_color = Color("49382e")
	material_cabo.roughness = 0.88
	cabo.material_override = material_cabo
	cabo.position.z = 0.16
	modelo_faca.add_child(cabo)

# A faca não consome munição, mas exige curta distância e tem cadência própria.
func _atacar_com_faca() -> void:
	if tempo_ataque_faca > 0.0:
		return
	tempo_ataque_faca = INTERVALO_FACA
	hud.animar_corte_faca()
	var inicio := camera.global_position
	var fim := inicio + (-camera.global_transform.basis.z) * ALCANCE_FACA
	var consulta := PhysicsRayQueryParameters3D.create(inicio, fim)
	consulta.exclude = [get_rid()]
	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)
	if resultado.is_empty():
		return
	var alvo: Object = resultado.collider
	if alvo.has_method("receber_tiro"):
		var tipo_acerto: String = alvo.receber_tiro(DANO_FACA, resultado.position, resultado.shape)
		hud.mostrar_acerto(tipo_acerto)
	elif alvo.has_method("receber_dano"):
		alvo.receber_dano(DANO_FACA)
		hud.mostrar_acerto()

# Inicia o slide ao correr em movimento; o cooldown impede uso contínuo.
func _iniciar_slide() -> void:
	if not is_on_floor() or recarga_slide_restante > 0.0 or tempo_slide_restante > 0.0:
		return
	if not Input.is_action_pressed("shift"):
		hud.mostrar_mensagem("CORRA COM SHIFT PARA DESLIZAR")
		return
	var movimento := Vector3(velocity.x, 0.0, velocity.z)
	if movimento.length() < velocidade_maxima * 0.55:
		return
	direcao_slide = movimento.normalized()
	velocity.x = direcao_slide.x * VELOCIDADE_INICIAL_SLIDE
	velocity.z = direcao_slide.z * VELOCIDADE_INICIAL_SLIDE
	tempo_slide_restante = DURACAO_SLIDE
	recarga_slide_restante = RECARGA_SLIDE
	alvos_atingidos_no_slide.clear()
	camera.position.y = altura_camera_base - 0.52
	hud.mostrar_mensagem("SLIDE  //  IMPACTE ZUMBIS PARA ABRIR CAMINHO")

# O impacto do slide atinge cada zumbi no máximo uma vez por deslize.
func _processar_impactos_slide() -> void:
	for indice in range(get_slide_collision_count()):
		var colisao := get_slide_collision(indice)
		var alvo := colisao.get_collider() as Node
		if not is_instance_valid(alvo) or not alvo.has_method("receber_dano"):
			continue
		var id_alvo := alvo.get_instance_id()
		if alvos_atingidos_no_slide.has(id_alvo):
			continue
		alvos_atingidos_no_slide.append(id_alvo)
		alvo.call("receber_dano", 32)
		hud.mostrar_mensagem("IMPACTO DE SLIDE  //  32 DANO")

# Atualiza os indicadores de vida, munição e mira sem expor a lógica da HUD.
func _atualizar_hud() -> void:
	hud.atualizar(vida_atual, vida_maxima, municao_atual, capacidade_municao, dispersao_atual, municao_reserva)

# Mantém a munição entre ondas; apenas atualiza a HUD, sem recarga grátis.
func preparar_proxima_onda() -> void:
	_atualizar_hud()

# Métodos chamados pelos itens coletáveis para alterar vida e munição.
func curar(quantidade: int) -> void:
	if vida_atual <= 0:
		return
	var anterior := vida_atual
	vida_atual = mini(vida_atual + quantidade, vida_maxima)
	if vida_atual > anterior:
		_atualizar_hud()
		hud.mostrar_mensagem("KIT MEDICO  +%d VIDA" % (vida_atual - anterior))

func receber_municao(quantidade: int) -> void:
	var anterior := municao_reserva
	municao_reserva = mini(municao_reserva + quantidade, reserva_maxima)
	if municao_reserva > anterior:
		_atualizar_hud()
		hud.mostrar_mensagem("RESERVA DE MUNICAO  +%d" % (municao_reserva - anterior))

# Cura passiva do sifão vital, acionada pelo zumbi ao morrer.
func ao_abater_zumbi() -> void:
	if cura_por_abate > 0 and vida_atual > 0:
		vida_atual = mini(vida_atual + cura_por_abate, vida_maxima)
		_atualizar_hud()

# Aplica o efeito da melhoria escolhida e registra o módulo no HUD.
func aplicar_melhoria(id: String) -> void:
	var nome_modulo := ""
	match id:
		"calibre":
			dano_arma += 15
			dispersao_maxima_graus += 1.0
			nome_modulo = "CALIBRE MAGNUM"
		"tambor":
			reserva_maxima += 30
			municao_reserva = mini(municao_reserva + 30, reserva_maxima)
			tempo_recarregar += 0.2
			nome_modulo = "TAMBOR ESTENDIDO"
		"botas":
			velocidade_maxima += 1.0
			dispersao_maxima_graus += 1.5
			nome_modulo = "ESTIMULANTES"
		"colete":
			vida_maxima += 25
			vida_atual = mini(vida_atual + 25, vida_maxima)
			velocidade_maxima = maxf(velocidade_maxima - 0.6, 5.0)
			nome_modulo = "COLETE REFORCADO"
		"estabilizador":
			dispersao_maxima_graus = maxf(dispersao_maxima_graus * 0.72, 1.5)
			velocidade_maxima = maxf(velocidade_maxima - 0.5, 5.0)
			nome_modulo = "EMPUNHADURA FIRME"
		"recarga":
			tempo_recarregar = maxf(tempo_recarregar * 0.72, 0.45)
			reserva_maxima = maxi(reserva_maxima - 20, 40)
			municao_reserva = mini(municao_reserva, reserva_maxima)
			nome_modulo = "MECANISMO RAPIDO"
		"municao_perfurante":
			dano_arma = roundi(dano_arma * 1.22)
			reserva_maxima = maxi(reserva_maxima - 20, 40)
			municao_reserva = mini(municao_reserva, reserva_maxima)
			nome_modulo = "PONTA PERFURANTE"
		"adrenalina":
			velocidade_maxima *= 1.18
			vida_maxima = maxi(vida_maxima - 10, 40)
			vida_atual = mini(vida_atual + 20, vida_maxima)
			nome_modulo = "ADRENALINA"
		"sifao":
			cura_por_abate = 3
			multiplicador_dano_recebido = maxf(multiplicador_dano_recebido, 1.12)
			nome_modulo = "SIFAO VITAL"
		"ricochete":
			dano_arma = roundi(dano_arma * 1.35)
			dispersao_maxima_graus += 3.0
			nome_modulo = "NUCLEO DE RICOCHETE"
		"sobrecarrega":
			dano_arma = roundi(dano_arma * 1.55)
			velocidade_maxima *= 1.25
			vida_maxima = maxi(vida_maxima - 30, 35)
			vida_atual = mini(vida_atual, vida_maxima)
			nome_modulo = "REATOR INSTAVEL"
		"segunda_chance":
			phoenix_disponivel = true
			velocidade_maxima *= 0.9
			nome_modulo = "PROTOCOLO PHOENIX"
		"mira_laser":
			dispersao_maxima_graus = maxf(dispersao_maxima_graus * 0.55, 0.8)
			tempo_recarregar *= 1.15
			nome_modulo = "MIRA LASER"
		"casca":
			reducao_dano = minf(reducao_dano + 0.18, 0.45)
			velocidade_maxima = maxf(velocidade_maxima - 0.8, 4.5)
			nome_modulo = "CASCA REFORCADA"
		"catador":
			chance_drop_municao = minf(chance_drop_municao + 0.2, 0.6)
			dano_arma = maxi(dano_arma - 4, 15)
			nome_modulo = "INSTINTO DE CATADOR"
		"sangue_quente":
			vida_maxima += 30
			vida_atual = mini(vida_atual, vida_maxima)
			dispersao_maxima_graus += 2.0
			nome_modulo = "SANGUE QUENTE"
		"gatilho":
			tempo_recarregar = maxf(tempo_recarregar * 0.8, 0.4)
			dano_arma = maxi(roundi(dano_arma * 0.9), 15)
			nome_modulo = "GATILHO LEVE"
	municao_atual = mini(municao_atual, capacidade_municao)
	melhorias_instaladas += 1
	hud.atualizar_modulos(melhorias_instaladas)
	_atualizar_hud()
	hud.mostrar_mensagem("MODULO INSTALADO  //  " + nome_modulo)
