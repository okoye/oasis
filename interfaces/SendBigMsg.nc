
includes BigMsg;

interface SendBigMsg {
	
	command result_t send (BigMsg msg, uint16_t dst);
	
	event result_t sendDone (BigMsgPtr msg, uint16_t dst, result_t result); 
	
}

