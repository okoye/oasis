

// interface used to make service discovery request or receive service information back
interface ServiceRequestInterface {
	
	// make a service request where service_id the unique id of the requested service
	command result_t serviceRequest (uint8_t service_id);
	
	// returns the information of the requested service
	// unique id of requested service, id of the provider node, provider's position and its power level
	event result_t outputInfo (SDMsg msg);//uint16_t service_id, uint16_t provider, uint16_t pos[3], uint16_t power);

	// returns information of all known service instances for a requested service
//	event result_t outputAllInfo (SDMsg msg[MAX_SERVICES], uint8_t numInstances);
	command uint8_t servicesRequest (uint8_t service_id, SDMsg service_message[MAX_SERVICES]);
	
	command result_t outputClear (result_t result); 
	
	event result_t requestAccepted (result_t result); 
	
	// requests the shortest path between two nodes
	command SPathMsg getShortestPath (uint16_t src, uint16_t dst);

}
