module dff (
    input clk,rst,
    input d,
    output reg q);

always @(posedge clk ) begin
    if (rst)
        q <= 1'b0;
    else
        q <= d;     

    end
endmodule    


interface dff_if();
logic  clk,rst,d;
logic q;
endinterface
