// SW[9:5] Y
// SW[4:0] X
// KEY[0] Reset
// KEY[1] Go
module lightsout2(
	input [9:0] SW,
	input [3:0] KEY,
	input CLOCK_50,
	input PS2_DAT,
	input PS2_CLK,
	output			VGA_CLK,   				//	VGA Clock
	output			VGA_HS,					//	VGA H_SYNC
	output			VGA_VS,					//	VGA V_SYNC
	output			VGA_BLANK_N,			//	VGA BLANK
	output			VGA_SYNC_N,				//	VGA SYNC
	output	[9:0]	VGA_R,   				//	VGA Red[9:0]
	output	[9:0]	VGA_G,	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B   				//	VGA Blue[9:0]
	output [9:0] LEDR,
	output HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);
	wire [5:0] dimension;
	assign dimension = 6'd32;
	
	wire write, do_display, load_enable, load_X;
	wire done_display, done_load, address_error;
	
	wire change_Y, change_X;
	wire [1:0] Y_Select;
	wire [2:0] X_Select;
	
	wire [31:0] ram;
	wire [4:0] address;
	wire [31:0] data;
	
	wire [7:0] x;
	wire [7:0] y;
	wire [2:0] colour;
	wire writeEn;
	
	wire zero;
	assign zero = (ram == 0) ? 1 : 0;
	
	wire [7:0] x_input;
	wire [7:0] y_input;
	wire done_input;
	
	wire reset_score;
	wire win;
	assign LEDR[0] = win;
	
	control c(
		.clk(CLOCK_50),
		.go(~KEY[1]),
		.reset(KEY[0]),
		.done_display(done_display),
		.done_load(done_load),
		.zero(zero),
		.change_Y(change_Y),
		.change_X(change_X),
		.Y_Select(Y_Select),
		.X_Select(X_Select),
		.write(write),
		.do_display(do_display),
		.load_enable(load_enable),
		.load_X(load_X),
		.done_input(done_input),
		.reset_score(reset_score),
		.win(win)
	);
	
	datapath d(
		.dimension(dimension),
		.x(x_input),
		.y(y_input),
		.Y_Select(Y_Select),
		.X_Select(X_Select),
		.ram(ram),
		.do_display(do_display),
		.clk(CLOCK_50),
		.change_X(change_X),
		.change_Y(change_Y),
		.load_X(load_X),
		.load_enable(load_enable),
		.done_load(done_load),
		.address_error(address_error),
		.address(address),
		.data(data)
	);
	
	ram32x32 r(
		.address(address),
		.clock(CLOCK_50),
		.data(data),
		.wren(write && ~address_error),
		.q(ram)
	);
	
	gameboard g(
		.do_display(do_display),
		.ram_addr(address),
		.ram_out(data),
		.clk(CLOCK_50),
		.address_error(address_error),
		.x(x),
		.y(y),
		.colour(colour),
		.writeEn(writeEn),
		.done_display(done_display)
	);
	
	keyboard k(
		.clk(PS2_CLK),
		.data(PS2_DAT),
		.x_input(x_input),
		.y_input(y_input),
		.done_input(done_input)
	);
	
	wire [7:0] current_score;
	wire [7:0] second;
	wire [7:0] minute;
	
	scoreboard s(
		.clk(CLOCK_50),
		.done_input(done_input),
		.reset_score(reset_score),
		.done_game(win),
		.current_score(current_score),
		.second(second[6:0]),
		.minute(minute[6:0])
	);
	
	hex7 h0(
		.hex_digit(current_score[3:0]),
		.segments(HEX0)
	);
	hex7 h1(
		.hex_digit(current_score[7:4]),
		.segments(HEX1)
	);
	hex7 h2(
		.hex_digit(second[3:0]),
		.segments(HEX2)
	);
	hex7 h3(
		.hex_digit(second[7:4]),
		.segments(HEX3)
	);
	hex7 h4(
		.hex_digit(minute[3:0]),
		.segments(HEX4)
	);
	hex7 h5(
		.hex_digit(minute[7:4]),
		.segments(HEX5)
	);
	
	// vga_adapter VGA(
				// .resetn(KEY[0]),
				// .clock(CLOCK_50),
				// .colour(colour),
				// .x(x),
				// .y(y),
				// .plot(writeEn),
				// /* Signals for the DAC to drive the monitor. */
				// .VGA_R(VGA_R),
				// .VGA_G(VGA_G),
				// .VGA_B(VGA_B),
				// .VGA_HS(VGA_HS),
				// .VGA_VS(VGA_VS),
				// .VGA_BLANK(VGA_BLANK_N),
				// .VGA_SYNC(VGA_SYNC_N),
				// .VGA_CLK(VGA_CLK));
			// defparam VGA.RESOLUTION = "160x120";
			// defparam VGA.MONOCHROME = "FALSE";
			// defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
			// defparam VGA.BACKGROUND_IMAGE = "black.mif";
