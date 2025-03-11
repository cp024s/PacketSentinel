class prt_sequencer extends uvm_sequencer #(prt_transaction);
  `uvm_component_utils(prt_sequencer)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
