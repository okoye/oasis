
/************************************************************************
 *																		*
 * @file	Gateway.java												*
 *																		*
 * @brief	Captures incoming messages from base station and performs	*
 *			necessary service discovery / access functions				*
 *																		*
 * @author	Isaac Amundson <isaac.amundson@vanderbilt.edu>				*
 *																		*
 ************************************************************************/

package net.tinyos.tools;

// AXIS LIBRARIES
import org.apache.axis.client.Call;
import org.apache.axis.client.Service;
import javax.xml.namespace.QName;

// UDDI4J LIBRARIES
import org.uddi4j.UDDIException;
import org.uddi4j.client.UDDIProxy;
import org.uddi4j.datatype.binding.AccessPoint;
import org.uddi4j.datatype.binding.BindingTemplate;
import org.uddi4j.datatype.tmodel.TModel;
import org.uddi4j.response.BindingDetail;
import org.uddi4j.response.DispositionReport;
import org.uddi4j.response.Result;
import org.uddi4j.response.TModelDetail;
import org.uddi4j.util.TModelBag;

// TINYOS LIBRARIES
import net.tinyos.util.*;
import net.tinyos.mcenter.*;

// JAVA LIBRARIES
import java.io.*;
import java.nio.*;
import java.util.*;
import java.net.*;

public class Gateway implements BigMSGListener {

	// private class to hold destination info for service binding
	private class DestinationInfo {
	
		private byte dstService;
		private short dstNode;
	
		public DestinationInfo(byte dst_service, Short dst_node) {
			dstService = dst_service;
			dstNode = dst_node;
		}
	
		public byte getDstService() {
			return dstService;
		}
		
		public short getDstNode() {
			return dstNode;
		}	
	
	}
	
	private class Hack extends Thread {
		ByteBuffer msgBuffer;
		short gatewayAddress;
	     public Hack(ByteBuffer b) {
		 msgBuffer = b;
		 gatewayAddress = 263;
         }
 
         public void run() {

//System.out.println("accessService: msgBuffer.capacity = " + msgBuffer.capacity());
	
		// Extract Service ID from byte array
//		byte serviceID = msgBuffer.get(SCONTROL_DSTS_LOC);
byte serviceID = 31;

		try {
	
			// Extract Input Data from byte array
			byte[] svcMsg = new byte[msgBuffer.capacity() - SCONTROL_LEN];
			for (int i = 0; i < msgBuffer.capacity() - SCONTROL_LEN; i++) {
				svcMsg[i] = msgBuffer.get(SCONTROL_LEN + i);
//System.out.println("accessService: svcMsg[" + i + "] = " + svcMsg[i]);
			}
			ByteBuffer inputBuffer = ByteBuffer.wrap(svcMsg);
			inputBuffer.order(ByteOrder.LITTLE_ENDIAN);
//			String inputData = convertInputData(serviceID, inputBuffer);
String inputData = "0";
System.out.println("accessService: inputData = " + inputData);

			// If access point does not exist, rediscover service
			if (accessPoints.get(serviceID) == null) {

System.out.println("accessService: Service " + serviceID + " NOT found, initiating service discovery");
	
				// Do service discovery
				if (rediscoverService(serviceID)) {
			
					// Recursively call this function, passing in same message
					accessService(msgBuffer);
					
				}
				else {
				
					System.out.println("accessService: Service Rediscovery failed!");
					
				}
				
				return;

			}
			
			String serviceURL = accessPoints.get(serviceID).toString();
System.out.println("accessService: serviceURL = " + serviceURL);
			
			// Instantiate Call class for accessing Service
			Service service = new Service();
			Call call = (Call)service.createCall();
			
			// Set the service URL
			call.setTargetEndpointAddress(new URL(serviceURL));
			
			// Set the name of the method to call within the service
			String serviceMethod = config.getProperty((short)serviceID + "_method");
System.out.println("accessService: " + (short)serviceID + "_method = " + serviceMethod);
			call.setOperationName(new QName(serviceMethod));
			
// HACK: This will invoke the service every six seconds.  This should be invoked periodically by the object
for (;;) {			
			
			// Invoke the service, passing the input data as an argument, and get the result
			String result = (String)call.invoke(new Object [] {new String(inputData)});
System.out.println("accessService: result = " + result);
			
			// Make sure there is another service to run
			if (serviceBindings.get(serviceID) != null) {
			
				// Find next service in service graph according to bind info
				byte nextServiceID;
				short nextNodeID;
				DestinationInfo destInfo = (DestinationInfo)serviceBindings.get(serviceID);
				nextServiceID = destInfo.getDstService();
				nextNodeID = destInfo.getDstNode();
			
				// convert the output data of the previous service to a byte sequence
				ByteBuffer outputData = convertOutputData(serviceID, result);

				// Compose appropriate message
				ByteBuffer reqMsg = ByteBuffer.allocate(SCONTROL_LEN + outputData.capacity());
				reqMsg.order(ByteOrder.LITTLE_ENDIAN);
				
				// SCONTROL
				reqMsg.putShort(this.gatewayAddress);							// source node id
				reqMsg.put(serviceID);											// source node service ??????
				reqMsg.putShort(nextNodeID);									// destination node id
				reqMsg.put(nextServiceID);										// destination node service
				reqMsg.put((byte)0);											// sequence number
				reqMsg.put((byte)ACCESS_TYPE);									// type
				
				// Data
				reqMsg.put(outputData.array());
			
				// If next service in service graph is a web service in cache
				if (accessPoints.get(nextServiceID) != null) {
					
					// recursively Call this function, passing in the new message
					accessService(reqMsg);
				
				}
				// Otherwise the next service is on a mote
				else {
					
					// Send to appropriate mote
					sendMessageToSensornet(nextNodeID, reqMsg);
					
				}
			}
			else {
System.out.println("accessService: no more services to run");			
			}
	this.sleep(6000);

}
		
		} 
		
		// Catch any other exception that may occur
		catch (Exception e) {
			e.printStackTrace();
		}
	
		return;


         }
	
	}

