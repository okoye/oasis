
/** 
	Local service localize 
	when triggered this service outputs next number from a pre-specified list.
*/

module ComponentLocalize {
	provides {
		interface FourPortServiceInterface as InputInterface;
		interface StdControl;
	}	
	uses {
		interface ServiceInterface as OutputInterface;
		interface Int3Output as Send;
	}
} implementation {
		
	ServiceMsg msg;
	bool present[4];
//	uint8_t iteration;
	
	// input variables from ports
	int8_t ux, uy;
	int32_t S[3][2];
	int32_t input[3];
	
	// noise characteristics
	int16_t Q, R;
	// observation model constant
	int32_t T;
	
	// system state variables
	int32_t x_hat;
	int32_t y_hat;
	int32_t x_hat_previous;
	int32_t y_hat_previous;

	// system state variables
	int32_t Pxx;
	int32_t Pxy;
	int32_t Pyy;
	int32_t Pxx_previous;
	int32_t Pxy_previous;
	int32_t Pyy_previous;

	bool again = 0;
	
	command result_t StdControl.init () {
		return SUCCESS;
	}
	
	command result_t StdControl.start () {
//		iteration = 0;
		Q = 100;
		R = 100;
		T = 1e8;

		x_hat_previous = 50;
		y_hat_previous = 50;
		Pxx_previous = Q;
		Pxy_previous = 0;
		Pyy_previous = Q;
		
		ux = 5;
		uy = 5;

		return SUCCESS;
	}
	
	command result_t StdControl.stop () {
		return SUCCESS;
	}

/*	task void addAndSend () {
		msg.data[4] = input[0] + input[1] + input[2] + input[3] + input[4];
		call OutputInterface.output (msg);
		present[0] = FALSE;		present[1] = FALSE;		present[2] = FALSE;		present[3] = FALSE;		present[4] = FALSE;
	}
*/	

	task void run_ekf ();

	command result_t InputInterface.output_port1 (ServiceMsg data) {
		// this port is connected sensor node - 1, 
		// the service message provides two things, 1. sensor location (x,y only)  (4 bytes), and 2. temperature (phenomenon) reading (2 bytes) 
		memcpy (&S[0][0], data.data+4, 2);
		memcpy (&S[0][1], data.data+6, 2);
		memcpy (&input[0], data.data+8, 2);

		present[0] = TRUE;
//		if (present[0] & present[1] & present[2] & present[3]) {
		if (present[0] & present[1] & present[2]) {
			post run_ekf ();
		}
		return SUCCESS;
	}
	
	command result_t InputInterface.output_port2 (ServiceMsg data) {
		// this port is connected sensor node - 2, 
		// the service message provides two things, 1. sensor location (x,y only)  (4 bytes), and 2. temperature (phenomenon) reading (2 bytes) 
		memcpy (&S[1][0], data.data+4, 2);
		memcpy (&S[1][1], data.data+6, 2);
		memcpy (&input[1], data.data+8, 2);

//call Send.output (S[1][0], S[1][1], input[1], input[1]>>8, x_hat_previous);

		present[1] = TRUE;

//call Send.output (present[0], present[1], present[2], present[3], input[1]);

//		if (present[0] & present[1] & present[2] & present[3]) {
		if (present[0] & present[1] & present[2]) {
			post run_ekf ();
		}
		return SUCCESS;
	}
	
	command result_t InputInterface.output_port3 (ServiceMsg data) {
		// this port is connected sensor node - 3, 
		// the service message provides two things, 1. sensor location (x,y only)  (4 bytes), and 2. temperature (phenomenon) reading (2 bytes) 
		memcpy (&S[2][0], data.data+4, 2);
		memcpy (&S[2][1], data.data+6, 2);
		memcpy (&input[2], data.data+8, 2);

//call Send.output (present[0], present[1], present[2], present[3], input[2]);

		present[2] = TRUE;
//		if (present[0] & present[1] & present[2] & present[3]) {
		if (present[0] & present[1] & present[2]) {
			post run_ekf ();
		}
		return SUCCESS;
	}
	
	command result_t InputInterface.output_port4 (ServiceMsg data) {
		// this port is connected to web-service that provides the mobility parameters i.e. wind-velocity (2 bytes)
		ux = *(int8_t *)(data.data+4);
		uy = *(int8_t *)(data.data+5);
//		ux = 0; 
//		uy = 0;
		present[3] = TRUE;

//call Send.output (present[0], present[1], present[2], present[3], *(uint8_t *)(data.data+4));

/*		if (present[0] & present[1] & present[2] & present[3]) {
			post run_ekf ();
		}*/
		return SUCCESS;
	}
	
	event result_t OutputInterface.outputComplete (result_t result) {
		signal InputInterface.outputComplete (SUCCESS);	
		return SUCCESS;
	}
	
	event result_t Send.outputComplete (result_t result) {
		if (again == 1) {
			call Send.output (y_hat, y_hat>>8, y_hat>>16, y_hat>>24, 0);
			again = 0;
		}
		return SUCCESS;
	}

/** ======================================================== **/

/** 
 * Relevant equations and functions for kalman filter based tracking
 * 
 */ 


 	/**
 	 *
 	 **/
	void compute_K1 (int32_t P1, int32_t P2, int32_t P3, int32_t H[3][2], int32_t K1[2][3]) {
	
		K1[0][0] = H[0][0]*P1 + H[0][1]*P2;
		K1[0][1] = H[1][0]*P1 + H[1][1]*P2;
		K1[0][2] = H[2][0]*P1 + H[2][1]*P2;
	
		K1[1][0] = H[0][0]*P2 + H[0][1]*P3; 
		K1[1][1] = H[1][0]*P2 + H[1][1]*P3; 
		K1[1][2] = H[2][0]*P2 + H[2][1]*P3; 
	}


 	/**
 	 *
 	 **/
	void compute_K2 (int32_t H[3][2], int32_t K1[2][3], int32_t r, int32_t K2[3][3]) {
	
		K2[0][0] = H[0][0]*K1[0][0] + H[0][1]*K1[1][0] + r;
		K2[0][1] = H[0][0]*K1[0][1] + H[0][1]*K1[1][1];
		K2[0][2] = H[0][0]*K1[0][2] + H[0][1]*K1[1][2];
	
		K2[1][0] = H[1][0]*K1[0][0] + H[1][1]*K1[1][0];
		K2[1][1] = H[1][0]*K1[0][1] + H[1][1]*K1[1][1] + r;
		K2[1][2] = H[1][0]*K1[0][2] + H[1][1]*K1[1][2];
	
		K2[2][0] = H[2][0]*K1[0][0] + H[2][1]*K1[1][0];
		K2[2][1] = H[2][0]*K1[0][1] + H[2][1]*K1[1][1];
		K2[2][2] = H[2][0]*K1[0][2] + H[2][1]*K1[1][2] + r;
	}

 	/**
 	 *
 	 **/
	int64_t compute_inv (int32_t A[3][3], int64_t iA[3][3]) {
	
		int64_t det = (int64_t)(A[2][2]*A[0][0])*A[1][1] - (int64_t)(A[0][0]*A[1][2])*A[2][1] 
								- (int64_t)(A[2][2]*A[1][0])*A[0][1] + (int64_t)(A[1][0]*A[0][2])*A[2][1] 
								+ (int64_t)(A[2][0]*A[0][1])*A[1][2] - (int64_t)(A[2][0]*A[0][2])*A[1][1];
		if (fabs(det) > 1) {
			iA[0][0] = 	((int64_t)(A[2][2]*A[1][1]) - (int64_t)(A[1][2]*A[2][1]));
			iA[0][1] = -((int64_t)(A[2][2]*A[0][1]) - (int64_t)(A[0][2]*A[2][1]));
			iA[0][2] = 	((int64_t)(A[0][1]*A[1][2]) - (int64_t)(A[0][2]*A[1][1]));
				
			iA[1][0] = (-(int64_t)(A[2][2]*A[1][0]) + (int64_t)(A[1][2]*A[2][0]));
			iA[1][1] = ((int64_t)(A[2][2]*A[0][0]) - (int64_t)(A[0][2]*A[2][0]));
			iA[1][2] = -((int64_t)(A[0][0]*A[1][2]) - (int64_t)(A[0][2]*A[1][0]));
		
			iA[2][0] = ((int64_t)(A[1][0]*A[2][1]) - (int64_t)(A[1][1]*A[2][0]));
			iA[2][1] = -((int64_t)(A[0][0]*A[2][1]) - (int64_t)(A[0][1]*A[2][0]));
			iA[2][2] = ((int64_t)(A[0][0]*A[1][1]) - (int64_t)(A[0][1]*A[1][0]));
			return det;
		}
		return 0;
	}


 	/**
 	 *
 	 **/
	int32_t compute_kalman_gain (int32_t K1[2][3], int32_t K2[3][3], int32_t K[2][3]) {
	//	K = K1 * inv(K2);
		int64_t iK[2][3];
		int64_t tK[2][3];
		int64_t det = compute_inv (K2, iK);
		uint8_t i, j;
		
		if ( det != 0 ) {	
			tK[0][0] = (K1[0][0]*iK[0][0] + K1[0][1]*iK[1][0] + K1[0][2]*iK[2][0]);
			tK[0][1] = (K1[0][0]*iK[0][1] + K1[0][1]*iK[1][1] + K1[0][2]*iK[2][1]);
			tK[0][2] = (K1[0][0]*iK[0][2] + K1[0][1]*iK[1][2] + K1[0][2]*iK[2][2]);
	
			tK[1][0] = (K1[1][0]*iK[0][0] + K1[1][1]*iK[1][0] + K1[1][2]*iK[2][0]);
			tK[1][1] = (K1[1][0]*iK[0][1] + K1[1][1]*iK[1][1] + K1[1][2]*iK[2][1]);
			tK[1][2] = (K1[1][0]*iK[0][2] + K1[1][1]*iK[1][2] + K1[1][2]*iK[2][2]);
	
			for (i = 0; i < 2; i++) {
				for (j = 0; j < 3; j++) {
					K[i][j] = (int32_t)(tK[i][j]/1e6);
				}
			}
			det = det/1e6;
		}
		return det;
	}
	
	
 	/**
 	 *
 	 **/
	void compute_innovation (int32_t z[], int32_t r1, int32_t r2, int32_t r3, int32_t v[]) {
		
		v[0] = z[0] - T/(r1);
		v[1] = z[1] - T/(r2);
		v[2] = z[2] - T/(r3);
	}
	
 	/**
 	 *
 	 **/
	void compute_update_covariance (int32_t K[2][3], int32_t H[3][2], int32_t Pxx_, int32_t Pxy_, int32_t Pyy_, int32_t P1, int32_t P2, int32_t P3, int32_t d) {
		int32_t tPxx = (K[0][0]*H[0][0] + K[0][1]*H[1][0] + K[0][2]*H[2][0]);
		int32_t tPxy = (K[0][0]*H[0][1] + K[0][1]*H[1][1] + K[0][2]*H[2][1]);
		int32_t tPyy = (K[1][0]*H[0][1] + K[1][1]*H[1][1] + K[1][2]*H[2][1]);
		
		tPxx = d  - tPxx;
		tPxy = - tPxy;
		tPyy = d - tPyy;
	
		P1 = (tPxx * Pxx_ + tPxy * Pxy_) / d; 
		P2 = (tPxx * Pxy_ + tPxy * Pyy_) / d;
		P3 = (tPxy * Pxy_ + tPyy * Pyy_) / d;
	
	}

 	/**
 	 *
 	 **/
	task void run_ekf () {

		int32_t x_hat_, y_hat_;
		int32_t Pxx_, Pxy_, Pyy_;
		int32_t r1, r2, r3;
		int32_t Hi[3][2];
		int32_t det;
		
		int32_t K1[2][3];
		int32_t K2[3][3];
		int32_t K[2][3];
		int32_t v[3];
		
		// starts at iteration = 1... 
//		iteration++;
//		call Send.output (x_hat_previous, y_hat_previous, ux, input[0], input[1]);

		// 2. prior (state prediction) 
		x_hat_ = x_hat_previous + ux;
		y_hat_ = y_hat_previous + uy;

		Pxx_ = Pxx_previous + Q;
		Pyy_ = Pyy_previous + Q;
		Pxy_ = Pxy_previous;
		
		r1 = ((x_hat_ - (int32_t)S[0][0])*(x_hat_ - (int32_t)S[0][0]) + (y_hat_ - (int32_t)S[0][1])*(y_hat_ - (int32_t)S[0][1]));
		r2 = ((x_hat_ - (int32_t)S[1][0])*(x_hat_ - (int32_t)S[1][0]) + (y_hat_ - (int32_t)S[1][1])*(y_hat_ - (int32_t)S[1][1]));
		r3 = ((x_hat_ - (int32_t)S[2][0])*(x_hat_ - (int32_t)S[2][0]) + (y_hat_ - (int32_t)S[2][1])*(y_hat_ - (int32_t)S[2][1]));
		
		Hi[0][0] = -2 * ((T/r1) * (x_hat_ - S[0][0])) / (r1);
		Hi[0][1] = -2 * ((T/r1) * (y_hat_ - S[0][1])) / (r1);
		Hi[1][0] = -2 * ((T/r2) * (x_hat_ - S[1][0])) / (r2);
		Hi[1][1] = -2 * ((T/r2) * (y_hat_ - S[1][1])) / (r2);
		Hi[2][0] = -2 * ((T/r3) * (x_hat_ - S[2][0])) / (r3);
		Hi[2][1] = -2 * ((T/r3) * (y_hat_ - S[2][1])) / (r3);

		// 4. innovation covariance 
		// K1 = P_ H'
		compute_K1 (Pxx_, Pxy_, Pyy_, Hi, K1);

		// K2 = H P_ H' + R = H K1 + R
		compute_K2 (Hi, K1, R, K2);
		
		// 5. Kalman gain 
		det = compute_kalman_gain (K1, K2, K);
		
		// 6. measurement update 
		compute_innovation (input, r1, r2, r3, v);


		// 7. state update (posterior) 
		x_hat = x_hat_ + (K[0][0]*v[0] + K[0][1]*v[1] + K[0][2]*v[2])/det;
		y_hat = y_hat_ + (K[1][0]*v[0] + K[1][1]*v[1] + K[1][2]*v[2])/det;
		
		compute_update_covariance (K, Hi, Pxx_, Pxy_, Pyy_, Pxx, Pxy, Pyy, det);
		
		call Send.output (x_hat, x_hat>>8, y_hat, y_hat>>8, 0);
		

		// ouput message includes, 1. current estimate of phenomenon (4 bytes), 2. covariance (6 bytes).
		msg.data[4] = x_hat;
		msg.data[5] = x_hat>>8;

		msg.data[6] = y_hat;
		msg.data[7] = y_hat>>8;

		msg.data[8] = Pxx;
		msg.data[9] = Pxx>>8;

		msg.data[10] = Pxy;
		msg.data[11] = Pxy>>8;

		msg.data[12] = Pyy;
		msg.data[13] = Pyy>>8;
		
		msg.data[14] = 0;

		msg.data[0] = 11; // length of this message
		msg.seqNum = 0xFF;
		if (call OutputInterface.output (msg)) {
			present[0] = FALSE;		present[1] = FALSE;		present[2] = FALSE;		present[3] = FALSE;
			x_hat_previous = x_hat;			y_hat_previous = y_hat;
			Pxx_previous = Pxx;			Pxy_previous = Pxy;			Pyy_previous = Pyy;
		}

	}


}


