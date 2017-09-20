module input_coord(
	input [7:0] d,
	input clk, en,
	output reg [4:0] x, y
);
reg dir, xy;

initial begin
	x = 5'b0;
	y = 5'b0;
end
always @(*) begin
	xy = 0;
	dir = 0;
	case (d)
	'h75: begin
		xy = 1;
	end
	'h6B: begin
	end
	'h72: begin
		dir = 1;
		xy = 1;
	end
	'h74: begin
		dir = 1;
	end
	endcase
end
always @(posedge clk) begin
	if (xy)
		y <= en ? (dir ? y + 1 : y - 1) : y;
	else
		x <= en ? (dir ? x + 1 : x - 1) : x;
end
endmodule

module input_actions(
	input [7:0] d,
	input clk, en,
	output reg quit, enter
);
always @(posedge clk) begin
	quit <= en && (d == 'h15);
	enter <= en && (d == 'h5A);
end
endmodule