
/**
 * This component receives messages from RcvBigMsgC and dispatches them to appropriate actors. 
**/
module NodeInC {
	provides {
		interface StdControl;
		interface ReceiveBigMsg as InputInterface;
	}
	uses {
		interface SDInterface;
		interface ComposerInterface;
		interface InternalInterface;
		interface ObjectInterface;

		interface FivePortServiceInterface as LocalizeInterface;
		interface ServiceInterface as NotifyInterface;
		interface ServiceInterface as ReadTInterface;
		interface ServiceInterface as WindInterface;

		interface Timer;
		interface Timer as SDTimer; 
		interface Int3Output as Send;
	}
} implementation {

	void* starts;
	void* ends;
	uint32_t totalLength;
	uint32_t currentLength;
	uint8_t msgSeqNum;

	ServiceMsg msg;
	SDMsg sdmsg;
	SBindMsg sbmsg;
	SControl ctrl;
	bool pending;

//	uint8_t graph[] = {76, 0, 0, 0, 	6, 5,		8, 1, 1, 6, 10, 4,	8, 1, 1, 6 ,10, 4, 	8, 1, 1, 6 ,10, 4,	8, 1, 1, 6 ,10, 4,	9, 1, 1, 6 ,10, 4,		10, 1, 1, 6, 10, 4,			3,	4, 1, 7, 1, 6, 	5, 2, 7, 2, 3, 4,		6, 5, 6, 1, 2, 3, 4,		1, 5, 1, 2, 5, 2, 3, 5, 3, 4, 5, 4, 6, 5, 5};
//	uint8_t graph[] = {37, 0, 0, 0,   3, 2, 		8, 1, 1, 6, 10, 4, 		9, 1, 1, 6, 10, 4, 		10, 1, 1, 6, 10, 4,			2,		4, 1, 7, 2, 3, 	4, 2, 7, 1, 2, 		1, 2, 1, 	2, 3, 1};	
//	uint8_t graph[] = {47, 0, 0, 0,  	4, 3, 	8, 1, 1, 6, 10, 4, 		8, 1, 1, 6, 10, 4, 		9, 1, 1, 6, 10, 4, 		10, 1, 1, 6, 10, 4,				2,		5, 1, 7, 2, 3, 4,		4, 2, 7, 1, 2, 		1, 3, 1, 	2, 3, 2,	3, 4, 1};	
//	uint8_t graph[] = {67, 0, 0, 0,  		6, 5, 		8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			9, 1, 1, 6, 10, 4, 			10, 1, 1, 6, 10, 4,					2,	5, 1, 7, 4, 5, 6,			6, 2, 7, 1, 2, 3, 4,  			1, 5, 1, 		2, 5, 2,		3, 5, 3,	4, 5, 4,	5, 6, 1	};	
//	uint8_t graph[] = {74, 0, 0, 0,  		6, 5, 		8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			9, 1, 1, 6, 10, 4, 			10, 1, 1, 6, 10, 4,					3,	5, 1, 7, 4, 5, 6,			6, 2, 7, 1, 2, 3, 4,  	6, 5, 6, 4, 1, 2, 3, 		1, 5, 1, 		2, 5, 2,		3, 5, 3,	4, 5, 4,	5, 6, 1	};	
	uint8_t graph[] = {56, 0, 0, 0,  			5, 4, 			8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			8, 1, 1, 6, 10, 4, 			9, 1, 1, 6, 10, 4, 			10, 1, 1, 6, 10, 4,						2,		4, 1, 7, 1, 5,			5, 2, 7, 1, 2, 3,  		1, 4, 1, 		2, 4, 2,		3, 4, 3,	4, 5, 1};	



	command result_t StdControl.init () {
		return SUCCESS;
	}

	command result_t StdControl.start () {
		call Timer.start (TIMER_ONE_SHOT, 2000);
//		call SDTimer.start (TIMER_ONE_SHOT, 4000);
		return SUCCESS;
	}

	command result_t StdControl.stop () {
		return SUCCESS;
	}

	event result_t InternalInterface.passToken (uint8_t sid, ServiceMsg message) {
		if ((sid & 0x1f) == LOCALIZE) {
			switch ((sid>>5)&(0x07)) {
				case 1:
					call LocalizeInterface.output_port2 (message);
					break;
				case 2:
					call LocalizeInterface.output_port3 (message);
					break;
				case 3:
					call LocalizeInterface.output_port4 (message);
					break;
/*				case 4:
					call LocalizeInterface.output_port5 (message);
					break;
*/				default:
					call LocalizeInterface.output_port1 (message);
					break;
			}
		} else if (sid == NOTIFY) {
			call NotifyInterface.output (message);
		} else if (sid == READ_TEMP) {
			call ReadTInterface.output (message);
		} else if (sid == WIND) {
			call WindInterface.output (message);
		}
		return SUCCESS;
	}

	// fill up a new message
	task void fillMsg () {
		// this task breaks the delivery of message in multiple service-messages

//call Send.output (ctrl.src, ctrl.srcs, ctrl.dst, (ctrl.dsts&0x1f), ctrl.dsts>>5);

		// next service-message in current sequence
		msg.seqNum = msgSeqNum++;
		// if there is more data than current message
		if (currentLength > SERVICE_MSG_DATA_LENGTH) {
			memcpy (msg.data, starts, SERVICE_MSG_DATA_LENGTH);
			starts = starts + SERVICE_MSG_DATA_LENGTH;
			currentLength = currentLength - SERVICE_MSG_DATA_LENGTH;
		} else {
			// last message packet
			memcpy (msg.data, starts, currentLength);
			pending = FALSE;
		}
		// deliver service message to destination service
		if (ctrl.dsts == COMPOSER) {
			call ComposerInterface.output (msg);
		} else if ((ctrl.dsts & 0x1f) == LOCALIZE) {
			switch ((ctrl.dsts>>5)&(0x07)) {
				case 1:
					call LocalizeInterface.output_port2 (msg);
					break;
				case 2:
					call LocalizeInterface.output_port3 (msg);
					break;
				case 3:
					call LocalizeInterface.output_port4 (msg);
					break;
/*				case 4:
					call LocalizeInterface.output_port5 (msg);
					break;
*/				default:
					call LocalizeInterface.output_port1 (msg);
					break;
			}
		} else if (ctrl.dsts == NOTIFY) {
			call NotifyInterface.output (msg);
		} else if (ctrl.dsts == READ_TEMP) {
			call ReadTInterface.output (msg);
		} else if (ctrl.dsts == WIND) {
			call WindInterface.output (msg);
		}
	}
	
	/**
	 * Receives a big message and dispatches it to appropriate actor. 
	 * @param addr big message source node id.
	 * @param start big message start pointer <code>void *</code>.
	 * @param end big message end pointer <code>void *</code>.
	 * @return returns <code>FAIL</code> if destination service for message is unknown.
	**/
	command result_t InputInterface.receive (uint16_t addr, void* start, void* end) {
		// This command must find the destination service, type of message and cast it to appropriate message format
		// before forwarding it to appropriate actor
		// Composer and local services expect one or more ServiceMsgs. this function sends multiple ServiceMsgs if the total length of 
		// the message to be forwarded is more than size of ServiceMsg. 

		// begining and end of service message
		starts = start;
		ends = end;
		totalLength = ends - starts - sizeof(SControl); // length of the service message without the service control part 
		currentLength = totalLength + sizeof(totalLength); // length of the message that would be passes to actors... used only for variable length messages
		
		// reterive the service message control part
		ctrl = *((SControl *)starts);
		// if destination service is service-discovery 
		if (ctrl.dsts == SDP) {
			memcpy (&sdmsg, starts, sizeof(SDMsg));
			call SDInterface.output (sdmsg);
		}
		// if destination service is composer
		else if (ctrl.dsts == COMPOSER) {
			msgSeqNum = 0xFF;
			pending = TRUE;
			// strip the SControl part from the message	and add the total length 
			starts = starts + (sizeof(SControl)-sizeof(totalLength));
			starts = memcpy (starts,&totalLength,sizeof(totalLength));
			// post a task to send whole message in ServiceMsg-sized chunks
			post fillMsg ();
		}
		// if the destination is a local service 
		else if ((ctrl.dsts & 0x1f) == LOCALIZE) {
			msgSeqNum = 0xFF;
			pending = TRUE;
			// strip the SControl part from the message	and add total length
			starts = starts + (sizeof(SControl)-sizeof(totalLength));
			starts = memcpy (starts,&totalLength,sizeof(totalLength));
			// if the desitnation service has already been configured (as part of some service application)
			if (call InternalInterface.isConfigured (LOCALIZE) == SUCCESS) {
				// post a task to send whole message in ServiceMsg-sized chunks
				post fillMsg ();
			} else { // unexpected message for local service
				return FAIL;
			}
		}
		// if the destination is a local service 
		else if (ctrl.dsts == NOTIFY) {
			msgSeqNum = 0xFF;
			pending = TRUE;
			// strip the SControl part from the message	and add total length
			starts = starts + (sizeof(SControl)-sizeof(totalLength));
			starts = memcpy (starts,&totalLength,sizeof(totalLength));
			// if the desitnation service has already been configured (as part of some service application)
			if (call InternalInterface.isConfigured (NOTIFY) == SUCCESS) {
				// post a task to send whole message in ServiceMsg-sized chunks
				post fillMsg ();
			} else { // unexpected message for local service
				return FAIL;
			}
		}
		// if the destination is a local service 
		else if (ctrl.dsts == READ_TEMP) {
			msgSeqNum = 0xFF;
			pending = TRUE;
			// strip the SControl part from the message	and add total length
			starts = starts + (sizeof(SControl)-sizeof(totalLength));
			starts = memcpy (starts,&totalLength,sizeof(totalLength));
			// if the desitnation service has already been configured (as part of some service application)
			if (call InternalInterface.isConfigured (READ_TEMP) == SUCCESS) {
				// post a task to send whole message in ServiceMsg-sized chunks
				post fillMsg ();
			} else { // unexpected message for local service
				return FAIL;
			}
		}
		// if the destination is node manager (and type is binding)
		else if (ctrl.dsts == NODE_MANAGER && ctrl.type == BINDING) {
			memcpy (&sbmsg, starts, sizeof(SBindMsg));
			if (call InternalInterface.binding (sbmsg) == SUCCESS) {
				if (sbmsg.src_service == READ_TEMP) {
					call ReadTInterface.trigger (6000);
				} else if (sbmsg.src_service == WIND) {
					call WindInterface.trigger (6000);
				} 
			}
		}
		else { // unknown destination service
			return FAIL;
		}
//		signal InputInterface.receiveDone (SUCCESS);
		return SUCCESS;
	}
		

	event result_t ComposerInterface.outputComplete (result_t result) {
		if (result == SUCCESS) {
			// if more data needs to be sent
			if (pending == TRUE) {
				post fillMsg ();
//			} else { // service graph message has been fully deilivered 
//				call ObjectInterface.trigger ();
			}
		}
		return SUCCESS;
	}
		
	// returns true when service graph is fully composed 
	event result_t ComposerInterface.composed (result_t result) {
		// service graph is fully composed 
		if (result == SUCCESS) {
			call ObjectInterface.trigger ();
			call WindInterface.trigger (6000);
			return SUCCESS;
		}
		return FAIL;
	}


	event result_t LocalizeInterface.outputComplete (result_t result) {
/*		if (result == SUCCESS) {
			// if more data needs to be sent
			if (pending == TRUE) {
				post fillMsg ();
			}
		}
*/		return SUCCESS;
	}

	event result_t NotifyInterface.outputComplete (result_t result) {
		return SUCCESS;
	}

	event result_t ReadTInterface.outputComplete (result_t result) {
		return SUCCESS;
	}

	event result_t WindInterface.outputComplete (result_t result) {
		return SUCCESS;
	}


	// fire detection service graph
	task void sample_service_graph () {

		msgSeqNum = 0xFF;
		pending = TRUE;

		ctrl.dsts = COMPOSER;
		starts = graph;
		post fillMsg ();
	}
	


	event result_t Timer.fired () {
		currentLength = 66 + 4;
		post sample_service_graph ();
		return SUCCESS;
	}


		// dummy message received from other nodes... 
	uint8_t dummy[] = {101, 0, 2, 143, 0, 2, 0, 11, 	8, 143, 0, 101, 0, 123, 0, 148, 1, 13, 0, 27, 9};
	uint8_t times = 0;

	event result_t SDTimer.fired () {
			memcpy (&sdmsg, dummy, sizeof(SDMsg));
			call SDInterface.output (sdmsg);
			call Send.output (99, dummy[0], times, 0, 0);
			times += 1;
			if (times < 4) {
//				call SDTimer.start (TIMER_ONE_SHOT, 500);
				switch (times) {
					case 1: dummy[0] = 123;	dummy[11] = 123;	dummy[14] = 3;	dummy[16] = 0;
									break;
					case 2: dummy[0] = 169;	dummy[11] = 169;	dummy[14] = 0;	dummy[16] = 4;
									break;
					case 3: dummy[0] = 147;	dummy[11] = 147;	dummy[14] = 4;	dummy[16] = 3;  dummy[20] = 3;
									break;
					default:
				}
			}
		return SUCCESS;
	}


	event result_t SDInterface.outputComplete (result_t result) {
		signal InputInterface.receiveDone (SUCCESS);
		return SUCCESS;
	}
	
	event result_t Send.outputComplete (result_t result) {
		return SUCCESS;
	}
	

	
}

