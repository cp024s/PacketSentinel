import cocotb
from cocotb.triggers import RisingEdge, Timer
from prt_test_sequences import run_all_tests
import logging

@cocotb.test()
async def prt_full_test(dut):
    dut._log.setLevel(logging.DEBUG)
    cocotb.log.info("🚀 Enhanced CoCoTB Testbench for PRT started!")

    # Reset sequence
    dut.RST_N.value = 0
    await Timer(20, units="ns")
    dut.RST_N.value = 1
    await Timer(10, units="ns")
    
    # Run all test sequences (they include randomized and stress tests)
    await run_all_tests(dut)
    
    cocotb.log.info("✅ Enhanced CoCoTB Verification Completed!")
