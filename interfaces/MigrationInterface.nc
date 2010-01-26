
interface MigrationInterface {
	
	command result_t send (MigrationMsg mmsg);
	
	command result_t sendObject (ObjectState obj);
	
	event result_t receive (MigrationMsg hmsg);
	
	event result_t receiveObject (ObjectState obj);
	
}

