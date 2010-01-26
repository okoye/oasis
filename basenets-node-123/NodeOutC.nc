
/**
 * This component receives messages from different actors and sends them over radio using SendBigMsgC. 
*/

module NodeOutC {
	provides {
		interface StdControl;
		interface InternalInterface;
		interface SDInterface;
		interface ServiceBindInterface;
		interface ServiceInterface as ReadTInterface;
	}
	uses {
		interface Timer;
		interface ServiceRequestInterface as CommFailureInterface;
		interface SendBigMsg as SendInterface;
	}
} implementation {
	
	typedef struct Binding {
		uint16_t name;
		uint8_t dst_service;
		uint16_t dst_node;
	} Binding;
	
	Binding local_services[MAX_SERVICES];
	uint8_t ls_size;

	/** 
	 *
	 *
	 *
	 **/
	void initialize_b (Binding list[]) {
		uint8_t i = 0;
		for (i = 0; i < MAX_SERVICES; i++) {
			list[i].name = 0;
			list[i].dst_service = 0;
		}
	}

	bool add_b (Binding list[], uint16_t name, uint8_t dsts, uint16_t dstn, uint8_t size) {
		uint8_t i = 0;
		if (size >= MAX_SERVICES) {
			return 0;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (list[i].name == 0) {
				atomic {
					list[i].name = name;
					list[i].dst_service = dsts;
					list[i].dst_node = dstn;
				}	
				return 1;
			}
		}
		return 0;
	}
	
	uint8_t getIndex_b (Binding list[], uint16_t name, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) {
			return MAX_SERVICES;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (list[i].name == name) {
				return i;
			}
		}
		return MAX_SERVICES;
	}
	
	uint8_t buffer_readt[BIGMSG_BUFFER_SIZE];

	uint8_t send_buffer[BIGMSG_BUFFER_SIZE];
	uint8_t local[21];

	bool pending;
	uint32_t totalLength;
	uint32_t currentLength;

	// destination service for service A (initialized by a binding message)
	uint8_t service_readt_dst;

	command result_t StdControl.init () {
		initialize_b (local_services);
		ls_size = 0;

		return SUCCESS;
	}
	
	command result_t StdControl.start () {
		if (add_b(local_services, READ_TEMP, 0, 0, ls_size)) 	{ ls_size += 1;	}
//		call Timer.start (TIMER_ONE_SHOT,3000);
		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
		call Timer.stop ();
		return SUCCESS;
	}

	// receive service discovery message from service-discovery actor
	command result_t SDInterface.output (SDMsg msg) {
		memcpy (local, &msg, sizeof(SDMsg));
		if (msg.ctrl.type == REQUEST) {
			call SendInterface.send (msg.ctrl.dst, local, local + 11);
		} else {
			call SendInterface.send (msg.ctrl.dst, local, local + sizeof(SDMsg));
		}			
		return SUCCESS;
	}

	// receive binding message from composer
	command result_t ServiceBindInterface.output (SBindMsg msg) {
		// accepts the SBindMsg, if the destination node is same as this then set the appropriate parameter 
		// otherwise compose a BigMsg and output it on SendInterface
		
		// if the source service to be bound is present on current node 
		if (msg.src_node == TOS_LOCAL_ADDRESS) {
			// bind src_service to dst_service
			//... find index of src_service in local_services 
			uint8_t sindex = getIndex_b (local_services, msg.src_service, ls_size);
			local_services[sindex].dst_service = msg.dst_service;
			local_services[sindex].dst_node = msg.dst_node;
			signal ServiceBindInterface.outputComplete (SUCCESS);
			return SUCCESS;
		}
		memcpy (local, &msg, sizeof(SBindMsg));
		if (call SendInterface.send (msg.ctrl.dst, local, local + sizeof(SBindMsg)) == SUCCESS) {
			signal ServiceBindInterface.outputComplete (SUCCESS);
		} else {
			signal ServiceBindInterface.outputComplete (FAIL);
		}
		return SUCCESS;
	}


