# SPI Master Controller in Verilog

A synthesizable **Serial Peripheral Interface (SPI) Master** implemented in Verilog HDL and verified using a self-checking testbench in Icarus Verilog. Waveforms can be inspected using GTKWave.

## Overview

This project implements a basic SPI master capable of transmitting and receiving 8-bit data over a single SPI bus. It uses **SPI Mode 0**, with MSB-first transmission and full-duplex communication.

The design uses a 100 MHz system clock and generates a 1 MHz SPI clock using a clock divider.

### Features

- SPI Master implementation in Verilog HDL
- SPI Mode 0 (CPOL = 0, CPHA = 0)
- 8-bit data transfers
- MSB-first transmission
- Full-duplex communication using MOSI and MISO
- Active-low chip select (`CS_N`)
- Clock divider for SPI clock generation
- Controller interface with `start`, `busy`, and `done` signals
- Self-checking testbench with five test cases
- VCD waveform generation for GTKWave analysis

## Architecture

The controller uses a finite state machine (FSM) to manage transaction setup, data transfer, and completion.

```text
                  SPI Master
             +-------------------+
 start ------>|                   |
 tx_data ---->|   Control FSM     |
 clk -------->|   Clock Divider   |
 reset ------>|   TX Shift Reg.   |---- MOSI
              |   RX Shift Reg.   |<--- MISO
              |                   |---- SCLK
              |                   |---- CS_N
              +-------------------+
                    |       |
                   busy    done
```

### SPI bus signals

| Signal | Direction | Description |
|---|---|---|
| `SCLK` | Output | SPI serial clock |
| `MOSI` | Output | Master Out, Slave In |
| `MISO` | Input | Master In, Slave Out |
| `CS_N` | Output | Active-low slave select |

### Controller interface

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | 100 MHz system clock |
| `reset` | Input | Resets the controller |
| `start` | Input | Requests a new transfer |
| `tx_data[7:0]` | Input | Byte to transmit |
| `rx_data[7:0]` | Output | Received byte |
| `busy` | Output | Indicates an active transfer |
| `done` | Output | Pulses when the transfer completes |

## SPI Mode 0 timing

The controller uses the following timing convention:

- `CPOL = 0`: SCLK idles LOW.
- `CPHA = 0`: Data is sampled on rising SCLK edges.
- MOSI data is prepared or shifted on falling SCLK edges.
- The most significant bit is transmitted first.
- `CS_N` goes LOW to select the slave and returns HIGH after the transfer.

For each 8-bit transaction, the master generates eight rising edges and eight falling edges.

## Clock generation

The system clock frequency is 100 MHz, corresponding to a 10 ns clock period.

The SCLK output toggles after every 50 system-clock cycles.

\[
f_{\mathrm{SCLK}}=\frac{f_{\mathrm{clk}}}{2D}
\]

Where:
- \(f_{\mathrm{clk}} = 100\,\text{MHz}\)
- \(D = 50\)

Therefore,

\[
f_{\mathrm{SCLK}}=\frac{100\,\text{MHz}}{2\times50}
=1\,\text{MHz}
\]

The resulting SCLK has a nominal period of 1 µs and a half-period of 500 ns.

## Verification

The design was simulated using Icarus Verilog with a self-checking testbench. A simulated SPI slave provides the expected response on MISO.

### Test cases

| Test | Master transmits | Slave returns | Result |
|---|---|---|---|
| 1 | `B2` | `CA` | PASS |
| 2 | `00` | `FF` | PASS |
| 3 | `FF` | `00` | PASS |
| 4 | `AA` | `55` | PASS |
| 5 | `55` | `AA` | PASS |

The testbench checks:
- Correct transmitted byte
- Correct received byte
- Eight rising and eight falling SCLK edges
- Chip-select deassertion after the transaction
- `busy` returning LOW and `done` asserting at completion

**Latest simulation result: 5/5 tests passed, 0 errors.**

## Tools used

- Verilog HDL
- Icarus Verilog — RTL simulation
- GTKWave — waveform inspection

## Running the simulation

Make sure `spi_master.v` and `tb_spi_master.v` are in the same directory.

### 1. Compile

```bash
iverilog -o spi_sim spi_master.v tb_spi_master.v
```

### 2. Run the testbench

```bash
vvp spi_sim
```

The testbench prints the results of all five tests and generates `spi_master.vcd`.

### 3. View the waveforms

```bash
gtkwave spi_master.vcd
```

Inspect `SCLK`, `MOSI`, `MISO`, `CS_N`, `busy`, `done`, and the internal shift registers to understand the data transfer and controller timing.

## Project status and future improvements

The current implementation is a basic, fixed-mode SPI master. Potential extensions include:

- Add timing assertions for SCLK period and data stability.
- Verify reset behavior and `start` requests during an active transaction.
- Test consecutive transactions and boundary conditions.
- Parameterize the clock divider and data width.
- Support configurable CPOL and CPHA for all four SPI modes.
- Verify the design against a more realistic slave model and, eventually, FPGA hardware.

## Learning outcomes

This project explores FSM-based RTL design, serial data shifting, clock division, synchronous control, full-duplex communication, self-checking verification, and waveform-based debugging.

The emphasis is on understanding both the RTL implementation and the verification process, rather than only producing a working module.
