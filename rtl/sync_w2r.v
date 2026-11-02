`timescale 1ns / 1ps

module sync_w2r #( //module 2flop synchroniser as discussed in the notes.
    parameter ADDR_WIDTH =3
) (
    input [ADDR_WIDTH:0]wptr,
    output reg [ADDR_WIDTH:0] rq2_wptr,
    input rrst_n,
    input rclk
);
  reg [ADDR_WIDTH:0] rq1_wptr;

  always@(posedge rclk or negedge rrst_n)begin
    if(!rrst_n){rq2_wptr,rq1_wptr}<=0; //every **register** in an async reset block should be reset.
    else begin
        rq1_wptr<= wptr;
        rq2_wptr<=rq1_wptr;
    end
  end  
endmodule