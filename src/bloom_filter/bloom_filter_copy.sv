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
    IDLE
}