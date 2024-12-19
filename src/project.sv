// =======================================================
// SPI TFT Controller Module
// =======================================================
module tt_um_spi_tft_controller (
    input wire clk,           // System clock
    input wire rst,           // Reset signal
    input wire start,         // Start signal
    input wire [7:0] data_in, // 8-bit data input
    input wire dc_select,     // DC pin: 0=Command, 1=Data
    output reg cs,            // Chip Select
    output reg sclk,          // SPI Clock
    output reg mosi,          // Master Out Slave In
    output reg dc,            // Data/Command pin
    output reg reset,         // Reset pin (active low)
    output reg led            // Backlight (always on)
);

// Parameters
parameter CLK_DIV = 4; // SPI clock divider

// Internal Registers
reg [7:0] shift_reg;  // Shift register
reg [3:0] clk_cnt;    // Clock divider counter
reg [2:0] bit_cnt;    // Bit counter
reg [1:0] state;      // State register

// State Encoding
parameter IDLE = 2'b00, LOAD = 2'b01, TRANSFER = 2'b10, DONE = 2'b11;

// Reset and LED initialization
initial begin
    reset = 1'b0; // Active reset
    led = 1'b1;   // Backlight ON
end

// SPI State Machine
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cs <= 1; sclk <= 0; mosi <= 0; dc <= 0;
        reset <= 0; state <= IDLE;
        clk_cnt <= 0; bit_cnt <= 0; shift_reg <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                reset <= 1;       // Release reset
                cs <= 1;          // Deactivate chip select
                if (start) begin
                    shift_reg <= data_in;
                    dc <= dc_select;
                    cs <= 0;      // Activate chip select
                    state <= LOAD;
                end
            end
            LOAD: begin
                clk_cnt <= 0; bit_cnt <= 0;
                state <= TRANSFER;
            end
            TRANSFER: begin
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 0;
                    sclk <= ~sclk; // Toggle SPI clock
                    if (!sclk) begin
                        mosi <= shift_reg[7]; // Send MSB first
                        shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 7) state <= DONE;
                    end
                end else clk_cnt <= clk_cnt + 1;
            end
            DONE: begin
                cs <= 1; // Deactivate chip select
                state <= IDLE;
            end
        endcase
    end
end

endmodule

// =======================================================
// Testbench for SPI TFT Controller
// =======================================================
module spi_tft_controller_tb;

    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    reg [7:0] data_in;
    reg dc_select;
    wire cs, sclk, mosi, dc, reset, led;

    // Instantiate the SPI TFT controller
    spi_tft_controller uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .data_in(data_in),
        .dc_select(dc_select),
        .cs(cs),
        .sclk(sclk),
        .mosi(mosi),
        .dc(dc),
        .reset(reset),
        .led(led)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test stimulus
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        start = 0;
        data_in = 8'h00;
        dc_select = 0;

        // Reset
        #20 rst = 0;
        
        // Send first command
        #10 start = 1; dc_select = 0; data_in = 8'h01; // Command: Software Reset
        #20 start = 0;

        // Send second command
        #50 start = 1; dc_select = 0; data_in = 8'h11; // Command: Sleep Out
        #20 start = 0;

        // Send data
        #50 start = 1; dc_select = 1; data_in = 8'h7F; // Data: Example pixel data
        #20 start = 0;

        // Finalize simulation
        #100 $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0d, CS=%b, SCLK=%b, MOSI=%b, DC=%b, RESET=%b, LED=%b", 
                 $time, cs, sclk, mosi, dc, reset, led);
    end

endmodule
