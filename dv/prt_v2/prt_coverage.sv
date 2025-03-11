class prt_coverage extends uvm_subscriber #(prt_transaction);
  `uvm_component_utils(prt_coverage)

  covergroup prt_cg;
    coverpoint item.op {
      bins write = {OP_WRITE};
      bins read  = {OP_READ};
      bins invalidate = {OP_INVALIDATE};
    }

    coverpoint item.frame_length {
      bins small_frames = {[1:64]};
      bins medium_frames = {[65:512]};
      bins large_frames = {[513:1518]};
    }

    coverpoint item.slot {
      bins slot0 = {0};
      bins slot1 = {1};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    prt_cg = new();
  endfunction

  virtual function void write(prt_transaction t);
    prt_cg.sample();
  endfunction
endclass
