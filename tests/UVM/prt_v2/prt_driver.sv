
class prt_driver extends uvm_driver #(prt_transaction);
  `uvm_component_utils(prt_driver)
  
  // Virtual interface handle
  virtual prt_if vif;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual prt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in prt_driver");
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    prt_transaction tr;
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(), $sformatf("Driver received transaction: %s", tr.convert2string()), UVM_MEDIUM);
      case (tr.op)
        OP_WRITE: begin
          // --- Write Transaction ---
          // Step 1: Issue write-start enable
          vif.EN_start_writing_prt_entry <= 1;
          @(posedge vif.clk);
          vif.EN_start_writing_prt_entry <= 0;
          wait(vif.RDY_start_writing_prt_entry == 1);
          `uvm_info(get_type_name(), $sformatf("Write Start acknowledged, slot = %0d", vif.start_writing_prt_entry), UVM_MEDIUM);
          // Step 2: Drive write data for frame_length bytes
          for (int i = 0; i < tr.frame_length; i++) begin
            @(posedge vif.clk);
            vif.EN_write_prt_entry <= 1;
            vif.write_prt_entry_data <= tr.start_value + i;
          end
          @(posedge vif.clk);
          vif.EN_write_prt_entry <= 0;
          // Step 3: Issue write-finish enable
          @(posedge vif.clk);
          vif.EN_finish_writing_prt_entry <= 1;
          @(posedge vif.clk);
          vif.EN_finish_writing_prt_entry <= 0;
          wait(vif.RDY_finish_writing_prt_entry == 1);
          `uvm_info(get_type_name(), "Write Finish acknowledged", UVM_MEDIUM);
        end
        OP_READ: begin
          // --- Read Transaction ---
          // Step 1: Issue read-start enable with slot specified.
          vif.start_reading_prt_entry_slot <= tr.slot;
          vif.EN_start_reading_prt_entry <= 1;
          @(posedge vif.clk);
          vif.EN_start_reading_prt_entry <= 0;
          wait(vif.RDY_start_reading_prt_entry == 1);
          `uvm_info(get_type_name(), "Read Start acknowledged", UVM_MEDIUM);
          // Step 2: Drive read enable for frame_length cycles (plus extra to observe complete flag)
          for (int i = 0; i < tr.frame_length + 5; i++) begin
            @(posedge vif.clk);
            vif.EN_read_prt_entry <= 1;
            @(posedge vif.clk);
            vif.EN_read_prt_entry <= 0;
            `uvm_info(get_type_name(), $sformatf("Read data: 0x%0h, Complete: %b", 
                       vif.read_prt_entry[7:0], vif.read_prt_entry[8]), UVM_LOW);
            if (vif.read_prt_entry[8] == 1)
              break;
          end
        end
        OP_INVALIDATE: begin
          // --- Invalidate Transaction ---
          vif.invalidate_prt_entry_slot <= tr.slot;
          vif.EN_invalidate_prt_entry <= 1;
          @(posedge vif.clk);
          vif.EN_invalidate_prt_entry <= 0;
          wait(vif.RDY_invalidate_prt_entry == 1);
          `uvm_info(get_type_name(), $sformatf("Invalidation acknowledged for slot %0d", tr.slot), UVM_MEDIUM);
        end
        default: begin
          `uvm_error(get_type_name(), "Unknown operation in transaction");
        end
      endcase
      seq_item_port.item_done();
    end
  endtask
  
endclass
