class prt_monitor extends uvm_monitor;
  `uvm_component_utils(prt_monitor)
  
  virtual prt_if vif;
  uvm_analysis_port #(prt_transaction) ap;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual prt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in prt_monitor");
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    prt_transaction trans;
    // In a real testbench, the monitor would sample the interface and convert activity
    // into transactions that are forwarded to the scoreboard. Here we simply log some signals.
    forever begin
      @(posedge vif.clk);
      `uvm_info(get_type_name(), $sformatf("Monitor: EN_start_write=%0d, RDY_start_write=%0d, EN_write=%0d, RDY_write=%0d",
          vif.EN_start_writing_prt_entry, vif.RDY_start_writing_prt_entry, vif.EN_write_prt_entry, vif.RDY_write_prt_entry), UVM_LOW);
    end
  endtask
  
endclass
