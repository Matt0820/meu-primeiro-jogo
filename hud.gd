extends Control

# Toda a interface é construída neste script para permitir redesenhar sem mexer na lógica da partida.
# As âncoras e offsets em _criar_hud() definem a posição dos indicadores nos cantos da tela.
signal melhoria_escolhida(indice: int)
signal jogo_iniciado

var vida_barra: ProgressBar
var vida_texto: Label
var municao_texto: Label
var reserva_texto: Label
var municao_atual_hud := 30
var municao_maxima_hud := 30
var municao_reserva_hud := 90
var arma_texto: Label
var arma_dica_texto: Label
var movimento_texto: Label
var dispersao_texto: Label
var mensagem: Label
var dispersao_mira := 0.0
var tempo_marcador_acerto := 0.0
var tipo_marcador_acerto := "normal"
var sobreposicao_dano: ColorRect
var tween_dano: Tween
var ameacas_texto: Label
var tempo_atualizacao_ameacas := 0.0
var onda_texto: Label
var modulos_texto: Label
var total_onda := 0
var menu_melhoria: Control
var mensagem_restante := 0.0
var fim_de_jogo := false
var tempo_corte_faca := 0.0
var menu_atual: Control
var menu_pausado := false
var configuracoes_abertas := false
var menu_de_melhoria_aberto := false
var origem_configuracao := "inicio"
var resolucao_opcoes: OptionButton
var tela_cheia_opcao: CheckButton

# Paleta da interface: altere estas cores para redesenhar rapidamente a identidade visual.
const COR_FUNDO_MENU := Color(0.018, 0.035, 0.04, 0.94)
const COR_DESTAQUE := Color("75d6ad")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_criar_hud()
	_criar_menu_inicial()
	queue_redraw()

# O HUD continua processando entradas e botões quando o jogo está pausado.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if fim_de_jogo or menu_de_melhoria_aberto:
			return
		if is_instance_valid(menu_atual):
			if configuracoes_abertas:
				_voltar_das_configuracoes()
			elif menu_pausado:
				_fechar_menu_pausa()
			return
		if menu_pausado:
			_fechar_menu_pausa()
		else:
			_abrir_menu_pausa()

func _process(delta: float) -> void:
	if mensagem_restante > 0.0:
		mensagem_restante = maxf(mensagem_restante - delta, 0.0)
	tempo_atualizacao_ameacas -= delta
	if tempo_atualizacao_ameacas <= 0.0:
		_atualizar_ameacas()
		tempo_atualizacao_ameacas = 0.25
	if tempo_marcador_acerto > 0.0:
		tempo_marcador_acerto = maxf(tempo_marcador_acerto - delta, 0.0)
		queue_redraw()
	if tempo_corte_faca > 0.0:
		tempo_corte_faca = maxf(tempo_corte_faca - delta, 0.0)
		queue_redraw()

