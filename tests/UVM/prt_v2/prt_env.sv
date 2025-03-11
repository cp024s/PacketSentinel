class prt_env extends uvm_env;
  `uvm_component_utils(prt_env)
  
  prt_agent agent;
  // A scoreboard can be added here for comparison.
  
  virtual prt_if vif;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = prt_agent::type_id::create("agent", this);
    if (!uvm_config_db#(virtual prt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in prt_env");
    uvm_config_db#(virtual prt_if)::set(this, "agent", "vif", vif);
  endfunction
  
endclass
