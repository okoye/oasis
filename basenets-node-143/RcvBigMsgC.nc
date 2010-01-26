
/** 
	This component receives multiple big messages in sequence and 'stitch' them together to reconstruct the original message sent. 
	The maximum length of reconstructed message is BIGMSG_BUFFER_SIZE.
*/

configuration RcvBigMsgC {
	provides {
		interface StdControl;
	} 
	uses {
		interface ReceiveBigMsg;
	}
} implementation {
	components RcvBigMsgM, GenericComm;

	ReceiveBigMsg = RcvBigMsgM.ReceiveBigMsg;
	StdControl = RcvBigMsgM.StdControl;

	RcvBigMsgM.ReceiveMsg -> GenericComm.ReceiveMsg[0x6F]; // active message channel for BigMsg
	RcvBigMsgM.CommControl -> GenericComm;

}


