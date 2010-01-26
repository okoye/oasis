

interface ObjectInterface {
	
//	command result_t trigger ();
	
	// Receive an Object message
//	command result_t receiveObject(ServiceMsg message);
//	HACK: for now we'll hardcode the object onto the node
//	command result_t receiveObject();
	
//	// Receive acknowledgement
//	event result_t receiveComplete(result_t result);
	
	// Object Initialization
	command result_t init();
	
	// Evaluate sensor output
	command result_t detect(ServiceMsg sensorData, uint8_t type);
	
	// Owner election
	command result_t ownerElection();
	
	// Object Activation
	command result_t activate();
	
	// Evaluate the object condition
	command result_t evaluateCondition(uint16_t value, uint8_t operator, uint16_t constant);
	
	// Evaluate the output of the service graph
	command result_t evaluateServiceGraphOutput();
	
	// check QoS conditions
	command result_t QoSCheck ();
}

