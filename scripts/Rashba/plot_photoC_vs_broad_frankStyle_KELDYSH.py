import numpy as np
import datetime
import sys
import os
import matplotlib.pyplot as plt
from random import randint
import matplotlib.cm as cm
from laser import laser


#	
#		IN FREIMUTH FORMULA THE IMAG PART OF THE TENSOR IS SELECTED
#	
#	

ex 	=	np.array([1,0,0])
ey 	=	np.array([0,1,0])
ez 	=	np.array([0,0,1])


au_to_ev	=	 27.211385			#	Eh	->	eV
bohr_rad_si	=	5.29177211*1e-11	#	a0	->  m

def discrete_cmap(N, base_cmap=None):
    """Create an N-bin discrete colormap from the specified input map"""

    # Note that if base_cmap is a string or None, you can simply do
    #    return plt.cm.get_cmap(base_cmap, N)
    # The following works for string, None, or a colormap instance:

    base = plt.cm.get_cmap(base_cmap)
    color_list = base(np.linspace(0, 1, N))
    #cmap_name = base.name + str(N)
    #return base.from_list(cmap_name, color_list, N)
    return color_list





class plotter:

	def __init__(self, root_dir,dir_id):
		#derived attributes
		self.root_dir	= root_dir
		self.data_dir	= root_dir+'/out'
		self.plot_dir	= self.root_dir+'/plots'
		self.dir_id		= dir_id
		self.n_bands	= 0
		#
		#
		#	containers
		self.hw_lst				=	[]
		self.ef_lst				=	[]
		self.scndPhoto_data		=	[]

		#	read data
		self.smr_lst		=	np.load(self.data_dir+'/smr_lst.npy')
		self.hw_lst			=	np.load(self.data_dir+'/hw_lst.npy')
		self.occ_lst		=	np.load(self.data_dir+'/occ_lst.npy')
		self.ef_lst			=	self.occ_lst[0][:]
		
		#
		self.hw_lst			=	self.hw_lst		*	au_to_ev
		self.smr_lst		=	self.smr_lst 	* au_to_ev


		#for elem in self.occ_lst:
		#	self.ef_lst.append(		elem[0]		)
		#
		self.scndPhoto_data	=	np.load(self.data_dir+'/keldysh_photoC2.npy')	
		np_arr				=	np.array(	self.scndPhoto_data)
		raw_shape			=	np_arr.shape
		#
		#	
		print("^")
		print("^")
		print("^")
		print("^")
		print("^^^^^^^^^^^^^^^	PLOTTING SCRIPT - 2nd order PHOTCURRENT AT DIFF SPIN CONFIGS  ^^^^^^^^^^^^^^^")
		print("-------------------------------------------------------------------------------")
		print("~")
		print("[init]: will search for data in folder: "	+	self.root_dir	)
		print("[init]: will output to folder: "				+ 	self.plot_dir	)
		print("..\n..")
		#
		print("[init]: input read from  "				+ 	self.data_dir	)
		print("[init]: input interpretation:"	)
		if (raw_shape[0]!=3) or (raw_shape[1]!=3) or (raw_shape[2]!=3):
			print("[init]: ERROR tensor is not defined in 3D")
			stop
		else:
			print("raw input shape:",   np_arr.shape,"	== (	x1,x2,x3,	#hw , #ef	)		")
		if len(self.hw_lst)!=raw_shape[3]:
			print("[init]: 	ERROR hw_lst has wrong length") 
			stop
		else:
			print("\tlen(hw_lst)=",len(self.hw_lst))
		if len(self.ef_lst)!=raw_shape[5]:
			print("[init]: 	ERROR ef_lst has wrong length") 
			print("[init]: ef_lst:",self.ef_lst)
			stop
		else:
			print("\tlen(ef_lst)=",len(self.ef_lst))
		print("[init]: initialization successfully completed!")
		print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		#
		#

		
	

	def __del__(self):
		print("~")
		print('plotted hw probing, by\n\n')
		print("-------------------------------------------------------------------------------")
		print("-------------------------------------------------------------------------------")
		print("-------------------------------------------------------------------------------")



	def rand_tens(self):
		rand = []
		for x in range(1,3):
			rand.append([])
			for i in range(1,3):
				rand[-1].append([randint(0,9),randint(0,9),randint(0,9)])







	def set_hall_units(self,units,scale, dim=3):
		unit_dsc	=	"atomic units"
		unit_str	=	r'$e^2$/ ($\hbar a_0$)'
		#
		au_to_S 		=	2.4341348e-4	#3.874046 * 1e-5			#	(e**2/h)	-> (S) Siemens
		au_to_cm		=	5.2917721e-9	# * 1e-9

		cond_quantum		=	2.434135 * 1e-4		#	1	[	e**2/hbar	]_atomic	=	2.434135×10^-4 	[	S	]_SI
		elem_e_over_hartree	=	0.03674932			#	1	[	e/E_h		]_atomic	=	0.03674932 		[	1/V	]_SI
		#
		omega_au_to_si		=	cond_quantum	*	elem_e_over_hartree	#[	e**2/hbar e/E_h	]_atomic	-> [ A/V**2] = [A/V**2] 
		#
		if dim==2:
			omega_au_to_si	=	omega_au_to_si * bohr_rad_si
		elif not dim==3:
			print("[plot_photoC_vs_broad/set_hall_units]: WARNING unsupported dimension =",dim)

		#
		#au_to_S_cm		=	au_to_S	/ au_to_cm
		#
		if units == "scale":
			unit_dsc	=	"use the scale given as function argument (sort of a wildcard)"
			unit_str	=	"-"
		elif units == "SI":
			scale			=	scale * omega_au_to_si
			if dim==3:
				unit_str		=	r'$[ A / m^2]_{\mathrm{3D}}$'
			elif dim==2:
				unit_str		=	r'$[ \mathrm{A} / \mathrm{m}]_{\mathrm{2D}}$'
			unit_dsc		=	"SI units"	
		#elif units == "wx":		 	
		#	scale			=	scale *au_to_S_cm	/ 100.
		#	unit_str		=	r'[$10^2$ S/cm]'
		#	unit_dsc		=	"Units used by wanxiang in his paper. this should be the SI value divided by 100"	
		#
		print('[set_hall_units]:  chooen unit system "'+units+'" with '+unit_str+'" and  descriptor: "'+unit_dsc+'" '	)
		#
		return scale, unit_str, unit_dsc 

			

	def plot_photoC(		self, title="", units='au', unit_scale=1.0, phi_laser=1.0,
							plot_ahc=True, plot_ahc_kubo= True, plot_ohc=True, 
							line_width=1, label_size=14, xtick_size=12, ytick_size=12,
							marker_size=12,
							upper_bound=1, lower_bound=0,
							plot_legend=False,laser=None, laser_dir=2, dim=3,
							interactive=False,
					):
		print("^")
		print("^")
		print("-------------------------------------------------------------------------------")	
		print("		PLOT HALL LIKE")
		print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		print("[plot_photoC]:	try to create folder where plots should go")
		#
		#
		if not os.path.isdir(self.plot_dir):
			try:
				os.mkdir(self.plot_dir)
			except OSError:
				print('[plot_photoC]:	Could not make directory ',self.plot_dir, '	(proably exists already)')
			finally:
				print("~")
		else:
			print('[plot_photoC]: '+self.plot_dir+"	exists already! (WARNING older plots might be overwriten)")
		#		
		#
		unit_scale, unit_str, unit_dsc	=	self.set_hall_units(units,unit_scale,dim=dim)
		#
		dim_str	= []
		dim_str.append('x')
		dim_str.append('y')
		dim_str.append('z')
		#
		#	color code for the AHC plot
		colors 	= discrete_cmap(len(self.ef_lst),	'cool')
		#
		#LOOP SPACIAL COMPONENTS OF TENSOR (make individual plot for each)
		fig, ax  = plt.subplots(1,1, sharex=True)
		plt.plot(self.smr_lst,np.zeros(len(self.smr_lst)),'-',color='grey')

		hw_idx			=	1
		if hw_idx >= len(self.hw_lst):
			hw_idx	=	len(self.hw_lst)-1
			print("[plot_photoC]: 	WARNING hw_idx out of bounds was set to #",hw_idx," with hw=",self.hw_lst[hw_idx]," eV")
		
		#	get polarization vector of laser
		print("^")
		print("^")
		print("--------------------")	
		print("		LASER WARMUP")
		print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		print("\tlaser propagation dirct: ",dim_str[laser_dir])
		

		laser_E0	=	laser.get_field_strength()
		laser_I 	=	laser.get_intensity()
		ef_idx = 33
		#
		field_cp		=	1j*np.zeros((2,2))
		field_cm		=	1j*np.zeros((2,2))
		field_lx		=	1j*np.zeros((2,2))
		field_ly		=	1j*np.zeros((2,2))
		#		
		plot_title			=	''
		##	circular
		lmbda				=	+1
		plot_title			=	'circ. lmbda='+str(lmbda)
		field_cp[0][0]	=	.5
		field_cp[0][1]	=	lmbda*1j / np.sqrt(2.)
		field_cp[1][0]	=	np.conj(field_cp[0][1])
		field_cp[1][1]	=	.5
		#
		field_cm		=	np.conj(field_cp)
		
		##	linear x
		#plot_title			=	'lin. x-pol '
		field_lx[0][0]	=	1
		field_lx[0][1]	=	0
		field_lx[1][0]	=	0
		field_lx[1][1]	=	0
		##	linear y
		#plot_title			=	'lin. y-pol'
		field_ly[0][0]	=	0
		field_ly[0][1]	=	0
		field_ly[1][0]	=	0
		field_ly[1][1]	=	1

		print('\t intensity I=',laser_I,r' $(',laser.I_units,')^2$')
		print('\t field squared E0**2=',laser_E0**2,r' $(',laser.E0_units,')^2$')
		#
		print("^")
		print("^")
		print("--------------------")
		print("NOW START PLOTTING RESPONSES...")
		print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		for x in range(0,2):
			print(" -> ",dim_str[x],"-response")
			if ef_idx>=len(self.ef_lst):
				ef_idx	=	len(self.ef_lst)-1
				print("[plot_photoC]:	WARNING ef_idx out of bounds, reset to #",ef_idx,"	with E_f=",self.ef_lst[ef_idx]," eV")
			#
			cp_plot	=	[]
			cm_plot	=	[]
			lx_plot	= 	[]
			ly_plot = 	[]
			scaler = 1
			for smr_idx, smr_val in enumerate(self.smr_lst):
				#
				cp_sum_ij	=	0
				cm_sum_ij	=	0
				lx_sum_ij	=	0
				ly_sum_ij	=	0
				for i in range(0,2):
					for j in range(0,2):
						scaler =1
						if x==1:
							scaler=10
						cp_sum_ij =	cp_sum_ij + laser_E0**2 *np.imag(unit_scale*scaler*field_cp[i][j] * self.scndPhoto_data[x][i][j][hw_idx][smr_idx][ef_idx] )
						cm_sum_ij = cm_sum_ij + laser_E0**2 *np.imag(unit_scale*scaler*field_cm[i][j] * self.scndPhoto_data[x][i][j][hw_idx][smr_idx][ef_idx] )
						scaler=1
						lx_scaler=1
						if x==0:
							scaler=1
							lx_scaler=10
						lx_sum_ij = lx_sum_ij + laser_E0**2 *np.imag(unit_scale*lx_scaler*field_lx[i][j] * self.scndPhoto_data[x][i][j][hw_idx][smr_idx][ef_idx] )
						ly_sum_ij = ly_sum_ij + laser_E0**2 *np.imag(unit_scale*scaler*field_ly[i][j] * self.scndPhoto_data[x][i][j][hw_idx][smr_idx][ef_idx] )

				cp_plot.append(cp_sum_ij)
				cm_plot.append(cm_sum_ij)
				lx_plot.append(lx_sum_ij)
				ly_plot.append(ly_sum_ij)

			#
			scaler =1
			cp_color = 'black'
			cm_color = 'red'
			cp_style = '-'
			cm_style = '--'
			if x==1:
				cp_style = 's-'
				cm_style = '^-'
				cp_color = 'darkorange'
				cm_color = 'palevioletred'
				scaler=10
			plt.plot(self.smr_lst,	cp_plot, cp_style,markersize=marker_size,color=cp_color, label=str(scaler)+r' $J^{'+dim_str[x]+r'},\; \sigma^{+}$ ')
			plt.plot(self.smr_lst,	cm_plot, cm_style,markersize=marker_size,color=cm_color, label=str(scaler)+r' $J^{'+dim_str[x]+r'},\; \sigma^{-}$ ')
			print("\t... plotted circular(+/-) pol J^",dim_str[x]," curve (#datapoints=",len(cp_plot),")")
			if x==0:	
				scaler=1
				lx_scaler=10
				plt.plot(self.smr_lst,	lx_plot, 'o-',markersize=marker_size,color='green', label=str(lx_scaler)+r' $J^{'+dim_str[x]+r'},\; \varepsilon \parallel \hat{\mathbf{e}}_x$ ')
				#plt.plot(self.smr_lst,	ly_plot, 'o-',markersize=marker_size,color='blue', label=str(scaler)+r' $J^{'+dim_str[x]+r'},\; \varepsilon \parallel \hat{\mathbf{e}}_y$ ')
				print("\t... plotted linear_x pol J^",dim_str[x]," curve (#datapoints=",len(lx_plot),")")
				print("\t... plotted linear_y pol J^",dim_str[x]," curve (#datapoints=",len(ly_plot),")")
			#else:
			#	plt.plot(self.smr_lst,	scnd_photo_plot, 'o-')
