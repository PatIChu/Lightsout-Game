module adj(
	input [4:0] center,
	input [5:0] dim,
	input dir,				// 0 left/up; 1 right/down
	output [4:0] q,
	output err
);
wire [5:0] out;	// add 1 extra bit for error check

assign out = dir ? center + 5'b1 : center - 5'b1;
assign err = out[5];
assign q = out[4:0];
endmodule