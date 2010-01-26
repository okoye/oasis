

interface ReceiveBigMsg {
	
	command result_t receive (uint16_t addr, void* start, void* end);
	
	event result_t receiveDone (result_t result);
	
}