/** implementation for local services 
 *
 **/
		
	command result_t ReadTInterface.trigger (uint16_t rate) {
		return SUCCESS;
	}

	// receive service message(s) from local service, 'stitch' them together and send it using SendBigMsg
	command result_t ReadTInterface.output (ServiceMsg message) {
		// TODO :: wait for full message to arrive and put it on send interface
		uint8_t readt_index = getIndex_b (local_services, READ_TEMP, ls_size); 
		uint8_t seqNum = message.seqNum;
		SControl ctrl;
		ctrl.src = TOS_LOCAL_ADDRESS;
		ctrl.srcs = READ_TEMP;
		ctrl.dst = local_services[readt_index].dst_node;
		ctrl.dsts = local_services[readt_index].dst_service;
		ctrl.seqnum = 0xFF;
		ctrl.type = 0x0;	// user defined
		if (seqNum > 0x7F) { 
			// highest bit is set to 1 i.e. this is a NEW big messages 
			if (pending == TRUE) { // reception of previous message is yet not finished  
				// should handle the expection properly... for now i will just assume that previous message is finished 
				// also... forward the previous (incomplete) message
				pending = FALSE;
				totalLength = 0;
			}
			// get total length of new message 
			totalLength = *((uint32_t *)message.data); // CHECK (totalLength < BIGMSG_BUFFER_SIZE)... failure is not handled yet

			if (totalLength <= SERVICE_MSG_DATA_LENGTH - sizeof(totalLength) - sizeof(SControl)) { // if no more big message packets to come 
//				call SendInterface.send (service_A_dst, message.data + sizeof(totalLength), message.data + totalLength); 
				memcpy (send_buffer, &ctrl, sizeof(SControl));
				memcpy (send_buffer+sizeof(SControl), message.data+sizeof(totalLength), totalLength);
				call SendInterface.send (ctrl.dst, send_buffer, send_buffer + totalLength + sizeof(SControl)); 
			} else {
				memcpy (buffer_readt, message.data + sizeof(totalLength), SERVICE_MSG_DATA_LENGTH - sizeof(totalLength));
				currentLength = (SERVICE_MSG_DATA_LENGTH - sizeof(totalLength));
				pending = TRUE;
			}
		} 
		else { 
			// old message (continuation of previous message)
			memcpy (buffer_readt + currentLength, message.data, SERVICE_MSG_DATA_LENGTH);
			currentLength = currentLength + SERVICE_MSG_DATA_LENGTH;
			if (currentLength > totalLength) { // this is the last packet of the current big message sequence
				memcpy (send_buffer, &ctrl, sizeof(SControl));
				memcpy (send_buffer+sizeof(SControl), buffer_readt, totalLength);
				call SendInterface.send (ctrl.dst, send_buffer, send_buffer + totalLength + sizeof(SControl)); 
				pending = FALSE;
				totalLength = 0;
			}
		}
		signal ReadTInterface.outputComplete (SUCCESS);
		return SUCCESS;
	}
		
	// service request is returned with service-information message
	event result_t CommFailureInterface.outputInfo (SDMsg msg) {
		// TODO :: bind the failed service to newly discovered service
//		call Timer.start (TIMER_ONE_SHOT,3000);
		call CommFailureInterface.outputClear (SUCCESS);
//		call CommFailureInterface.serviceRequest (3);
		return SUCCESS;
	} 
	
	event result_t CommFailureInterface.requestAccepted (result_t result) {
		return SUCCESS;
	} 
	

	event void SendInterface.sendDone (result_t result) {
		if (result != SUCCESS) {
			// if communication failure (??)
			uint16_t request = 0; // ... TODO :: identify and request
			call CommFailureInterface.serviceRequest (request);
		}
		signal SDInterface.outputComplete (SUCCESS);
	}
	
	// returns success if 'sid' is currently configured i.e. 'sid' is part of some executing service application
	command result_t InternalInterface.isConfigured (uint8_t sid) {
		// if the dst_service for this service is set in local_services then okay... 
		if (local_services[getIndex_b (local_services, sid, ls_size)].dst_service > 0) {
			return SUCCESS;
		} else {
			return FAIL;
		}
	}
			
	event result_t Timer.fired () {
//		call CommFailureInterface.serviceRequest (3);
		return SUCCESS;
	}
	
	// receives binding message from NodeInC (i.e. from other node)
	command result_t InternalInterface.binding (SBindMsg msg) {
		// if the source service to be bound is present on current node 
		if (msg.src_node == TOS_LOCAL_ADDRESS) {
			// bind src_service to dst_service
			//... find index of src_service in local_services 
			uint8_t sindex = getIndex_b (local_services, msg.src_service, ls_size);
			// also CHECK (overwrite)
			local_services[sindex].dst_service = msg.dst_service;
			local_services[sindex].dst_node = msg.dst_node;
			return SUCCESS;
		}
		return FAIL;
	}

	
}

