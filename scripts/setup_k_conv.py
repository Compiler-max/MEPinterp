import numpy as np
import datetime
import os

from mep_worker import MEP_worker




#************************************************************************************************************************************************************************

class conv_run:

	def __init__(self, root_dir):
		self.work_dirs	= []
		self.jobs		= []
		self.root_dir	= root_dir
		#
		#create root directory
		if os.path.isdir(self.root_dir):
			old_path 	= self.root_dir
			cnt 		= 0
		
			while os.path.isdir(old_path) and cnt < 5:
				old_path	= old_path + '.old'
				cnt			= cnt + 1
				try:
					os.rename(self.root_dir, old_path)
				except OSError:
					print(old_path+ ' exists already')
		os.mkdir(self.root_dir)


	def add_jobs(self, phi, val_bands, mp_dens_per_dim, kubo_tol, hw, eFermi, Tkelvin, eta_smearing, do_gauge_trafo='T'):
		for n_mp in mp_dens_per_dim:
			nK 		=	n_mp**3
			mp_grid	=	[n_mp, n_mp, n_mp]

			work_dir= self.root_dir+'/nK'+str(nK)
			self.work_dirs.append(work_dir)

			job = MEP_worker(self.root_dir, work_dir, phi, val_bands, mp_grid, kubo_tol, hw, eFermi, Tkelvin, eta_smearing, do_gauge_trafo	)
			self.jobs.append( 	job	)


	def run_jobs(self, mpi_np=1):
		for job in self.jobs:
			job.run(mpi_np)



#************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************






root_dir		=	os.getcwd()+'/k_conv_cluster'
kubo_tol		=	1e-5
hw				= 	0.3
eFermi			=	-3.0	
Tkelvin			=	300.0	
eta_smearing	=	0.3

do_gauge_trafo	=	'T'

val_bands		=	2
mp_dens			=	[1, 2, 4, 6, 8, 12, 16]#, 32, 48, 64, 80, 128,256,512]
phi_lst			=	[0.0] 	#,1.0,2.0]

n_mpi_procs		=	4

for phi in phi_lst:
	cluster_calc 	= 	conv_run(root_dir+'_phi'+str(phi))
	#
	cluster_calc.add_jobs(phi,	val_bands,	mp_dens, kubo_tol, hw, eFermi, Tkelvin, eta_smearing, do_gauge_trafo)
	cluster_calc.run_jobs(mpi_np=n_mpi_procs)



