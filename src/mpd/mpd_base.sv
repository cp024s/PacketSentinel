module mkMPD(CLK,
	     RST_N,

	     eth0_master_awvalid,

	     eth0_master_awaddr,

	     eth0_master_awprot,

	     eth0_master_awsize,

	     eth0_master_m_awready_awready,

	     eth0_master_wvalid,

	     eth0_master_wdata,

	     eth0_master_wstrb,

	     eth0_master_m_wready_wready,

	     eth0_master_m_bvalid_bvalid,
	     eth0_master_m_bvalid_bresp,

	     eth0_master_bready,

	     eth0_master_arvalid,

	     eth0_master_araddr,

	     eth0_master_arprot,

	     eth0_master_arsize,

	     eth0_master_m_arready_arready,

	     eth0_master_m_rvalid_rvalid,
	     eth0_master_m_rvalid_rresp,
	     eth0_master_m_rvalid_rdata,

	     eth0_master_rready,

	     EN_get_header,
	     get_header,
	     RDY_get_header,

	     send_header_ethid_in,
	     send_header_tag_in,
	     send_header_result,
	     EN_send_header,
	     RDY_send_header,

	     enable_firewall_en,
	     EN_enable_firewall,
	     RDY_enable_firewall);