	// Create message type constants
	public static final byte ACCESS_MESSAGE = 14;
	public static final byte DISCOVERY_MESSAGE = 2;
	public static final byte BIND_MESSAGE = 1;
	public static final byte DISCOVERY_TYPE = 10;
	public static final byte INFO_TYPE = 11;
	public static final byte BINDING_TYPE = 13;
	public static final byte ACCESS_TYPE = 14;
	public static final byte SHUTDOWN_TYPE = 86;
	
	// Create message length constants
	public static final byte SCONTROL_LEN = 8;
	public static final byte SDMSG_LEN = 21;
	public static final byte SBINDMSG_LEN = 14;
	
	// Create byte location constants
	public static final byte SCONTROL_DST_LOC = 3;
	public static final byte SCONTROL_DSTS_LOC = 5;
	public static final byte SCONTROL_TYPE_LOC = 7;
	public static final byte SDMSG_SERVICE_LOC = 8;
	public static final byte SDMSG_ORIGIN_LOC = 9;
	public static final byte SBINDMSG_SRC_SERVICE_LOC = 8;
	public static final byte SBINDMSG_DST_SERVICE_LOC = 11;
	public static final byte SBINDMSG_DST_NODE_LOC = 12;

	public static final short TOS_BCAST_ADDR = (short) 0xffff;
	public static final short BIGMSG_RETRY_COUNT = 3;
	public static final short BIGMSG_AM_TYPE = 0x6F;
	public static final short BIGMSG_HEADER_LEN = 3;
	public static final short BIGMSG_DATA_LEN = 26;
	public static final short BIGMSG_SIZE_LEN = 4;
	
	public boolean waitForRequest = true;
	public static Properties config = null;
	public static short gatewayAddress = 263;

	// Hash Map to store service bindings
// NOTE: THIS NEEDS TO BE ABLE TO HOLD MULTIPLE KEYS OF THE SAME NAME
// IN CASE THE OUTPUT OF ONE SERVICE IS BOUND TO THE INPUT OF SEVERAL SERVICES!!!!!!!!!!!!!!!!!
	public HashMap serviceBindings = new HashMap();
	
	// Hash Map to store accessPoints
	public HashMap accessPoints = new HashMap();

	// main function
	public static void main(String[] argv) throws IOException {
		
//		// Make sure the user enters the base station address on the command line
//		if (argv.length < 1) {
//			System.out.println("usage: java net.tinyos.tools.Gateway <base station address>");
//			System.exit(-1);
//		}
		// Check if the user wants to override the default base station address
		if (argv.length > 0) {
			gatewayAddress = new Short(argv[0]).shortValue();
		}
		
		// Load properties file
		config = new Properties();
		try {
			config.load(new FileInputStream("Gateway.prop"));
		} 
		catch (Exception e) {
			System.out.println("Unable to load property file Gateway.prop");
			System.exit(-1);
		}
		
		Gateway gateway = new Gateway();
			
		try {
			
			// Wait for message
			BigMSGReceiver receiver = new BigMSGReceiver(gateway);
			
//			gateway.testIn(ACCESS_MESSAGE, REQUEST_TYPE);
			
			synchronized (gateway) {
				
				for (;;) {
				
					if (gateway.waitForRequest) {
						System.out.println("Waiting for request...");
						gateway.wait(60000);
					}
				}
			}
		}
		
		catch (Exception e) {
			e.printStackTrace();
		}
		
	}

