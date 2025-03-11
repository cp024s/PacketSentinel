class prt_test extends uvm_test;
  `uvm_component_utils(prt_test)
  
  prt_env env;
  prt_sequencer seqr;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = prt_env::type_id::create("env", this);
    seqr = prt_sequencer::type_id::create("seqr", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    prt_transaction tr;
    phase.raise_objection(this);
    
    // --- Test Case 1: Write a 10-byte frame ---
    tr = prt_transaction::type_id::create("tr1");
    tr.op = OP_WRITE;
    tr.frame_length = 10;
    tr.start_value = 8'hA0;
    seqr.start(tr);
    
    // --- Test Case 2: Read the 10-byte frame from slot 0 ---
    tr = prt_transaction::type_id::create("tr2");
    tr.op = OP_READ;
    tr.slot = 0; // read from slot 0
    tr.frame_length = 10;
    seqr.start(tr);
    
    // --- Test Case 3: Invalidate slot 0 ---
    tr = prt_transaction::type_id::create("tr3");
    tr.op = OP_INVALIDATE;
    tr.slot = 0;
    seqr.start(tr);
    
    // --- Test Case 4: Write two frames sequentially to fill both slots ---
    tr = prt_transaction::type_id::create("tr4");
    tr.op = OP_WRITE;
    tr.frame_length = 5;
    tr.start_value = 8'h10;
    seqr.start(tr);
    
    tr = prt_transaction::type_id::create("tr5");
    tr.op = OP_WRITE;
    tr.frame_length = 7;
    tr.start_value = 8'h20;
    seqr.start(tr);
    
    // --- Test Case 5: Attempt a write when no free slot is available ---
    tr = prt_transaction::type_id::create("tr6");
    tr.op = OP_WRITE;
    tr.frame_length = 4;
    tr.start_value = 8'h30;
    seqr.start(tr);
    
    // --- Test Case 6: Attempt to read from an invalid slot (slot 0) ---
    tr = prt_transaction::type_id::create("tr7");
    tr.op = OP_READ;
    tr.slot = 0; // assume slot 0 is invalid now
    tr.frame_length = 5;
    seqr.start(tr);
    
    // --- Test Case 7: Write a minimal 1-byte frame and read it ---
    tr = prt_transaction::type_id::create("tr8");
    tr.op = OP_WRITE;
    tr.frame_length = 1;
    tr.start_value = 8'h55;
    seqr.start(tr);
    
    tr = prt_transaction::type_id::create("tr9");
    tr.op = OP_READ;
    tr.slot = 0; // assume available slot is 0
    tr.frame_length = 1;
    seqr.start(tr);
    
    phase.drop_objection(this);
  endtask
  
endclass
