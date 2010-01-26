
/** Message formats used in service architecture.. 

 * Author: Manish Kushwaha
 * Date last modified: 3/11/06
*/


// Service message control information (11 bytes)
typedef struct SControl {
	/** service message control information */
	// source node ID
	uint16_t src;
	// source service ID on source node
	uint8_t srcs;
	// final destination node ID
	uint16_t dst;
	// destination service ID on destination node
	uint8_t dsts;
	// sequence number ?? 
	uint8_t seqnum;
	// current hop number
	uint8_t hopnum;
	// message type 
	uint8_t type;
	// the ID of the next node in the path to the destination
	uint16_t next;
} SControl;


// types of failure detection messages... and other associated constants
enum {
		NOT,
		NOP,
		
		INIT,
		DIAG,
		HANDSHAKE,

		INIT_REPLY,
		DIAG_REPLY,
		HANDSHAKE_REPLY
};


// type of service messages
enum {
	SOURCE = 1,
	SINK = 2,
	REQUEST = 10,
	INFO = 11,
	SERVICE_GRAPH = 12,
	BINDING = 13,
	SERVICE_ACCESS_REQUEST = 14,
	HEARTBEAT = 15,
	MIGRATION = 16,
	MIGRATION_ACK = 17,
	OBJECT_STATE = 18,
	GENERAL_REQUEST = 19,
	PATH = 20
};


/** constants used in architecture */
enum {
	MAX_SERVICES = 9,
	MAX_NODES = 10,
	MAX_HOPS = 1,	// maximum number of hops between the object node and a service
	MAX_PATH_SIZE = 2, 	// 2 * MAX_HOPS
	MIN_FORWARD_POWER = 2000,	// lowest power level that will still permit forwarding
	MAX_SERVICE_BINDINGS = 10,
	SERVICE_GRAPH_BUFFER_SIZE = 85,
	SERVICE_REQUEST_SIZE = 14,
	OBJECT_BUFFER_SIZE = 447,	// assumes 4 fully connected FSM modes and service graph size of 85
	BIGMSG_BUFFER_SIZE = 30,
	SERVICE_DISCOVERY_TIMEOUT = 5000, // (ms)
	COMPOSER_TIMEOUT = 5000, // (ms)
	MIGRATION_TIMEOUT = 2000, // (ms)
	
	TRIGGER_TIME = 1000
};

/** actors in service architecture and service application */
enum {
	NODE_MANAGER = 1,
	SDP = 2,
	COMPOSER = 3,
	OBJECT = 4,
	FORWARDER = 5
};

enum {
	READ_TEMP = 8,
	LOCALIZE = 9,
	LOCALIZE_PORT1 = 9,			// 0x0<<5 + 0x9
	LOCALIZE_PORT2 = 41,		// 0x1<<5 + 0x9
	LOCALIZE_PORT3 = 73,		// 0x2<<5 + 0x9
	LOCALIZE_PORT4 = 105,		// 0x3<<5 + 0x9
	LOCALIZE_PORT5 = 137,		// 0x3<<5 + 0x9

	NOTIFY = 10,
	WIND = 11,
	WIND_SERVICE = 31
};

// Timer types
enum {
	NODEOUT_T = 1,
	NODEIN_T = 2
};
	
enum {
	// HACKS::
	SOURCE_DATA_SEQNUM = 111,	//??
	SINK_DATA_SEQNUM = 112,		// ??
	OBJECT_NODE = 143,
	BASE_STATION = 263
};


/** Service discovery message (24 bytes)
	same format for service request and service info message 
*/
typedef struct SDMsg {
	/** service message control information */
	SControl ctrl;

	/** message content */
	// ID of requested service
	uint8_t service;
	// node id of the service requester
	uint16_t origin;
	// node ID of provider 
	uint16_t provider;
	// position of provider node
//	uint16_t position[3];
	uint16_t position[2];
	// power level of provider node
	uint16_t power;
} SDMsg;

// Service Path message (2*MAX_PATH_SIZE + 1 bytes)
typedef struct SPathMsg {
	uint16_t path[MAX_PATH_SIZE];
	uint8_t size;	// number of nodes in path[]
} SPathMsg;

// Service binding message (14 + 2*MAX_PATH_SIZE + 1 bytes)
typedef struct SBindMsg {
	/** service message control information */
	SControl ctrl;

	/** message content */
	// source service to bind in service graph
	uint8_t src_service;
	// and the node that contains it 
	uint16_t src_node;
	// destination service in service graph
	uint8_t dst_service;
	// the node containing dst service
	uint16_t dst_node;
	// the path from src_node to dst_node
	SPathMsg path;

} SBindMsg;