	// BigMSGReceived() function
	public void BigMSGReceived(int source, byte[] message) {
		
		ByteBuffer msgBuffer = ByteBuffer.wrap(message);
		msgBuffer.order(ByteOrder.LITTLE_ENDIAN);
		
		String msgData = "";
		for (int i = 0; i < message.length; i++) {
			msgData += " " + (message[i] & 0xff);
		}
		
System.out.println("BigMSGReceived: Received request message: " + msgData);
		
		// Make sure the message is intended for the gateway
		short destAddress = msgBuffer.getShort(SCONTROL_DST_LOC);
		if (destAddress != this.gatewayAddress && destAddress != TOS_BCAST_ADDR) {
System.out.println("BigMSGReceived: Message not intended for gateway");
			return;
		}

		// Figure out what kind of message this is by looking at where it's going
//		short destService = msgBuffer.getShort(SCONTROL_DSTS_LOC);
		byte messageType = msgBuffer.get(SCONTROL_TYPE_LOC);
//System.out.println("BigMSGReceived: destService = " + destService);
//System.out.println("BigMSGReceived: messageType = " + messageType);
		
		// Handle request based on message type
//		if (destService == DISCOVERY_MESSAGE && messageType == DISCOVERY_TYPE) {
		if (messageType == DISCOVERY_TYPE) {
System.out.println("BigMSGReceived: calling discoverService()");
			discoverService(msgBuffer);
		}
//		else if (destService == BIND_MESSAGE && messageType == BINDING_TYPE) {
		else if (messageType == BINDING_TYPE) {
System.out.println("BigMSGReceived: calling bindService()");
			bindService(msgBuffer);
		}
//		else if (destService != DISCOVERY_MESSAGE && messageType == ACCESS_TYPE) {
		else if (messageType == ACCESS_TYPE) {
System.out.println("BigMSGReceived: calling accessService()");
			accessService(msgBuffer);
		}
		else if (messageType == SHUTDOWN_TYPE) {
			this.waitForRequest = false;
		}
		
		return;
	}
	
	// Accesses UDDI registry to look for a service
	public void discoverService(ByteBuffer msgBuffer) {
	
		// Initialize serviceExists flag to FALSE
		boolean serviceExists = false;
		
		// Extract the service ID from the byte array
		byte serviceID = msgBuffer.get(SDMSG_SERVICE_LOC);
System.out.println("discoverService: Looking for service " + (short)serviceID);
		
		// If the accessPoint URL is NOT cached
		if (accessPoints.get(serviceID) == null) {
		
			// Get tModelKey and serviceKey for this service
			String tModelKey = config.getProperty((short)serviceID + "_tModelKey");
			String serviceKey = config.getProperty((short)serviceID + "_serviceKey");
System.out.println("discoverService: tModelKey = " + tModelKey);
System.out.println("discoverService: serviceKey = " + serviceKey);

			if (tModelKey == null || serviceKey == null)
				return;

			// UDDI Inquiry
			String serviceURL = UDDIInquiry(tModelKey, serviceKey);
System.out.println("discoverService: serviceURL = " + serviceURL);
		
			// If accessPoint URL DOES NOT exist in UDDI registry
			if (serviceURL == null) {
			
				// Set serviceExists flag to FALSE and do nothing
				serviceExists = false;
				
			}
		
			// Otherwise if the accessPoint URL DOES exist
			else {
			
				// cache accessPoint
				accessPoints.put(serviceID, serviceURL);
				
				// Set serviceExists flag to TRUE
				serviceExists = true;
				
			}
		}
				
		// Otherwise if the accessPoint URL is cached
		else {
		
			// Set serviceExists flag to TRUE
			serviceExists = true;
			
		}
		
		// If the service exists, let the requesting mote know
		if (serviceExists) {
		
			// Construct the return message
			ByteBuffer retMsg = ByteBuffer.allocate(SDMSG_LEN);
			retMsg.order(ByteOrder.LITTLE_ENDIAN);
			
			// First construct the SControl structure
			retMsg.putShort(this.gatewayAddress);  				// source node id
			retMsg.put(DISCOVERY_MESSAGE);							// source node service
			retMsg.putShort(msgBuffer.getShort(SDMSG_ORIGIN_LOC));	// destination node id
			retMsg.put(DISCOVERY_MESSAGE);							// destination node service ???
			retMsg.put((byte)0);									// sequence number ???
			retMsg.put(INFO_TYPE);									// type
			
			// Now construct the SDMsg structure
			retMsg.put(serviceID);									// service id
			retMsg.putShort(msgBuffer.getShort(SDMSG_ORIGIN_LOC));	// origin of service request
			retMsg.putShort(this.gatewayAddress);					// provider
			retMsg.putShort((short)0);								// x positon
			retMsg.putShort((short)0);								// y position
			retMsg.putShort((short)0);								// z position
			retMsg.putShort((short)2000);							// power
		
			// Send return message back to mote
			sendMessageToSensornet(msgBuffer.getShort(SDMSG_ORIGIN_LOC), retMsg);
		
		}
		
		return;
	
	}
	
