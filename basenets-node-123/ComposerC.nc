
/**
 * 
 **/
module ComposerC {
	provides {
		interface ComposerInterface;
		interface StdControl;
	}
	uses {
		interface Timer as TimeoutTimer;
		interface ServiceRequestInterface as RequestInterface;
		interface ServiceBindInterface as BindInterface;
		interface Int3Output as Send;
	}
} 
implementation {
	/**
	 * variables to store and process service graph message
	 **/
	uint32_t totalLength;
	uint32_t currentLength;
	uint8_t buffer[SERVICE_GRAPH_BUFFER_SIZE];
	uint8_t *current_buffer_pointer;
	/**
	 * 
	 **/
	uint8_t pending;
	uint8_t timerStarted;
	
	uint8_t again;
	/**
	 * number of services and constraints
	 **/
	uint8_t numServices;
	uint8_t numCompConstraints;
	
	/**
	 * starting pointer of connections in buffer
	 **/
	uint8_t connectionIndex;
	uint8_t compositionalConstraintIndex;
	
	/**
	 * variables to store the requested service ids
	 **/
	uint8_t requests[MAX_SERVICES];
	uint8_t next;

	/**
	 * variables for binding messages
	 **/
	uint8_t nextbind;
	uint8_t next_bind_output;
	SBindMsg binds[6]; 
	
	/**
	 * variables to store node list
	 **/
	typedef struct NodeInfo {
		uint16_t id;
		uint16_t position[3];
		uint16_t power;
	} NodeInfo;
	NodeInfo node_list[MAX_NODES];
	uint8_t numNodes;


	/** 
	 *
	 *
	 *
	 **/
	void initialize_ni (NodeInfo list[]) {
		uint8_t i = 0;
		for (i = 0; i < MAX_NODES; i++) {
			list[i].id = 0;
		}
	}

	uint8_t add_ni (NodeInfo list[], uint16_t id, uint16_t pos[], uint16_t pw, uint8_t size) {
		uint8_t i = 0;
		if (size >= MAX_NODES) {
			return MAX_NODES;
		}
		for (i = 0; i < MAX_NODES; i++) {
			if (list[i].id == 0) {
				atomic {
					list[i].id = id;
					list[i].position[0] = pos[0];
					list[i].position[1] = pos[1];
					list[i].position[2] = pos[2];
					list[i].power = pw;
				}	
				return i;
			}
		}
		return MAX_NODES;
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
	uint8_t getIndex_ni (NodeInfo list[], uint16_t id, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) {
			return MAX_NODES;
		}
		for (i = 0; i < MAX_NODES; i++) {
			if (list[i].id == id) {
				return i;
			}
		}
		return MAX_NODES;
	}
	
	bool check_ni (NodeInfo list[], uint16_t id, uint8_t size) {
		if (getIndex_ni(list,id,size) < MAX_NODES) {
			return 1;
		}
		return 0;
	}
	


	/**
	 * variables to store service domains
	 **/
	typedef struct ServiceDomain {
		uint8_t service;
		uint8_t bufferPtr;
		uint8_t solution;
		uint8_t domain[MAX_SERVICES];
		uint8_t domain_size;
	} ServiceDomain; 
	ServiceDomain services[MAX_SERVICES];
	
	/**
	 * 
	 **/
	command result_t StdControl.init () {
		timerStarted = FALSE;
		return SUCCESS;
	}
	
	/**
	 * 
	 **/
	command result_t StdControl.start () {
		pending = FALSE;
		totalLength = 0;
		currentLength = 0;
		connectionIndex = 0;
		nextbind = 0;

		initialize_ni (node_list);
		numNodes = 0;
		
		again = 0;

		return SUCCESS;
	}
	
	/**
	 * 
	 **/
	command result_t StdControl.stop () {
		return SUCCESS;
	}
	
	
	/**
	 * 
	 * function to evaluate a property constraint
	 **/
	result_t evaluateProperty(uint16_t nodePropertyValue, uint8_t operator, uint16_t desiredValue) {
	
		uint8_t retval = FALSE;
		
		switch (operator) {
			case EQUAL_TO:
				if (nodePropertyValue == desiredValue) retval = TRUE;
				break;
			case NOT_EQUAL_TO:
				if (nodePropertyValue != desiredValue) retval = TRUE;
				break;
			case LESS_THAN:
				if (nodePropertyValue < desiredValue) retval = TRUE;
				break;
			case GREATER_THAN:
				if (nodePropertyValue > desiredValue) retval = TRUE;
				break;
			case GREATER_THAN_EQUAL_TO:
				if (nodePropertyValue >= desiredValue) retval = TRUE;
				break;
			case LESS_THAN_EQUAL_TO:
				if (nodePropertyValue <= desiredValue) retval = TRUE;
				break;
			default:
				retval = FALSE;
				break;
		}
		return retval;
	}
	
	/**
	 * 
	 **/
	task void make_requests () {
		if (next < numServices) {
			call RequestInterface.serviceRequest ( requests[next]);
		} 
	}

	
	/**
	 * 
	 **/
	command result_t ComposerInterface.output (ServiceMsg message) {
	
		// composer accepts the service graph as a sequence of ServiceMsg.
		// composer parses the service graph and generates service request messages and puts the requests on RequestInterface
		// NOTE: request for services should be made separately

		uint8_t currentServiceIndex = 0;
		uint8_t i = 0;
		uint8_t numConstraints = 0;
		
		if (message.seqNum > 127 && pending == FALSE) { 
			// highest bit is set to 1 i.e. this is a new service graph message
			// get total length of new message 
			totalLength = *((uint32_t *)message.data); // first four bytes indicate length of entire message
			
			// check that totalLength < SERVICE_GRAPH_BUFFER_SIZE
			if (totalLength > SERVICE_GRAPH_BUFFER_SIZE) {
				// handle this error somehow
			}
			current_buffer_pointer = memcpy (buffer, message.data + SERVICE_MSG_LENGTH_HEADER, SERVICE_MSG_DATA_LENGTH - SERVICE_MSG_LENGTH_HEADER);
			current_buffer_pointer = current_buffer_pointer + (SERVICE_MSG_DATA_LENGTH - SERVICE_MSG_LENGTH_HEADER); 
			currentLength = SERVICE_MSG_DATA_LENGTH - SERVICE_MSG_LENGTH_HEADER;
		}
		else if (pending == TRUE) {
			// already working on a service graph
			return FAIL;
		}
		else {
		
			// old message (continuation of previous message)
			current_buffer_pointer = memcpy (current_buffer_pointer, message.data, SERVICE_MSG_DATA_LENGTH);
			current_buffer_pointer = current_buffer_pointer + SERVICE_MSG_DATA_LENGTH;
			currentLength = currentLength + SERVICE_MSG_DATA_LENGTH;
		}

//			call Send.output (totalLength,currentLength,0,0,0);

		// if the entire service graph has been received, 
		// parse the graph and send each service to the Service Discovery Protocol
		if (currentLength >= totalLength) {
			// Find out how many services are contained in the service graph
			// The first byte in the service graph contains this number
			numServices = buffer[0];
			currentServiceIndex = 2;
			
			for (i = 0; i < numServices; i++) {
				// should we check to make sure we haven't already come across this service in the service graph ???
			
				// send this service to the Service Discovery Protocol:
				// RequestInterface is connected to ServiceDiscovery, 
				// the information will be returned by event 'outputInfo'
				requests[i] = buffer[currentServiceIndex];
				// DUPLICATE REQUESTS --- if requested service is already present in request list then dont add it  

				services[i].service = buffer[currentServiceIndex];
				services[i].bufferPtr = currentServiceIndex;
				services[i].domain_size = 0;
//				call RequestInterface.serviceRequest ( buffer[currentServiceIndex] + (buffer[currentServiceIndex+1] << 8) );

				// Get the number of constraints attached to this service
				numConstraints = buffer[currentServiceIndex + 1];
				// figure out which byte in the buffer is the next service
				// :: (each constraint consumes 4 bytes) ::
				// WARNING :: HACK... FOR NOW.... @RAC comsumes variable number of bytes
				currentServiceIndex += 4*numConstraints + 2;
			}
			// remember the buffer position where the connections begin
			compositionalConstraintIndex = currentServiceIndex;
			connectionIndex = currentServiceIndex;

//		call RequestTimer.start (TIMER_REPEAT, 2000);
			next = 0;
			post make_requests ();
		}

		signal ComposerInterface.outputComplete (SUCCESS);
		return SUCCESS;
	} 


	/**
	 * 
	 **/
	event result_t RequestInterface.outputInfo (SDMsg serviceInfo) {

		// service information corresponding to an earlier service request is returned in this event 
		// composer generates binding messages from the available service information
		uint8_t constraintIndex;
		uint8_t currentProperty = 0;
		uint8_t currentOperator = 0;
		uint16_t currentValue = 0;
		bool constraintsSatisfied = TRUE;
		uint8_t numConstraints = 0;
		uint8_t i = 0;
		uint8_t j = 0;

		uint8_t nodeIndex;
		bool already_present = FALSE;
		
		// If timeout timer hasn't been started, start it.
		// When it fires, the current binding info will be sent to NodeManager
		if (!timerStarted) {
			call TimeoutTimer.start (TIMER_ONE_SHOT, SERVICE_DISCOVERY_TIMEOUT);
			timerStarted = TRUE;
		}
		
		// add node information to the node list
		// check if this node information already exist
		nodeIndex = getIndex_ni (node_list, serviceInfo.provider, numNodes);
		if (nodeIndex >= MAX_NODES) {
			// new node information
			nodeIndex = add_ni (node_list, serviceInfo.provider, serviceInfo.position, serviceInfo.power, numNodes);
			numNodes += 1;
		} 
//		else if (node_list[nodeIndex].service == serviceInfo.service) {
			// we already have information about this service from this node 
//			return SUCCESS;
//		}
			
		
		// add node index to the service domain
		for(i = 0; i < numServices; i++) {
			if (services[i].service == serviceInfo.service) {
				// new domain entry to existing service information
				
		// ---DOUBLE COUNTING--- OF SAME NODE IN A SERVICE"S DOMAIN... BECAUSE OUTPUTINFO IS TRIGGERED MULTIPLE TIMES
				// check if services.domain contains nodeIndex+1 
				for (j = 0; j < MAX_SERVICES; j++) {
					if (services[i].domain[j] == nodeIndex+1) {
						already_present = TRUE;
						break;
					}
				}
				if (already_present) {
					break;
				}
				// check atomic constraints on this service... proceed only if satisfied
				numConstraints = buffer[services[i].bufferPtr+1];
				
				// Take a look at the service's constraints.
				// If there aren't any, add this service info
				if (numConstraints == 0) {
						constraintsSatisfied = TRUE;
				}	else {
					// move cursor to constraint property
					constraintIndex = services[i].bufferPtr + 2;
					// set the constraintsSatisfied flag to TRUE for now
					constraintsSatisfied = TRUE;
					
					for (j = 0; j < numConstraints; j++) {
						// get the current property, operator, and value
						currentProperty = buffer[constraintIndex];
						currentOperator = buffer[constraintIndex + 1];
						currentValue = buffer[constraintIndex+2] + (buffer[constraintIndex+3] << 8);
					
						// examine the property.
						// based on the property, call the specified function
						switch (currentProperty) {
							case POWER:
								constraintsSatisfied = constraintsSatisfied & (evaluateProperty (serviceInfo.power, currentOperator, currentValue));
								break;
							case X_POSITION:
								constraintsSatisfied = constraintsSatisfied & (evaluateProperty (serviceInfo.position[0], currentOperator, currentValue));
								break;
							case Y_POSITION:
								constraintsSatisfied = constraintsSatisfied & (evaluateProperty (serviceInfo.position[1], currentOperator, currentValue));
								break;
							case Z_POSITION:
								constraintsSatisfied = constraintsSatisfied & (evaluateProperty (serviceInfo.position[2], currentOperator, currentValue));
								break;
							case ID: // NOTE:: ID and TYPE constraint properties need to be evaluated in different way because they involve checking a set
								constraintsSatisfied = constraintsSatisfied & (evaluateProperty (serviceInfo.provider, currentOperator, currentValue));
								break;
							case TYPE:
								switch (currentValue) {
									case WEB_SERVICE:
										if (serviceInfo.provider == BASE_STATION) {
											constraintsSatisfied = constraintsSatisfied & TRUE;
										}
										break;
									case NODE_SERVICE: 
										if (serviceInfo.provider != BASE_STATION) {
											constraintsSatisfied = constraintsSatisfied & TRUE;
										}
										break;
								}
								break;			
							// ... WORK ON OTHERS TOO 
						}
						// move cursor to next constraint
						constraintIndex = constraintIndex + 4;
					}
				}
				// if all constraints are satisfied, add this service info
				if (constraintsSatisfied) {
					services[i].domain[services[i].domain_size++] = nodeIndex + 1 ;
				}
			}
		}

//		call Send.output (serviceInfo.provider, serviceInfo.service, services[0].domain_size, services[4].domain_size,ek_count);

		if (i >= numServices) {
			// some problem ... 
		}

		call RequestInterface.outputClear (SUCCESS);
		return SUCCESS;
	}
	
	/**
	 * 
	 **/
	task void bindMsg () {
		if (next_bind_output < nextbind) {
			call BindInterface.output (binds[next_bind_output]);
		} else {
			signal ComposerInterface.composed (SUCCESS);
		}
	}

	/**
	 *
	 *
	 *
	 **/
	uint8_t add (uint8_t list[], uint8_t e, uint8_t size) {
		if (size >= MAX_SERVICES) {	return size;	}
		list[size++] = e;
		return size;
	}
	
	bool check (uint8_t list[], uint16_t e, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) { return 0;	}
		for (i = 0; i < size; i++) {
			if (list[i] == e) {
				return 1;
			}
		}
		return 0;
	}
	
	// list1  <-  list1  U  list2
	uint8_t domain_union (uint8_t *list1, uint8_t *list2, uint8_t size1, uint8_t size2) {
		uint8_t i;
		for (i = 0; i < size2; i++) {
			if ( !check (list1, *(list2+i), size1) ) {
				size1 = add (list1, *(list2+i), size1);
			}
		}
		return size1;
	}
	
	// TODO:: 
	bool ccw (uint8_t a, uint8_t b, uint8_t c) { // need node information
		if ((a==b) || (b==c) || (c==a)) {
			return 0;
		} else {
	//		ax = node_list[a-1].position[0]; ay = node_list[a-1].position[1];
			// numerator = (ax - bx)*(ay-cy) - (ax-cx)*(ay-by)
			// denom = (ax - bx)*(ax-cx) + (ay-by)*(ay-cy)
			int32_t ax = node_list[a-1].position[0];
			int32_t ay = node_list[a-1].position[1];
			int32_t bx = node_list[b-1].position[0];
			int32_t by = node_list[b-1].position[1];
			int32_t cx = node_list[c-1].position[0];
			int32_t cy = node_list[c-1].position[1];
			
			int32_t numerator = (ax - bx)*(ay-cy) - (ax - cx)*(ay - by);
			if (numerator > 0) {
				return 1;
			}
		}
		return 0;
	}
	
	uint8_t possibilities (uint8_t e, uint8_t *d1, uint8_t *d2, uint8_t size1, uint8_t size2, uint8_t *p) {
		uint8_t size = 0;
		uint8_t i, j;
		for (i = 0; i < size1; i++) {
			for (j = 0; j < size2; j++) {
				if ( ccw(e, *(d1+i), *(d2+j)) ) {
					size = add (p, *(d1+i), size);
					size = add (p, *(d2+j), size);
				}
			}
		}
		return size;
	}
						
	uint8_t combine_possibilities (uint8_t e, uint8_t *p1, uint8_t *p2, uint8_t size1, uint8_t size2, uint8_t *cp, uint8_t size) {
		uint8_t i, j;
		for (i = 0; i < size1; i+=2) {
			for (j = 0; j < size2; j+=2) {
				if ( *(p1+i+1) == *(p2+j) ) {
					*(cp+(size++)) = e;
					*(cp+(size++)) = *(p1+i);
					*(cp+(size++)) = *(p1+i+1);
					*(cp+(size++)) = *(p2+j+1);
				}
			}
		}
		return size;
	}
	
	bool check_consec (uint8_t list[], uint8_t u, uint8_t v, uint8_t size) {
		uint8_t i = 0;
		if (size == 0) { return 0;	}
		for (i = 0; i < size; i++) {
			if (list[i] == u && list[i+1] == v) {
				return 1;
			}
		}
		return 0;
	}
	
	
	uint8_t reorder_and_combine (uint8_t *p, uint8_t p_size, uint8_t *cp, uint8_t size) {
		uint8_t i;
		for (i = 0; i < size; i+=4) {
			if ( !check_consec (p, *(cp+i+3), *(cp+i+1), p_size) ) {
				// remove this possibility .... 
				// NOTE::we can combine the two functions such that instead of removing the possib we only add it if satisfied
				*(cp+i) = 0;	*(cp+i+1) = 0;	*(cp+i+2) = 0;	*(cp+i+3) = 0;
				size -= 4;
			}
		}
		return size;
	}
		

	/**
	 * 
	 **/
	event result_t TimeoutTimer.fired () {
	
		// This timeout event indicates that it is time to check for compositional constraints and 
		// send the bindings to NodeManager
		
		// get a list of all compositional constraints 
		// satisfy all compositonal resource allocation constraints (make domains arc-consistent)
		// satisfy all compostional property constraints ... output of this is a tuple of service domain values
		
		uint8_t numConnections = buffer[1];
		uint8_t srcService = 0;
		uint8_t dstService = 0;
		uint8_t dstServicePort = 0;
		uint8_t i = 0;
		SBindMsg serviceBinding;

		uint8_t RACPtr[6]; // resource allocation constraint ptrs in buffer
		uint8_t PCPtr[6];  // property constraint ptrs in buffer
		uint8_t numRAC = 0;
		uint8_t numPC = 0;

		bool okay = FALSE;
		bool no_solution = FALSE;
		
		uint8_t constraintLength;
		uint8_t compositionFunction;
		uint8_t constraintProperty;
		uint8_t service_set[MAX_SERVICES];
		
		uint8_t cposs[MAX_SERVICES*3];
		uint8_t cp_size = 0;
		uint8_t combined_services[MAX_SERVICES];
		uint8_t cs_size = 0;

		uint8_t rest_services[MAX_SERVICES];
		uint8_t rs_next[MAX_SERVICES];
		uint8_t rs_size = 0;

		uint16_t state_space_size = 1;
			
		uint8_t iteration = 0;

		numCompConstraints = buffer[compositionalConstraintIndex]; 
		connectionIndex = compositionalConstraintIndex + 1;
		for (i = 0; i < numCompConstraints; i++) {
			uint8_t ctype = buffer[connectionIndex+1];
			if ( ctype==1 || ctype==2 ) {
				// if allsame or alldiff 
				RACPtr[numRAC++] = connectionIndex;
			} 
			else { // if ctype == 3,4,5
				PCPtr[numPC++] = connectionIndex;
			}
			connectionIndex = connectionIndex + buffer[connectionIndex] + 1;
		}
		
//		call Send.output (services[0].domain_size, services[1].domain_size, services[5].domain_size, services[5].domain[0], numCompConstraints);

		// satisfy all compositonal resource allocation constraints (make domains arc-consistent)
		// solve allsame before alldiff... the order is maintained in the service graph encoding
		// NOTE:: note that this step makes the domains consistent.. it doesn't provide the solution
		for (i = 0; i < numRAC; i++) {
			uint8_t domain_u[MAX_SERVICES];
			uint8_t common_domain[MAX_SERVICES];
			uint8_t du_size = 0;
			uint8_t cd_size = 0;
			uint8_t element;
			uint8_t j, k;
			
			bool not_present = FALSE;

			constraintLength = buffer[RACPtr[i]];
			compositionFunction = buffer[RACPtr[i]+1];
			constraintProperty = buffer[RACPtr[i]+2];
	
			// number of services in service set for this constraint = constraintLength - 2
			memcpy (service_set, buffer+RACPtr[i]+3, constraintLength-2);
			
			switch (compositionFunction) {
				case ALLSAME: 
					// get the UNION of all constituent service domains
					for (j = 0; j < constraintLength-2; j++) {
						du_size = domain_union (domain_u, services[service_set[j]-1].domain, du_size, services[service_set[j]-1].domain_size);
					}
					// find the INTERSECTION of all constituent service domains
					for (j = 0; j < du_size; j++) {
						element = domain_u[j];
						for (k = 0; k < constraintLength-2; k++) {
							if ( check (services[service_set[k]-1].domain, element, services[service_set[k]-1].domain_size) == 0) {
								not_present = TRUE;
								break;
							}
						}
						if (!not_present) {
							cd_size = add (common_domain, element, cd_size);
						}
					}
					// resulting domains for all constituent services is the common/intersection domain...
					for (j = 0; j < constraintLength-2; j++) {
						memcpy (services[service_set[j]-1].domain, common_domain, cd_size);
						services[service_set[j]-1].domain_size = cd_size;
					}
					break;
				case ALLDIFFERENT: 
					break;
				default: 
			}
		}

//		call Send.output (services[0].domain_size, services[4].domain_size, services[5].domain_size, services[0].domain[0], services[5].domain[0]);

		// satisfy all compostional property constraints ... output of this is a tuple of service domain values
		for (i = 0; i < numPC; i++) {
			uint8_t dynamicRegionAssociation; 
			uint8_t constantRegionAssociation[3];

			uint8_t j;

			constraintLength = buffer[PCPtr[i]];
			compositionFunction = buffer[PCPtr[i]+1];
			constraintProperty = buffer[PCPtr[i]+2];
	
			switch (constraintProperty) {
				case DYNAMIC_REGION: 
					dynamicRegionAssociation = buffer[PCPtr[i]+3];
					memcpy (service_set, buffer+PCPtr[i]+4, constraintLength-3);
					break;
				case CONSTANT_REGION:
					memcpy (constantRegionAssociation, buffer+PCPtr[i]+3, 3);
					memcpy (service_set, buffer+PCPtr[i]+6, constraintLength-5);
					break;
				default:
					memcpy (service_set, buffer+PCPtr[i]+3, constraintLength-2);
			}
			
			switch (compositionFunction) {
				case SUM:
					break;
				case AVG:
					break;
				case ENCLOSE:
					if (constraintProperty == DYNAMIC_REGION) {
						uint8_t poss[3][MAX_SERVICES];
						uint8_t ps_size[3];

						uint8_t s1 = service_set[0];
						uint8_t s2 = service_set[1];
						uint8_t s3 = service_set[2];

						if (constraintLength-3 != 3) {	break;	} // NOTE: the member set should be of size = 3.. i will deal with bigger sets later

						cs_size = add (combined_services, dynamicRegionAssociation, cs_size);
						cs_size = add (combined_services, s1, cs_size);
						cs_size = add (combined_services, s2, cs_size);
						cs_size = add (combined_services, s3, cs_size);

						for (j = 0; j < services[dynamicRegionAssociation-1].domain_size; j++) {
							uint8_t e = services[dynamicRegionAssociation-1].domain[j];
							
							ps_size[0] = possibilities (e, services[s1-1].domain, services[s2-1].domain, services[s1-1].domain_size, services[s2-1].domain_size, poss[0]);
							ps_size[1] = possibilities (e, services[s2-1].domain, services[s3-1].domain, services[s2-1].domain_size, services[s3-1].domain_size, poss[1]);
							ps_size[2] = possibilities (e, services[s3-1].domain, services[s1-1].domain, services[s3-1].domain_size, services[s1-1].domain_size, poss[2]);
						
							cp_size = combine_possibilities (e, poss[0], poss[1], ps_size[0], ps_size[1], cposs, cp_size);
							cp_size = reorder_and_combine (poss[2], ps_size[2], cposs, cp_size);
						}
					}
					break;
				default:
			}
		}

//		call Send.output (constraintLength, compositionFunction, constraintProperty, cs_size, cp_size);

		for (i = 0; i < numServices; i++) {
			if ( check (combined_services, i+1, cs_size) == 0) {
				rs_next[rs_size] = 0;
				rest_services[rs_size++] = i+1;
				state_space_size = state_space_size*services[i].domain_size;
			}
		}
		if (cs_size > 0) {
			state_space_size = state_space_size*(cp_size/cs_size);
		}
		if (state_space_size == 0) {
			no_solution = TRUE;
		}

//	call Send.output (iteration, state_space_size, cs_size, rs_size+(cs_size>0), 0);
//	call Send.output (services[0].domain_size, services[1].domain_size, services[2].domain_size, services[3].domain_size, services[4].domain_size);
//		call Send.output (cs_size, rs_size, rest_services[0], cp_size, state_space_size);


		// pick a solution and if (current_solution !satisfy all cRAC) then BACKTRACK...
		// TODO:: BACKTRACK..
		while (!okay) {
			// pick a solution
			// NOTE:: what if there is no solution!!
			uint8_t tuple[MAX_SERVICES];
			uint8_t tuple_index = 0;
			uint8_t bt_index = rs_size - 1 + (cs_size>0);
			
			okay = TRUE;
			iteration++;
			if (iteration > state_space_size) {
				no_solution = TRUE;
				break;
			}

			// CHECK (tuple_index exceeds cp_size)
/*			if (tuple_index >= cp_size) {
				no_solution = TRUE;
				break;
			} */
			
			if (cs_size > 0) {
				memcpy (tuple, cposs+tuple_index, cs_size);
//			tuple_index += cs_size;
				for (i = 0; i < cs_size; i++) {
					services[combined_services[i]-1].solution = tuple[i];
				}
			}

			// CHECK (rs_next[i] exceeds services[sid].domain_size)
			for (i = 0; i < rs_size; i++) {
				uint8_t sid = rest_services[i]-1;
				services[sid].solution = services[sid].domain[rs_next[i]];
			}

			// check all compositional resource allocation constraints again... 
			// NOTE :: checking constraint satisfaction is exponentially easier than solving/satisfying
			for (i = 0; i < numRAC; i++) {
				uint8_t k, j = 0;
				uint8_t sid[MAX_SERVICES];

				constraintLength = buffer[RACPtr[i]];
				compositionFunction = buffer[RACPtr[i]+1];
				constraintProperty = buffer[RACPtr[i]+2];
		
				// number of services in service set for this constraint = constraintLength - 2
				memcpy (service_set, buffer+RACPtr[i]+3, constraintLength-2);
				
				switch (compositionFunction) {
					case ALLSAME: 
						k = services[service_set[0]-1].solution;
						for (j = 1; j < constraintLength-2; j++) {
							if (services[service_set[j]-1].solution != k) {
								okay = FALSE;
								break;
							}
						}
						break;
					case ALLDIFFERENT:
						for (j = 0; j < constraintLength-2; j++) {
							sid[j] = services[service_set[j]-1].solution;
						}
						for (j = 0; j < constraintLength-3; j++) {
							for (k = j+1; k < constraintLength-2; k++) {
								if (sid[j] == sid[k]) {
									okay = FALSE;
									break;
								}
							}
						}
						break;
					default:
				}
				if (!okay) {
					// back track
					if (bt_index == rs_size) {
						tuple_index += cs_size;
						if ( tuple_index > cp_size) {
							tuple_index = 0;
							bt_index--;
							rs_next[bt_index]++;
							while (rs_next[bt_index] > services[bt_index].domain_size) {
								rs_next[bt_index] = 0;
								bt_index--;
								rs_next[bt_index]++;
							}
						}
						bt_index = rs_size;
					} else if (bt_index < rs_size) {
						rs_next[bt_index]++;
						while (rs_next[bt_index] > services[bt_index].domain_size) {
							rs_next[bt_index] = 0;
							bt_index--;
							rs_next[bt_index]++;
						}
						bt_index = rs_size - 1;
					}
					break;
				}
			}
			
		}
		
		if (no_solution) {
			signal ComposerInterface.composed (FAIL);
			return SUCCESS;
		}

//	call Send.output (iteration, services[0].solution, services[1].solution, services[2].solution, services[3].solution);
			
		// for each connection, create a binding and deliver it to NodeManager
		for (i = 0; i < numConnections; i++) {
		
			// get the source and destination service (UNIQUE) IDs... notice that these are not same as service names
			srcService = buffer[connectionIndex] - 1;
			dstService = buffer[connectionIndex+1] - 1;
			dstServicePort = buffer[connectionIndex+2] - 1;
		
			// add the source and destination service info to binding message
			serviceBinding.src_service = services[srcService].service;
			serviceBinding.src_node = node_list[services[srcService].solution - 1].id;
			serviceBinding.dst_service = services[dstService].service + (dstServicePort<<5);
			serviceBinding.dst_node = node_list[services[dstService].solution - 1].id;
			
			serviceBinding.ctrl.src  = TOS_LOCAL_ADDRESS;
			serviceBinding.ctrl.srcs = COMPOSER;
			serviceBinding.ctrl.dst  = serviceBinding.src_node;
			serviceBinding.ctrl.dsts = NODE_MANAGER;
			serviceBinding.ctrl.seqnum = 0;
			serviceBinding.ctrl.type = BINDING;
			
			binds[nextbind++] = serviceBinding;
			// deliver the binding to the node manager
			// move the cursor to the next connection
			connectionIndex += 3;
		}

//		call Send.output (srcService, dstService, serviceBinding.src_service, serviceBinding.dst_service, nextbind);

		next_bind_output = 0;
		post bindMsg ();
		
		// Reset global counter variables and flags
		connectionIndex = 0;
		totalLength = 0;
		currentLength = 0;
		connectionIndex = 0;
		numServices = 0;
		timerStarted = FALSE;
		pending = FALSE;
		
		signal ComposerInterface.composed (SUCCESS);
		return SUCCESS;
	}
	
	/**
	 * 
	 **/
	event result_t BindInterface.outputComplete (result_t result) {
		// returns success if binding was succesfully done
		// if all services are successfully bound then return success to ComposerInterface (this will be used to initiate object)	
		if (result == SUCCESS) {
			next_bind_output++;
		}
		post bindMsg ();
//		signal ComposerInterface.composed (result);
		return SUCCESS;
	}

	/**
	 * 
	 **/
	event result_t RequestInterface.requestAccepted (result_t result) {
		if (result == SUCCESS) {
			next++;
		}
		post make_requests ();
		return SUCCESS;
	}
	
	event result_t Send.outputComplete (result_t result) {
		return SUCCESS;
	}
	


	
}

