
includes Service;

interface SDInterface {
	
	command result_t output (SDMsg msg);
	
	event result_t outputComplete (result_t result);
}