endmodule

module control(
	input clk, go, reset, done_display, done_load, zero, done_input,
	output reg change_Y, change_X,
	output reg [1:0] Y_Select,
	output reg [2:0] X_Select,
	output reg write, do_display, load_enable, load_X, reset_score, win
);
	reg [4:0] state, next_state;
	
	localparam
		START = 5'd0,
		START_WAIT = 5'd1,
		LOAD = 5'd2,
		INPUT = 5'd3,
		INPUT_WAIT = 5'd4,
		READ_ABOVE = 5'd5,
		WRITE_ABOVE = 5'd6,
		DISPLAY_ABOVE = 5'd7,
		DISPLAY_WAIT_ABOVE = 5'd8,
		READ_MIDDLE = 5'd9,
		WRITE_MIDDLE = 5'd10,
		DISPLAY_MIDDLE = 5'd11,
		DISPLAY_WAIT_MIDDLE = 5'd12,
		READ_BELOW = 5'd13,
		WRITE_BELOW = 5'd14,
		DISPLAY_BELOW = 5'd15,
		DISPLAY_WAIT_BELOW = 5'd16,
		TEST_WIN = 5'd17,
		END = 5'd18,
		CALCULATE_ABOVE = 5'd19,
		CALCULATE_MIDDLE = 5'd20,
		CALCULATE_BELOW = 5'd21,
		LOAD_DISPLAY = 5'd22,
		LOAD_DISPLAY_WAIT = 5'd23,
		WAIT_ABOVE = 5'd24,
		WAIT_MIDDLE = 5'd25,
		WAIT_BELOW = 5'd26,
		CHANGE_ADDRESS_ABOVE = 5'd27,
		CHANGE_ADDRESS_MIDDLE = 5'd28,
		CHANGE_ADDRESS_BELOW = 5'd29,
		SCORE_WAIT = 5'd30;
		
	always @(*) begin
		case (state)
		START: next_state <= go ? START_WAIT : START;
		START_WAIT: next_state <= go ? START_WAIT : LOAD;
		
		//Load a display (preset for now)
		LOAD: next_state = done_load ? INPUT : LOAD_DISPLAY;
		LOAD_DISPLAY: next_state = LOAD_DISPLAY_WAIT;
		LOAD_DISPLAY_WAIT: next_state = done_display ? LOAD : LOAD_DISPLAY_WAIT;
		
		INPUT: next_state = go ? INPUT : INPUT_WAIT;
		INPUT_WAIT : next_state = done_input ? CHANGE_ADDRESS_ABOVE : INPUT_WAIT;
		
		//Row above
		CHANGE_ADDRESS_ABOVE: next_state = READ_ABOVE;
		READ_ABOVE: next_state = WAIT_ABOVE;
		WAIT_ABOVE: next_state = CALCULATE_ABOVE;
		CALCULATE_ABOVE: next_state = WRITE_ABOVE;
		WRITE_ABOVE: next_state = DISPLAY_ABOVE;
		DISPLAY_ABOVE: next_state = DISPLAY_WAIT_ABOVE;
		DISPLAY_WAIT_ABOVE: next_state = done_display ? CHANGE_ADDRESS_MIDDLE : DISPLAY_WAIT_ABOVE;
		
		//Row middle
		CHANGE_ADDRESS_MIDDLE: next_state = READ_MIDDLE;
		READ_MIDDLE: next_state = WAIT_MIDDLE;
		WAIT_MIDDLE: next_state = CALCULATE_MIDDLE;
		CALCULATE_MIDDLE: next_state = WRITE_MIDDLE;
		WRITE_MIDDLE: next_state = DISPLAY_MIDDLE;
		DISPLAY_MIDDLE: next_state = DISPLAY_WAIT_MIDDLE;
		DISPLAY_WAIT_MIDDLE: next_state = done_display ? CHANGE_ADDRESS_BELOW : DISPLAY_WAIT_MIDDLE;
		
		//Row below
		CHANGE_ADDRESS_BELOW: next_state = READ_BELOW;
		READ_BELOW: next_state = WAIT_BELOW;
		WAIT_BELOW: next_state = CALCULATE_BELOW;
		CALCULATE_BELOW: next_state = WRITE_BELOW;
		WRITE_BELOW: next_state = DISPLAY_BELOW;
		DISPLAY_BELOW: next_state = DISPLAY_WAIT_BELOW;
		DISPLAY_WAIT_BELOW: next_state = done_display ? TEST_WIN : DISPLAY_WAIT_BELOW;
		
		TEST_WIN: next_state = zero ? (done_load ? END : TEST_WIN) : INPUT;
		END: next_state = go ? START : END;
		default: next_state = START;
		endcase
	end
	
	always @(*) begin
		change_Y = 1'b0;
		change_X = 1'b0;
		Y_Select = 2'b00;
		X_Select = 3'b0;
		write = 1'b0;
		do_display = 1'b0;
		load_enable = 1'b0;
		load_X = 1'b0;
		reset_score = 1'b0;
		win = 1'b0;
		
		case(state)
		START: begin
			reset_score = 1'b1;
		end
		LOAD: begin
			change_Y = 1'b1;
			Y_Select = 2'b11;
			load_enable = 1'b1;
			load_X = 1'b1;
		end
		LOAD_DISPLAY : begin
			load_enable = 1'b1;
			write = 1'b1;
			do_display = 1'b1;
		end
		LOAD_DISPLAY_WAIT: begin
			load_enable = 1'b1;
		end
		CHANGE_ADDRESS_ABOVE: begin
			change_Y = 1;
			Y_Select = 2'b00;
		end
		CALCULATE_ABOVE: begin
			X_Select = 3'b010;
			change_X = 1'b1;
		end
		WRITE_ABOVE: begin
			write = 1'b1;
		end
		DISPLAY_ABOVE: begin
			do_display = 1'b1;
		end
		CHANGE_ADDRESS_MIDDLE: begin
			change_Y = 1'b1;
			Y_Select = 2'b01;
		end
		CALCULATE_MIDDLE: begin
			X_Select = 3'b111;
			change_X = 1'b1;
		end
		WRITE_MIDDLE: begin
			write = 1'b1;
		end
		DISPLAY_MIDDLE: begin
			do_display = 1'b1;
		end
		CHANGE_ADDRESS_BELOW: begin
			change_Y = 1'b1;
			Y_Select = 2'b10;
		end
		CALCULATE_BELOW: begin
			X_Select = 3'b010;
			change_X = 1'b1;
		end
		WRITE_BELOW: begin
			write = 1'b1;
		end
		DISPLAY_BELOW: begin
			do_display = 1'b1;
		end
		TEST_WIN: begin
			load_enable = 1'b1;
		end
		END: begin
			win = 1'b1;
		end
		endcase
	end
	
	always @(posedge clk) begin
		state = reset ?  next_state : START;
	end
