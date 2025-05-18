package mem_utils;

    function [31:0] enforce_constraints;
        input [1:0] internal_data_size;
        input extend_sign;
        input [31:0] value;
        begin
            unique case (internal_data_size)
                2'b00: enforce_constraints = extend_sign ? {{24{value[7]}}, value[7:0]} : {24'b0, value[7:0]};
                2'b01: enforce_constraints = extend_sign ? {{16{value[15]}}, value[15:0]} : {16'b0, value[15:0]};
                2'b10, 2'b11: enforce_constraints = value;
            endcase
        end
    endfunction

endpackage