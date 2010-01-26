

interface InternalInterface {
	
	command result_t isConfigured (uint8_t sid);
	
	command result_t binding (SBindMsg msg);

	event result_t passToken (uint8_t sid, ServiceMsg message);

	event result_t trigger_source (uint8_t service_id, bool trigger);

	event result_t start_trigger_timer (uint16_t time);
	
	command result_t setNext (uint16_t destNode, uint16_t nextNode);
	
	command result_t forwardMessage (void* start, void* end, bool broadcast);
	
	command result_t setPath (SPathMsg msg);
	
	command uint16_t getNext (uint16_t destNode);
	
}


