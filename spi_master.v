
module spi_master (
    input  wire       clk,       // 100 MHz system clock
    input  wire       reset,     // Active-high synchronous reset
    input  wire       start,     // Start one 8-bit transfer
    input  wire [7:0] tx_data,   // Data to transmit
    input  wire       miso,      // Master In, Slave Out

    output reg        sclk,      // SPI clock: Mode 0
    output reg        mosi,      // Master Out, Slave In
    output reg        cs_n,      // Active-low chip select
    output reg  [7:0] rx_data,   // Received byte
    output reg        busy,
    output reg        done
);

    // 100 MHz / (2 * 50) = 1 MHz SPI clock
    localparam integer CLK_DIV = 50;

    localparam IDLE = 2'd0,
               SETUP = 2'd1,
               TRANSFER = 2'd2,
               FINISH = 2'd3;

    reg [1:0] state;

    reg [5:0] div_count;
    reg [2:0] bit_count;

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;

    // One system-clock cycle pulse every CLK_DIV cycles
    wire tick = (div_count == CLK_DIV - 1);

    always @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            div_count <= 0;
            bit_count <= 0;
            tx_shift  <= 0;
            rx_shift  <= 0;
            rx_data   <= 0;
            sclk      <= 0;
            mosi      <= 0;
            cs_n      <= 1;
            busy      <= 0;
            done      <= 0;
        end else begin
            done <= 0;

            case (state)

                IDLE: begin
                    sclk      <= 0;
                    cs_n      <= 1;
                    busy      <= 0;
                    div_count <= 0;

                    if (start) begin
                        tx_shift  <= tx_data;
                        rx_shift  <= 0;
                        bit_count <= 0;
                        mosi      <= tx_data[7];
                        cs_n      <= 0;
                        busy      <= 1;
                        state     <= SETUP;
                    end
                end

                SETUP: begin
                    // Allow CS and first MOSI bit to settle
                    if (tick) begin
                        div_count <= 0;
                        state     <= TRANSFER;
                    end else begin
                        div_count <= div_count + 1'b1;
                    end
                end

                TRANSFER: begin
                    if (tick) begin
                        div_count <= 0;

                        if (sclk == 1'b0) begin
                            // Rising edge: sample MISO
                            sclk <= 1'b1;
                            rx_shift <= {rx_shift[6:0], miso};

                        end else begin
                            // Falling edge: prepare next MOSI bit
                            sclk <= 1'b0;

                            if (bit_count == 3'd7) begin
                                rx_data <= rx_shift;
                                state   <= FINISH;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                                tx_shift  <= {tx_shift[6:0], 1'b0};
                                mosi      <= tx_shift[6];
                            end
                        end

                    end else begin
                        div_count <= div_count + 1'b1;
                    end
                end

                FINISH: begin
                    cs_n <= 1;
                    sclk <= 0;
                    busy <= 0;
                    done <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
