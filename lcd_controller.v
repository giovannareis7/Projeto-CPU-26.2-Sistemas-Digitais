module lcd_controller(
    input clock,
    input reset,
    input ligado,
    input atualizar,
    input [2:0] opcode,
    input [3:0] destino,
    input [15:0] resultado,
    output busy,
    output LCD_RS,
    output LCD_RW,
    output LCD_EN,
    output [7:0] LCD_DATA,
    output LCD_ON
);

    //Clock de 50 MHz
    localparam  CLK_HZ = 50000000;

    //Tempos de espera
    localparam  CICLOS_LIGAR = CLK_HZ / 50;
    localparam  CICLOS_microssegundos = CLK_HZ / 1000000;
    localparam  CICLOS_milissegundos = CLK_HZ / 1000;

    //Estados da maquina
    localparam [3:0]    ESPERA_LIGAR   = 4'd0,
                        ESCOLHA_COMANDO    = 4'd1,
                        ESPERA    = 4'd2,
                        ENABLE  = 4'd3,
                        ESPERAR_LCD    = 4'd4,
                        PROXIMO    = 4'd5,
                        ESPERAR_CPU    = 4'd6,
                        DISPLAY = 4'd7;

    reg [3:0] estado;
    reg [31:0] contador;
    reg [3:0] inicializacao;
    reg [5:0] exibir;
    reg enviando_inicializacao;
    reg tela_inicial;

    //Dados recebidos da CPU
    reg [2:0] opcode;
    reg [3:0] destino;
    reg [15:0] resultado;

    //Dados que serao enviados ao LCD
    reg tipo;
    reg [7:0] dado;

    assign LCD_ON = ligado && !reset;
    assign LCD_RW = 1'b0;
    assign LCD_RS = tipo;
    assign LCD_DATA = dado;

    assign LCD_EN = (estado == ENABLE) && ligado && !reset;
    assign busy = (estado != ESPERAR_CPU) || !ligado || reset;

    //Conversao do resultado para decimal
    reg negativo;
    reg [15:0] valor_absoluto;
    reg [19:0] valor_bcd;

    integer i, j;

    always @(*) begin

        negativo = resultado[15];

        if (negativo)
            valor_absoluto = (~resultado) + 16'd1;
        else
            valor_absoluto = resultado;

        valor_bcd = 20'd0;

        for (i = 15; i >= 0; i = i - 1) begin

            for (j = 0; j < 5; j = j + 1) begin

                if (valor_bcd[j*4 +: 4] >= 4'd5)
                    valor_bcd[j*4 +: 4] = valor_bcd[j*4 +: 4] + 4'd3;
            end

            valor_bcd = {valor_bcd[18:0], valor_absoluto[i]};
        end
    end

    //Memoria dos caracteres que serao exibidos
    reg [7:0] tela [0:31];

    integer k;

    always @(*) begin

        //Preenche a tela com espacos
        for (k = 0; k < 32; k = k + 1)
            tela[k] = " ";

        if (tela_inicial) begin

            tela[10] = "[";
            tela[11] = "-";
            tela[12] = "-";
            tela[13] = "-";
            tela[14] = "-";
            tela[15] = "]";

            tela[27] = "+";
            tela[28] = "0";
            tela[29] = "0";
            tela[30] = "0";
            tela[31] = "0";

        end
        else begin

            //Identifica a operacao
            case (opcode)

                3'b000: begin
                    tela[0] = "L";
                    tela[1] = "O";
                    tela[2] = "A";
                    tela[3] = "D";
                end

                3'b001: begin
                    tela[0] = "A";
                    tela[1] = "D";
                    tela[2] = "D";
                end

                3'b010: begin
                    tela[0] = "A";
                    tela[1] = "D";
                    tela[2] = "D";
                    tela[3] = "I";
                end

                3'b011: begin
                    tela[0] = "S";
                    tela[1] = "U";
                    tela[2] = "B";
                end

                3'b100: begin
                    tela[0] = "S";
                    tela[1] = "U";
                    tela[2] = "B";
                    tela[3] = "I";
                end

                3'b101: begin
                    tela[0] = "M";
                    tela[1] = "U";
                    tela[2] = "L";
                end

                3'b110: begin
                    tela[0] = "C";
                    tela[1] = "L";
                    tela[2] = "E";
                    tela[3] = "A";
                    tela[4] = "R";
                end

                3'b111: begin
                    tela[0] = "D";
                    tela[1] = "P";
                    tela[2] = "L";
                end

                default: begin
                end

            endcase

            //CLEAR nao exibe registrador nem resultado
            if (opcode != 3'b110) begin

                tela[10] = "[";
                tela[15] = "]";

                //Registrador de destino em binario
                tela[11] = destino[3] ? "1" : "0";
                tela[12] = destino[2] ? "1" : "0";
                tela[13] = destino[1] ? "1" : "0";
                tela[14] = destino[0] ? "1" : "0";

                //Exibe cinco digitos quando necessario
                if (valor_bcd[19:16] != 4'd0) begin

                    tela[26] = negativo ? "-" : "+";

                    tela[27] = 8'h30 + {4'b0000, valor_bcd[19:16]};
                    tela[28] = 8'h30 + {4'b0000, valor_bcd[15:12]};
                    tela[29] = 8'h30 + {4'b0000, valor_bcd[11:8]};
                    tela[30] = 8'h30 + {4'b0000, valor_bcd[7:4]};
                    tela[31] = 8'h30 + {4'b0000, valor_bcd[3:0]};
                end
                else begin

                    tela[27] = negativo ? "-" : "+";

                    tela[28] = 8'h30 + {4'b0000, valor_bcd[15:12]};
                    tela[29] = 8'h30 + {4'b0000, valor_bcd[11:8]};
                    tela[30] = 8'h30 + {4'b0000, valor_bcd[7:4]};
                    tela[31] = 8'h30 + {4'b0000, valor_bcd[3:0]};
                end
            end
        end
    end

    //Maquina de estados do controlador
    always @(posedge clk or posedge reset) begin

        if (reset) begin

            estado <= ESPERA_LIGAR;

            contador <= 32'd0;
            inicializacao <= 4'd0;
            exibir <= 6'd0;

            enviando_inicializacao <= 1'b1;
            tela_inicial <= 1'b1;

            opcode <= 3'd0;
            destino <= 4'd0;
            resultado <= 16'd0;

            tipo <= 1'b0;
            dado <= 8'd0;

        end

        else if (!ligado) begin

            estado <= ESPERA_LIGAR;

            contador <= 32'd0;
            inicializacao <= 4'd0;
            exibir <= 6'd0;

            enviando_inicializacao <= 1'b1;
            tela_inicial <= 1'b1;

            opcode <= 3'd0;
            destino <= 4'd0;
            resultado <= 16'd0;

            tipo <= 1'b0;
            dado <= 8'd0;

        end

        else begin

            case (estado)

                //Aguarda o LCD estabilizar
                ESPERA_LIGAR: begin

                    if (contador >= CICLOS_LIGAR - 1) begin
                        contador <= 32'd0;
                        estado <= ESCOLHA_COMANDO;
                    end
                    else begin
                        contador <= contador + 1'b1;
                    end

                end

                //Seleciona os comandos de inicializacao
                ESCOLHA_COMANDO: begin

                    tipo <= 1'b0;

                    case (inicializacao)

                        0: dado <= 8'h38;
                        1: dado <= 8'h38;
                        2: dado <= 8'h38;
                        3: dado <= 8'h08;
                        4: dado <= 8'h01;
                        5: dado <= 8'h06;
                        6: dado <= 8'h0C;

                        default: dado <= 8'h0C;
                    endcase

                    contador <= 32'd0;
                    estado <= ESPERA;
                end

                //Aguarda 1 microssegundo
                ESPERA: begin

                    if (contador >= CICLOS_microssegundos - 1) begin
                        contador <= 32'd0;
                        estado <= ENABLE;
                    end
                    else begin
                        contador <= contador + 1'b1;
                    end

                end

                //Mantem ENABLE ativo
                ENABLE: begin

                    if (contador >= CICLOS_microssegundos - 1) begin
                        contador <= 32'd0;
                        estado <= ESPERAR_LCD;
                    end
                    else begin
                        contador <= contador + 1'b1;
                    end
                end

                //Aguarda 1 milissegundo
                ESPERAR_LCD: begin

                    if (contador >= CICLOS_milissegundos - 1) begin
                        contador <= 32'd0;
                        estado <= PROXIMO;
                    end
                    else begin
                        contador <= contador + 1'b1;
                    end
                end

                //Decide a proxima etapa
                PROXIMO: begin

                    if (enviando_inicializacao) begin

                        if (inicializacao == 6) begin

                            enviando_inicializacao <= 1'b0;
                            exibir <= 6'd0;
                            estado <= DISPLAY;
                        end
                        else begin

                            inicializacao <= inicializacao + 1'b1;
                            estado <= ESCOLHA_COMANDO;
                        end
                    end
                    else begin

                        if (exibir == 34) begin
                            estado <= ESPERAR_CPU;
                        end
                        else begin
                            exibir <= exibir + 1'b1;
                            estado <= DISPLAY;
                        end
                    end
                end

                //Aguarda uma nova operacao da CPU
                ESPERAR_CPU: begin

                    if (atualizar) begin

                        opcode <= opcode;
                        destino <= destino;
                        resultado <= resultado;

                        tela_inicial <= 1'b0;

                        exibir <= 6'd0;
                        estado <= DISPLAY;
                    end
                end

                //Seleciona o comando ou caractere da tela
                DISPLAY: begin

                    contador <= 32'd0;

                    if (exibir == 0) begin

                        tipo <= 1'b0;
                        dado <= 8'h01;
                    end
                    else if (exibir == 1) begin

                        tipo <= 1'b0;
                        dado <= 8'h80;
                    end
                    else if (exibir <= 17) begin

                        tipo <= 1'b1;
                        dado <= tela[exibir - 6'd2];
                    end
                    else if (exibir == 18) begin

                        tipo <= 1'b0;
                        dado <= 8'hC0;
                    end
                    else begin

                        tipo <= 1'b1;
                        dado <= tela[exibir - 6'd3];
                    end

                    estado <= ESPERA;
                end

                //Retorna ao inicio em caso de estado inesperado
                default: begin

                    estado <= ESPERA_LIGAR;

                    contador <= 32'd0;
                    inicializacao <= 4'd0;
                    exibir <= 6'd0;

                    enviando_inicializacao <= 1'b1;
                    tela_inicial <= 1'b1;
                end
            endcase
        end
    end
endmodule