#
			#
		#print("field matrix: ",field_matrix)
		#
		smr_max	=	max(self.smr_lst)
		smr_min	=	min(self.smr_lst)
		#ax.set_xticks(np.arange(smr_min-1.0, smr_max+1.0, (smr_max-smr_min)/len(self.smr_lst)), minor=True)
		#try:	
		ax.set_xlim([smr_min, smr_max])
		#ax.set_ylim([lower_bound, upper_bound  ])
		#	#
		#	ax.yaxis.label.set_size(label_size)	
		#except:
		#	print("[plot_photoC]: labeling of plot failed")
		#
		plt.ylabel(r'$\mathrm{J_i}\;$'	+	unit_str,	fontsize=label_size)
		plt.xlabel(r'$ \Gamma $ (eV)',		fontsize=label_size)


		if(len(title)>0):
			#plt.title(title+r'$\;\varepsilon_F=$'+str(self.ef_lst[ef_idx])+' eV')
			plt.title(r'  @$\;\hbar\omega = $'+str(self.hw_lst[hw_idx])+' eV')

		#ax.set_ylim([mep_min,mep_max])
		#ax[0].tick_params(axis='y',which='major', direction='in',labelsize=ytick_size)
		#ax[0].tick_params(axis='x',which='both', direction='in',labelsize=xtick_size)
		#ax[1].tick_params(axis='x',which='both', direction='in',labelsize=xtick_size, top=True)
		#ax[1].tick_params(axis='y',which='major', direction='in',labelsize=ytick_size)
		#
		if True:#plot_legend:
			plt.legend(loc='upper right')
		#
		#plt.tight_layout()
		#
		outFile_path	= self.plot_dir+'/Jphoto_vs_broad.pdf'
		plt.savefig(outFile_path)
		print('[plot_photoC]:	plot saved to '+outFile_path)

		if interactive:
			plt.show()
		plt.close()
		#
		print("-------------------------------------------------------------------------------")
		print("")
		print("")	








	def plot_opt(self):
		print("^")
		print("^")
		print("-------------------------------------------------------------------------------")	
		print("		PLOT HALL LIKE")
		print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		print("[plot_opt]: 	WARNING this function is not implemented yet (ToDo!)	")
		#		MAYBE JUST ADD THIS TO HALL LIKE, THEN ITS EASIER TO COMPARE ALL DATA!!!!!!
		#

	
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#	end of class 	HW_probe
#
#**************************************************************************************************************************************
#**************************************************************************************************************************************
#--------------------------------------------------------------------------------------------------------------------------------------
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

