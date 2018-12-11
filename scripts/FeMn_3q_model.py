import numpy as np
import 	datetime
#
#
#	parameter to convert from degrees to radiants
conv_deg_to_rad	=	np.pi / 180.
#
#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#		CLASS HOLDING THE PARAMETERS																											   |
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class FeMn_3q_model:
	#
	#
	def __init__(self, fpath,	verbose=False):
		self.nWfs		=	8
		self.nrpts		=	13
		self.verbose	=	verbose
		#
		self.thconv		=	[]
		self.phconv		=	[] 
		self.wf_pos		=	[]
		self.R_nn_lst	=	[]
		self.tHopp		=	[]
		self.rHopp		=	[]
		#
		self.v_print("	~~~~~~~~~~~~3D FCC - FeMn - 3q state~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		#
		
		#	real space positions
		rx_at	=	[.0,	.5,		.5,		.0]
		ry_at	=	[.0,	.5,		.0,		.5]
		rz_at	=	[.0,	.0,		.5,		.5]

		#	for spin up and down
		rx_wf	=	rx_at	+	rx_at
		ry_wf	=	ry_at	+	ry_at
		rz_wf	=	rz_at	+	rz_at

		print("[FeMn_3q_model/init]: rx_wf=",rx_wf)
		#
		for wf in range(self.nWfs):
			#position op. is real
			self.wf_pos.append(		[	rx_wf[wf],.0,		ry_wf[wf],.0,		rz_wf[wf],.0	]		)
		#
		#
		#	spin structure
		self.v_print(		'		  S4 ------ S2  '			)
		self.v_print(		'		   \        /   '			)
		self.v_print(		'		    \  S1  /    '			)
		self.v_print(		'		y    \    /     '			)
		self.v_print(		'		|     \  /      '			)
		self.v_print(		'		|      S3       '			)
		self.v_print(		'		O---x           '			)
		#
		with open(fpath) as f_in:
			for idx, line in enumerate(f_in):
				#	
				#	IDENTIFY INDIVIDUAL LINES 
				#
				if idx	== 0:
					self.nKx, self.nKy, self.nKz				=		np.fromstring(	line,		dtype=float, count=3, sep=" ")			
				#-------------------------------------------------------------------------------------
				#
				elif idx == 1:
					self.intra_t, self.inter_t, self.lmbda		=		np.fromstring(	line,		dtype=float, count=3, sep=" ")
				#-------------------------------------------------------------------------------------
				#
				elif idx >=2 and idx<=5:
					phi, theta									= 		np.fromstring(	line,		dtype=float, count=2, sep=" ")		
					self.phconv.append(		phi			* conv_deg_to_rad	)
					self.thconv.append(		theta		* conv_deg_to_rad	)
				#-------------------------------------------------------------------------------------
				#-------------------------------------------------------------------------------------
				#-------------------------------------------------------------------------------------
		self.v_print(	"	[FeMn_3q_model]:	initalized new param set from "+fpath			)
		self.v_print(	"	[FeMn_3q_model]:	 summary"										)
		self.v_print(	"		t1	    =	" + str(	self.intra_t		)	+ str("(eV)")		)
		self.v_print(	"		t2	    =	" + str(	self.inter_t		)	+ str("(eV)")		)
		self.v_print(	"		lmbda	=	" + str(	self.lmbda	)	+ str("(eV)")		)
		self.v_print(	" 		# spin		|	phi(rad) 		| theta(rad) "					)
		self.v_print(	"		------------------------------------------------------"			)
		for  spin in range(4):
			self.v_print("		  "+		str(spin+1)	+ "		|	"	+	str(self.phconv[spin])	+	"		|	"	+	str(self.thconv[spin])	)
		self.v_print(	"		------------------------------------------------------"			)
		self.v_print(	"		------------------------------------------------------"			)
	#
	#
	#	----
	def v_print(self,out_string):
		#print only if verbose option is true
		if self.verbose:	print(out_string)
	







	def tHopp_fill_zeros(self):
		#	FILL REST WITH ZERO
		#
		# creat list with already added elements
		tHopp_exist = []
		exist_cnt	= 0
		for t in self.tHopp:
			tHopp_exist.append(	[	int(t[0]),int(t[1]),int(t[2]),int(t[3]),int(t[4])	]	 )
			exist_cnt	= exist_cnt + 1
		if exist_cnt != 80:
			print("WARNING the tHopp_exist list is wrong")
		#
		#only if not in already added list append value
		zero_cnt = 0
		match_cnt = 0
		t_matches = []
		for R_nn in self.R_nn_lst:
			for m in range(self.nWfs):
				for n in range(self.nWfs):
					if [ int(R_nn[0]), int(R_nn[1]), int(R_nn[2]), int(m+1), int(n+1)] in tHopp_exist:
						t_matches.append([ int(R_nn[0]), int(R_nn[1]), int(R_nn[2]), int(m+1), int(n+1)])
						match_cnt = match_cnt + 1				
					else:			
						zero_cnt	= zero_cnt + 1
						self.tHopp.append(		[ R_nn[0], R_nn[1], R_nn[2], m+1, n+1, 0.0, 0.0	]		)
		return self.tHopp











	def set_right_left_cc(self,	R_left, R_right,	m, n, t_hopp):
		#
		# add the hopping (left & right)
		self.tHopp.append(	np.concatenate((	R_right,	[	m,	n,	t_hopp[0],		t_hopp[1]			])))
		self.tHopp.append(	np.concatenate(( 	R_left,		[	m,	n,	t_hopp[0], 		t_hopp[1]			])))
		#
		#	now add complex conjugates of both terms
		self.tHopp.append(	np.concatenate(( 	R_right,	[	n  , m,	t_hopp[0],  - 	t_hopp[1]			])))
		self.tHopp.append(	np.concatenate(( 	R_left,		[	n  , m,	t_hopp[0],  - 	t_hopp[1]			])))
		




	#
	#
	#	----
	def setup_Ham(self):
		#tHopp.append(	[ 0, 0, 0,			1,	2,			np.real(hopping[x][at1])	,   np.imag(hopping[x][at1])	])
		#
		#
		#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
		#      EXCHANGE																|
		#---------------------------------------------------------------------------
		sintheta	= []
		costheta	= []
		phasphi		= []
		for i in range(4):
			sintheta.append(						np.sin( self.thconv[i] )							)
			costheta.append(						np.cos(	self.thconv[i] )							)
			phasphi.append(		np.complex128(	np.cos(self.phconv[i])	 - 1j * np.sin(self.phconv[i]))	) 	
			#
			z_upDw	=	self.lmbda 	* sintheta[i]	*	phasphi[i]
			re_upDw	=	np.real(	z_upDw	)
			im_upDw	=	np.imag(	z_upDw	)
			#       do i=1,4 ! exchange
			#        ham(i,i) = lambda*costheta(i)
			#        ham(i+4,i+4) = -lambda*costheta(i)
			#        ham(i,i+4) = lambda*phasphi(i)*sintheta(i)
			#       enddo
			self.tHopp.append(	[	0, 0, 0, 		i+1, i+1, 		self.lmbda 	* costheta[i]						, 	.0			]				)
			self.tHopp.append(	[ 	0, 0, 0,		i+5, i+5, 	-	self.lmbda	* costheta[i] 						, 	.0			]				)
			self.tHopp.append(	[	0, 0, 0,		i+1, i+5,			re_upDw										, 	im_upDw		]				)
			self.tHopp.append(	[	0, 0, 0, 		i+5, i+1,			re_upDw										, - im_upDw		]				)
		self.R_nn_lst.append([0,0,0])
		#
		#
		#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
		#      HOPPING																|
		#---------------------------------------------------------------------------
		#
		#	JAN'S HOPPING SETUP			
		#> 	1	do i=0,4,4 ! intra- and inter-layer hopping
        #> 	2		ham(1+i,2+i)=ht1(1)+ht2(1)
        #> 	3		ham(1+i,3+i)=ht1(2)+ht2(2)
        #> 	4		ham(1+i,4+i)=ht1(3)+ht2(3)
        #> 	5		ham(2+i,3+i)=ht1(3)+ht2(3)
        #> 	6		ham(2+i,4+i)=ht1(2)+ht2(2)
        #> 	7		ham(3+i,4+i)=ht1(1)+ht2(1)
       	#> 	8	enddo
       	#
       	#
		#	JAN'S SOURE CODE
		#>	1		! intra-layer hopping	
       	#>	2		ht1(1) = -2*t*cos(pi*kx-3./2.*pi*ky)		/(2*Pi)	=	cos(	1/2 kx	-	3/4 ky	)
       	#>	3		ht1(2) = -2*t*cos(2.*pi*kx)					/(2*Pi)	=	cos(	1	kx				)
       	#>	4		ht1(3) = -2*t*cos(pi*kx+3./2.*pi*ky)		/(2*Pi)	=	cos(	1/2 kx	+	3/4 ky	)

       	#todo:	jans & mine are slightly different: 	jan uses 		3./2.*pi*ky 
       	#												i use			sqrt(3.)/2.*pi*ky								

       	#	in-plane hopping directions
		Rr_intra_12	=	[ +	1/2.	, +	 np.sqrt(3.)/4.		,	 .0	]
		Rl_intra_12	=	[ -	1/2.	, -	 np.sqrt(3.)/4.		,	 .0	]
		self.R_nn_lst.append( Rr_intra_12)
		self.R_nn_lst.append( Rl_intra_12)
		#
		Rr_intra_13	=	[ +	1.0		,		 .0				,	 .0	]
		Rl_intra_13	=	[ - 1.0		,		 .0				,	 .0	]
		self.R_nn_lst.append( Rr_intra_13)
		self.R_nn_lst.append( Rl_intra_13)
		#
		Rr_intra_14	=	[ +	1/2.	, - np.sqrt(3.)/4.		,	 .0	]
		Rl_intra_14	=	[ -	1/2.	, + np.sqrt(3.)/4.		,	 .0	]
		self.R_nn_lst.append( Rr_intra_14)
		self.R_nn_lst.append( Rl_intra_14)
		#
		#
		#	in-plane hopping strength
		intra_hopp		=	np.array(	[np.real(self.intra_t),	+ np.imag(self.intra_t)]	)
		#
		#
		#	ADD INTRA-LAYER HOPPING
		for i in range(0,8,4):
			#
			self.set_right_left_cc(		Rl_intra_12,	Rr_intra_12,		1+i, 2+i,	intra_hopp		)
			self.set_right_left_cc(		Rl_intra_13,	Rr_intra_13,		1+i, 3+i,	intra_hopp		)
			self.set_right_left_cc(		Rl_intra_14,	Rr_intra_14,		1+i, 4+i,	intra_hopp		)
			#
			self.set_right_left_cc(		Rl_intra_14,	Rr_intra_14,		2+i, 3+i,	intra_hopp		)
			self.set_right_left_cc(		Rl_intra_13,	Rr_intra_13,		2+i, 4+i,	intra_hopp		)
			self.set_right_left_cc(		Rl_intra_12,	Rr_intra_12,		3+i, 4+i,	intra_hopp		)


		# 	JAN'S SOURCE CODE
       	#! inter-layer hopping
       	#ht2(1) =-2*t2*cos(-pi*kx-pi/2.*ky-2.*pi*kz)	/(2*Pi)	=	cos( -	1/2 kx	-	1/4 ky	- 1 kz	)
       	#ht2(2) =-2*t2*cos(          pi*ky-2.*pi*kz)	/(2*Pi)	=	cos(				1/2 ky	- 1 kz	)
       	#ht2(3) =-2*t2*cos( pi*kx-pi/2.*ky-2.*pi*kz)	/(2*Pi)	=	cos(	1/2 kx	-	1/4 ky	- 1 kz	)
       	#
		#
		Rr_inter_12	=	[	-1./2.	, -	1./4.	,	-	1.0 ]
		Rl_inter_12	=	[	+1./2.	, +	1./4.	,	+	1.0 ]
		self.R_nn_lst.append( Rr_inter_12) 
		self.R_nn_lst.append( Rl_inter_12) 
		#
		Rr_inter_13	=	[	  .0	, +	1./2.	,	-	1.0	]
		Rl_inter_13	=	[	  .0	, -	1./2.	,	+	1.0	]		
		self.R_nn_lst.append( Rr_inter_13) 
		self.R_nn_lst.append( Rl_inter_13) 
		#		
		Rr_inter_14	=	[ +  1./2.	, -	1./4.	,	-	1.0	] 		
		Rl_inter_14	=	[ -  1./2.	, +	1./4.	,	+	1.0	] 		
		self.R_nn_lst.append( Rr_inter_14) 
		self.R_nn_lst.append( Rl_inter_14) 
		#
		#
		#	out-of-plane hopping strength
		inter_hopp		=	np.array(	[np.real(self.inter_t),	+ np.imag(self.inter_t)]	)    	
       	#
		#	ADD INTER-LAYER HOPPING
		for i in range(0,8,4):
			self.set_right_left_cc(		Rl_inter_12,	Rr_inter_12,		1+i, 2+i,	inter_hopp		)
			self.set_right_left_cc(		Rl_inter_13,	Rr_inter_13,		1+i, 3+i,	inter_hopp		)
			self.set_right_left_cc(		Rl_inter_14,	Rr_inter_14,		1+i, 4+i,	inter_hopp		)
			#
			self.set_right_left_cc(		Rl_inter_14,	Rr_inter_14,		2+i, 3+i,	inter_hopp	 	)
			self.set_right_left_cc(		Rl_inter_13,	Rr_inter_13,		2+i, 4+i,	inter_hopp	 	)
			self.set_right_left_cc(		Rl_inter_12,	Rr_inter_12,		3+i, 4+i,	inter_hopp	 	)



		#
		#
		#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
		#      FILL REST WITH ZEROS													|
		#---------------------------------------------------------------------------
		self.tHopp_fill_zeros()	
	










































	#
	#
	#	----
	def setup_Pos(self):
		#
		self.v_print(	"		[FeMn_3q_model/setup_Pos]:	start position operator setup!"		)
		self.v_print(	"		[FeMn_3q_model/setup_Pos]: got the following nn cells: "		)
		self.v_print(	"		 n	|	R_nn")
		self.v_print(	"		-----------------------------------")
		for idx,R_nn in enumerate(self.R_nn_lst):
			self.v_print(" 		"+str(idx)+"  |  "+str(R_nn))
		self.v_print(	"		-----------------------------------")

		#
		for m in range(self.nWfs):
			for n in range(self.nWfs):
				for idx,R_nn in enumerate(self.R_nn_lst):
					at_pos 	=	[	.0,.0,		.0,.0,		.0,.0]
					#	R_nn is diagonal
					if R_nn == [0,0,0]:		
						if m == n:
							at_pos	=	self.wf_pos[m]		
					self.rHopp.append(	[	R_nn[0],R_nn[1],R_nn[2], 	m+1, n+1, 		at_pos[0], at_pos[1], at_pos[2], at_pos[3], at_pos[4], at_pos[5]		])
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~






#
#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#		INTERFACE																																   |
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def get_FeMn3q_tb(fpath, verbose=False):
	print("[get_FeMn3q_tb]:	started..  FeMn3q model setup at " +			datetime.datetime.now().strftime("%I:%M%p on %B %d, %Y"))
	#
	#	READ INPUT FILE
	test_model		=	FeMn_3q_model(fpath, verbose)
	#
	#
	#	HOPPING
	test_model.setup_Ham()
	#
	#	POSITION
	test_model.setup_Pos()
	#
	#	LATTICE
	a0 	= 1.0
	ax	= np.zeros(3)
	ay 	= np.zeros(3)
	az	= np.zeros(3)
	ax[0]	=	1.0
	ay[1]	=	1.0
	az[2]	=	1.0	
	#
	#
	print("[get_FeMn3q_tb]:	..finished FeMn3q model setup (TODO: PROPER LATTICE SETUP !) at " +	datetime.datetime.now().strftime("%I:%M%p on %B %d, %Y"))
	#
	return test_model.nWfs, test_model.nrpts, test_model.tHopp, test_model.rHopp, ax, ay, az, a0


#
#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#		TESTING																																	   |
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
def test(verbose=True):
	fpath 	= '/Users/merte/bin/tbmodel_3qstate/inp_params_3q'
	#
	#
	print("*")
	print("*")
	print("*")
	print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|")
	print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~TEST_OF_FeMn_3q_CLASS~~~~~~~~~~|")
	print("")
	print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|")
	print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|")
	if verbose:	print("[FeMn_3q_model/test]:	verbose mode active")
	print("")
	print("")
	print("")
	#
	#
	nWfs, nrpts, tHopp, rHopp, ax, ay, az, a0	=	get_FeMn3q_tb(fpath, verbose)
	#
	#
	#
	print("")
	print("")
	print("")
	print("*")
	print("*")
	print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|")
	print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~SUMMARY~~~~~~~~~~~~~~~~~~~~~~~~|")
	print("")
	print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|")
	print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|")
	print("[FeMn_3q_model/test]:			nWfs ="	+	str(	nWfs			))
	print("[FeMn_3q_model/test]:			nrpts="	+	str(	nrpts			))
	print("	"	)
	print("LATTICE")
	print("ax=	",a0*ax,"	(arb. units)")
	print("ay=	",a0*ay,"	(arb. units)")
	print("az=	",a0*az,"	(arb. units)")


	print("[FeMn_3q_model/test]:			tHopp (len="+str(len(tHopp))+"): [eV]")
	print("")
	print("	R 	|	n m  |	t^R_nm (eV)")
	print("----------------------------------------------")
	for t_mn in tHopp:
		print("%5.2f %5.2f %5.2f	| %1d %1d"	%(t_mn[0],	t_mn[1], t_mn[2],	t_mn[3],t_mn[4])			,"	|	%5.2f +i* %5.2f"%(t_mn[-2],t_mn[-1])	)

	
	print("")
	print("[FeMn_3q_model/test]:			rHopp (len="+str(len(rHopp))+")")
	#for r_nm in rHopp:
	#	print(r_nm)
	print("~~~~~~~~~~~~~~~~~~~~~~~~")
	

#
#
#UNCOMMENT TO TEST THIS SCRIPT
test(verbose	=	True)






