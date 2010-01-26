
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
		interface Random;
	}
} implementation {
	
	uint8_t iteration;
	uint16_t temp;
	ServiceMsg msg;
	bool timerStarted;
	
	uint8_t meas_noise;
	
	uint16_t mylocation[] = {500, 200};
	// q = 10
//	uint8_t x[] = {0, 11, 19, 27, 41, 52, 66, 78, 92, 105, 119, 133, 140, 155, 166};
//	uint8_t y[] = {0, 9, 22, 37, 47, 56, 65, 74, 82, 96, 106, 119, 129, 136, 148};

	// r = 10
//	uint16_t z[] = {349, 364, 384, 408, 430, 459, 490, 521, 561, 607, 653, 707, 748, 814, 878};
	// r = 50
//	uint16_t z[] = {369, 372, 400, 444, 443, 493, 514, 547, 593, 641, 671, 711, 773, 825, 890};
	// r = 100
//	uint16_t z[] = {394, 382, 420, 489, 460, 536, 544, 580, 632, 684, 694, 715, 805, 838, 906};//, 966, 1129, 1180, 1290, 1423};

/*	// q = 20
	uint16_t x[] = {0, 16, 28, 39, 62, 78, 101, 119, 143, 164, 187, 209, 219, 243, 260, 282, 299, 323, 345, 360, 376, 387, 400, 412, 429};
	uint16_t y[] = {0, 13, 35, 60, 75, 87, 101, 114, 125, 149, 165, 186, 200, 209, 228, 246, 253, 276, 284, 300, 316, 328, 344, 356, 373};
	// r = 50
	uint16_t z[] = {369, 381, 419, 475, 497, 565, 621, 687, 790, 907, 1030, 1182, 1297, 1525, 1727, 2016, 2361, 2713 ,3230, 3409, 3473, 3478, 3301, 3117, 2874};
*/

	uint16_t x[] = {0, 11, 19, 27, 41, 52, 66, 78, 92, 105, 119, 133, 140, 155, 166, 180, 191, 205, 219, 229, 240, 248, 257, 266, 277, 292, 302, 310, 318, 333,
		347, 356, 365, 379, 385, 400, 408, 413, 423, 430, 438, 452, 464, 475, 486, 496, 504, 509, 517, 522};
	uint16_t y[] = {0, 9, 22, 37, 47, 56, 65, 74, 82, 96, 106, 119, 129, 136, 148, 160, 166, 180, 186, 197, 208, 216, 227, 236, 247, 257, 269, 275, 285, 299, 
			306, 320, 333, 344, 354, 364, 374, 386, 392,403,414, 419, 434, 440, 454, 465, 476, 483, 490, 499};
	uint16_t z[] = {369, 372, 400, 444, 443, 493 ,514, 547 ,593, 641, 671, 711, 773, 825, 890, 963, 1081, 1161, 1276, 1392, 1482, 1616, 1720, 1784, 1940, 2195,
			2320, 2440, 2490, 2657, 2934, 2851, 2800, 2831, 2717, 2751, 2598, 2416, 2374, 2175, 2053, 2026, 1792, 1726, 1553, 1446, 1315, 1263, 1196, 1140};



	command result_t StdControl.init () {
//		call SensorControl.init ();
		return SUCCESS;
	}
	
	command result_t StdControl.start () {
//		temp = 323;
		iteration = 0;
		meas_noise = 10;
		timerStarted = FALSE;

//		mylocation[0] = 500;
//		mylocation[1] = 200;
		
		call Random.init ();
//		call SensorControl.start ();

		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
//    call SensorControl.stop();
    call Timer.stop();
		return SUCCESS;
	}
	
	task void sendTemp () {
//		int32_t diffx = ((int32_t)x[iteration] - (int32_t)mylocation[0]);
//		int32_t diffy = ((int32_t)y[iteration] - (int32_t)mylocation[1]);

//		z[iteration] = (1e8/(diffx*diffx + diffy*diffy)) + meas_noise * (0x7 & ((call Random.rand ())>>13) );	// effectively random returns a 3-bit random number

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

