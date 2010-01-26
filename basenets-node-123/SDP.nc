
/**
 * service discovery protocol module
 *
 * 
 *
 * @author Manish Kushwaha
 * 
 *
 **/
module SDP {
	provides {
		interface StdControl;
		interface SDInterface;
		interface ServiceRequestInterface as NodeRequest;
		interface ServiceRequestInterface as ComposerRequest;
	}
	uses {
		interface SDInterface as OutInterface;
		
		interface SDMsgPit as SDMsgBuffer;
	}
} implementation {
	
	/** 
	 * data structure to keep records of services discovered 
	 **/
	typedef struct Sinfo {
		uint8_t service;
		uint16_t provider;
		uint16_t position[3];
		uint16_t power;
	} Sinfo;

	/** 
	 * 
	 **/
	SDMsg request;
	SDMsg infomsg;

	/** 
	 * position of this node
	 **/
	uint16_t position[3];
	/**
	 * current power level 
	 **/
	uint16_t power;

	/** 
	 * list of local services (present on this node) (will use circular buffer for this)
	 **/
	uint8_t local_services [MAX_SERVICES];
	uint8_t ls_size;

	/** 
	 * list of discovered services (and their information)  (will use circular buffer for this)
	 **/
	Sinfo disc_services [MAX_SERVICES];
	uint8_t ds_size;

	/** 
	 * list of services requested by composer/nodeman (will use circular buffer for this)
	 **/
	uint8_t nodeman_pending [MAX_SERVICES];
	uint8_t nm_size;

	uint8_t composer_pending[MAX_SERVICES];
	uint8_t cp_size;
	
	/** 
	 *
	 **/
	 bool nodepending;
	 bool composerpending;
	 bool pending;

	/** 
	 * 
	 **/
/*	SDMsg buffer[4];
	uint8_t bindex;
	uint8_t oindex;
*/	
		
	void initialize (uint8_t *list) {
		uint8_t i = 0;
		for (i = 0; i < MAX_SERVICES; i++) {
			*(list+i) = 0;
		}
	}

	bool add(uint8_t *list, uint8_t val, uint8_t size) {
		uint8_t i = 0;
		if (size >= MAX_SERVICES) {
			return 0;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (*(list+i) == 0) {
				*(list+i) = val;
				return 1;
			}
		}
		return 0;
	}
	
	bool remove(uint8_t *list, uint8_t val, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) {
			return 0;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (*(list+i) == val) {
				*(list+i) = 0;
				return 1;
			}
		}
		return 0;
	}
	
	bool check (uint8_t *list, uint8_t val, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) {
			return 0;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (*(list+i) == val) {
				return 1;
			}
		}
		return 0;
	}
	

	/** 
	 *
	 *
	 *
	 **/
	void initialize_1 (Sinfo list[]) {
		uint8_t i = 0;
		for (i = 0; i < MAX_SERVICES; i++) {
			list[i].service = 0;
		}
	}

	bool add_1 (Sinfo list[], uint8_t ser, uint16_t prov, uint16_t pos[], uint16_t pw, uint8_t size) {
		uint8_t i = 0;
		if (size >= MAX_SERVICES) {
			return 0;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (list[i].service == 0) {
				atomic {
					list[i].service = ser;
					list[i].provider = prov;
//					memcpy (list[i].provider, pos, 6);
					list[i].position[0] = pos[0];
					list[i].position[1] = pos[1];
					list[i].position[2] = pos[2];
					list[i].power = pw;
				}	
				return 1;
			}
		}
		return 0;
	}
	
