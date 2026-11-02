`timescale 1ns / 1ps

module sync_r2w #( //module 2flop synchroniser as discussed in the notes.
    parameter ADDR_WIDTH =3
) (
    input [ADDR_WIDTH:0]rptr,
    output reg [ADDR_WIDTH:0] wq2_rptr,
    input wrst_n,
    input wclk
);
  reg [ADDR_WIDTH:0] wq1_rptr;

  always@(posedge wclk or negedge wrst_n)begin
    if(!wrst_n){wq2_rptr,wq1_rptr}<=0; //every **register** in an async reset block should be reset.
    else begin
        wq1_rptr<= rptr;
        wq2_rptr<=wq1_rptr;
    end
  end  
endmodule
