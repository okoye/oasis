
includes Service;

interface ServiceBindInterface {
	
	command result_t output (SBindMsg msg);

	event result_t outputComplete (result_t result);

}
 