/*	bool remove(Sinfo *list, uint16_t ser, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) {
			return 0;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (*(list+i).service == ser) {
				*(list+i).service = 0;
				return 1;
			}
		}
		return 0;
	}
*/	
	uint8_t getIndex (Sinfo list[], uint8_t ser, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) {
			return MAX_SERVICES;
		}
		for (i = 0; i < MAX_SERVICES; i++) {
			if (list[i].service == ser) {
				return i;
			}
		}
		return MAX_SERVICES;
	}

	/** 
	 * 
	 **/
	command result_t StdControl.init () {
		initialize (local_services);
		ls_size = 0;

		initialize (composer_pending);
		cp_size = 0;

		initialize (nodeman_pending);
		nm_size = 0;

		initialize_1 (disc_services);
		ds_size = 0;

		call SDMsgBuffer.init ();

		return SUCCESS;
	}
	
	/** 
	 * 
	 **/
	command result_t StdControl.start () {
		if (add (local_services,READ_TEMP,ls_size)) {			ls_size += 1;		}
		// properties of current node
		position[0] = 600;
		position[1] = 700;
		position[2] = 13;
		power = 2331;
		pending = FALSE;
		
		return SUCCESS;
	}
	
	/** 
	 * 
	 **/
	command result_t StdControl.stop () {
		return SUCCESS;
	}

	/** 
	 * compose infomation message in response to a service request
	 **/
	void composeInfo (SDMsg msg, uint8_t sid) {
		// set the control part
		infomsg.ctrl.src = TOS_LOCAL_ADDRESS;
		infomsg.ctrl.srcs = SDP;
		infomsg.ctrl.dst = msg.ctrl.src;
		infomsg.ctrl.dsts = msg.ctrl.srcs;
		infomsg.ctrl.seqnum = 0;
		infomsg.ctrl.type = INFO;
		// set the data part		
		infomsg.service = sid;
		infomsg.origin = msg.origin;
		infomsg.provider = TOS_LOCAL_ADDRESS;
		infomsg.position[0] = position[0];
		infomsg.position[1] = position[1];
		infomsg.position[2] = position[2];
		infomsg.power = power;
	}
	
	/** 
	 * 
	 **/
	task void SendInfo2Node () {
		if (!nodepending) {
			signal NodeRequest.outputInfo (infomsg);
			nodepending = TRUE;
		}
	}

	/** 
	 * 
	 **/
	task void SendInfo2Composer () {
		if (!composerpending) {
			signal ComposerRequest.outputInfo (infomsg);
			composerpending = TRUE;
		} else {
			// wait and send
		}
	}

	task void SendRequest () {
		if (!pending) {
			if (call SDMsgBuffer.numElements () > 0) {
				if (call OutInterface.output (call SDMsgBuffer.top ()) == FAIL) {
					// try after some time
//					post SendRequest ();
				} else {
					pending = TRUE;
				}
			}
		}
	}
				
	/** 
	 * 
	 **/
