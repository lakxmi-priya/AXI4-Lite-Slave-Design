`timescale 1ns / 1ps

module tb_axi_lite_slave;

    // ---------- Global Signals ----------
    reg         ACLK;
    reg         ARESETn;

    // ---------- Write Address Channel ----------
    reg  [31:0] AWADDR;
    reg         AWVALID;
    wire        AWREADY;

    // ---------- Write Data Channel ----------
    reg  [31:0] WDATA;
    reg         WVALID;
    wire        WREADY;

    // ---------- Write Response Channel ----------
    wire [1:0]  BRESP;
    wire        BVALID;
    reg         BREADY;

    // ---------- Read Address Channel ----------
    reg  [31:0] ARADDR;
    reg         ARVALID;
    wire        ARREADY;

    // ---------- Read Data Channel ----------
    wire [31:0] RDATA;
    wire [1:0]  RRESP;
    wire        RVALID;
    reg         RREADY;
    
    // Internal testbench variable to catch read data
    reg  [31:0] rdata_catch;

    // ---------- Instantiate the Slave ----------
    axi_lite_slave uut (
        .ACLK     (ACLK),
        .ARESETn  (ARESETn),
        .AWADDR   (AWADDR),
        .AWVALID  (AWVALID),
        .AWREADY  (AWREADY),
        .WDATA    (WDATA),
        .WVALID   (WVALID),
        .WREADY   (WREADY),
        .BRESP    (BRESP),
        .BVALID   (BVALID),
        .BREADY   (BREADY),
        .ARADDR   (ARADDR),
        .ARVALID  (ARVALID),
        .ARREADY  (ARREADY),
        .RDATA    (RDATA),
        .RRESP    (RRESP),
        .RVALID   (RVALID),
        .RREADY   (RREADY)
    );

    // ---------- Clock Generator (100 MHz) ----------
    always #5 ACLK = ~ACLK;

    // ---------- Main Test Sequence ----------
    initial begin
        // Initialize all master signals
        ACLK    = 0;
        ARESETn = 0;
        AWADDR  = 0;
        AWVALID = 0;
        WDATA   = 0;
        WVALID  = 0;
        BREADY  = 0;
        ARADDR  = 0;
        ARVALID = 0;
        RREADY  = 0;

        $dumpfile("dump.vcd");
        $dumpvars(0, tb_axi_lite_slave);

        // Apply reset for 5 clock cycles
        repeat(5) @(posedge ACLK);
        ARESETn = 1;

        // Wait 2 more cycles for stability
        repeat(2) @(posedge ACLK);

        // =========================================================
        // TEST 1: The "Happy Path" (Write and Read from Address 0x04)
        // =========================================================
        $display("=== Starting Test 1: Valid Read/Write ===");

        axi_write(32'h0000_0004, 32'hDEADBEEF);
        if (BRESP !== 2'b00) $display("FAIL: Expected OKAY (00), got %b", BRESP);

        axi_read(32'h0000_0004, rdata_catch);
        if (RRESP !== 2'b00) $display("FAIL: Expected OKAY (00), got %b", RRESP);

        if (rdata_catch === 32'hDEADBEEF) begin
            $display("PASS: Wrote 0xDEADBEEF and read it back successfully.");
        end else begin
            $display("FAIL: Expected 0xDEADBEEF, got 0x%08h", rdata_catch);
        end

        // Wait a few cycles between tests
        repeat(5) @(posedge ACLK);

        // =========================================================
        // TEST 2: The "Robustness" Test (Write to Invalid Address 0xF0)
        // =========================================================
        $display("=== Starting Test 2: Invalid Address Check ===");
        
        axi_write(32'h0000_00F0, 32'h11112222); 
        if (BRESP === 2'b11) begin
            $display("PASS: Slave correctly rejected bad address with DECERR (11).");
        end else begin
            $display("FAIL: Slave accepted a bad address! Response was %b", BRESP);
        end

        $display("=== All Tests Complete ===");
        $finish;
    end

    // ---- Safety Timeout Block ----
    initial begin
        #1000;
        $display("TIMEOUT: Simulation hung. Check your VALID/READY handshakes!");
        $finish;
    end

    // =========================================================
    // Master Emulation Tasks
    // =========================================================
    task automatic axi_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge ACLK);
        AWADDR  = addr;
        AWVALID = 1'b1;
        WDATA   = data;
        WVALID  = 1'b1;
        BREADY  = 1'b0;

        // Wait until slave accepts both
        wait (AWREADY && WREADY);
        @(posedge ACLK);
        AWVALID = 1'b0;
        WVALID  = 1'b0;

        // Wait for response receipt
        BREADY = 1'b1;
        wait (BVALID);
        @(posedge ACLK);
        BREADY = 1'b0;
    end
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
    begin
        @(posedge ACLK);
        ARADDR  = addr;
        ARVALID = 1'b1;
        RREADY  = 1'b0;

        // Wait until slave accepts the address
        wait (ARREADY);
        @(posedge ACLK);
        ARVALID = 1'b0;

        // Wait for read data
        wait (RVALID);
        data = RDATA;
        RREADY = 1'b1;
        @(posedge ACLK);
        RREADY = 1'b0;
    end
    endtask

endmodule