endmodule

module datapath(
	input [5:0] dimension,
	input [4:0] x,
	input [4:0] y,
	input [1:0] Y_Select,
	input [2:0] X_Select,
	input [31:0] ram,
	input do_display, clk, change_X, change_Y, load_X, load_enable,
	output reg done_load, address_error,
	output reg [4:0] address,
	output reg [31:0] data
);
	wire y_above_overflow, y_below_overflow, x_left_overflow, x_right_overflow;
	wire [4:0] y_above, y_below, x_left, x_right;
	reg [4:0] y_load;

	assign y_above_overflow = (y == 0) ? 1 : 0;
	assign y_above = y - 1'b1;
	assign y_below_overflow = (y == (dimension - 1'b1)) ? 1 : 0;
	assign y_below = y + 1'b1;
	
	assign x_left_overflow = (x == 0) ? 1 : 0;
	assign x_left = x - 1'b1;
	assign x_right_overflow = (x == (dimension - 1'b1)) ? 1 : 0;
	assign x_right = x + 1'b1;
	
	// This chooses what address is
	always @(posedge clk) begin
		if (change_Y) begin
			address_error <= 0;
			case (Y_Select)
			2'd0: begin
				address <= y_above;
				address_error <= y_above_overflow;
			end
			2'd1: address <= y;
			2'd2: begin
				address <= y_below;
				address_error <= y_below_overflow;
			end
			2'd3: address <= y_load;
			endcase
		end
	end
	// Randomizer
	reg [31:0] d;
	always @(posedge clk) begin
		d <= {d[31:0], d[30] ^ d[27]};
	end
	// This chooses what data is
	always @(posedge clk) begin
		data <= ram;
		if (change_X) begin
			if (X_Select[0] && !x_left_overflow) begin
				data[x_left] <= ~(data[x_left]);
			end
			if (X_Select[1]) begin
				data[x] <= ~(data[x]);
			end
			if (X_Select[2] && !x_right_overflow) begin
				data[x_right] <= ~(data[x_right]);
			end
		end
		if (load_X) begin
			// This is the preset what gets loaded when doing a load.
			data <= d;
		end
	end
	
	// This cycles through 0 to dimension for ram_address
	always @(posedge clk) begin
		done_load <= load_enable ? (y_load == dimension - 1): 1'b0;
		y_load <= load_enable ? (change_Y ? (done_load ? dimension - 1 : y_load + 1) : y_load ) : 5'b0;
	end
	
endmodule

module gameboard (
	input do_display,
	input [4:0] ram_addr,
	input [31:0] ram_out,
	input clk, address_error,
	output reg [2:0] colour,
	output reg [8:0] x,
	output reg [8:0] y,
	output reg writeEn,
	output reg done_display
);
	reg [5:0] index;
	reg [3:0] counter;
	reg write;

	always @(posedge clk) begin
		done_display <= 1'b0;
		writeEn <= 1'b0;
		colour <= 3'b000;
		x <= 8'd0;
		y <= 8'd0;
		
		if (do_display) begin
			index <= 5'd0;
			counter <= 5'd0;
			write <= 1'b0;
		end
		
		if (index == 6'd32 || address_error) begin
				done_display <= 1'b1;
				index <= 0;
		end
		
		if (~(index == 6'd32) && ~address_error) begin
			if (write == 0) begin
				x <= ((4'd4 * index) + counter[1:0]);
				y <= ((4'd4 * ram_addr) + counter[3:2]);
				
				case (ram_out[index])
				1'b0: begin
					colour <= 3'b000;
					writeEn <= 1'b1;
				end
				1'b1: begin
					colour <= 3'b111;
					writeEn <= 1'b1;
				end
				default: writeEn <= 1'b0;
				endcase
				
				write <= write + 1'b1;
				counter <= counter + 1'b1;
				if (counter == 4'd15) begin
					index <= index + 1'b1;
					counter <= 5'd0;
				end
			end
			else begin
				write <= write + 1'b1;
			end
		end
	end
endmodule

//USING PS2 FROM 
module keyboard(
	input clk,
	input data,
	output reg [7:0] x_input,
	output reg [7:0] y_input,
	output reg [7:0] done_input
);
reg [7:0] key_curr;
reg [7:0] key_full;
reg [3:0] counter;
reg done;

initial begin
	counter <= 4'h1;
	key_curr <= 8'hf0;
	key_full <= 8'hf0;
	x_input <= 7'b0;
	y_input <= 7'b0;
	done <= 1'b0;
end

always @(negedge clk) begin
	case(counter)
	1:;
	2:key_curr[0] <= data;
	3:key_curr[1] <= data;
	4:key_curr[2] <= data;
	5:key_curr[3] <= data;
	6:key_curr[4] <= data;
	7:key_curr[5] <= data;
	8:key_curr[6] <= data;
	9:key_curr[7] <= data;
	10:done <= 1'b1;
	11:done <= 1'b0;
	endcase
	
	if (counter <= 10) begin
		counter <= counter + 1;
	end
	else if (counter == 11) begin
		counter <= 1;
	end
end

always @(posedge done) begin
	done_input <= 0;
	if (key_curr == 8'hf0) begin
		case (key_full)
		8'h75: begin
			y_input <= y_input - 1;
		end
		8'h6B: begin
			x_input <= x_input - 1;
		end
		8'h72: begin
			y_input <= y_input + 1;
		end
		8'h74: begin
			x_input <= x_input + 1;
		end
		8'h5A: begin
			done_input <= 1'b1;
		end
		endcase
	end
	else begin
		key_full <= key_curr;
	end
end
endmodule

module scoreboard(
	input done_input, reset_score, done_game, clk,
	output reg [7:0] current_score,
	output reg [6:0] second,
	output reg [6:0] minute
);

reg [25:0] counter;

always @(posedge clk) begin
	if (reset_score) begin
		current_score <= 8'b0;
		counter <= 0;
		second <= 0;
		minute <= 0;
	end
	
	if (done_input) begin
		current_score <= current_score + 1;
	end
	
	if (~win) begin
		counter <= counter + 1;
		if (counter == 50000000) begin
			second <= second + 1;
		end
		if (second == 60) begin
			second <= 0;
			minute <= minute + 1;
		end
	end
end
endmodule