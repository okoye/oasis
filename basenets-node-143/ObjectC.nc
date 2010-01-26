
module ObjectC {
	provides interface ObjectInterface;
	provides interface StdControl;
	
	uses interface ServiceInterface;
} implementation {
	
	command result_t StdControl.init () {
		return SUCCESS;
	}
	
	command result_t StdControl.start () {
		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
		return SUCCESS;
	}

	command result_t ObjectInterface.trigger () {
		// object knows what to do.. how to initiate the service graph...
		// initiate service_A in this case... 
		// TODO :: 
		// HACK :: service graph is initiated by the called of this trigger functions...
		
		uint16_t rate = 6000;
		call ServiceInterface.trigger (rate);
		return SUCCESS;
	} 
	
	event result_t ServiceInterface.outputComplete (result_t result) {
		return SUCCESS;
	}
	
}

