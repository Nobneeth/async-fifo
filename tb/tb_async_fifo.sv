`timescale 1ns / 1ps
// `timescale <unit> / <precision>
//   unit      = 1ns  -> "#5" means 5 ns
//   precision = 1ps  -> the simulator can resolve times down to 1 ps,
//                       which is why "#13.5" below (13.5 ns) is allowed.

// =====================================================================
// TESTBENCH FOR ASYNC FIFO
// ---------------------------------------------------------------------
// A testbench has NO ports. It is a "virtual lab bench":
//   - it creates the signals (clocks, resets, data),
//   - plugs them into the design (DUT = Design Under Test),
//   - drives inputs, watches outputs, and reports PASS / FAIL.
//
// HOW WE CHECK CORRECTNESS ("scoreboard" idea):
//   We keep our OWN simple software FIFO (a SystemVerilog queue, exp_q).
//   - Every time the real FIFO ACCEPTS a write, we also push the same
//     value into exp_q.
//   - Every time we read from the real FIFO, we pop from exp_q and
//     compare. If the hardware is correct, both must give the same data
//     in the same order.
//
// WHAT IS SPECIAL ABOUT AN *ASYNC* FIFO:
//   Write side and read side run on DIFFERENT, unrelated clocks.
//   The pointers cross between clock domains through 2-flop
//   synchronisers, so:
//     - rempty goes LOW only ~2-3 rclk cycles AFTER a write happens.
//     - wfull  goes LOW only ~2-3 wclk cycles AFTER a read happens.
//   The flags are "pessimistic" (late) but never wrong in the unsafe
//   direction. The tests below are written with that delay in mind.
// =====================================================================

