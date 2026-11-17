module memory (
    input       clock,
    input       reset,                    // zera tudo (ligar/desligar o sistema)
    input       clear,                  // instrucao CLEAR
    input       we,                     // habilita escrita
    input       [3:0]  destino,         // registrador de destino
    input       [15:0] valor,           // dado a gravar (complemento de 2)
    input       [3:0]  registrador1,    // registrador de leitura 1
    input       [3:0]  registrador2,    // registrador de leitura 2
    output reg  [15:0] valor_lido1,     // valor lido de src1 (complemento de 2)
    output reg  [15:0] valor_lido2      // valor lido de src2 (complemento de 2)
);

    reg [15:0] R [0:15]; //crição dos 16 registradores(R0, R1...R15)
    integer i;

    initial begin // for para iniciar tds os registradores com 0 no inicio
        for (i = 0; i < 16; i = i + 1)
            R[i] = 16'd0;
    end

    always @(posedge clock) begin
        if (reset || clear) begin //zerar quando reseta e na opção clear
            for (i = 0; i < 16; i = i + 1)
                R[i] <= 16'd0;
        end
        else if (we && (destino != 4'd0)) begin
            R[destino] <= valor;   // R0 n e escrito
        end
    end

    //leituras com mudança contínua
    always @(*) begin
        if (registrador1 == 4'd0) begin
            valor_lido1 = 16'd0;
        end
        else begin
            valor_lido1 = R[registrador1];
        end
    end

    always @(*) begin
        if (registrador2 == 4'd0) begin
            valor_lido2 = 16'd0;
        end
        else begin
            valor_lido2 = R[registrador2];
        end
    end

endmodule