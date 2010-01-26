

includes AM;
includes BigMsg;
includes Service;

module RcvBigMsgM {
  provides interface StdControl;
  uses {
    interface ReceiveMsg;
    interface ReceiveBigMsg;
    interface StdControl as CommControl;
  }
}
implementation {
	
	bool pending;
	uint32_t totalLength;
	uint32_t currentLength;
	uint8_t buffer[BIGMSG_BUFFER_SIZE];
	
  command result_t StdControl.init() {
    return call CommControl.init();
  }

  command result_t StdControl.start() {
  	pending = FALSE;
  	totalLength = 0;
  	currentLength = 0;
    return call CommControl.start();
  }

  command result_t StdControl.stop() {
    return call CommControl.stop();
  }

	/**
	 * Accepts Big Message in multiple TOS messages. 
	 * This function stitches all TOS messages together to retreive original Big message sent. Passes the big message to ReceiveBigMsg 
	 * Interface. The arguments passed are message source, message start pointer and message end pointer.  
	**/
  event TOS_MsgPtr ReceiveMsg.receive(TOS_MsgPtr msg) {
  // TODO :: incorporate the functionality of receiving multiple simultaneous big messages
		// accept TOSMsg from radio and compose a BigMsg and forward it to ReceiveBigMsg interface
		// This component must find the length of the BigMsg and wait for all data to come and then send the start and end 
		// data pointers to ReceiveBigMsg interface
		BigMsg *message = (BigMsg *)msg->data;
		uint8_t tos_length = msg->length;
		uint8_t seqNum = message->seqNum;

		if (seqNum > 0x7F) { 
			// highest bit is set to 1 i.e. this is a NEW big messages 
			if (pending == TRUE) { // reception of previous message is yet not finished  
				// should handle the expection properly... for now i will just assume that previous message is finished 
				// also... forward the previous (incomplete) message
				pending = FALSE;
				totalLength = 0;
			}
			// get total length of new message 
			totalLength = *((uint32_t *)message->data); // CHECK (totalLength < BIGMSG_BUFFER_SIZE)... failure is not handled yet

			if (totalLength <= BIGMSG_DATA_LENGTH - sizeof(totalLength)) { // if no more big message packets to come 
				call ReceiveBigMsg.receive (message->source, message->data + sizeof(totalLength), message->data+totalLength+sizeof(totalLength)); 
//				call ReceiveBigMsg.receive (message->source, message->data + sizeof(totalLength), message->data+totalLength); 
			} else {
				memcpy (buffer,message->data + sizeof(totalLength),tos_length - BIGMSG_CONTROL_LENGTH - sizeof(totalLength));
				pending = TRUE;
				currentLength = (tos_length - BIGMSG_CONTROL_LENGTH - sizeof(totalLength));
			}
		} 
		else { 
			// old message (continuation of previous message)
			memcpy (buffer + currentLength, message->data, tos_length - BIGMSG_CONTROL_LENGTH);
			currentLength = currentLength + (tos_length - BIGMSG_CONTROL_LENGTH);
			if (currentLength >= totalLength) { // this is the last packet of the current big message sequence
				call ReceiveBigMsg.receive (message->source, buffer, buffer + totalLength); 
				pending = FALSE;
				totalLength = 0;
			}
		}
    return msg;
  }

  event result_t ReceiveBigMsg.receiveDone (result_t success) {
    return SUCCESS;
  }

}



