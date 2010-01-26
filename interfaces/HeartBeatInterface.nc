
interface HeartBeatInterface {
	
	command result_t heartbeatOut (HeartbeatMsg hmsg);
	
	event result_t heartbeatIn (HeartbeatMsg hmsg);
	
}

