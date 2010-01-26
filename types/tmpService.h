
//#include <AM.h>
//#include <BigMsg.h>

/** Message formats used in service architecture.. 

 * Author: Manish Kushwaha
 * Date last modified: 3/11/06
*/


// 10 bytes
typedef struct SControl {
	/** service message control information */
	// source node ID
	uint16_t src;
	// source service ID on source node
	uint16_t srcs;
	// destination node ID
	uint16_t dst;
	// destination service ID on destination node
	uint16_t dsts;
	// sequence number ?? 
	uint8_t seqnum;
	// message type 
	uint8_t type;
} SControl;


// types of service discovery message
enum {
	REQUEST = 10,
	INFO = 11,
	MAX_SERVICES = 16,
	MAX_SERVICE_BINDINGS = 16,
	BIGMSG_BUFFER_SIZE = 200,
//	SDP = 19,
	SERVICE_DISCOVERY_TIMEOUT = 30
};

enum {
	SDP = 001,
	COMPOSER = 002,
	SERVICE_A = 003,
	SERVICE_B = 004,
	SERVICE_C = 005,
	SERVICE_D = 006
};



// 24 bytes
typedef struct SDMsg {
	/** service message control information */
	SControl ctrl;

	/** message content */
	// ID of requested service
	uint16_t service;
	// originator of the service
	uint16_t origin;
	// node ID of provider 
	uint16_t provider;
	// position of provider node
	uint16_t position[3];
	// power level of provider node
	uint16_t power;
} SDMsg;



typedef struct SGraphMsg {
	/** service message control information */
	SControl ctrl;
	
} SGraphMsg;

	

// 18 bytes
typedef struct SBindMsg {
	/** service message control information */
	SControl ctrl;

	/** message content */
	// source service to bind in service graph
	uint16_t 	src_service;
	// and the node that contains it 
	uint16_t src_node;
	// destination service in service graph
	uint16_t dst_service;
	// the node containing dst service
	uint16_t dst_node;
} SBindMsg;


// 14 bytes
typedef struct SRequestMsg {
	/** service message control information */
	SControl ctrl;

	/** message content */
	// ID of requested service
	uint16_t service;
	// originator of the service
	uint16_t origin;
} SRequestMsg;

// 20 bytes
typedef struct SInfoMsg {
	/** service message control information */
	SControl ctrl;

	/** message content */
	// ID of requested service
	uint16_t service;
	// originator of the service
	uint16_t origin;
	// node ID of provider 
	uint16_t provider;
	// position of provider node
	uint16_t position[3];
	// power level of provider node
	uint16_t power;
} SInfoMsg;

enum {
	SERVICE_MSG_CONTROL_LENGTH = 1,	// size of control info (seqNum, etc.)
	SERVICE_MSG_DATA_LENGTH = 28,	// length of actual data
	SERVICE_MSG_LENGTH_HEADER = 4	// size of header in first packet data that provides the size of the total message
};

// 29 bytes w/ 28 bytes payload
typedef struct ServiceMsg {
	uint8_t seqNum;
	uint8_t data[SERVICE_MSG_DATA_LENGTH];
} ServiceMsg;

// Property enum for service graph constraints
enum {
	POWER,
	X_POSITION,
	Y_POSITION,
	Z_POSITION
} CONSTRAINT_PROPERTY;

// Operator enum for service graph constraints
enum {
	EQUAL_TO,
	NOT_EQUAL_TO,
	LESS_THAN,
	GREATER_THAN,
	GREATER_THAN_EQUAL_TO,
	LESS_THAN_EQUAL_TO
} CONSTRAINT_OPERATOR;

// Constraint struct for service graph constraints
typedef struct SGraphConstraint {
	// the property to evaluate
	CONSTRAINT_PROPERTY property;
	// the operator to use for the evaluation
	CONSTRAINT_OPERATOR operator;
	// the value to compare against the property
	uint16_t value;
} SGraphConstraint;