module tb_async_fifo;
  // localparam = constant that cannot be overridden from outside.
  // DW    = data width (bits per word)          -> 8
  // AW    = address width                       -> 3
  // DEPTH = number of slots = 2^AW = 1 << 3     -> 8
  localparam DW = 8, AW = 3, DEPTH = 1 << AW;

  // ---------------- Signals that DRIVE the DUT (inputs) ----------------
  // 'logic' because the testbench assigns them from initial/tasks.
  // "= 0" gives a starting value at time 0 so they are not X.
  logic wclk = 0, rclk = 0;          // two independent clocks
  logic wrst_n, rrst_n;              // active-LOW resets (0 = reset)
  logic winc = 0, rinc = 0;          // write request / read request
  logic [DW-1:0] wdata = 0;          // data we want to write

  // ---------------- Signals DRIVEN BY the DUT (outputs) ----------------
  // 'wire' because the DUT drives them; the testbench only reads them.
  wire  [DW-1:0] rdata;              // data at the head of the FIFO
  wire  wfull, rempty;               // status flags

  // ---------------- Instantiate the design ----------------
  // #(...) = parameter overrides, (...) = port connections.
  async_fifo #(.DATA_WIDTH(DW), .ADDR_WIDTH(AW)) dut (
    .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),   // write side
    .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)); // read side

  // ---------------- Clock generation ----------------
  // Toggle every half-period, forever.
  // The periods are deliberately NOT multiples of each other (10 vs 27),
  // so the clock edges drift relative to each other. This exercises the
  // clock-domain crossing the way real unrelated clocks would.
  always #5  wclk = ~wclk;   // 10 ns period (fast writer)
  always #13.5  rclk = ~rclk;   // 27 ns period (slow reader)

  // ---------------- Scoreboard ----------------
  // exp_q  : queue ([$] = grows/shrinks automatically) holding the values
  //          we EXPECT to come out of the FIFO, in order.
  // errors : counts every mismatch / wrong flag we detect.
  logic [DW-1:0] exp_q[$];
  int errors = 0;

  // =====================================================================
  // TASK: write one word
  // ---------------------------------------------------------------------
  // 'automatic' = each call gets its own copy of local variables
  //               (safe if the task is ever called in parallel).
  //
  // WHY NEGEDGE?  The DUT samples inputs on POSEDGE. We change inputs on
  // the NEGEDGE, half a cycle earlier, so they are stable and settled
  // when the posedge arrives. This avoids testbench/DUT race conditions.
  // =====================================================================
  task automatic write(input logic [DW-1:0] d);
    @(negedge wclk);                 // wait for a safe point to change inputs
    wdata = d; winc = 1;             // present data and request a write

    // CHECK: will the FIFO actually accept this write?
    // The DUT writes only when (winc && !wfull) at the next posedge.
    // wfull is stable here (it only changes on posedge), so it tells us
    // exactly what the DUT will decide. If accepted -> record it in the
    // scoreboard. If full -> the write is DROPPED, so we must NOT record
    // it; otherwise our model would expect data that never got stored.
    if (winc&&~wfull) exp_q.push_back(d);            // will this write be accepted?

    @(negedge wclk);                 // one full cycle later the posedge has passed
    winc = 0;                        // drop the request -> exactly ONE write
  endtask

  // =====================================================================
  // TASK: read one word
  // ---------------------------------------------------------------------
  // Our FIFO has a COMBINATIONAL read: rdata always shows the word at the
  // read pointer (the "head"), BEFORE we pulse rinc. rinc only moves the
  // pointer forward to the next word. So: first CHECK rdata, then pop.
  // =====================================================================
  task automatic read();
    logic [DW-1:0] exp;              // local: the value we expect to see
    @(negedge rclk);                 // change inputs away from rclk posedge

    // CHECK: rdata is only meaningful when the FIFO is NOT empty.
    // !!! BUG: this condition is inverted. It should be  if (!rempty)
    //     As written, we compare only when the FIFO is EMPTY (rdata is
    //     stale garbage then), and we SKIP the check on every valid read.
    //     It also pops exp_q at the wrong times, so the final
    //     exp_q.size()==0 check will fail.
    if (!rempty) begin                          // is rdata valid right now?
      exp = exp_q.pop_front();       // oldest expected value (FIFO order)

      // !== (case inequality) also catches X and Z.
      // A normal != with an X gives X, which 'if' treats as false,
      // so an X on rdata would silently PASS. !== prevents that.
      if (rdata !== exp) begin
        $error("Mismatch: got %h, expected %h", rdata, exp);
        errors = errors + 1;
      end
    end

    // Request a read even if empty. When empty, the DUT must IGNORE it
    // (rinc && !rempty is false) - that is what the underflow test uses.
    rinc = 1;
    @(negedge rclk);                 // posedge in between performs the read
    rinc = 0;                        // exactly ONE read
  endtask

  // =====================================================================
  // MAIN TEST SEQUENCE
  // =====================================================================
  initial begin
    // ---------- Reset ----------
    // Hold both domains in reset long enough to cover several edges of
    // BOTH clocks (100 ns = 10 wclk cycles, ~3.7 rclk cycles), so every
    // flop, including the synchroniser flops, is cleared to 0.
    // After reset: pointers = 0, rempty = 1, wfull = 0.
    wrst_n = 0; rrst_n = 0;
    #100;
    wrst_n = 1; rrst_n = 1;

    // ---------- 1. Fill ----------
    // Write DEPTH (8) values: 1,2,...,8 into an 8-slot FIFO.
    // WHAT WE CHECK: after exactly DEPTH writes, wfull must be 1.
    // wfull is computed in the WRITE domain, from the write pointer and
    // the (synchronised) read pointer. No reads happened, so the read
    // pointer is 0 and the full condition is reached immediately.
    for (int i = 1; i <= DEPTH; i++) write(i);
    if (wfull==0) begin $error("wfull not set after %0d writes", DEPTH); errors = errors + 1; end

    // ---------- 2. Overflow ----------
    // Try to write 0x99 into a FULL FIFO.
    // WHAT WE CHECK: the DUT must DROP it and not overwrite old data.
    // The write task sees wfull=1, so 0x99 is NOT added to exp_q.
    // If the DUT wrongly stored it (overwriting value 1), the reads in
    // step 3 would return 0x99 where 1 was expected -> mismatch error.
    // So this step is verified INDIRECTLY by the drain step.
    write(8'h99);

    // ---------- 3. Drain ----------
    // The write pointer must cross into the read clock domain (through
    // the 2-flop synchroniser) before rempty can drop to 0.
    // wait(!rempty) blocks until the read side "sees" the data.
    // Without it, the first reads would find rempty=1 and do nothing.
    wait (!rempty); //empty coomputed only after write crosses read clk

    // Read all DEPTH words.
    // WHAT WE CHECK: each rdata equals the scoreboard value
    // -> data correct AND in the same order it was written (1..8).
    for (int i = 0; i < DEPTH; i++) read();

    // WHAT WE CHECK: after reading everything, rempty must be 1.
    // rempty is computed in the READ domain, from the read pointer and
    // the synchronised write pointer, so it updates right away here.
    if (rempty==0) begin $error("rempty not set after drain"); errors = errors + 1; end

    // ---------- 4. Underflow ----------
    // Try to read from an EMPTY FIFO.
    // WHAT WE CHECK: the read pointer must NOT move (rinc is ignored
    // because rempty=1). If it moved, the pointers would get out of step:
    // rempty would drop to 0 with no real data, and later reads would
    // return wrong values.
    read();

    // ---------- 5. Final check ----------
    // PASS only if:
    //   - no mismatches or wrong flags were counted (errors == 0), AND
    //   - every value we expected was actually read out (exp_q empty).
    //     A leftover item in exp_q means data was lost or never read.
    if (errors == 0 && exp_q.size()==0 ) $display("PASS");
    else                     $display("FAIL: %0d errors", errors);
    $finish;                         // end the simulation
  end
endmodule
