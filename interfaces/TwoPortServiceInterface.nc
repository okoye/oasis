
interface TwoPortServiceInterface {
	
//	command result_t trigger (uint16_t rate);
	
	command result_t output_port1 (ServiceMsg msg);
	
	command result_t output_port2 (ServiceMsg msg);
	
	event result_t outputComplete (result_t result);
	
}
