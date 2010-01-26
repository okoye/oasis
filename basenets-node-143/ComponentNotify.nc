
/** 
	Local service Notify 
	when triggered this service outputs next number from a pre-specified list.
*/

module ComponentNotify {
	provides {
		interface ServiceInterface as InputInterface;
		interface StdControl;
		command result_t myfunction (ServiceMsg data, uint32_t rt);
	}	
	uses {
		interface ServiceInterface as OutputInterface;
		interface Leds;
		interface Int3Output as Send;
		interface SysTime;
	}
} implementation {

	uint8_t iteration;
	int16_t x_hat, y_hat;
	
	command result_t StdControl.init () {
		return SUCCESS;
	}
	
	command result_t StdControl.start () {
		call Leds.init ();
		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
		return SUCCESS;
	}
	
	command result_t InputInterface.trigger (uint16_t rate) {
		return SUCCESS;
	}

	command result_t myfunction (ServiceMsg data, uint32_t rt) {
		
		uint32_t t = call SysTime.getTime32 () - rt;
		call Send.output (t, t>>8, t>>16, t>>24, 66);
		
		return SUCCESS;
	}

	command result_t InputInterface.output (ServiceMsg data) {
		
		call Leds.redToggle ();
//		uint32_t t = call SysTime.getTime32 ();
//		call Send.output (t, t>>8, t>>16, t>>24, 66);
		
/*		memcpy (&x_hat, data.data+4, 2);
		memcpy (&y_hat, data.data+6, 2);
		memcpy (&iteration, data.data+14, 2);
*/
//		call Send.output (x_hat, x_hat>>8, y_hat, y_hat>>8, 0);
		call OutputInterface.output (data);
		return SUCCESS;
	}
	
	event result_t OutputInterface.outputComplete (result_t result) {
		signal InputInterface.outputComplete (SUCCESS);	
		return SUCCESS;
	}
	
	event result_t Send.outputComplete (result_t result) {
		return SUCCESS;
	}


}

