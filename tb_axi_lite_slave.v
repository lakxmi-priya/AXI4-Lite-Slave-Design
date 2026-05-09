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
    reg  [31:0] rdata;

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

    // ---------- Clock Generator ----------
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

        // Wait 2 more cycles
        repeat(2) @(posedge ACLK);

        // ----- Test -----
        $display("=== Starting AXI4-Lite Slave Test ===");

        axi_write(32'h0000_0004, 32'hDEADBEEF);
        if (BRESP !== 2'b00) begin
            $display("FAIL: Write response was %b, expected 00", BRESP);
            $finish;
        end

        axi_read(32'h0000_0004, rdata);
        if (RRESP !== 2'b00) begin
            $display("FAIL: Read response was %b, expected 00", RRESP);
            $finish;
        end

        if (rdata === 32'hDEADBEEF) begin
            $display("PASS: Wrote 0xDEADBEEF, read back 0x%08h", rdata);
        end else begin
            $display("FAIL: Expected 0xDEADBEEF, got 0x%08h", rdata);
        end

        $display("=== Test complete ===");
        $finish;
    end

    // ---- Safety timeout ----
    initial begin
        #1000;
        $display("TIMEOUT: Simulation stopped at 1000ns");
        $finish;
    end

    // ---- Write Task (NON‑BLOCKING ASSIGNMENTS) ----
    task automatic axi_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge ACLK);
        AWADDR  <= addr;
        AWVALID <= 1'b1;
        WDATA   <= data;
        WVALID  <= 1'b1;
        BREADY  <= 1'b0;

        wait (AWREADY && WREADY);
        @(posedge ACLK);
        AWVALID <= 1'b0;
        WVALID  <= 1'b0;

        BREADY <= 1'b1;
        wait (BVALID);
        @(posedge ACLK);
        BREADY <= 1'b0;
    end
    endtask

    // ---- Read Task (NON‑BLOCKING ASSIGNMENTS) ----
    task automatic axi_read(input [31:0] addr, output [31:0] data);
    begin
        @(posedge ACLK);
        ARADDR  <= addr;
        ARVALID <= 1'b1;
        RREADY  <= 1'b0;

        wait (ARREADY);
        @(posedge ACLK);
        ARVALID <= 1'b0;

        wait (RVALID);
        data    = RDATA;
        RREADY <= 1'b1;
        @(posedge ACLK);
        RREADY <= 1'b0;
    end
    endtask

endmodule