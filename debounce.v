
module debounce(
    input       clock,
    input       entrada,
    output reg  saida = 1 //botão solto
);

    // Sincronizacao do botao, ambas com 1, pos o botão esta incialmente solto
    reg botao1 = 1;
    reg botao2 = 1;
    reg [31:0] contador = 0;

    always @(posedge clock) begin
        botao1 <= entrada;
        botao2 <= botao1;
    end

    always @(posedge clock) begin

        //Verifica se o botao voltou ao estado atual
        if (botao2 == saida) begin
            contador <= 0;
        end
        else begin
            // Espera completar 500.000 ciclos - 10ms
            if (contador == 500_000) begin
                saida <= botao2;
                contador <= 0;
            end
            else begin
                contador <= contador + 1;
            end
        end
    end

endmodule
