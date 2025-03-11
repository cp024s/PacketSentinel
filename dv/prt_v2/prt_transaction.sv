`include "uvm_macros.svh"

typedef enum { OP_WRITE, OP_READ, OP_INVALIDATE } prt_op_t;

class prt_transaction extends uvm_sequence_item;
  `uvm_object_utils(prt_transaction)

  // Operation type
  prt_op_t op;

  // For write transactions
  int frame_length;       // number of bytes to write
  bit [7:0] start_value;  // starting data value

  // For read and invalidate transactions
  bit [$clog2(2)-1:0] slot;  // slot number

  // Constructor
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

  virtual function void convert2string(string &str);
    $sformat(str, "op: %0d, frame_length: %0d, start_value: 0x%0h, slot: %0d", op, frame_length, start_value, slot);
  endfunction

endclass
