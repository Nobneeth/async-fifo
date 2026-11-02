`timescale 1ns / 1ps

module wptr_full#(parameter ADDR_WIDTH = 3, 

parameter AF = 2)(//creating an asynch fifo write side. read will be similar.
    input wclk,
    input wrst_n,
    input winc,
    output [ADDR_WIDTH-1:0]waddr,
    output reg [ADDR_WIDTH:0]wptr,
    output reg wfull,
    output reg walmost_full,
    input [ADDR_WIDTH:0] wq2_rptr
);

localparam DEPTH = 1<<ADDR_WIDTH;

wire [ADDR_WIDTH:0] wbinnext,wgraynext;
reg [ADDR_WIDTH:0] wbin;
reg [ADDR_WIDTH:0] wq2_rbin;
assign waddr = wbin[ADDR_WIDTH-1:0];
assign wbinnext = (winc && ~wfull)? wbin+1:wbin;
assign wgraynext = wbinnext^(wbinnext>>1);
//gray to binary conversion. loop needed.

integer i;
always@(*)begin
wq2_rbin[ADDR_WIDTH] = wq2_rptr[ADDR_WIDTH];
for(i=ADDR_WIDTH-1;i>=0;i=i-1)begin
    wq2_rbin[i] = wq2_rptr[i]^wq2_rbin[i+1];
end
end

wire [ADDR_WIDTH:0] wfill = wbinnext - wq2_rbin;

always@(posedge wclk or negedge wrst_n)begin
    if(~wrst_n) {wptr,wbin,wfull,walmost_full}<=0;
    else begin
        wptr<=wgraynext;
        wbin<=wbinnext;
        wfull<= (wgraynext =={~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1],wq2_rptr[ADDR_WIDTH-2:0]});
        walmost_full<=(wfill>= DEPTH-AF);

    end
end
endmodule
