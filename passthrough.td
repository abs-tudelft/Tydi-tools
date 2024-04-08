package passthrough;

bit_4 = Bit(4);
bit_8 = Bit(8);
bit_16 = Bit(16);

#this is a union size#
Union size {
    small : bit_4;
    mid : bit_8;
    large : bit_16;
}

stream_size = Stream(size);

#this is a streamlet#
streamlet bypass_s {
    # this is port_in #
    port_in: stream_size in;

    # this is port_out #
    port_out: stream_size out;
}

#this is an implementation#
impl bypass_i_inner of bypass_s {
    self.port_in => self.port_out;
}

impl bypass_i of bypass_s {
    # this instance is used to test using an implementation without template expansion #
    instance test_inst(bypass_i_inner);

    # ports on self have "opposite" direction #
    self.port_in => test_inst.port_in;
    test_inst.port_out => self.port_out;
}
