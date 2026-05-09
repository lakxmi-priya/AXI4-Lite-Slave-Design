
module axi_lite_slave (
    // ---------- Global Signals ----------
    input  wire        ACLK,       // Clock (all channels use rising edge)
    input  wire        ARESETn,    // Active-low reset

    // ---------- Write Address Channel ----------
    input  wire [31:0] AWADDR,     // Write address from master
    input  wire        AWVALID,    // Master says "address is valid"
    output reg         AWREADY,    // Slave says "I'm ready to accept address"

    // ---------- Write Data Channel ----------
    input  wire [31:0] WDATA,      // Write data from master
    input  wire        WVALID,     // Master says "data is valid"
    output reg         WREADY,     // Slave says "I'm ready to accept data"

    // ---------- Write Response Channel ----------
    output reg  [1:0]  BRESP,      // Write response status (00 = OKAY)
    output reg         BVALID,     // Slave says "response is valid"
    input  wire        BREADY,     // Master says "I'm ready for response"

    // ---------- Read Address Channel ----------
    input  wire [31:0] ARADDR,     // Read address from master
    input  wire        ARVALID,    // Master says "address is valid"
    output reg         ARREADY,    // Slave says "I'm ready to accept address"

    // ---------- Read Data Channel ----------
    output reg  [31:0] RDATA,      // Read data from slave to master
    output reg  [1:0]  RRESP,      // Read response status (00 = OKAY)
    output reg         RVALID,     // Slave says "data is valid"
    input  wire        RREADY      // Master says "I'm ready for data"
);

    // Internal memory: 4 registers, each 32 bits
    reg [31:0] mem [3:0];

    // ---------- Write FSM States ----------
    localparam W_IDLE = 1'b0;
    localparam W_RESP = 1'b1;
    reg w_state;

    // ---------- Write Channel Logic ----------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            // Reset: force slave outputs to inactive
            AWREADY <= 1'b0;
            WREADY  <= 1'b0;
            BVALID  <= 1'b0;
            BRESP   <= 2'b00;
            w_state <= W_IDLE;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (AWVALID && WVALID) begin
                        // Both address and data are valid → handshake now
                        AWREADY <= 1'b1;
                        WREADY  <= 1'b1;
                        // Store data into the register selected by address bits [3:2]
                        mem[AWADDR[3:2]] <= WDATA;
                        // Move to response phase
                        w_state <= W_RESP;
                    end else begin
                        // Not ready yet → keep waiting
                        AWREADY <= 1'b0;
                        WREADY  <= 1'b0;
                    end
                end

                W_RESP: begin
                    // Send the write response
                    BVALID <= 1'b1;
                    BRESP  <= 2'b00;   // 00 = OKAY (success)
                    // Make sure we do NOT accept new address/data during response
                    AWREADY <= 1'b0;
                    WREADY  <= 1'b0;
                    if (BREADY) begin
                        // Master accepted response → finish
                        BVALID  <= 1'b0;
                        w_state <= W_IDLE;
                    end
                end

                default: begin
                    // Safety net
                    AWREADY <= 1'b0;
                    WREADY  <= 1'b0;
                    BVALID  <= 1'b0;
                    w_state <= W_IDLE;
                end
            endcase
        end
    end

    // ---------- Read FSM States ----------
    localparam R_IDLE = 1'b0;
    localparam R_DATA = 1'b1;
    reg r_state;

    // ---------- Read Channel Logic ----------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            // Reset: force slave outputs to inactive
            ARREADY <= 1'b0;
            RVALID  <= 1'b0;
            RDATA   <= 32'h0;
            RRESP   <= 2'b00;
            r_state <= R_IDLE;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (ARVALID) begin
                        // Master requests a read → accept the address
                        ARREADY <= 1'b1;
                        // Fetch the data from the register selected by bits [3:2]
                        RDATA <= mem[ARADDR[3:2]];
                        RRESP <= 2'b00;     // OKAY
                        r_state <= R_DATA;
                    end else begin
                        ARREADY <= 1'b0;
                    end
                end

                R_DATA: begin
                    // Present read data to the master
                    RVALID <= 1'b1;
                    // Keep ARREADY low during data phase
                    ARREADY <= 1'b0;
                    if (RREADY) begin
                        // Master accepted the data → end transaction
                        RVALID  <= 1'b0;
                        r_state <= R_IDLE;
                    end
                end

                default: begin
                    // Safety net
                    ARREADY <= 1'b0;
                    RVALID  <= 1'b0;
                    r_state <= R_IDLE;
                end
            endcase
        end
    end
endmodule