`include "uvm_macros.svh"

typedef enum { OP_WRITE, OP_READ, OP_INVALIDATE } prt_op_t;

class prt_transaction extends uvm_sequence_item;
  `uvm_object_utils(prt_transaction)

  // Operation type
  rand prt_op_t op;
  rand bit [$clog2(2)-1:0] slot;  
  rand int frame_length;
  rand bit [7:0] start_value;

  // Constraints
  constraint valid_frame_size { frame_length inside {[1:1518]}; } // 1-1518 bytes
  constraint valid_start_value { start_value inside {[8'h00:8'hFF]}; } // Any byte value

  // Ensure reads and invalidations happen on valid slots
  constraint valid_read_invalidate_slot {
    if (op == OP_READ || op == OP_INVALIDATE)
      slot inside {0, 1};
  }

  function new(string name = "prt_transaction");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    prt_transaction rhs_;
    if (!$cast(rhs_, rhs))
      `uvm_fatal("DO_COPY", "Cast failed in prt_transaction do_copy");
    op = rhs_.op;
    frame_length = rhs_.frame_length;
    start_value = rhs_.start_value;
    slot = rhs_.slot;
  endfunction

  virtual function string convert2string();
    return $sformatf("op: %s, frame_length: %0d, start_value: 0x%0h, slot: %0d",
                     op.name(), frame_length, start_value, slot);
  endfunction

endclass
