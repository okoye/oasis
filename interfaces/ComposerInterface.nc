
includes Service;

interface ComposerInterface {
	
	command result_t output (ServiceMsg msg);
	
	command result_t constraintCheck (ObjectState state);//uint8_t current_solution[MAX_SERVICES]);

	command result_t reconfigure ();

	event result_t outputComplete (result_t result);

	event result_t composed (result_t result);

	event result_t constraintCheckOutput (result_t result);
	
}