	public boolean rediscoverService(byte serviceID) {
	
		boolean serviceExists = false;
	
		// Get tModelKey and serviceKey for this service
		String tModelKey = config.getProperty((short)serviceID + "_tModelKey");
		String serviceKey = config.getProperty((short)serviceID + "_serviceKey");
	
		// If we don't already have the keys, as far as we're concerned, the service doesn't exist
		if (tModelKey == null || serviceKey == null) {
			return serviceExists;
		}
	
		// UDDI Inquiry
		String serviceURL = UDDIInquiry(tModelKey, serviceKey);
	
		// If accessPoint URL DOES NOT exist in UDDI registry
		if (serviceURL == null) {
		
			// Set serviceExists flag to FALSE and do nothing
			serviceExists = false;
			
		}
	
		// Otherwise if the accessPoint URL DOES exist
		else {
		
			// cache accessPoint
			accessPoints.put(serviceID, serviceURL);
			
			// Set serviceExists flag to TRUE
			serviceExists = true;
			
		}
		
		return serviceExists;
	
	}
	
	public void bindService(ByteBuffer msgBuffer) {

		// Extract Service ID pairs from LogMsg
		byte sourceServiceID = msgBuffer.get(SBINDMSG_SRC_SERVICE_LOC);
		byte dstServiceID = msgBuffer.get(SBINDMSG_DST_SERVICE_LOC);
		short dstNodeID = msgBuffer.getShort(SBINDMSG_DST_NODE_LOC);
		DestinationInfo destinationInfo = new DestinationInfo(dstServiceID, dstNodeID);
		
System.out.println("bindService: sourceServiceID = " + (short)sourceServiceID);
System.out.println("bindService: destination service ID = " + (destinationInfo.getDstService() & 0xff));
System.out.println("bindService: destination node = " + destinationInfo.getDstNode());
		
		// Insert Service ID pairs into binding structure
		serviceBindings.put(sourceServiceID, destinationInfo);
		
// HACK: Binding message is the service invokation trigger
ByteBuffer accessBuffer = ByteBuffer.allocate(SCONTROL_LEN + 5);
accessBuffer.order(ByteOrder.LITTLE_ENDIAN);
accessBuffer.putShort(msgBuffer.getShort(0));
accessBuffer.put(msgBuffer.get(2));
accessBuffer.putShort((short)this.gatewayAddress);
accessBuffer.put((byte)31);
accessBuffer.put((byte)0);
accessBuffer.put(ACCESS_TYPE);
accessBuffer.putInt((int)1);
accessBuffer.put((byte)0);
accessService(msgBuffer);
		
		return;
	
	}
	
