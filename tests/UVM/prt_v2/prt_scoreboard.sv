class prt_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(prt_scoreboard)

  // Storage for expected frame data
  bit [7:0] expected_data[2][$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void write(prt_transaction tr);
    case (tr.op)
      OP_WRITE: begin
        expected_data[tr.slot] = new[tr.frame_length];
        foreach (expected_data[tr.slot][i])
          expected_data[tr.slot][i] = tr.start_value + i;
      end

      OP_READ: begin
        if (expected_data[tr.slot].size() == 0)
          `uvm_error("SCOREBOARD", $sformatf("Attempted read from empty slot %0d", tr.slot))
        else begin
          `uvm_info("SCOREBOARD", $sformatf("Reading expected frame from slot %0d", tr.slot), UVM_MEDIUM);
        end
      end

      OP_INVALIDATE: begin
        expected_data[tr.slot].delete();
        `uvm_info("SCOREBOARD", $sformatf("Slot %0d invalidated", tr.slot), UVM_MEDIUM);
      end
    endcase
  endfunction
endclass
