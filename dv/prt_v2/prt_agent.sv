class prt_agent extends uvm_agent;
  `uvm_component_utils(prt_agent)
  
  prt_sequencer sequencer;
  prt_driver driver;
  prt_monitor monitor;
  
  virtual prt_if vif;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = prt_sequencer::type_id::create("sequencer", this);
    driver    = prt_driver::type_id::create("driver", this);
    monitor   = prt_monitor::type_id::create("monitor", this);
    if (!uvm_config_db#(virtual prt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in prt_agent");
    uvm_config_db#(virtual prt_if)::set(this, "driver", "vif", vif);
    uvm_config_db#(virtual prt_if)::set(this, "monitor", "vif", vif);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
  
endclass
