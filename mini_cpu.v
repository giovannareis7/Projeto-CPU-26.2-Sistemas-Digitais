module mini_cpu(
    input       clock,
    input       [17:0] switches,
    input       enviar,
    input       ligar,
    output wire LCD_RS,
    output wire LCD_RW,
    output wire LCD_EN,
    output wire [7:0] LCD_DATA,
    output wire LCD_ON
);
	//Debounce do botao 
    wire ligar_limpo, enviar_limpo;
    debounce db_ligar  (.clock(clock), .entrada(ligar),  .saida(ligar_limpo));
    debounce db_enviar (.clock(clock), .entrada(enviar), .saida(enviar_limpo));

   //Detectar a borda
    reg ligar_ant = 1'b1;          
    always @(posedge clock) begin
			ligar_ant <= ligar_limpo;
    end

    //pulso de 1 ciclo quando o botão é SOLTO
    wire pulso_ligar = (ligar_ant == 1'b0) && (ligar_limpo == 1'b1);

    //Ligar e desligar
    reg ligado = 1'b0;
    always @(posedge clock) begin
        if (pulso_ligar) ligado <= ~ligado;
    end

    wire clear = ~ligado;     

    //para guardar as instrucoes, mesmo que comece a mudar os switches no processo
    reg [17:0] instrucoes;

    //Maquina de estados para o botao:
    parameter AGUARDAR = 0, PRESSIONADO = 1, CAPTURAR_INSTRUCAO = 2;
    reg [1:0] estado_atual = 0;
    reg [1:0] proximo_estado;

    //atualizar os estados
    always @(posedge clock) begin
        if(!ligado) estado_atual <= AGUARDAR;
        else estado_atual <= proximo_estado;
    end

    //transicao
    always @(*) begin
        proximo_estado = estado_atual; //se nao atribuir, ele pode guardar o estado anterior e interferir
        case(estado_atual)
            AGUARDAR: begin
                if(enviar_limpo == 0) proximo_estado = PRESSIONADO;
            end

            PRESSIONADO: begin
                if(enviar_limpo == 1) proximo_estado = CAPTURAR_INSTRUCAO;
            end

            CAPTURAR_INSTRUCAO: begin
                proximo_estado = AGUARDAR;
            end

            default: begin
                proximo_estado = AGUARDAR;
            end
        endcase
    end

    //capturar informacoes
	 reg validar = 1'b0;
    always @(posedge clock) begin
			validar <= 1'b0;
        if(!ligado) instrucoes <= 18'b0;
        else if(estado_atual == CAPTURAR_INSTRUCAO)begin
				instrucoes <= switches;
				validar <= 1'b1;
			end
    end   
	 
	 //opcode:
	 wire [2:0] opcode = instrucoes[17:15];
	 parameter LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4, MUL = 5, CLEAR = 6, DISPLAY = 7;
	 
	//separar os casos e declarar fios:
		reg [3:0] destino;
		reg [3:0] registrador1;
		reg [3:0] registrador2;
		reg sinal;
		reg [5:0] imediato;
		wire reset = 0;
	
	 always @(*) begin 
			destino      = 4'd0;
			registrador1 = 4'd0;
			registrador2 = 4'd0;
			sinal        = 1'b0;
			imediato     = 6'd0;

			case(opcode)
				ADD, SUB: begin
					destino = instrucoes[14:11];
					registrador1 = instrucoes[10:7];
					registrador2 = instrucoes[6:3];
				end
					
				ADDI, SUBI, MUL: begin
					destino = instrucoes[14:11];
					registrador1 = instrucoes[10:7];
					sinal = instrucoes[6];
					imediato = instrucoes[5:0];
				end
					
				LOAD: begin
					destino = instrucoes[14:11];
					sinal = instrucoes[10];
					imediato = instrucoes[9:4];
				end
				
				DISPLAY: begin
					registrador1 = instrucoes[14:11];
				end		
			endcase
	 end
	 
	//chamar a ula e a memoria:
	 
    // valores que a memoria vai devolver para a CPU
    wire [15:0] valor_lido1;
    wire [15:0] valor_lido2;

    // resultado que sera calculado pela ULA
    wire [15:0] resultado_ula;

    // verifica se a instrucao deve escrever na memoria
    wire escrever = validar && ligado &&
                    (opcode == LOAD ||
                     opcode == ADD ||
                     opcode == ADDI ||
                     opcode == SUB ||
                     opcode == SUBI ||
                     opcode == MUL);

    // verifica se a instrucao pede para limpar a memoria
    wire limpar_memoria = clear || (validar && opcode == CLEAR);

    // chamada do modulo da memoria
    memory memoria(
        .clock(clock),
        .reset(reset),
        .clear(limpar_memoria),
        .we(escrever),
        .destino(destino),
        .valor(resultado_ula),
        .registrador1(registrador1),
        .registrador2(registrador2),
        .valor_lido1(valor_lido1),
        .valor_lido2(valor_lido2)
    );
	 
	//chamada do modulo da ula
	ula diva(
        .opcode(opcode),
        .valor1(valor_lido1),
        .valor2(valor_lido2),
        .sinal(sinal),
        .imediato(imediato),
        .resultado(resultado_ula)
    );
	 
    //lcd:
    wire lcd_busy;
    reg lcd_pendente = 1'b0;

    reg [2:0] opcode_lcd = 3'd0;
    reg [3:0] destino_lcd = 4'd0;
    reg [15:0] resultado_lcd = 16'd0;
        
    // o LCD aceita no mesmo ciclo em que estiver livre (IDLE) e houver pedido
    wire atualizar_lcd = lcd_pendente && !lcd_busy;

    always @(posedge clock) begin
        if (!ligado) begin
            lcd_pendente <= 1'b0;
        end 
        else begin
            if (atualizar_lcd) lcd_pendente <= 1'b0; 

            if (validar) begin                       
                opcode_lcd    <= opcode;
                destino_lcd   <= (opcode == DISPLAY) ? registrador1 : destino;
                resultado_lcd <= resultado_ula;
                lcd_pendente  <= 1'b1;
            end
        end
    end

	lcd_controller lcd(
        .clock(clock),
        .reset(reset),
        .ligado(ligado),
        .atualizar(atualizar_lcd),

        .opcode(opcode_lcd),
        .destino(destino_lcd),
        .resultado(resultado_lcd),

        .busy(lcd_busy),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_EN(LCD_EN),
        .LCD_DATA(LCD_DATA),
        .LCD_ON(LCD_ON)
    );

endmodule