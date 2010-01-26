
/** 
	Local READ_TEMP
	when triggered this service outputs next number from a pre-specified list.
*/

module ComponentReadT {
	provides {
		interface ServiceInterface as InputInterface;
		interface StdControl;
//		command result_t trigger (uint16_t rate);
	}	
	uses {
//		interface ADC as TempADC;
//		interface StdControl as SensorControl;
		interface ServiceInterface as OutputInterface;
		interface Timer;
//		interface Random;
		
		command result_t myfunc (uint32_t rt);
		interface Int3Output as Send;
		interface SysTime;
	}
} implementation {
	
	uint8_t iteration;
	uint16_t temp;
	ServiceMsg msg;
	bool timerStarted;
	
	uint8_t meas_noise;

	uint8_t x[] = {0, 11, 19, 27, 41, 52, 66, 78, 92, 105, 119, 133, 140, 155, 166};
	uint8_t y[] = {0, 9, 22, 37, 47, 56, 65, 74, 82, 96, 106, 119, 129, 136, 148};

//	uint16_t mylocation[] = {500, 200}; //101
//	uint16_t z[] = {349, 364, 384, 408, 430, 459, 490, 521, 561, 607, 653, 707, 748, 814, 878};

//	uint16_t mylocation[] = {600, 700};	//123
//	uint16_t z[] = {122, 127, 133, 131, 141, 139, 154, 159, 159, 172, 179, 185, 189, 201, 208};

	uint16_t mylocation[] = {100, 300};
	uint16_t z[] = {1006, 1081, 1192, 1342, 1489, 1617, 1777, 1943, 2106, 2401, 2639, 2955, 3242, 3351, 3643};

	command result_t StdControl.init () {
//		call SensorControl.init ();
		return SUCCESS;
	}
	
	command result_t StdControl.start () {
//		temp = 323;
		iteration = 0;
		meas_noise = 10;
		timerStarted = FALSE;

//		mylocation[0] = 100;
//		mylocation[1] = 300;
		
//		call Random.init ();
//		call SensorControl.start ();

		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
//    call SensorControl.stop();
    call Timer.stop();
		return SUCCESS;
	}
	

	task void sendTemp () {
//		uint32_t r1 = (x[iteration] - mylocation[0])*(x[iteration] - mylocation[0]) + (y[iteration] - mylocation[1])*(y[iteration] - mylocation[1]);
//		iteration++;

//		temp = (1e8/r1) + meas_noise * ((call Random.rand ())>>13);	// effectively random returns a 3-bit random number

		msg.data[4] = mylocation[0];
		msg.data[5] = mylocation[0]>>8;

		msg.data[6] = mylocation[1];
		msg.data[7] = mylocation[1]>>8;

		msg.data[8] = z[iteration];
		msg.data[9] = z[iteration]>>8;

		msg.data[10] = iteration;
		iteration++;

		msg.seqNum = 0xff;
		msg.data[0] = 7;
		call OutputInterface.output (msg);
	}

/*  async event result_t TempADC.dataReady (uint16_t data) {
  	temp = data;
  	post sendTemp ();
    return SUCCESS;
  }
*/
	command result_t InputInterface.output (ServiceMsg data) {
		// start a timer and generate a number at regular interval
		return SUCCESS;
	}
	
	event result_t Timer.fired () {
		
		uint32_t t = call SysTime.getTime32 ();
		call myfunc (t);
//		call Send.output (t, t>>8, t>>16, t>>24, 55);

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
	
	event result_t Send.outputComplete (result_t result) {
		return SUCCESS;
	}

}

