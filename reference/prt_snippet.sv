module PacketReferenceTable #(
    parameter DATA_WIDTH = 8,   // Byte-wide data
    parameter ADDR_WIDTH = 10,  // Addressing capability for BRAM
    parameter MAX_ENTRIES = 16  // Number of PRT entries
)(
    input  logic                clk,
    input  logic                rst_n,

    // Control Signals
    input  logic                write_en,       // Write enable for storing incoming frame
    input  logic [ADDR_WIDTH-1:0] write_addr,   // Address for storing incoming frame
    input  logic [DATA_WIDTH-1:0] write_data,   // Incoming frame data byte
    input  logic                frame_done,     // Marks completion of frame reception

    input  logic                read_en,        // Read enable for sending frame out
    input  logic [ADDR_WIDTH-1:0] read_addr,    // Address for reading stored frame
    output logic [DATA_WIDTH-1:0] read_data,    // Outgoing frame data byte
    output logic                frame_valid,    // Indicates frame is valid
    output logic                frame_complete, // Frame is fully received

    input  logic                invalidate_entry // Signal to invalidate an entry
);

    // Memory for storing frames (BRAM-like implementation)
    logic [DATA_WIDTH-1:0] frame_memory [0:MAX_ENTRIES-1][0:(1<<ADDR_WIDTH)-1];

    // Control registers for managing PRT entries
    logic [ADDR_WIDTH-1:0] num_bytes_rcvd [0:MAX_ENTRIES-1]; // Bytes received counter
    logic [ADDR_WIDTH-1:0] num_bytes_sent [0:MAX_ENTRIES-1]; // Bytes sent counter
    logic valid_entry [0:MAX_ENTRIES-1]; // Validity bit for entries
    logic frame_received [0:MAX_ENTRIES-1]; // Frame reception status

    // Write Logic (Storing incoming frame)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MAX_ENTRIES; i++) begin
                num_bytes_rcvd[i] <= '0;
                valid_entry[i] <= 1'b0;
                frame_received[i] <= 1'b0;
            end
        end else if (write_en) begin
            frame_memory[write_addr][num_bytes_rcvd[write_addr]] <= write_data;
            num_bytes_rcvd[write_addr] <= num_bytes_rcvd[write_addr] + 1;
            valid_entry[write_addr] <= 1'b1;
        end
        if (frame_done) begin
            frame_received[write_addr] <= 1'b1;  // Marks frame as fully received
        end
    end

    // Read Logic (Transmitting stored frame)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MAX_ENTRIES; i++) begin
                num_bytes_sent[i] <= '0;
            end
        end else if (read_en && valid_entry[read_addr]) begin
            read_data <= frame_memory[read_addr][num_bytes_sent[read_addr]];
            num_bytes_sent[read_addr] <= num_bytes_sent[read_addr] + 1;
        end
    end

    // Frame validity check
    assign frame_valid = valid_entry[read_addr];
    assign frame_complete = frame_received[read_addr];

    // Invalidate entry logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MAX_ENTRIES; i++) begin
                valid_entry[i] <= 1'b0;
            end
        end else if (invalidate_entry) begin
            valid_entry[read_addr] <= 1'b0;
        end
    end

endmodule
