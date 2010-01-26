
/** 
	simulation of the wind service
*/

module ComponentWind {
	provides {
		interface ServiceInterface as InputInterface;
		interface StdControl;
	}	
	uses {
		interface ServiceInterface as OutputInterface;
		interface Timer;
	}
} implementation {
	
	ServiceMsg msg;
	bool timerStarted;
	
	command result_t StdControl.init () {
		return SUCCESS;
	}
	
	command result_t StdControl.start () {
		timerStarted = FALSE;
		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
    call Timer.stop();
		return SUCCESS;
	}
	

	task void sendTemp () {
		msg.data[4] = 5;
		msg.data[5] = 5;

		msg.seqNum = 0xff;
		msg.data[0] = 2;
		call OutputInterface.output (msg);
	}

	command result_t InputInterface.output (ServiceMsg data) {
		// start a timer and generate a number at regular interval
		return SUCCESS;
	}
	
	event result_t Timer.fired () {
		return post sendTemp ();
//    return call TempADC.getData();
	} 
	
	event result_t OutputInterface.outputComplete (result_t result) {
		signal InputInterface.outputComplete (SUCCESS);	
		return SUCCESS;
	}
	
	command result_t InputInterface.trigger (uint16_t rate) {
		// start a timer and generate a number at regular interval
		if (!timerStarted) {
//			nindex = 0;
			timerStarted = TRUE;
			call Timer.start (TIMER_REPEAT, rate);
		}
		return SUCCESS;
	}

}

