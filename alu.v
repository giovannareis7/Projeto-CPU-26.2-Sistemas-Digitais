module alu(
    input       [2:0] opcode,          // operacao a ULA deve realizar
    input       [15:0] valor1,         // primeiro registrador 
    input       [15:0] valor2,         // segundo registrador
    input       sinal,                
    input       [5:0] imediato,        // imediato sem sinal
    output reg  [15:0] resultado       // resultado em complemento de dois
);

    // instrucoes com 3 bits
    parameter LOAD = 3'b000,
              ADD = 3'b001,
              ADDI = 3'b010,
              SUB = 3'b011,
              SUBI = 3'b100,
              MUL = 3'b101,
              CLEAR = 3'b110,
              DISPLAY = 3'b111;

    //imediato convertido para 16 bits, pois a memória trabalha com 16 bits em complemento de dois
    reg [15:0] imediato16;

    //conversão do imediato e calcula o resultado da operacao
    always @(*) begin
        // transforma o imediato de 6 para 16 bits
        imediato16 = {10'b0000000000, imediato};

        //verificação se o imediato e negativo
        if (sinal == 1'b1) begin
            //se  for, converte o valor para complemento de dois
            imediato16 = (~imediato16) + 16'd1;
        end

        //zerar para evitar que a ULA guarde resultados anteriores
        resultado = 16'd0;

        //case para cada operacao a ser executada
        case (opcode)
            LOAD: begin
                //copia o valor imediato convertido
                resultado = imediato16;
            end

            ADD: begin
                //soma os valores dos dois registradores
                resultado = valor1 + valor2;
            end

            ADDI: begin
                //soma o primeiro registrador com o imediato
                resultado = valor1 + imediato16;
            end

            SUB: begin
                //subtrai o segundo registrador do primeiro
                resultado = valor1 - valor2;
            end

            SUBI: begin
                //subtrai o imediato do primeiro registrador
                resultado = valor1 - imediato16;
            end

            MUL: begin
                //multiplica o primeiro registrador pelo imediato
                resultado = valor1 * imediato16;
            end

            CLEAR: begin
                //a ULA retorna zero nessa instrucao, quem realmente zera os 16 registradores e a memoria
                resultado = 16'd0;
            end

            DISPLAY: begin
                //retorna o valor do registrador
                resultado = valor1;
            end

            default: begin
                resultado = 16'd0;
            end
        endcase
    end
endmodule

