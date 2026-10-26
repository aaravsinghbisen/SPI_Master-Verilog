
`timescale 1ns/1ps

module tb_spi_master;

    reg clk;
    reg reset;
    reg start;
    reg [7:0] tx_data;
    reg miso;

    wire sclk;
    wire mosi;
    wire cs_n;
    wire [7:0] rx_data;
    wire busy;
    wire done;

    // DUT
    spi_master dut (
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .tx_data (tx_data),
        .miso    (miso),
        .sclk    (sclk),
        .mosi    (mosi),
        .cs_n    (cs_n),
        .rx_data (rx_data),
        .busy    (busy),
        .done    (done)
    );

    // 100 MHz system clock: 10 ns period
    always #5 clk = ~clk;

    // Simulated SPI slave
    reg [7:0] slave_response;
    reg [7:0] mosi_captured;
    integer slave_bit;
    integer rising_edges;
    integer falling_edges;
    integer errors;
    integer tests_passed;
    integer tests_run;

    // Reset transaction-specific monitoring when selected
    always @(negedge cs_n) begin
        slave_bit    = 7;
        miso         = slave_response[7];
        mosi_captured = 8'h00;
        rising_edges = 0;
        falling_edges = 0;
    end

    // Mode 0: master samples on rising edge.
    // Capture MOSI and count sampling edges.
    always @(posedge sclk) begin
        if (!cs_n) begin
            mosi_captured = {mosi_captured[6:0], mosi};
            rising_edges = rising_edges + 1;
        end
    end

    // Mode 0: slave prepares next MISO bit on falling edge.
    always @(negedge sclk) begin
        if (!cs_n) begin
            falling_edges = falling_edges + 1;

            if (slave_bit > 0) begin
                slave_bit = slave_bit - 1;
                miso = slave_response[slave_bit];
            end
        end
    end

    // Run one transfer and check its results
    task run_test;
        input [7:0] master_byte;
        input [7:0] slave_byte;

        begin
            // Set inputs while the system clock is low
            @(negedge clk);
            tx_data        = master_byte;
            slave_response = slave_byte;
            start          = 1'b1;

            // Start is a one-cycle request
            @(negedge clk);
            start = 1'b0;

            // Wait for completion
            wait (done === 1'b1);
            #1;

            tests_run = tests_run + 1;

            $display("");
            $display("Test %0d", tests_run);
            $display("TX expected : %02h", master_byte);
            $display("TX captured : %02h", mosi_captured);
            $display("RX expected : %02h", slave_byte);
            $display("RX actual   : %02h", rx_data);
            $display("SCLK rising : %0d", rising_edges);
            $display("SCLK falling: %0d", falling_edges);

            if (mosi_captured !== master_byte) begin
                $display("FAIL: MOSI data mismatch");
                errors = errors + 1;
            end

            if (rx_data !== slave_byte) begin
                $display("FAIL: RX data mismatch");
                errors = errors + 1;
            end

            if (rising_edges != 8) begin
                $display("FAIL: Expected 8 rising edges");
                errors = errors + 1;
            end

            if (falling_edges != 8) begin
                $display("FAIL: Expected 8 falling edges");
                errors = errors + 1;
            end

            if (cs_n !== 1'b1) begin
                $display("FAIL: CS_N should be HIGH");
                errors = errors + 1;
            end

            if (busy !== 1'b0) begin
                $display("FAIL: Busy should be LOW");
                errors = errors + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: Done should be HIGH");
                errors = errors + 1;
            end

            if (errors == 0) begin
                tests_passed = tests_passed + 1;
                $display("RESULT: PASS");
            end else begin
                $display("RESULT: CHECK FAILURES");
            end

            // Allow the DUT to return fully to IDLE
            @(negedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        clk             = 0;
        reset           = 1;
        start           = 0;
        tx_data         = 0;
        miso            = 0;
        slave_response  = 0;
        mosi_captured   = 0;
        slave_bit       = 7;
        rising_edges    = 0;
        falling_edges   = 0;
        errors          = 0;
        tests_passed    = 0;
        tests_run       = 0;

        $dumpfile("spi_master.vcd");
        $dumpvars(0, tb_spi_master);

        // Apply reset
        repeat (5) @(negedge clk);
        reset = 0;

        // Test different bit patterns and independent TX/RX data
        run_test(8'hB2, 8'hCA);
        run_test(8'h00, 8'hFF);
        run_test(8'hFF, 8'h00);
        run_test(8'hAA, 8'h55);
        run_test(8'h55, 8'hAA);

        $display("");
        $display("================================");
        $display("SPI REGRESSION SUMMARY");
        $display("Tests run    : %0d", tests_run);
        $display("Tests passed : %0d", tests_passed);
        $display("Errors       : %0d", errors);
        $display("================================");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TEST SUITE FAILED");

        #20;
        $finish;
    end

    // Global timeout
    initial begin
        #200000;
        $display("ERROR: Simulation timed out");
        $finish;
    end

endmodule
