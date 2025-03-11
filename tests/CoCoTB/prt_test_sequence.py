import cocotb
import random
from cocotb.triggers import RisingEdge, Timer
from prt_scoreboard import Scoreboard
from prt_coverage import Coverage

# Global objects for coverage and scoreboard
scoreboard = Scoreboard()
coverage = Coverage()

async def write_frame(dut, slot, length, start_value):
    """Writes a frame into a given slot and logs the expected data for scoreboard/coverage."""
    dut._log.info(f"[WRITE] Writing {length} bytes into slot {slot} with start value 0x{start_value:02X}")
    
    # Issue start writing enable
    dut.EN_start_writing_prt_entry.value = 1
    await RisingEdge(dut.CLK)
    dut.EN_start_writing_prt_entry.value = 0
    # Wait for ready (one cycle pulse)
    await RisingEdge(dut.RDY_start_writing_prt_entry)
    # (Assume DUT chooses free slot; override if needed)
    selected_slot = int(dut.start_writing_prt_entry.value)
    if selected_slot != slot:
        dut._log.warning(f"Expected slot {slot}, but DUT chose slot {selected_slot}")
    
    # Write data: one byte per cycle
    expected_data = []
    for i in range(length):
        await RisingEdge(dut.CLK)
        dut.EN_write_prt_entry.value = 1
        data = (start_value + i) & 0xFF
        dut.write_prt_entry_data.value = data
        expected_data.append(data)
        await RisingEdge(dut.CLK)
        dut.EN_write_prt_entry.value = 0
    # Issue finish writing enable
    await RisingEdge(dut.CLK)
    dut.EN_finish_writing_prt_entry.value = 1
    await RisingEdge(dut.CLK)
    dut.EN_finish_writing_prt_entry.value = 0
    await RisingEdge(dut.RDY_finish_writing_prt_entry)
    
    # Update scoreboard and coverage
    scoreboard.store_frame(slot, expected_data)
    coverage.record_frame_size(length)
    coverage.record_slot_usage(slot)
    
    dut._log.info(f"[WRITE] Completed write into slot {slot}")

async def read_frame(dut, slot, expected_length):
    """Reads a frame from a given slot and compares with expected data from scoreboard."""
    dut._log.info(f"[READ] Reading frame from slot {slot} expecting {expected_length} bytes")
    received = []
    
    # Issue read-start enable
    dut.start_reading_prt_entry_slot.value = slot
    dut.EN_start_reading_prt_entry.value = 1
    await RisingEdge(dut.CLK)
    dut.EN_start_reading_prt_entry.value = 0
    await RisingEdge(dut.RDY_start_reading_prt_entry)
    
    # Read bytes until complete flag is asserted or until expected_length cycles pass
    for i in range(expected_length + 5):
        await RisingEdge(dut.CLK)
        dut.EN_read_prt_entry.value = 1
        await RisingEdge(dut.CLK)
        dut.EN_read_prt_entry.value = 0
        read_val = int(dut.read_prt_entry.value) & 0x1FF  # 9 bits: [8]=complete flag, [7:0]=data
        complete = (read_val >> 8) & 0x1
        data = read_val & 0xFF
        received.append(data)
        dut._log.info(f"[READ] Cycle {i}: Data=0x{data:02X}, Complete={complete}")
        if complete:
            break
    scoreboard.check_frame(slot, received[:expected_length])
    return received

async def invalidate_slot(dut, slot):
    """Invalidates the given slot."""
    dut._log.info(f"[INVALIDATE] Invalidating slot {slot}")
    dut.invalidate_prt_entry_slot.value = slot
    dut.EN_invalidate_prt_entry.value = 1
    await RisingEdge(dut.CLK)
    dut.EN_invalidate_prt_entry.value = 0
    await RisingEdge(dut.RDY_invalidate_prt_entry)
    scoreboard.invalidate_frame(slot)
    coverage.record_slot_usage(slot)  # record that we used this slot for invalidation
    dut._log.info(f"[INVALIDATE] Slot {slot} invalidated")

