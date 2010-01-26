
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

		interface ServiceInterface as ReadTInterface;

		interface Timer;
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

	command result_t StdControl.init () {
		return SUCCESS;
	}

	command result_t StdControl.start () {
//		call Timer.start (TIMER_ONE_SHOT, 2000);
		return SUCCESS;
	}

	command result_t StdControl.stop () {
		return SUCCESS;
	}

	event result_t InternalInterface.passToken (uint8_t sid, ServiceMsg message) {
		return SUCCESS;
	}

	// fill up a new message
	task void fillMsg () {
		// this task breaks the delivery of message in multiple service-messages

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
		} else if (ctrl.dsts == READ_TEMP) {
			call ReadTInterface.output (msg);
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
//call Send.output (ctrl.type, sbmsg.src_node, sbmsg.src_service, sbmsg.dst_node, sbmsg.dst_service);
			if (call InternalInterface.binding (sbmsg) == SUCCESS) {
				if (sbmsg.src_service == READ_TEMP) {
					call ReadTInterface.trigger (6000);
				} 
//				else if (sbmsg.src_service == READ_TEMP) {
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
			return SUCCESS;
		}
		return FAIL;
	}


	event result_t ReadTInterface.outputComplete (result_t result) {
		return SUCCESS;
	}

	event result_t Timer.fired () {
		currentLength = 80;
//		post sample_service_graph ();
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

