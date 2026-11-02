`timescale 1ns / 1ps
module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter AE = 2,
    parameter AF = 2
) (
    input wclk,
    input rclk,
    input rrst_n,
    input wrst_n,
    input [DATA_WIDTH-1:0]wdata,
    output [DATA_WIDTH-1:0] rdata,
    //input [ADDR_WIDTH-1:0]waddr,
    //input [ADDR_WIDTH-1:0]raddr, 
    //because we dont need what address to be written on. this is not RAM. this is FIFO. address is ours.
    //writer/reader only gives out rinc and winc.
    input rinc,
    input winc,
    //we also need to output the full,empty flags.
    //so that the writer can stop feeding wdata.
    output rempty,
    output ralmost_empty,
    output walmost_full,
    output wfull
);
    //first creating memory
    wire wclken;
    assign wclken = (winc&&!wfull);
    wire [ADDR_WIDTH-1:0]raddr;
    wire [ADDR_WIDTH-1:0]waddr;
    fifomem #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) fifomem (.wclk(wclk),.wclken(wclken),.wdata(wdata),.waddr(waddr),.raddr(raddr),.rdata(rdata));

    //compute wfull 
    wire [ADDR_WIDTH:0]wq2_rptr; //wire not reg
    wire [ADDR_WIDTH:0]wptr; // wire not reg
    wptr_full #(.AF(AF),.ADDR_WIDTH(ADDR_WIDTH))wptr_full(.wclk(wclk),.wrst_n(wrst_n),.winc(winc),.wq2_rptr(wq2_rptr),.waddr(waddr),.wptr(wptr),.wfull(wfull),.walmost_full(walmost_full));
    
    //compute rempty
    
    wire [ADDR_WIDTH:0]rq2_wptr; //wire not reg
    wire [ADDR_WIDTH:0]rptr; //wire not reg
    rptr_empty #(.AE(AE),.ADDR_WIDTH(ADDR_WIDTH))rptr_empty(.rclk(rclk),.rrst_n(rrst_n),.rinc(rinc),.rq2_wptr(rq2_wptr),.raddr(raddr),.rptr(rptr),.rempty(rempty),.ralmost_empty(ralmost_empty));
    
    //2flop synchronisers
    sync_r2w #(.ADDR_WIDTH(ADDR_WIDTH)) sync_r2w (.wclk(wclk),.wrst_n(wrst_n),.rptr(rptr),.wq2_rptr(wq2_rptr));
    sync_w2r #(.ADDR_WIDTH(ADDR_WIDTH)) sync_w2r (.rclk(rclk),.rrst_n(rrst_n),.wptr(wptr),.rq2_wptr(rq2_wptr));

    //why wire not reg? i wrote reg because in the submodules .
    //regs are already declared and will be synthesised inside the submodules. so we dont need to declare them as reg here. they are already regs in the submodules.
    //reg is strictly only used when we are using it in an always block.
    //to connect different submodules we only need wires.

endmodule