func _criar_hud() -> void:
	# Camada de tela cheia para o flash vermelho recebido ao tomar dano.
	sobreposicao_dano = ColorRect.new()
	sobreposicao_dano.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sobreposicao_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sobreposicao_dano.color = Color(0.8, 0.015, 0.025, 0.0)
	add_child(sobreposicao_dano)

	# Retrato e vida no canto superior esquerdo; esta seção é o principal ponto para redesenhar vida.
	var retrato := PanelContainer.new()
	retrato.anchor_left = 0.0
	retrato.anchor_top = 0.0
	retrato.anchor_bottom = 0.0
	retrato.offset_left = 24
	retrato.offset_top = 24
	retrato.offset_right = 104
	retrato.offset_bottom = 112
	_estilizar_painel(retrato)
	add_child(retrato)
	var iniciais := Label.new()
	iniciais.text = "P\nRETRATO"
	iniciais.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iniciais.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	iniciais.add_theme_color_override("font_color", Color("a9c8c8"))
	retrato.add_child(iniciais)

	var vida_painel := PanelContainer.new()
	vida_painel.anchor_left = 0.0
	vida_painel.anchor_top = 0.0
	vida_painel.anchor_bottom = 0.0
	vida_painel.offset_left = 120
	vida_painel.offset_top = 24
	vida_painel.offset_right = 352
	vida_painel.offset_bottom = 112
	_estilizar_painel(vida_painel)
	add_child(vida_painel)
	var vida_layout := VBoxContainer.new()
	vida_layout.add_theme_constant_override("separation", 6)
	vida_painel.add_child(vida_layout)
	vida_texto = _criar_label("INTEGRIDADE  100 / 100", 15)
	vida_layout.add_child(vida_texto)
	vida_barra = ProgressBar.new()
	vida_barra.custom_minimum_size = Vector2(200, 18)
	vida_barra.show_percentage = false
	vida_barra.max_value = 100
	vida_barra.value = 100
	vida_barra.add_theme_stylebox_override("background", _caixa(Color("202b31")))
	vida_barra.add_theme_stylebox_override("fill", _caixa(Color("75d6ad")))
	vida_layout.add_child(vida_barra)

	# Estado da onda, ameaças e melhorias no canto superior direito.
	var setor_painel := PanelContainer.new()
	setor_painel.anchor_left = 1.0
	setor_painel.anchor_top = 0.0
	setor_painel.anchor_right = 1.0
	setor_painel.anchor_bottom = 0.0
	setor_painel.offset_left = -268
	setor_painel.offset_top = 24
	setor_painel.offset_right = -24
	setor_painel.offset_bottom = 116
	_estilizar_painel(setor_painel)
	add_child(setor_painel)
	var setor_layout := VBoxContainer.new()
	setor_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	setor_layout.add_theme_constant_override("separation", 5)
	setor_painel.add_child(setor_layout)
	onda_texto = _criar_label("RONDA 00  //  HORDAS", 13)
	onda_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	setor_layout.add_child(onda_texto)
	ameacas_texto = _criar_label("AMEACAS: --", 16)
	ameacas_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ameacas_texto.add_theme_color_override("font_color", Color("f2aa72"))
	setor_layout.add_child(ameacas_texto)
	modulos_texto = _criar_label("MODULOS: 00", 11)
	modulos_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	modulos_texto.add_theme_color_override("font_color", Color("a9c8c8"))
	setor_layout.add_child(modulos_texto)

	# Munição e precisão no canto inferior direito.
	var municao_painel := PanelContainer.new()
	municao_painel.anchor_left = 1.0
	municao_painel.anchor_top = 1.0
	municao_painel.anchor_right = 1.0
	municao_painel.anchor_bottom = 1.0
	municao_painel.offset_left = -268
	municao_painel.offset_top = -136
	municao_painel.offset_right = -24
	municao_painel.offset_bottom = -24
	_estilizar_painel(municao_painel)
	add_child(municao_painel)
	var municao_layout := VBoxContainer.new()
	municao_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	municao_layout.add_theme_constant_override("separation", 5)
	municao_painel.add_child(municao_layout)
	arma_texto = _criar_label("ARMA  //  PISTOLA", 12)
	municao_layout.add_child(arma_texto)
	municao_texto = _criar_label("PENTE  30 / 30", 17)
	municao_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	municao_layout.add_child(municao_texto)
	reserva_texto = _criar_label("RESERVA  090", 13)
	reserva_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reserva_texto.add_theme_color_override("font_color", Color("f4c76b"))
	municao_layout.add_child(reserva_texto)
	dispersao_texto = _criar_label("PRECISAO  PARADO", 12)
	dispersao_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dispersao_texto.add_theme_color_override("font_color", Color("a9c8c8"))
	municao_layout.add_child(dispersao_texto)
	arma_dica_texto = _criar_label("1 PISTOLA  //  2 FACA  //  Q ALTERNAR", 9)
	arma_dica_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	municao_layout.add_child(arma_dica_texto)

	mensagem = _criar_label("", 18)
	mensagem.anchor_left = 0.5
	mensagem.anchor_top = 0.18
	mensagem.anchor_right = 0.5
	mensagem.offset_left = -180
	mensagem.offset_right = 180
	mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(mensagem)
	movimento_texto = _criar_label("SHIFT CORRER  //  C SLIDE", 11)
	movimento_texto.anchor_left = 0.0
	movimento_texto.anchor_top = 1.0
	movimento_texto.anchor_bottom = 1.0
	movimento_texto.offset_left = 28
	movimento_texto.offset_top = -45
	movimento_texto.offset_bottom = -24
	movimento_texto.add_theme_color_override("font_color", Color("a9c8c8"))
	add_child(movimento_texto)