def read_rashba_cfg(cfg_file='./rashba.cfg'):
	nMag 		= 	np.zeros(3)
	aR			=	0
	Vex			=	0
	descriptor	=	''
	#
	try:
		with open(cfg_file,'r') as cfg:
			for row,string in enumerate(cfg):
				if "=" in string:
					string	=	string.split("=")[1]
					string	=	string.split("#")[0]
					string	=	string.strip()
				#
				if row==1:
					aR 		= 	float(	string	)
				elif row==2:
					Vex = 		float(	string	)#float(	string.split("=")[1]	)
				elif row==3:
					string_arr 	= 	string.split(" ")
					for idx, string in enumerate(string_arr):
						if idx<3:
							nMag[idx]	=	float(string)
		#
		#	setup descriptive string
		descriptor	=	r' $\alpha_R=$'+'{:3.1f}'.format(aR)+r' $\mathrm{eV} \AA, \; V_{\mathrm{ex}}= $'+'{:3.1f}'.format(Vex)+r' $\mathrm{eV}$,'
		if(np.abs(Vex)>1e-3):
			if(	vec_is_parallel(nMag,ex)):
				descriptor	=	descriptor	+	r'$\;(\hat{\mathbf{n}}_{\mathrm{Mag}} \parallel 	\hat{\mathbf{e}}_x)$'
			if(	vec_is_parallel(nMag,ey)):
				descriptor	=	descriptor	+	r'$\;(\hat{\mathbf{n}}_{\mathrm{Mag}} \parallel 	\hat{\mathbf{e}}_y)$'
			if(	vec_is_parallel(nMag,ez)):
				descriptor	=	descriptor	+	r'$\;(\hat{\mathbf{n}}_{\mathrm{Mag}} \parallel 	\hat{\mathbf{e}}_z)$'
	except:
		print("[read_rashba_cfg]: ERROR failed to read rashba cfg file")
	#
	return aR, Vex, nMag, descriptor