async def test_write_read(dut):
    """Simple test: write a frame then read it back."""
    slot = 0
    length = 20
    start_value = random.randint(0, 0xFF)
    await write_frame(dut, slot, length, start_value)
    await Timer(10, units="ns")
    await read_frame(dut, slot, length)

async def test_full_table(dut):
    """Fill all slots and then attempt an extra write (should fail gracefully)."""
    dut._log.info("[TEST] Running full table test")
    # Write to slot 0 and slot 1
    await write_frame(dut, 0, 15, 0x10)
    await write_frame(dut, 1, 15, 0x20)
    # Now try writing another frame – no free slot expected.
    dut.EN_start_writing_prt_entry.value = 1
    await RisingEdge(dut.CLK)
    dut.EN_start_writing_prt_entry.value = 0
    # Check if ready signal is not asserted
    if int(dut.RDY_start_writing_prt_entry.value) == 1:
        dut._log.error("[TEST] Unexpected ready pulse when no slot should be free!")
    else:
        dut._log.info("[TEST] No free slot as expected")
    await Timer(10, units="ns")

async def test_invalid_read(dut):
    """Attempt to read from an invalid slot."""
    dut._log.info("[TEST] Running invalid read test")
    # Invalidate slot 0 then attempt to read from it
    await invalidate_slot(dut, 0)
    dut.start_reading_prt_entry_slot.value = 0
    dut.EN_start_reading_prt_entry.value = 1
    await RisingEdge(dut.CLK)
    dut.EN_start_reading_prt_entry.value = 0
    if int(dut.RDY_start_reading_prt_entry.value) == 1:
        dut._log.error("[TEST] Unexpected ready pulse for read from an invalid slot!")
    else:
        dut._log.info("[TEST] Correctly no ready pulse for invalid slot read")
    await Timer(10, units="ns")

async def test_stress_randomized(dut, num_iterations=10):
    """Stress test with randomized mixed operations."""
    dut._log.info("[STRESS] Starting randomized stress test")
    for i in range(num_iterations):
        op = random.choice(["write", "read", "invalidate"])
        if op == "write":
            # Only attempt write if a free slot exists
            if int(dut.is_prt_slot_free.value) == 1:
                slot = 0 if (not scoreboard.has_frame(0)) else 1
                length = random.randint(1, 50)
                start_value = random.randint(0, 0xFF)
                dut._log.info(f"[STRESS] Iteration {i}: WRITE on slot {slot}")
                await write_frame(dut, slot, length, start_value)
            else:
                dut._log.info(f"[STRESS] Iteration {i}: No free slot for WRITE")
        elif op == "read":
            # Only attempt read if there is an expected frame
            available_slots = [s for s in [0,1] if scoreboard.has_frame(s)]
            if available_slots:
                slot = random.choice(available_slots)
                length = scoreboard.get_frame_length(slot)
                dut._log.info(f"[STRESS] Iteration {i}: READ on slot {slot}")
                await read_frame(dut, slot, length)
            else:
                dut._log.info(f"[STRESS] Iteration {i}: No frame available for READ")
        elif op == "invalidate":
            # Invalidate a slot if it has a frame
            available_slots = [s for s in [0,1] if scoreboard.has_frame(s)]
            if available_slots:
                slot = random.choice(available_slots)
                dut._log.info(f"[STRESS] Iteration {i}: INVALIDATE slot {slot}")
                await invalidate_slot(dut, slot)
            else:
                dut._log.info(f"[STRESS] Iteration {i}: No slot available for INVALIDATE")
        await Timer(10, units="ns")
    dut._log.info("[STRESS] Randomized stress test completed")

async def run_all_tests(dut):
    """Runs all test scenarios sequentially and concurrently where possible."""
    await test_write_read(dut)
    await test_full_table(dut)
    await test_invalid_read(dut)
    await test_stress_randomized(dut, num_iterations=20)
    coverage.report()