# Atualiza os valores visuais sem reconstruir os controles da HUD.
func atualizar(vida: int, vida_maxima: int, municao: int, municao_maxima: int, dispersao: float, reserva: int) -> void:
	if not is_node_ready():
		return
	municao_atual_hud = municao
	municao_maxima_hud = municao_maxima
	municao_reserva_hud = reserva
	vida_barra.max_value = vida_maxima
	vida_barra.value = vida
	vida_barra.add_theme_stylebox_override("fill", _caixa(Color("e56b6f") if vida <= vida_maxima * 0.3 else Color("75d6ad")))
	vida_texto.text = "INTEGRIDADE  %d / %d" % [vida, vida_maxima]
	if is_instance_valid(arma_texto) and arma_texto.text.ends_with("FACA"):
		municao_texto.text = "FACA  //  SEM PENTE"
	else:
		municao_texto.text = "PENTE  %02d / %02d" % [municao, municao_maxima]
	reserva_texto.text = "RESERVA  %03d" % reserva
	if dispersao < 0.35:
		dispersao_texto.text = "PRECISAO  PARADO"
	else:
		dispersao_texto.text = "DISPERSAO  %.1f DEG" % dispersao
	if fim_de_jogo:
		return
	if municao == 0 and (not is_instance_valid(arma_texto) or not arma_texto.text.ends_with("FACA")):
		mensagem.text = "SEM MUNICAO" if reserva <= 0 else "PENTE VAZIO  -  PRESSIONE R"
		mensagem_restante = 0.0
	elif mensagem_restante <= 0.0:
		mensagem.text = ""
	dispersao_mira = dispersao
	queue_redraw()

# Atualiza arma e atalhos na HUD sem reconstruir o painel de munição.
func atualizar_arma(nome: String, dica: String) -> void:
	if not is_node_ready():
		return
	arma_texto.text = "ARMA  //  " + nome
	arma_dica_texto.text = dica
	if nome == "FACA":
		municao_texto.text = "FACA  //  SEM PENTE"
	else:
		municao_texto.text = "PENTE  %02d / %02d" % [municao_atual_hud, municao_maxima_hud]
	reserva_texto.text = "RESERVA  %03d" % municao_reserva_hud

# Informa corrida, disponibilidade do slide e o tempo restante do cooldown.
func atualizar_movimento(slide_restante: float, recarga_slide: float, correndo: bool) -> void:
	if not movimento_texto:
		return
	if slide_restante > 0.0:
		movimento_texto.text = "SLIDE ATIVO  //  IMPACTO PRONTO"
		movimento_texto.add_theme_color_override("font_color", Color("f4c76b"))
	elif correndo:
		var estado := "PRONTO" if recarga_slide <= 0.0 else "%.1f s" % recarga_slide
		movimento_texto.text = "CORRENDO  //  SLIDE " + estado
		movimento_texto.add_theme_color_override("font_color", Color("75d6ad"))
	else:
		movimento_texto.text = "SHIFT CORRER  //  C SLIDE"
		movimento_texto.add_theme_color_override("font_color", Color("a9c8c8"))

# Aciona o feedback visual do golpe de faca desenhado sobre o retículo.
func animar_corte_faca() -> void:
	tempo_corte_faca = 0.2
	queue_redraw()

# Lê o grupo de inimigos da cena e atualiza o contador no canto superior direito.
func _atualizar_ameacas() -> void:
	if not ameacas_texto:
		return
	var quantidade := get_tree().get_nodes_in_group("inimigos").size()
	if quantidade > 0:
		ameacas_texto.text = "AMEACAS: %02d  /  %02d" % [quantidade, total_onda]
		ameacas_texto.add_theme_color_override("font_color", Color("f2aa72"))
	else:
		ameacas_texto.text = "SETOR CONTROLADO"
		ameacas_texto.add_theme_color_override("font_color", Color("75d6ad"))

