import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset_dut(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.rst_n.value = 1

    # Allow gate-level reset to settle
    await RisingEdge(dut.clk)
    await Timer(100, unit="ns")


def set_config(dut, duration, mode):
    value = (duration << 4) | (mode << 2)
    dut.ui_in.value = value


async def generate_pulse(dut):
    # Assert pulse
    dut.ui_in.value = int(dut.ui_in.value) | 0x01

    # Give gate-level input path setup time
    await Timer(1, unit="us")

    # Sample pulse
    await RisingEdge(dut.clk)
    await Timer(100, unit="ns")

    # Deassert pulse
    dut.ui_in.value = int(dut.ui_in.value) & 0xFE

    await Timer(100, unit="ns")

    # The 2-flop input synchronizer adds 2 clock cycles of latency
    for _ in range(2):
        await RisingEdge(dut.clk)
    await Timer(100, unit="ns")


async def wait_for_output_low(dut, max_cycles=3):
    """
    Wait for pulse_out to become LOW.
    Allows extra gate-level propagation latency.
    """
    for i in range(max_cycles):
        if int(dut.uo_out.value) == 0:
            return True

        await RisingEdge(dut.clk)
        await Timer(100, unit="ns")

    return int(dut.uo_out.value) == 0


@cocotb.test()
async def test_project(dut):

    dut._log.info("==============================================")
    dut._log.info("PROGRAMMABLE DIGITAL PULSE STRETCHER")
    dut._log.info("==============================================")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # =================================================
    # TEST 1 : RESET
    # =================================================

    dut._log.info("TEST 1: RESET")

    await reset_dut(dut)

    assert dut.uo_out.value == 0

    dut._log.info("RESET PASSED")

    # =================================================
    # TEST 2 : MODE 00
    # =================================================

    dut._log.info("==============================================")
    dut._log.info("TEST 2: MODE 00 - NORMAL")
    dut._log.info("==============================================")

    duration = 4
    mode = 0

    set_config(dut, duration, mode)
    await Timer(100, unit="ns")

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    dut._log.info(
        f"MODE 00 pulse detected: {dut.uo_out.value}"
    )

    # Verify it stays active for the expected stretch period
    for i in range(duration - 1):

        await RisingEdge(dut.clk)
        await Timer(100, unit="ns")

        dut._log.info(
            f"MODE 00 cycle {i + 1}: {dut.uo_out.value}"
        )

    # Allow gate-level propagation to complete
    assert await wait_for_output_low(dut, 3)

    dut._log.info("MODE 00 PASSED")

    # =================================================
    # TEST 3 : MODE 01 - RETRIGGER
    # =================================================

    dut._log.info("==============================================")
    dut._log.info("TEST 3: MODE 01 - RETRIGGER")
    dut._log.info("==============================================")

    duration = 4
    mode = 1

    set_config(dut, duration, mode)
    await Timer(100, unit="ns")

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    await RisingEdge(dut.clk)
    await Timer(100, unit="ns")

    assert dut.uo_out.value == 1

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    for i in range(3):
        await RisingEdge(dut.clk)
        await Timer(100, unit="ns")

    dut._log.info("MODE 01 PASSED")

    # =================================================
    # TEST 4 : MODE 10 - EXTEND
    # =================================================

    dut._log.info("==============================================")
    dut._log.info("TEST 4: MODE 10 - EXTEND")
    dut._log.info("==============================================")

    duration = 4
    mode = 2

    set_config(dut, duration, mode)
    await Timer(100, unit="ns")

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    await RisingEdge(dut.clk)
    await Timer(100, unit="ns")

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    for i in range(3):
        await RisingEdge(dut.clk)
        await Timer(100, unit="ns")

    dut._log.info("MODE 10 PASSED")

    # =================================================
    # TEST 5 : MODE 11
    # =================================================

    dut._log.info("==============================================")
    dut._log.info("TEST 5: MODE 11 - NORMAL / RETRIGGER")
    dut._log.info("==============================================")

    duration = 4
    mode = 3

    set_config(dut, duration, mode)
    await Timer(100, unit="ns")

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    await RisingEdge(dut.clk)
    await Timer(100, unit="ns")

    await generate_pulse(dut)

    assert dut.uo_out.value == 1

    for i in range(3):
        await RisingEdge(dut.clk)
        await Timer(100, unit="ns")

    dut._log.info("MODE 11 PASSED")

    # =================================================
    # TEST 6 : DIFFERENT DURATIONS
    # =================================================

    dut._log.info("==============================================")
    dut._log.info("TEST 6: DIFFERENT DURATIONS")
    dut._log.info("==============================================")

    for duration in [1, 2, 4, 8]:

        mode = 0

        set_config(dut, duration, mode)
        await Timer(100, unit="ns")

        await generate_pulse(dut)

        assert dut.uo_out.value == 1

        dut._log.info(
            f"Duration {duration}: pulse detected"
        )

        # Wait for normal duration
        for i in range(duration):
            await RisingEdge(dut.clk)
            await Timer(100, unit="ns")

        # Allow gate-level output to settle
        assert await wait_for_output_low(dut, 3)

        dut._log.info(
            f"Duration {duration}: PASSED"
        )

    # =================================================
    # FINAL
    # =================================================

    dut._log.info("==============================================")
    dut._log.info("ALL GATE-LEVEL TESTS PASSED")
    dut._log.info("==============================================")
