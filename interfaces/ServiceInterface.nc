
interface ServiceInterface {
	
	command result_t output (ServiceMsg msg);
	
	event result_t outputComplete (result_t result);
	
	command result_t trigger (uint16_t rate);
	
}
