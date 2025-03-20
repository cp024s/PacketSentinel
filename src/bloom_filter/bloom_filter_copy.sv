module bloom_filter (
    parameter BIT_ARRAY_SIZE =
    parameter HASH_WIDTH     = $clog2(BIT_ARRAY_SIZE)
)(
    input logic                 clk,
    input logic                 rst_n;
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
)

typedef enum logc [2:0] {
    IDLE,
    CAPTURE_HASH,
    BRAM_READ,
    CHECK_MATCH
    GENERTE_OUTPUT
} State_t present_state, next_state;

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