func atualizar_onda(numero: int, total: int) -> void:
	total_onda = total
	if onda_texto:
		onda_texto.text = "RONDA %02d  //  HORDA" % numero
	_atualizar_ameacas()

func atualizar_modulos(quantidade: int) -> void:
	if modulos_texto:
		modulos_texto.text = "MODULOS INSTALADOS: %02d" % quantidade

# Pausa a run e cria três cartões clicáveis para escolher o próximo módulo.
func abrir_melhorias(opcoes: Array[Dictionary], numero_onda: int) -> void:
	menu_de_melhoria_aberto = true
	menu_melhoria = Control.new()
	menu_melhoria.name = "MenuMelhorias"
	menu_melhoria.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_melhoria.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_melhoria.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_melhoria)
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.012, 0.025, 0.028, 0.88)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_melhoria.add_child(fundo)
	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_top = 0.5
	painel.anchor_right = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -405
	painel.offset_top = -190
	painel.offset_right = 405
	painel.offset_bottom = 190
	_estilizar_painel(painel)
	menu_melhoria.add_child(painel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	painel.add_child(layout)
	var titulo := _criar_label("INTERVALO DE COMBATE  //  RONDA %02d" % numero_onda, 21)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(titulo)
	var subtitulo := _criar_label("Escolha um modulo. Todo reforco cobra seu preco.", 14)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_color_override("font_color", Color("a9c8c8"))
	layout.add_child(subtitulo)
	var cartoes := HBoxContainer.new()
	cartoes.alignment = BoxContainer.ALIGNMENT_CENTER
	cartoes.add_theme_constant_override("separation", 12)
	layout.add_child(cartoes)
	for indice in range(opcoes.size()):
		var opcao: Dictionary = opcoes[indice]
		var botao := Button.new()
		botao.custom_minimum_size = Vector2(240, 245)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.text = "%s  //  %s\n\n%s\n\n[ INSTALAR ]" % [str(opcao.get("raridade", "Comum")).to_upper(), opcao.titulo, opcao.descricao]
		botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
		botao.add_theme_font_size_override("font_size", 14)
		botao.add_theme_color_override("font_color", Color("edf6f2"))
		var cor_raridade := _cor_raridade(str(opcao.get("raridade", "Comum")))
		botao.add_theme_color_override("font_hover_color", cor_raridade.lightened(0.3))
		_estilizar_cartao_melhoria(botao, cor_raridade)
		botao.pressed.connect(_selecionar_melhoria.bind(indice))
		cartoes.add_child(botao)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _selecionar_melhoria(indice: int) -> void:
	menu_de_melhoria_aberto = false
	if is_instance_valid(menu_melhoria):
		menu_melhoria.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	melhoria_escolhida.emit(indice)

# Monta o menu principal por código para manter todos os elementos editáveis no projeto.
func _criar_menu_inicial() -> void:
	get_tree().paused = true
	menu_pausado = false
	configuracoes_abertas = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layout := _criar_base_menu("ZONA MORTA", "SOBREVIVA ÀS HORDAS  //  ACESSO DE CAMPO")
	_criar_botao_menu(layout, "INICIAR RUN", _iniciar_partida)
	_criar_botao_menu(layout, "CONFIGURAÇÕES", func() -> void: _abrir_configuracoes("inicio"))
	_criar_botao_menu(layout, "SAIR", _sair_do_jogo)
	_adicionar_dica_menu(layout, "WASD mover  •  Shift correr  •  C slide  •  1/2 armas  •  Mouse mirar  •  R recarregar")

# Cria a camada e o painel central compartilhados pelos menus do jogo.
func _criar_base_menu(titulo_texto: String, subtitulo_texto: String) -> VBoxContainer:
	_limpar_menu_atual()
	menu_atual = Control.new()
	menu_atual.name = "MenuAtual"
	menu_atual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_atual.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_atual.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_atual)
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = COR_FUNDO_MENU
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_atual.add_child(fundo)
	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_top = 0.5
	painel.anchor_right = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -230
	painel.offset_top = -230
	painel.offset_right = 230
	painel.offset_bottom = 230
	_estilizar_painel(painel)
	menu_atual.add_child(painel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	painel.add_child(layout)
	var titulo := _criar_label(titulo_texto, 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	layout.add_child(titulo)
	var subtitulo := _criar_label(subtitulo_texto, 12)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.add_theme_color_override("font_color", Color("a9c8c8"))
	layout.add_child(subtitulo)
	var separador := HSeparator.new()
	separador.modulate = Color(0.45, 0.85, 0.75, 0.55)
	layout.add_child(separador)
	return layout

# Adiciona um botão consistente aos menus de início, pausa e configurações.
func _criar_botao_menu(layout: VBoxContainer, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(300, 48)
	botao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	botao.add_theme_font_size_override("font_size", 15)
	botao.add_theme_color_override("font_color", Color("edf6f2"))
	botao.add_theme_color_override("font_hover_color", COR_DESTAQUE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.09, 0.1, 0.45)
	normal.border_color = Color(0.42, 0.78, 0.7, 0.45)
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.36, 0.31, 0.7)
	hover.border_color = COR_DESTAQUE
	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", hover)
	botao.pressed.connect(acao)
	layout.add_child(botao)
	return botao

# Texto auxiliar para controles e atalhos sem criar mais um painel visual.
func _adicionar_dica_menu(layout: VBoxContainer, texto: String) -> void:
	var dica := _criar_label(texto, 11)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.add_theme_color_override("font_color", Color("91aaa8"))
	layout.add_child(dica)

# Inicia a run e libera o mouse para o controle de câmera.
func _iniciar_partida() -> void:
	menu_pausado = false
	configuracoes_abertas = false
	if is_instance_valid(menu_atual):
		menu_atual.queue_free()
	menu_atual = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	jogo_iniciado.emit()

# Abre a sobreposição de pausa sem interromper o processamento deste HUD.
func _abrir_menu_pausa() -> void:
	menu_pausado = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layout := _criar_base_menu("JOGO PAUSADO", "A EXPEDIÇÃO ESTÁ EM ESPERA")
	_criar_botao_menu(layout, "CONTINUAR", _fechar_menu_pausa)
	_criar_botao_menu(layout, "CONFIGURAÇÕES", func() -> void: _abrir_configuracoes("pausa"))
	_criar_botao_menu(layout, "VOLTAR AO INÍCIO", _voltar_ao_inicio)
	_criar_botao_menu(layout, "SAIR", _sair_do_jogo)
	_adicionar_dica_menu(layout, "Pressione ESC para continuar")

# Fecha a pausa e devolve a captura do mouse ao jogo.
func _fechar_menu_pausa() -> void:
	if not menu_pausado:
		return
	menu_pausado = false
	_limpar_menu_atual()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Mostra controles de resolução e modo de tela dentro do menu atual.
func _abrir_configuracoes(origem: String) -> void:
	origem_configuracao = origem
	configuracoes_abertas = true
	var layout := _criar_base_menu("CONFIGURAÇÕES", "VÍDEO  //  AJUSTE A EXIBIÇÃO")
	var label_resolucao := _criar_label("RESOLUÇÃO DA JANELA", 13)
	label_resolucao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(label_resolucao)
	resolucao_opcoes = OptionButton.new()
	resolucao_opcoes.custom_minimum_size = Vector2(280, 42)
	var resolucoes := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
	for resolucao in resolucoes:
		resolucao_opcoes.add_item("%d × %d" % [resolucao.x, resolucao.y])
		resolucao_opcoes.set_item_metadata(resolucao_opcoes.item_count - 1, resolucao)
	var tamanho_atual := get_window().size
	for indice in range(resolucao_opcoes.item_count):
		if resolucao_opcoes.get_item_metadata(indice) == tamanho_atual:
			resolucao_opcoes.select(indice)
	layout.add_child(resolucao_opcoes)
	tela_cheia_opcao = CheckButton.new()
	tela_cheia_opcao.text = "TELA CHEIA"
	tela_cheia_opcao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tela_cheia_opcao.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	layout.add_child(tela_cheia_opcao)
	_criar_botao_menu(layout, "APLICAR", _aplicar_configuracoes_video)
	_criar_botao_menu(layout, "VOLTAR", _voltar_das_configuracoes)
	_adicionar_dica_menu(layout, "A resolução selecionada é aplicada à janela do jogo.")

# Aplica a resolução escolhida e alterna entre janela e tela cheia.
func _aplicar_configuracoes_video() -> void:
	if tela_cheia_opcao.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if resolucao_opcoes.selected >= 0:
			var tamanho: Vector2i = resolucao_opcoes.get_item_metadata(resolucao_opcoes.selected)
			get_window().size = tamanho
			var tela := DisplayServer.window_get_current_screen()
			var origem_tela := DisplayServer.screen_get_position(tela)
			var tamanho_tela := DisplayServer.screen_get_size(tela)
			get_window().position = origem_tela + (tamanho_tela - tamanho) / 2
	_mostrar_confirmacao_temporaria()

# Informa a aplicação do vídeo sem trocar o menu de configurações.
func _mostrar_confirmacao_temporaria() -> void:
	var texto := _criar_label("CONFIGURAÇÃO APLICADA", 12)
	texto.name = "ConfirmacaoVideo"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_color_override("font_color", COR_DESTAQUE)
	var layout := resolucao_opcoes.get_parent() as VBoxContainer
	layout.add_child(texto)
	var tween := texto.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(texto, "modulate:a", 0.0, 0.35)
	tween.tween_callback(texto.queue_free)

# Retorna ao menu de onde as configurações foram abertas.
func _voltar_das_configuracoes() -> void:
	configuracoes_abertas = false
	if origem_configuracao == "pausa":
		_abrir_menu_pausa()
	else:
		_criar_menu_inicial()

# Remove a sobreposição atual com segurança antes de montar outra tela.
func _limpar_menu_atual() -> void:
	if is_instance_valid(menu_atual):
		menu_atual.queue_free()
	menu_atual = null

# Reinicia a cena e volta para o menu principal.
func _voltar_ao_inicio() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# Encerra o executável do jogo.
func _sair_do_jogo() -> void:
	get_tree().quit()

# Tela final com resumo da run e botão para iniciar outra expedição.
func mostrar_fim_de_jogo(numero_onda: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fim_de_jogo = true
	mensagem.text = "SINAL PERDIDO  //  VOCE ALCANCOU A RONDA %02d" % numero_onda
	mensagem.add_theme_color_override("font_color", Color("ff6d62"))
	var tela := Control.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.process_mode = Node.PROCESS_MODE_ALWAYS
	tela.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tela)
	var fundo := ColorRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.012, 0.018, 0.02, 0.78)
	tela.add_child(fundo)
	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_top = 0.5
	painel.anchor_right = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -220
	painel.offset_top = -115
	painel.offset_right = 220
	painel.offset_bottom = 115
	_estilizar_painel(painel)
	tela.add_child(painel)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	painel.add_child(layout)
	var titulo := _criar_label("FIM DA EXPEDICAO", 23)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color("ff766d"))
	layout.add_child(titulo)
	var resumo := _criar_label("Voce sobreviveu ate a ronda %02d." % numero_onda, 15)
	resumo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(resumo)
	var reiniciar := Button.new()
	reiniciar.text = "INICIAR NOVA RUN"
	reiniciar.custom_minimum_size = Vector2(240, 46)
	reiniciar.pressed.connect(_reiniciar_run)
	layout.add_child(reiniciar)

