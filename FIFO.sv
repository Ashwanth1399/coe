module FIFO (
    clk,
    reset,
    write_en,
    read_en,
    data_in,
    data_out,
    full,
    empty
);

  parameter depth = 8;  // Depth of the FIFO
  parameter ptr_size = 3;  // width of pointer for read and write
  parameter data_width = 32;  // Width of data in bits

  reg [data_width-1:0] mem[0:depth-1];
  reg [ptr_size-1:0] wr_ptr;
  reg [ptr_size-1:0] rd_ptr;
  reg [depth-1:0] count;
  output full;
  output empty;
  output reg [31:0] data_out;
  input [31:0] data_in;
  input clk, reset, write_en, read_en;

  always @(posedge clk or posedge reset) begin
    if (!reset) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      count  <= 0;
    end else begin
      fork
        begin
          if (write_en && !full) begin
            mem[wr_ptr] <= data_in;
            wr_ptr <= wr_ptr + 1;
          end
        end
        begin
          if (read_en && !empty) begin
            data_out <= mem[rd_ptr];
            rd_ptr   <= rd_ptr + 1;
          end
        end
      join

      if (write_en && !full) begin
        if (!(read_en && !empty)) begin
          count <= count + 1;
        end
      end else begin
        if (read_en && !empty) begin
          count <= count - 1;
        end
      end
     end
  end

  assign full  = (count == depth);
  assign empty = (count == 0);

endmodule