/*
// 14 bytes
typedef struct SRequestMsg {
	// service message control information 
	SControl ctrl;

	// message content 
	// ID of requested service
	uint16_t service;
	// originator of the service
	uint16_t origin;
} SRequestMsg;
*/

/*
// 20 bytes
// contains info on nodes hosting specific services
typedef struct SInfoMsg {
	// service message control information 
	SControl ctrl;

	// message content 
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
*/

/** constants for Service message */
enum {
	SERVICE_MSG_CONTROL_LENGTH = 1,	// size of control info (seqNum, etc.)
	SERVICE_MSG_DATA_LENGTH = 28,	// length of actual data
	SERVICE_MSG_LENGTH_HEADER = 4	// size of header in first packet data that provides the size of the total message
};

/** constant for Big Message */
enum {
	BIGMSG_CONTROL_LENGTH = 3
};

/** generic service message (29 bytes w/ 28 bytes payload) */
typedef struct ServiceMsg {
	// data payload 
	uint8_t data[SERVICE_MSG_DATA_LENGTH];
	// sequence number
	uint8_t seqNum;
} ServiceMsg;

enum SERVICE_TYPE {
	NODE_SERVICE = 1,
	WEB_SERVICE = 2
};

// Property enum for service graph constraints
enum CONSTRAINT_PROPERTY {
	POWER = 1,
	X_POSITION = 2,
	Y_POSITION = 3,
	Z_POSITION = 4,
	CONSTANT_REGION = 5,
	DYNAMIC_REGION = 6,
	ID = 7,
	TYPE = 8,
	OBJECT_REGION = 9
};

// Operator enum for service graph constraints
enum CONSTRAINT_OPERATOR {
	EQUAL_TO = 1,
	NOT_EQUAL_TO = 2,
	LESS_THAN = 3,
	LESS_THAN_EQUAL_TO = 4,
	GREATER_THAN = 5,
	GREATER_THAN_EQUAL_TO = 6,
	MEMBER_OF = 7,
	NOT_MEMBER_OF = 8
};

// compositional functions for constraints
enum COMPOSITIONAL_FUNCTION {
	ALLSAME = 1,
	ALLDIFFERENT = 2,
	SUM = 3, 
	AVG = 4,
	ENCLOSE = 5
};


// Constraint struct for service graph constraints
typedef struct SGraphConstraint {
	// the property to evaluate
	enum CONSTRAINT_PROPERTY property;
	// the operator to use for the evaluation
	enum CONSTRAINT_OPERATOR operator;
	// the value to compare against the property
	uint16_t value;
} SGraphConstraint;

// struct to keep track of a physical object's state (8 bytes)
typedef struct ObjectState {

	uint16_t xPos;
	uint16_t yPos;
	uint16_t speed;
	uint16_t heading;
	
	uint16_t object_holder;
} ObjectState;

// enum for object byte string
enum {
/*	OPERATOR_LOC = 3,
	THRESHOLD_LOC = 4,
	OBJECT_HEADER_LEN = 7,
	NUM_MODES_OFFSET = 6,
	NUM_TRANSITIONS_OFFSET = 4,*/

	OPERATOR_LOC = 5,
	THRESHOLD_LOC = 6,
	NUM_MODES_OFFSET = 8,
	OBJECT_HEADER_LEN = 9,
	NUM_TRANSITIONS_OFFSET = 1,

	MODE_TRANSITION_LEN = 5,
	EXECUTION_PERIOD_OFFSET = 1,
	REPEAT_FLAG_OFFSET = 3,
	TRANSITION_PROPERTY_OFFSET = 1,
	TRANSITION_OPERATOR_OFFSET = 2,
	TRANSITION_VALUE_OFFSET = 3,
	TRANSITION_DESTINATION_OFFSET = 5
};

// enum for transition properties
enum {
	OBJECT_X_POSITION = 1,
	OBJECT_Y_POSITION = 2,
	OBJECT_SPEED = 3,
	OBJECT_HEADING = 4
};

// heartbeat message
typedef struct HeartbeatMsg {
	uint16_t src_node;	// Node ID of sender
	uint16_t value;		// Detection value
} HeartbeatMsg;

typedef HeartbeatMsg MigrationMsg;

// enum for heartbeat
enum {
	CANDIDATE_PERIOD = 2000,	// 2 seconds
	HEARTBEAT_PERIOD = 500		// 0.5 seconds
};