	public void accessService(ByteBuffer msgBuffer) {
	
	Hack h = new Hack(msgBuffer);
	
	h.start();
	
	
/*	
//System.out.println("accessService: msgBuffer.capacity = " + msgBuffer.capacity());
	
		// Extract Service ID from byte array
//		byte serviceID = msgBuffer.get(SCONTROL_DSTS_LOC);
byte serviceID = 31;

		try {
	
			// Extract Input Data from byte array
			byte[] svcMsg = new byte[msgBuffer.capacity() - SCONTROL_LEN];
			for (int i = 0; i < msgBuffer.capacity() - SCONTROL_LEN; i++) {
				svcMsg[i] = msgBuffer.get(SCONTROL_LEN + i);
//System.out.println("accessService: svcMsg[" + i + "] = " + svcMsg[i]);
			}
			ByteBuffer inputBuffer = ByteBuffer.wrap(svcMsg);
			inputBuffer.order(ByteOrder.LITTLE_ENDIAN);
//			String inputData = convertInputData(serviceID, inputBuffer);
String inputData = "0";
System.out.println("accessService: inputData = " + inputData);

			// If access point does not exist, rediscover service
			if (accessPoints.get(serviceID) == null) {

System.out.println("accessService: Service " + serviceID + " NOT found, initiating service discovery");
	
				// Do service discovery
				if (rediscoverService(serviceID)) {
			
					// Recursively call this function, passing in same message
					accessService(msgBuffer);
					
				}
				else {
				
					System.out.println("accessService: Service Rediscovery failed!");
					
				}
				
				return;

			}
			
			String serviceURL = accessPoints.get(serviceID).toString();
System.out.println("accessService: serviceURL = " + serviceURL);
			
			// Instantiate Call class for accessing Service
			Service service = new Service();
			Call call = (Call)service.createCall();
			
			// Set the service URL
			call.setTargetEndpointAddress(new URL(serviceURL));
			
			// Set the name of the method to call within the service
			String serviceMethod = config.getProperty((short)serviceID + "_method");
System.out.println("accessService: " + (short)serviceID + "_method = " + serviceMethod);
			call.setOperationName(new QName(serviceMethod));
			
// HACK: This will invoke the service every six seconds.  This should be passed as input from the object
for (;;) {			
			
			// Invoke the service, passing the input data as an argument, and get the result
			String result = (String)call.invoke(new Object [] {new String(inputData)});
System.out.println("accessService: result = " + result);
			
			// Make sure there is another service to run
			if (serviceBindings.get(serviceID) != null) {
			
				// Find next service in service graph according to bind info
				byte nextServiceID;
				short nextNodeID;
				DestinationInfo destInfo = (DestinationInfo)serviceBindings.get(serviceID);
				nextServiceID = destInfo.getDstService();
				nextNodeID = destInfo.getDstNode();
			
				// convert the output data of the previous service to a byte sequence
				ByteBuffer outputData = convertOutputData(serviceID, result);

				// Compose appropriate message
				ByteBuffer reqMsg = ByteBuffer.allocate(SCONTROL_LEN + outputData.capacity());
				reqMsg.order(ByteOrder.LITTLE_ENDIAN);
				
				// SCONTROL
				reqMsg.putShort(this.gatewayAddress);							// source node id
				reqMsg.put(serviceID);											// source node service ??????
				reqMsg.putShort(nextNodeID);									// destination node id
				reqMsg.put(nextServiceID);										// destination node service
				reqMsg.put((byte)0);											// sequence number
				reqMsg.put((byte)ACCESS_TYPE);									// type
				
				// Data
				reqMsg.put(outputData.array());
			
				// If next service in service graph is a web service in cache
				if (accessPoints.get(nextServiceID) != null) {
					
					// recursively Call this function, passing in the new message
					accessService(reqMsg);
				
				}
				// Otherwise the next service is on a mote
				else {
					
					// Send to appropriate mote
					sendMessageToSensornet(nextNodeID, reqMsg);
					
				}
			}
			else {
System.out.println("accessService: no more services to run");			
			}
			

}
		
		} 
		
		// Catch any other exception that may occur
		catch (Exception e) {
			e.printStackTrace();
		}
*/
		return;
	
	}
	