/*	task void SendRequest () {
		if (!pending) {
			if (oindex < bindex) {
				if (call OutInterface.output (buffer[oindex]) == FAIL) {
					// try after some time
//					post SendRequest ();
				} else {
					pending = TRUE;
				}
			}
		}
	}*/
	
	/** 
	 * 
	 **/
	command result_t SDInterface.output (SDMsg msg) {
		// this command accepts SDMsg. 
		// if it is a service request message then find if the requested service is present, 
		// compose an information message and output it on OutInterface.
		// if it is an information message then save the information. if someone was waiting on this information 
		// then signal the event
		
		// message type 
		uint8_t type = msg.ctrl.type;
		// service associated with the message
		uint8_t sid = msg.service;

		// if the message is a request 
		if (type == REQUEST) {
			// if the requested service is present locally 
			if ( check (local_services,sid,ls_size) ) {
				// then compose an infomation message and send it to OutputInterface... DOES NOT FORWARD the request hence SINGLE HOP DISCOVERY
				composeInfo (msg, sid);
				call SDMsgBuffer.add (infomsg);
//				buffer[bindex++] = infomsg;
				post SendRequest ();
//				call OutInterface.output (infomsg);
			}
		}
		// if the message is an information
		else if (type == INFO) {
			// save the information in discovered-services list
			if (add_1 (disc_services, msg.service, msg.provider, msg.position, msg.power, ds_size)) {
				ds_size += 1;
			}
//			call Send.output (ds_size,msg.service,msg.provider,msg.power,0);
			infomsg = msg;
			// check if composer and/or node manager were waiting on this service and signal them with the information
			// if sid present in composer_requests
			if (check(composer_pending,sid,cp_size)) {
//				cp_size -= 1;
				post SendInfo2Composer ();
//				signal ComposerRequest.outputInfo (msg);
			} 
			// if sid present in node_requests
			if (check(nodeman_pending,sid,nm_size)) {
//				nm_size -= 1;
				post SendInfo2Node ();
//				signal NodeRequest.outputInfo (msg);
			}	
		}
		signal SDInterface.outputComplete (SUCCESS);
		return SUCCESS;
	}
	

	/** 
	 * 
	 **/
	command result_t NodeRequest.serviceRequest (uint8_t sid) {
		// lookup the local repository, if the requested service is not present then compose a service request message
		// and output it to OutInterface
		// mark a flag to indicate that node-manager is waiting on this service 
		uint8_t tindex;
//		signal NodeRequest.requestAccepted (SUCCESS);
		// if the requested service is present locally 
		if (check (local_services,sid,ls_size)) {
			infomsg.service = sid;
			infomsg.origin = TOS_LOCAL_ADDRESS;
			infomsg.provider = TOS_LOCAL_ADDRESS;
			infomsg.position[0] = position[0];
			infomsg.position[1] = position[1];
			infomsg.position[2] = position[2];
			infomsg.power = power;
			post SendInfo2Node ();
//			signal NodeRequest.outputInfo (infomsg);
		}
		// if the requested service is present in the discovered services list
		else if ( (tindex = getIndex (disc_services, sid, ds_size)) < MAX_SERVICES ) {
			infomsg.service = sid;
			infomsg.origin = disc_services[tindex].provider;
			infomsg.provider = disc_services[tindex].provider;
			infomsg.position[0] = disc_services[tindex].position[0];
			infomsg.position[1] = disc_services[tindex].position[1];
			infomsg.position[2] = disc_services[tindex].position[2];
			infomsg.power = disc_services[tindex].power;
			post SendInfo2Node ();
//			signal NodeRequest.outputInfo (infomsg);
		}
		// otherwise compose a service request message and put it on OutputInterface
		else { 
			if (check (nodeman_pending,sid,nm_size) == 0) {
				request.ctrl.src = TOS_LOCAL_ADDRESS;
				request.ctrl.srcs = SDP;
				request.ctrl.dst = TOS_BCAST_ADDR;
				request.ctrl.dsts = SDP;
				request.ctrl.seqnum = 0;
				request.ctrl.type = REQUEST;
			
				request.service = sid;
				request.origin = TOS_LOCAL_ADDRESS;
				// mark a pending flag... handle INDEX OVERFLOW
				if (add (nodeman_pending,sid,nm_size)) {
					nm_size += 1;
				}
				call SDMsgBuffer.add (request);
	//			buffer[bindex++] = request;
				post SendRequest ();
	//			call OutInterface.output (request);
			}
		}
		signal NodeRequest.requestAccepted (SUCCESS);
		return SUCCESS;
	}
	
	/** 
	 * 
	 **/
	command result_t ComposerRequest.serviceRequest (uint8_t sid) {
		// lookup the local repository, if the requested service is not present then compose a service request message
		// and output it to OutInterface
		// mark a flag to indicate that composer is waiting on this service 
		uint8_t tindex;
		// if the requested service is present locally ... then store the information in disc_services but continue with further discovery
		if (check (local_services,sid,ls_size)) {
			infomsg.service = sid;
			infomsg.origin = TOS_LOCAL_ADDRESS;
			infomsg.provider = TOS_LOCAL_ADDRESS;
			infomsg.position[0] = position[0];
			infomsg.position[1] = position[1];
			infomsg.position[2] = position[2];
			infomsg.power = power;
			post SendInfo2Composer ();
//			signal ComposerRequest.outputInfo (infomsg);
		}
		// if the requested service is present in the discovered services list
		if ( (tindex = getIndex (disc_services, sid, ds_size)) < MAX_SERVICES ) {
			infomsg.service = sid;
			infomsg.origin = disc_services[tindex].provider;
			infomsg.provider = disc_services[tindex].provider;
			infomsg.position[0] = disc_services[tindex].position[0];
			infomsg.position[1] = disc_services[tindex].position[1];
			infomsg.position[2] = disc_services[tindex].position[2];
			infomsg.power = disc_services[tindex].power;
			post SendInfo2Composer ();
//			signal ComposerRequest.outputInfo (infomsg);
		}
		// otherwise compose a service request message and put it on OutputInterface
//		else {	// OPTIONAL.... discover more or be satisfied with current information???
			// composer a request message 
			if (check (composer_pending,sid,cp_size) == 0) {
				// already made request for this service 
				request.ctrl.src = TOS_LOCAL_ADDRESS;
				request.ctrl.srcs = SDP;
				request.ctrl.dst = TOS_BCAST_ADDR;
				request.ctrl.dsts = SDP;
				request.ctrl.seqnum = 0;
				request.ctrl.type = REQUEST;
			
				request.service = sid;
				request.origin = TOS_LOCAL_ADDRESS;
				// mark a pending flag... handle INDEX OVERFLOW
				if (add (composer_pending, sid, cp_size)) {
					cp_size += 1;
				}
				call SDMsgBuffer.add (request);
//				buffer[bindex++] = request;
				post SendRequest ();
//				call OutInterface.output (request);
			}
//		}
		signal ComposerRequest.requestAccepted (SUCCESS);
		return SUCCESS;
	}
	
	/** 
	 * 
	 **/
	event result_t OutInterface.outputComplete (result_t result) {
//		if (result == SUCCESS) {
//			oindex++;
//		}
		pending = FALSE;
		post SendRequest ();
		return SUCCESS;
	}
	
	/** 
	 * 
	 **/
	command result_t NodeRequest.outputClear (result_t result) {
		if (result == SUCCESS) {
			nodepending = FALSE;
//			post SendInfo2Node ();
		}
		return SUCCESS;
	}

	/** 
	 * 
	 **/
	command result_t ComposerRequest.outputClear (result_t result) {
		if (result == SUCCESS) {
			composerpending = FALSE;
//			post SendInfo2Composer ();
		}
		return SUCCESS;
	}

}

