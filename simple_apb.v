module simple_apb (
    input             PCLK,
    input             PRESETn,
    input             PSEL,
    input             PENABLE,
    input             PWRITE,
    input      [31:0] PADDR,
    input      [31:0] PWDATA,
    output reg [31:0] PRDATA,
    output            PREADY,
    output            PSLVERR
);

    reg [31:0] control_reg;

    assign PREADY = 1'b1;  // Always ready for simplicity
    assign PSLVERR = 1'b0; // No error condition

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            control_reg <= 32'h0;
            PRDATA <= 32'h0;
        end else if (PSEL && PENABLE) begin
            if (PWRITE) begin
                // Write operation
                case (PADDR)
                    32'h0: control_reg <= PWDATA;
                endcase
            end else begin
                // Read operation
                case (PADDR)
                    32'h0: PRDATA <= control_reg;
                endcase
            end
        end
    end
endmodule

