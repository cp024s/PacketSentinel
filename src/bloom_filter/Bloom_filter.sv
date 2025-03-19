// bloom_filter_optimized.sv
// Optimized Bloom filter module that instantiates the separate BRAM module.
// It processes separate 32-bit source and destination IP addresses and a 16-bit tag.
// The module computes hash indices (using a simplified Jenkins hash function) for each IP,
// reads the corresponding bits from the BRAM, and if both bits are set,
// outputs the concatenated header and tag. If not, it updates the BRAM.
module bloom_filter_optimized #(
  parameter BIT_ARRAY_SIZE = 1024,
  parameter HASH_WIDTH     = $clog2(BIT_ARRAY_SIZE)
)(
  input  logic                clk,
  input  logic                rst_n,       // Active-low reset
  input  logic                enable,      // New input valid signal
  input  logic [31:0]         src_ip,      // Source IP address
  input  logic [31:0]         dest_ip,     // Destination IP address
  input  logic [15:0]         tag,         // Reference tag for PRT
  // Outputs: if both hash indices are set, the Bloom filter flags safe and outputs the header and tag.
  output logic                safe,        // Indicates a match (both bits set)
  output logic                output_valid,// Indicates output header and tag are valid
  output logic [63:0]         header,      // Combined header: concatenation of src_ip and dest_ip
  output logic [15:0]         out_tag,     // Forwarded tag (unchanged)
  output logic                busy         // Busy flag when processing is ongoing
);

  //-------------------------------------------------------------------------
  // FSM Declaration
  //-------------------------------------------------------------------------
  typedef enum logic [2:0] {
    IDLE,
    CAPTURE_HASH,  // Latch inputs and compute hash indices concurrently
    READ,          // Drive BRAM addresses; wait for synchronous read
    DECIDE,        // Check BRAM outputs and update BRAM if needed
    OUTPUT_STATE   // Generate output and return to IDLE
  } state_t;
  state_t state, next_state;

  //-------------------------------------------------------------------------
  // Registers for latched inputs and computed hashes
  //-------------------------------------------------------------------------
  logic [31:0] latched_src_ip, latched_dest_ip;
  logic [15:0] latched_tag;
  logic [HASH_WIDTH-1:0] hash_src, hash_dest;

  //-------------------------------------------------------------------------
  // BRAM Interface Signals
  //-------------------------------------------------------------------------
  logic [HASH_WIDTH-1:0] bram_addr_src, bram_addr_dest;
  logic                  we_src, we_dest;
  logic                  bram_data_src, bram_data_dest;

  //-------------------------------------------------------------------------
  // Output Registers
  //-------------------------------------------------------------------------
  logic safe_reg, output_valid_reg;
  logic [63:0] header_reg;
  logic [15:0] out_tag_reg;

  assign busy         = (state != IDLE);
  assign safe         = safe_reg;
  assign output_valid = output_valid_reg;
  assign header       = header_reg;
  assign out_tag      = out_tag_reg;

  //-------------------------------------------------------------------------
  // Simplified Jenkins Hash Function
  //-------------------------------------------------------------------------
  function automatic [HASH_WIDTH-1:0] jenkins_hash (input logic [31:0] data);
    logic [31:0] hash;
    begin
      hash = 0;
      hash = hash + data[7:0];
      hash = hash + (hash << 10);
      hash = hash ^ (hash >> 6);
      
      hash = hash + data[15:8];
      hash = hash + (hash << 10);
      hash = hash ^ (hash >> 6);
      
      hash = hash + data[23:16];
      hash = hash + (hash << 10);
      hash = hash ^ (hash >> 6);
      
      hash = hash + data[31:24];
      hash = hash + (hash << 10);
      hash = hash ^ (hash >> 6);
      
      hash = hash + (hash << 3);
      hash = hash ^ (hash >> 11);
      hash = hash + (hash << 15);
      
      jenkins_hash = hash[HASH_WIDTH-1:0];
    end
  endfunction

  //-------------------------------------------------------------------------
  // FSM: Sequential Logic (State and Data Updates)
  //-------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state           <= IDLE;
      latched_src_ip  <= 32'd0;
      latched_dest_ip <= 32'd0;
      latched_tag     <= 16'd0;
      hash_src        <= {HASH_WIDTH{1'b0}};
      hash_dest       <= {HASH_WIDTH{1'b0}};
      bram_addr_src   <= {HASH_WIDTH{1'b0}};
      bram_addr_dest  <= {HASH_WIDTH{1'b0}};
      safe_reg        <= 1'b0;
      output_valid_reg<= 1'b0;
      header_reg      <= 64'd0;
      out_tag_reg     <= 16'd0;
      we_src          <= 1'b0;
      we_dest         <= 1'b0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          output_valid_reg <= 1'b0;
          we_src <= 1'b0;
          we_dest <= 1'b0;
          if (enable) begin
            // Latch inputs and compute hash indices immediately.
            latched_src_ip  <= src_ip;
            latched_dest_ip <= dest_ip;
            latched_tag     <= tag;
            hash_src        <= jenkins_hash(src_ip);
            hash_dest       <= jenkins_hash(dest_ip);
          end
        end
        
        CAPTURE_HASH: begin
          // No extra data capture needed; transition occurs in next cycle.
        end
        
        READ: begin
          // Drive BRAM addresses.
          bram_addr_src  <= hash_src;
          bram_addr_dest <= hash_dest;
        end
        
        DECIDE: begin
          // Check the BRAM read bits.
          if (bram_data_src & bram_data_dest)
            safe_reg <= 1'b1;
          else begin
            safe_reg <= 1'b0;
            if (!bram_data_src)
              we_src <= 1'b1;  // Write '1' if missing for source IP
            if (!bram_data_dest)
              we_dest <= 1'b1; // Write '1' if missing for destination IP
          end
        end
        
        OUTPUT_STATE: begin
          // Prepare outputs.
          header_reg       <= {latched_src_ip, latched_dest_ip};
          out_tag_reg      <= latched_tag;
          output_valid_reg <= 1'b1;
          // Clear write enables.
          we_src <= 1'b0;
          we_dest <= 1'b0;
        end
        
        default: ;
      endcase
    end
  end
  
  //-------------------------------------------------------------------------
  // FSM: Next-State Combinational Logic
  //-------------------------------------------------------------------------
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (enable)
          next_state = CAPTURE_HASH;
      end
      
      CAPTURE_HASH: begin
        next_state = READ;
      end
      
      READ: begin
        // One cycle delay for synchronous BRAM read.
        next_state = DECIDE;
      end
      
      DECIDE: begin
        next_state = OUTPUT_STATE;
      end
      
      OUTPUT_STATE: begin
        next_state = IDLE;
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  //-------------------------------------------------------------------------
  // Instantiation of the Separate BRAM Module
  //-------------------------------------------------------------------------
  bloom_bram #(
    .BIT_ARRAY_SIZE(BIT_ARRAY_SIZE),
    .DATA_WIDTH(1),
    .ADDR_WIDTH(HASH_WIDTH)
  ) u_bram (
    .clk(clk),
    .rst_n(rst_n),
    // Port 0: for source IP hash
    .addr0(bram_addr_src),
    .we0(we_src),
    .din0(1'b1),
    .dout0(bram_data_src),
    // Port 1: for destination IP hash
    .addr1(bram_addr_dest),
    .we1(we_dest),
    .din1(1'b1),
    .dout1(bram_data_dest)
  );

endmodule
