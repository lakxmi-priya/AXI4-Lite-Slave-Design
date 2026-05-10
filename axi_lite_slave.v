module axi_lite_slave (
    // ---------- Global Signals ----------
    input  wire        ACLK,
    input  wire        ARESETn,

    // ---------- Write Address Channel ----------
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output reg         AWREADY,

    // ---------- Write Data Channel ----------
    input  wire [31:0] WDATA,
    input  wire        WVALID,
    output reg         WREADY,

    // ---------- Write Response Channel ----------
    output reg  [1:0]  BRESP,
    output reg         BVALID,
    input  wire        BREADY,

    // ---------- Read Address Channel ----------
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output reg         ARREADY,

    // ---------- Read Data Channel ----------
    output reg  [31:0] RDATA,
    output reg  [1:0]  RRESP,
    output reg         RVALID,
    input  wire        RREADY
);

    // Internal memory: 4 registers (Addresses 0x00, 0x04, 0x08, 0x0C)
    reg [31:0] mem [3:0];

    // ---------- WRITE CHANNEL (Latch-Based, Independent) ----------
    reg aw_done;
    reg w_done;
    reg [31:0] latched_awaddr;
    reg [31:0] latched_wdata;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            AWREADY <= 1'b0;
            WREADY  <= 1'b0;
            BVALID  <= 1'b0;
            BRESP   <= 2'b00;
            aw_done <= 1'b0;
            w_done  <= 1'b0;
        end else begin
            // 1. Capture Address independently
            if (AWVALID && !AWREADY && !aw_done && !BVALID) begin
                AWREADY <= 1'b1;
                latched_awaddr <= AWADDR;
                aw_done <= 1'b1;
            end else begin
                AWREADY <= 1'b0;
            end

            // 2. Capture Data independently
            if (WVALID && !WREADY && !w_done && !BVALID) begin
                WREADY <= 1'b1;
                latched_wdata <= WDATA;
                w_done <= 1'b1;
            end else begin
                WREADY <= 1'b0;
            end

            // 3. Commit Write when BOTH are captured
            if (aw_done && w_done && !BVALID) begin
                BVALID <= 1'b1;
                
                // Address Decoding (Out of Range Check)
                // If address is less than 0x10, it fits in our 4 registers
                if (latched_awaddr < 32'h0000_0010) begin
                    mem[latched_awaddr[3:2]] <= latched_wdata;
                    BRESP <= 2'b00; // 00 = OKAY
                end else begin
                    BRESP <= 2'b11; // 11 = DECERR (Decode Error)
                end
                
                // Reset latches for the next transaction
                aw_done <= 1'b0;
                w_done  <= 1'b0;
            end 
            // 4. Close transaction when Master accepts receipt
            else if (BVALID && BREADY) begin
                BVALID <= 1'b0;
            end
        end
    end

    // ---------- READ CHANNEL (Address Checked) ----------
    localparam R_IDLE = 1'b0;
    localparam R_DATA = 1'b1;
    reg r_state;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ARREADY <= 1'b0;
            RVALID  <= 1'b0;
            RDATA   <= 32'h0;
            RRESP   <= 2'b00;
            r_state <= R_IDLE;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (ARVALID && !ARREADY) begin
                        ARREADY <= 1'b1;
                        
                        // Address Decoding (Out of Range Check)
                        if (ARADDR < 32'h0000_0010) begin
                            RDATA <= mem[ARADDR[3:2]];
                            RRESP <= 2'b00; // OKAY
                        end else begin
                            RDATA <= 32'h0;
                            RRESP <= 2'b11; // DECERR
                        end
                        r_state <= R_DATA;
                    end else begin
                        ARREADY <= 1'b0;
                    end
                end

                R_DATA: begin
                    ARREADY <= 1'b0;
                    if (!RVALID) begin
                        RVALID <= 1'b1;
                    end 
                    else if (RVALID && RREADY) begin
                        RVALID  <= 1'b0;
                        r_state <= R_IDLE;
                    end
                end
            endcase
        end
    end
endmodule