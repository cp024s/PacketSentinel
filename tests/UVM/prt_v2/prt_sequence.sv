class prt_sequence extends uvm_sequence #(prt_transaction);
  `uvm_object_utils(prt_sequence)

  function new(string name = "prt_sequence");
    super.new(name);
  endfunction

  virtual task body();
    prt_transaction tr;

    // Generate 20 random transactions
    repeat (20) begin
      tr = prt_transaction::type_id::create("tr");
      if (!tr.randomize())
        `uvm_error("SEQUENCE", "Randomization failed for transaction");
      
      `uvm_info(get_type_name(), $sformatf("Generated Transaction: %s", tr.convert2string()), UVM_MEDIUM);
      
      start_item(tr);
      finish_item(tr);
    end
  endtask
endclass
