`timescale 1ns / 1ps

module rptr_empty#(parameter ADDR_WIDTH = 3,
parameter AE = 2)(//creating an asynch fifo read side.
    input rclk,
    input rrst_n,
    input rinc,
    output [ADDR_WIDTH-1:0]raddr,
    output reg [ADDR_WIDTH:0]rptr,
    output reg rempty,
    output reg ralmost_empty,
    input [ADDR_WIDTH:0] rq2_wptr
);
localparam DEPTH = 1<<ADDR_WIDTH;
reg [ADDR_WIDTH:0] rq2_wbin;
wire [ADDR_WIDTH:0] rbinnext,rgraynext;
reg [ADDR_WIDTH:0] rbin;

integer i;
always@(*)begin
    rq2_wbin[ADDR_WIDTH] = rq2_wptr[ADDR_WIDTH];
    for(i=ADDR_WIDTH-1;i>=0;i=i-1)begin
        rq2_wbin[i] = rq2_wptr[i]^rq2_wbin[i+1];
    end
end

assign raddr = rbin[ADDR_WIDTH-1:0];
assign rbinnext = (rinc && ~rempty)? rbin+1:rbin;
assign rgraynext = rbinnext^(rbinnext>>1);

wire [ADDR_WIDTH:0] rfill = rq2_wbin - rbinnext;
always@(posedge rclk or negedge rrst_n)begin
    if(~rrst_n) begin{rptr,rbin}<=0;{ralmost_empty,rempty}<=2'b11;end
    else begin
        rptr<=rgraynext;
        rbin<=rbinnext;
        rempty<= (rgraynext ==rq2_wptr);
        ralmost_empty<=(rfill<= AE);

    end
end
endmodule