def vec_is_parallel(a,b,tolerance=1e-10):
	norm_a	=	a / np.linalg.norm(a)
	norm_b	=	b / np.linalg.norm(b)
	#
	return	np.linalg.norm(norm_a-norm_b)	< tolerance




def plot_scnd_photo():
	#	use the above class in here to plot data in folder root_dir
	print('[plot_scnd_photo]:	hello there')
	dir_id	=	"theta"
	root_dir	=	'.'
	#
	frank_I		=	10. 						# G W / cm**2		=	1e9	W/cm**2	= 1e9 1e-4 W/m**2	=	1e5 W/m
	frank_I_SI	=	frank_I * 1e4				# G	W / m**2
	frank_I_SI	=	frank_I_SI * 1e9			#	W / m**2
	frank_LASER	=	laser(x=frank_I_SI,x_is_intensity=True)
	#
	if os.path.isdir(root_dir):	
		print("try to read rashba_cfg file:")
		aR, Vex, nMag, sys_info	=	read_rashba_cfg()
		#
		#
		#	read data 
		myTest	= plotter(root_dir,dir_id)
		#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
		#
		#	PLOT RESPONSES 
		#
		#	~~~~~~~~~~~~~~~~~~~~~~~~
		#
		myTest.plot_photoC(		title			=		sys_info	,
									units			=		'SI'		, 
									unit_scale			=		1.0			, 
									phi_laser		=		1.0			,	# = 1j
									plot_ahc		=		False		, 
									plot_ahc_kubo	= 		True		, 
									plot_ohc		=		False		, 
									line_width=1.5,label_size=14, xtick_size=12, ytick_size=12, marker_size=2.4,
									upper_bound		=	5		,
									lower_bound		=	-5		,
									plot_legend=True			,
									laser=frank_LASER			,
									laser_dir=2					,
									dim=2						,
									interactive=True			,
							)
		print("...")
		print('[plot_scnd_photo]:	plotted Hall like tensors')
		#	~~~~~~~~~~~~~~~~~~~~~~~~
		#
		#----------------------------------------------------------------------------------------------------------------------
	else:
		print('[plot_scnd_photo]:	ERROR '+str(root_dir)+'	seems to be non existing. please specify valid folder')








plot_scnd_photo()