	// This function appropriately converts input data from a byte sequence to a string
	public String convertInputData(byte serviceID, ByteBuffer msgBuffer) {
	
		String inputData = "";
		
		// We need to know what type of data this is
		String inputDataType = config.getProperty((short)serviceID + "_inputDataType");
		// If input is a series of values, we need to know what the delimiter is
		String inputDataDelimiter = config.getProperty((short)serviceID + "_inputDataDelimiter");
		if (inputDataDelimiter.compareToIgnoreCase("SPACE") == 0) {
			inputDataDelimiter = " ";
		}
		
		// Convert the input data into String format
		if (inputDataType.compareToIgnoreCase("STRING") == 0) {
			CharBuffer charBuffer = msgBuffer.asCharBuffer();
			inputData = charBuffer.toString();
		} 
		else if (inputDataType.compareToIgnoreCase("DOUBLE") == 0) {
			DoubleBuffer doubleBuffer = msgBuffer.asDoubleBuffer();
			for (int i = 0; i < doubleBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += String.valueOf(doubleBuffer.get());
			}
		} 
		else if (inputDataType.compareToIgnoreCase("FLOAT") == 0) {
			FloatBuffer floatBuffer = msgBuffer.asFloatBuffer();
			for (int i = 0; i < floatBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += String.valueOf(floatBuffer.get());
			}
		}
		else if (inputDataType.compareToIgnoreCase("INTEGER") == 0) {
			IntBuffer intBuffer = msgBuffer.asIntBuffer();
			for (int i = 0; i < intBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += String.valueOf(intBuffer.get());
			}
		}
		else if (inputDataType.compareToIgnoreCase("LONG") == 0) {
			LongBuffer longBuffer = msgBuffer.asLongBuffer();
			for (int i = 0; i < longBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += String.valueOf(longBuffer.get());
			}
		}
		else if (inputDataType.compareToIgnoreCase("SHORT") == 0) {
			ShortBuffer shortBuffer = msgBuffer.asShortBuffer();
			for (int i = 0; i < shortBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += shortBuffer.get();
			}
		}
		else if (inputDataType.compareToIgnoreCase("BYTE") == 0) {
			for (int i = 0; i < msgBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += (short)msgBuffer.get();
			}
		}
		else if (inputDataType.compareToIgnoreCase("BOOLEAN") == 0) {
			for (int i = 0; i < msgBuffer.capacity(); i++) {
				if (i > 0)
					inputData += inputDataDelimiter;
				inputData += (((short)msgBuffer.get() > 0) ? "1" : "0");
			}
		}
		
		return inputData;
	
	}
	
