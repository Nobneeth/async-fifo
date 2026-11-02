`timescale 1ns / 1ps
module fifomem #(
    parameter DATA_WIDTH = 8, //size of each word
    parameter ADDR_WIDTH = 3 ////depth = 2^3.
) (
    input wclk,//why? cant we do it using write enable w_en? 
    //in memories , w_en is enabled for consecutive writes, it is detected every clock cycle.
    //hence we need to have both enable and clk
    input wclken,
    //also, there is no rclk because data will not be destroyed in read. read is combinational in our model,
    input [DATA_WIDTH-1:0]wdata,
    input [ADDR_WIDTH-1:0]waddr,
    input [ADDR_WIDTH-1:0]raddr,
    output [DATA_WIDTH-1:0] rdata
);
reg [DATA_WIDTH-1:0]fifomem[2**ADDR_WIDTH-1:0];// 2^addrwidth  slots, each slot of 'datawidth' length
assign rdata = fifomem[raddr];
always@(posedge wclk)begin
    if(wclken)fifomem[waddr]<=wdata;

end
endmodule