func _reiniciar_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func mostrar_acerto(tipo: String = "normal") -> void:
	tempo_marcador_acerto = 0.14
	tipo_marcador_acerto = tipo
	queue_redraw()

func animar_dano_jogador() -> void:
	if not is_node_ready():
		return
	if tween_dano and tween_dano.is_running():
		tween_dano.kill()
	sobreposicao_dano.color = Color(0.8, 0.015, 0.025, 0.0)
	tween_dano = create_tween()
	tween_dano.tween_property(sobreposicao_dano, "color", Color(0.8, 0.015, 0.025, 0.34), 0.07)
	tween_dano.tween_property(sobreposicao_dano, "color", Color(0.8, 0.015, 0.025, 0.0), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Desenha retículo, abertura de dispersão e marcador de acerto por cima da cena.
func _draw() -> void:
	var centro := size * 0.5
	var gap := 7.0 + dispersao_mira * 5.0
	var comprimento := 7.0
	var cor := Color(0.77, 0.96, 0.91, 0.95)
	var espessura := 2.0
	# Retículo de quatro segmentos: sua abertura mostra a dispersão atual da arma.
	draw_line(centro + Vector2(-gap - comprimento, 0), centro + Vector2(-gap, 0), cor, espessura, true)
	draw_line(centro + Vector2(gap, 0), centro + Vector2(gap + comprimento, 0), cor, espessura, true)
	draw_line(centro + Vector2(0, -gap - comprimento), centro + Vector2(0, -gap), cor, espessura, true)
	draw_line(centro + Vector2(0, gap), centro + Vector2(0, gap + comprimento), cor, espessura, true)
	draw_circle(centro, 1.5, cor)
	if tempo_corte_faca > 0.0:
		var alpha_corte := clampf(tempo_corte_faca / 0.2, 0.0, 1.0)
		var cor_corte := Color(0.65, 0.95, 1.0, alpha_corte)
		draw_line(centro + Vector2(-38, 28), centro + Vector2(34, -30), cor_corte, 3.0, true)
		draw_line(centro + Vector2(-30, 35), centro + Vector2(42, -23), Color(0.85, 1.0, 1.0, alpha_corte * 0.55), 1.5, true)
	if tempo_marcador_acerto > 0.0:
		var hit_cor := Color(1.0, 0.42, 0.35, 1.0)
		var texto_acerto := ""
		if tipo_marcador_acerto == "cabeca":
			hit_cor = Color(1.0, 0.78, 0.28, 1.0)
			texto_acerto = "CRITICO"
		elif tipo_marcador_acerto == "perna":
			hit_cor = Color(0.45, 0.88, 1.0, 1.0)
			texto_acerto = "LENTO"
		for sinal in [-1.0, 1.0]:
			draw_line(centro + Vector2(sinal * 5, -5), centro + Vector2(sinal * 10, -10), hit_cor, 2.0, true)
			draw_line(centro + Vector2(sinal * 5, 5), centro + Vector2(sinal * 10, 10), hit_cor, 2.0, true)
		if not texto_acerto.is_empty():
			draw_string(ThemeDB.fallback_font, centro + Vector2(-42, 31), texto_acerto, HORIZONTAL_ALIGNMENT_CENTER, 84, 13, hit_cor)

func mostrar_mensagem(texto: String) -> void:
	if is_node_ready():
		mensagem.text = texto
		mensagem_restante = 2.4

func _criar_label(texto: String, tamanho: int) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", Color("edf6f2"))
	return label

func _estilizar_painel(painel: PanelContainer) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.025, 0.055, 0.06, 0.42)
	estilo.border_color = Color(0.42, 0.78, 0.7, 0.38)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	painel.add_theme_stylebox_override("panel", estilo)

func _cor_raridade(raridade: String) -> Color:
	match raridade:
		"Incomum": return Color("79d99d")
		"Raro": return Color("66b9ff")
		"Epico": return Color("c38aff")
		"Lendario": return Color("ffc45e")
	return Color("c4d0cf")

func _estilizar_cartao_melhoria(botao: Button, cor: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.05, 0.06, 0.30)
	normal.border_color = Color(cor.r, cor.g, cor.b, 0.52)
	normal.set_border_width_all(1)
	normal.border_width_left = 3
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(cor.r, cor.g, cor.b, 0.14)
	hover.border_color = cor
	var pressionado := normal.duplicate() as StyleBoxFlat
	pressionado.bg_color = Color(cor.r, cor.g, cor.b, 0.24)
	botao.add_theme_stylebox_override("normal", normal)
	botao.add_theme_stylebox_override("hover", hover)
	botao.add_theme_stylebox_override("pressed", pressionado)

func _caixa(cor: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(5)
	return estilo