	// This function appropriately converts output data from a string to a ByteBuffer
	public ByteBuffer convertOutputData(byte serviceID, String data) {
	
		ByteBuffer outputData = ByteBuffer.allocate(0);
		
		// We need to know what type of data this is
		String outputDataType = config.getProperty((short)serviceID + "_outputDataType");
		
		// If output is a series of values, we need to know what the delimiter is
		String outputDataDelimiter = config.getProperty((short)serviceID + "_outputDataDelimiter");
		if (outputDataDelimiter.compareToIgnoreCase("SPACE") == 0) {
			outputDataDelimiter = " ";
		}

		// Parse the data string into fields
		String [] fields = data.split(outputDataDelimiter);
		
		// Convert the output data into bytes and wrap into a ByteBuffer
		if (outputDataType.compareToIgnoreCase("STRING") == 0) {
			outputData = ByteBuffer.allocate(data.getBytes().length);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			outputData = ByteBuffer.wrap(data.getBytes());
		} 
		else if (outputDataType.compareToIgnoreCase("DOUBLE") == 0) {
			outputData = ByteBuffer.allocate(fields.length * 8);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.putDouble(Double.parseDouble(fields[i]));
			}
		} 
		else if (outputDataType.compareToIgnoreCase("FLOAT") == 0) {
			outputData = ByteBuffer.allocate(fields.length * 4);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.putFloat(Float.parseFloat(fields[i]));
			}
		}
		else if (outputDataType.compareToIgnoreCase("INTEGER") == 0) {
			outputData = ByteBuffer.allocate(fields.length * 4);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.putInt(Integer.parseInt(fields[i]));
			}
		}
		else if (outputDataType.compareToIgnoreCase("LONG") == 0) {
			outputData = ByteBuffer.allocate(fields.length * 8);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.putLong(Long.parseLong(fields[i]));
			}
		}
		else if (outputDataType.compareToIgnoreCase("SHORT") == 0) {
			outputData = ByteBuffer.allocate(fields.length * 2);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.putShort(Short.parseShort(fields[i]));
			}
		}
		else if (outputDataType.compareToIgnoreCase("BYTE") == 0) {
			outputData = ByteBuffer.allocate(fields.length);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.put(Byte.parseByte(fields[i]));
			}
		}
		else if (outputDataType.compareToIgnoreCase("BOOLEAN") == 0) {
			outputData = ByteBuffer.allocate(fields.length);
			outputData.order(ByteOrder.LITTLE_ENDIAN);
			for (int i = 0; i < fields.length; i++) {
				outputData.put(((fields[i] == "0") ? (byte)0 : (byte)1));
			}
		}

		return outputData;
	
	}
	
	// Sends a message to the specified node in the sensor network
	public void sendMessageToSensornet(short nodeAddress, ByteBuffer message) {
	
		// Put the message in BigMsg format
//		ByteBuffer dataBuffer = ByteBuffer.allocate(BIGMSG_HEADER_LEN + BIGMSG_DATA_LEN);
		ByteBuffer dataBuffer = ByteBuffer.allocate(BIGMSG_HEADER_LEN + BIGMSG_SIZE_LEN + message.capacity());
		dataBuffer.order(ByteOrder.LITTLE_ENDIAN);
		// Big Message header
		dataBuffer.putShort(this.gatewayAddress);			// sender address
		dataBuffer.put((byte)0xff);						// sequence number of first packet
		// The first four bytes of the first Big Message packet contain the Big Message's total length
		dataBuffer.putInt(message.capacity());

		// For now I'm assuming that message will not exceed BIGMSG_DATA_LEN so there will only be 1 packet for now
		dataBuffer.put(message.array());
	
		// Try sending the message BIGMSG_RETRY_COUNT times
		boolean success = false;
		int i = 0;
		do {
			success = SerialConnectorCmd.instance().sendMessage((int)nodeAddress, BIGMSG_AM_TYPE, (short)0, dataBuffer.array());
		} while (!success && ++i < BIGMSG_RETRY_COUNT);
		
		// If the send hasn't been successful, display an error message and return
		if (!success) {
			System.out.println("Unable to send message to sensornet!");
		}
	
		return;
		
	}
	
	public String UDDIInquiry(String tModelKey, String serviceKey) {
	
		// Construct a UDDIProxy object
		UDDIProxy proxy = new UDDIProxy();
	
		try {
	
			// Select the desired UDDI server node
			proxy.setInquiryURL(config.getProperty("inquiryURL"));
			
			// Create the TModel Bag
			TModelBag tModelBag = new TModelBag();
			Vector tModelKeyVector = new Vector();
			tModelKeyVector.add(tModelKey);
			tModelBag.setTModelKeyStrings(tModelKeyVector);
			
			// Find the Binding Template
			// And set the maximum rows to be returned as 5
			BindingDetail bindingDetailReturned = proxy.find_binding(null, serviceKey, tModelBag, 5);
			
			// Process returned BindingDetail object
			Vector bindingTemplatesFound = bindingDetailReturned.getBindingTemplateVector();
			BindingTemplate bindingTemplateFound = (BindingTemplate)(bindingTemplatesFound.elementAt(0));
			String endpoint = bindingTemplateFound.getAccessPoint().getText();
System.out.println("UDDIInquiry: endPoint = " + endpoint);
			
			// Return accesspoint URL
			return endpoint;
		}
		
		// Handle possible errors
		catch (UDDIException e) {
		
			DispositionReport dr = e.getDispositionReport();
			
			// If UDDI inquiry produced a fault, print it
			if (dr != null) {
				
				System.out.println("UDDIInquiry: UDDIException faultCode:" + e.getFaultCode() +
									"\n operator:" + dr.getOperator() +
									"\n generic:"  + dr.getGeneric() );
				
				Vector results = dr.getResultVector();
				
				for (int i = 0; i < results.size(); i++) {
					
					Result r = (Result)results.elementAt(i);
					System.out.println("\n errno:" + r.getErrno());
					
					if (r.getErrInfo() != null) {
						
						System.out.println("\n errCode:" + r.getErrInfo().getErrCode() +
											"\n errInfoText:" + r.getErrInfo().getText());
					}
				}
			}
			
			// Otherwise print stack trace
			e.printStackTrace();
		}
		
		// Catch any other exception that may occur
		catch (Exception e) {
			e.printStackTrace();
		}
		
		// If we are here, a fault occurred, so return null
		return null;
	
	}
	
	public void BigMSGFailed(int source) {
	
		System.out.println("Incoming Big Message Failed!");
		return;
	}
	
	public void BigMSGArriving(int source) {
	
//		System.out.println("Big Message Arriving!");
		return;
	}
	
	public void testOut(byte msgType) {
	
		// Construct the return message
		ByteBuffer retMsg = ByteBuffer.allocate(SDMSG_LEN);
		retMsg.order(ByteOrder.LITTLE_ENDIAN);
		
		// First construct the SControl structure
		retMsg.putShort(this.gatewayAddress);  				// source node id
		retMsg.put(DISCOVERY_MESSAGE);							// source node service ???
		retMsg.putShort((short)182);							// destination node id
		retMsg.put((byte)2);									// destination node service ???
		retMsg.put((byte)0);									// sequence number ???
		retMsg.put((byte)11);									// type
				
		if (msgType == DISCOVERY_MESSAGE) {
			// Construct the SDMsg structure
			retMsg.put((byte)5);								// service id
			retMsg.putShort((short)182);						// origin of service request
			retMsg.putShort(this.gatewayAddress);				// provider
			retMsg.putShort((short)0);							// x positon
			retMsg.putShort((short)0);							// y position
			retMsg.putShort((short)0);							// z position
			retMsg.putShort((short)100);						// power
		}
		else if (msgType == ACCESS_MESSAGE) {
		
			String result = "5";
		
			// convert the output data of the previous service to a byte sequence
			ByteBuffer outputData = convertOutputData((byte)31, result);
			
			// Data
//			retMsg.put(outputData.array());
			retMsg.put((byte)5);

			// Fill the rest in with 0
			retMsg.putShort((short)0);
			retMsg.putShort((short)0);
			retMsg.putShort((short)0);
			retMsg.putShort((short)0);
			retMsg.putShort((short)0);
			retMsg.putShort((short)0);
		
		}
		
		// Send return message back to mote
		sendMessageToSensornet((short)TOS_BCAST_ADDR, retMsg);
		
		return;
	
	}
	
	public void testIn(byte msgType) {
	
		if (msgType == DISCOVERY_TYPE) {
		
			// Construct service discovery message
			ByteBuffer msgBuffer = ByteBuffer.allocate(SDMSG_LEN);
			msgBuffer.order(ByteOrder.LITTLE_ENDIAN);
			
			msgBuffer.putShort((short)220);		// SControl.src
			msgBuffer.put((byte)13);				// SControl.srcs
			msgBuffer.putShort((short)0);			// SControl.dst
			msgBuffer.put(DISCOVERY_MESSAGE);		// SControl.dsts
			msgBuffer.put((byte)1);				// SControl.seqnum
			msgBuffer.put(INFO_TYPE);				// SControl.type
			
			msgBuffer.put((byte)31);				// SDMsg.service
			msgBuffer.putShort((short)220);		// SDMsg.origin
			msgBuffer.putShort((short)0);			// SDMsg.provider
			msgBuffer.putShort((short)0);			// SDMsg.position[0]
			msgBuffer.putShort((short)0);			// SDMsg.position[1]
			msgBuffer.putShort((short)0);			// SDMsg.position[2]
			msgBuffer.putShort((short)0);			// SDMsg.power
			
			// Call discover service function
			discoverService(msgBuffer);
		
		}
		else if (msgType == BINDING_TYPE) {
		
			// Construct service bind message
			ByteBuffer msgBuffer = ByteBuffer.allocate(SBINDMSG_LEN);
			msgBuffer.order(ByteOrder.LITTLE_ENDIAN);
			
			msgBuffer.putShort((short)220);		// SControl.src
			msgBuffer.put((byte)13);				// SControl.srcs
			msgBuffer.putShort((short)0);			// SControl.dst
			msgBuffer.put(BIND_MESSAGE);			// SControl.dsts
			msgBuffer.put((byte)1);				// SControl.seqnum
			msgBuffer.put(BINDING_TYPE);			// SControl.type
			
			msgBuffer.put((byte)31);				// SBindMsg.src_service
			msgBuffer.putShort((short)0);			// SBindMsg.src_node
			msgBuffer.put((byte)13);				// SBindMsg.dst_service
			msgBuffer.putShort((short)220);		// SBindMsg.dst_node
			
			// Call bind service function
			bindService(msgBuffer);
		
		}
		else if (msgType == ACCESS_TYPE) {
		
		
			// Construct service access message
			ByteBuffer msgBuffer = ByteBuffer.allocate(SCONTROL_LEN + 2);
			msgBuffer.order(ByteOrder.LITTLE_ENDIAN);
			
			msgBuffer.putShort((short)220);		// SControl.src
			msgBuffer.put((byte)13);				// SControl.srcs
			msgBuffer.putShort((short)0);			// SControl.dst
			msgBuffer.put((byte)31);				// SControl.dsts
			msgBuffer.put((byte)1);				// SControl.seqnum
			msgBuffer.put(ACCESS_TYPE);				// SControl.type
			
			msgBuffer.putShort((short)42);			// input data

			// Call access service function
			accessService(msgBuffer);
		
		}
	
	}

}