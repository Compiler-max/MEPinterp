module core
	!this module uses a semiclassic approach to calculate the first ordrer correction
	!	to the polariztion induced by a perturbive magnetic field
	! 	see Niu PRL 112, 166601 (2014)
	!use omp_lib
#ifdef __INTEL_COMPILER
	use ifport !needed for time 
#endif
#ifdef USE_MPI
	use mpi
#endif
	use omp_lib
	use m_npy
	use endian_swap
	use matrix_math,	only:	get_linspace
	use constants,		only:	dp, aUtoEv, i_dp
	use mpi_community,	only:	mpi_root_id, mpi_id, mpi_nProcs, ierr,			&
								mpi_ki_selector,								&
								mpi_bcast_tens,									&
								mpi_reduce_sum,									&
								mpi_allreduce_sum
	use statistics,		only:	fd_stat, fd_stat_deriv, fd_get_N_el
	use input_paras,	only:	use_mpi,										&
								use_kspace_ham,	kspace_ham_id,					&
								do_gauge_trafo,									&
								do_mep,											&
								do_write_velo,									&
								do_write_mep_bands,								&
								do_kubo,										&
								do_ahc,											&
								do_opt,											&
								do_photoC,										&
								do_bcd_photo,									&
								do_keldysh,										&
								do_gyro,										&
								debug_mode,										&
								wf_centers,										&
								k_cutoff,										&
								valence_bands, 									&
								seed_name,										&
								hw_min, hw_max, n_hw, 							&
								N_eF, eF_min, eF_max, T_kelvin, 				&
								N_smr ,eta_smr_min, eta_smr_max,  				&
								out_dir
	!
	use k_space,		only:	get_mp_grid, 									&
								kspace_allocator,								&
								get_rel_kpt,									&
								normalize_k_int
	!								
	use model_hams,		only:	model_ham_allocator
	use wann_interp,	only:	get_wann_interp
	!
	use mep_niu,		only:	mep_niu_CS,	mep_niu_IC, mep_niu_LC
	use kubo_mep,		only:	kubo_mep_CS, kubo_mep_LC, kubo_mep_IC
	use kubo,			only:	kubo_DC_ahc, kubo_AC_ahc,  &
								kubo_opt_tens, kubo_ohc_tens 
	use gyro,			only:	get_gyro_C, get_gyro_D, get_gyro_Dw
	use photo,			only:	photo_2nd_cond
	use bcd_photo,		only:	get_fd_k_deriv, 								&
								photoC_bcd_term,								&
								photoC_bcd_rect_term,							&
								photoC_jrk_term,								&
								photoC_inj_term,								&
								photoC_ib_term
	use keldysh,		only:	keldysh_scnd_photoC

	!
	use w90_interface, 	only:	read_tb_basis
	use file_io,		only:	write_velo
	!
	!
	implicit none
	!
	!
	private
	public ::			core_worker
	!
	save
	integer									::		num_kpts
	logical,		parameter				::		do_calc_velo=.True.
contains



!public
	subroutine	core_worker()
		!	interpolate the linear magnetoelectric response tensor alpha
		!
		!	lc	: local current contribution
		!	ic	: itinerant current contribution
		!	cs	: chern - simons term	
		!
		real(dp)							::	kpt(3)
												!local sum targets:
		real(dp),		allocatable			::	en_k(:), R_vect(:,:),					& 
												Ne_loc_sum(:), 							&
												ef_lst(:),smr_lst(:), hw_lst(:),		&
												fd_distrib(:,:), fd_deriv(:,:),			&
												fd_k_deriv(:,:,:),						&
												!
												mep_bands_ic_loc(	:,:,:),	 			&
												mep_bands_lc_loc(	:,:,:),				&
												mep_bands_cs_loc(	:,:,:),				&
												!
												kubo_dc_ahc_loc(	:,:,:),				&
												kubo_mep_ic_loc(	:,:,:),				&
												kubo_mep_lc_loc(	:,:,:),				&
												kubo_mep_cs_loc(	:,:,:)
												!
		complex(dp),	allocatable			::	H_tb(:,:,:), r_tb(:,:,:,:), 			&
												A_ka(:,:,:), Om_kab(:,:,:,:),			&
												V_ka(:,:,:),							&
												!
												tempS(:,:,:,:), tempA(:,:,:,:),			&
												!
												kubo_ac_ahc_loc(	:,:,:,:,:),			&
												kubo_ohc_loc(	  :,:,:,:),				&
												kubo_opt_s_loc(	  :,:,:,:),				&
												kubo_opt_a_loc(	  :,:,:,:),				&
												photo2_cond_loc(:,:,:,:,:,:),			&
												photoC_bcd_loc(:,:,:,:,:,:),			&
												photoC_BCD_rect_loc(:,:,:,:,:,:),		&
												photoC_jrk_loc(:,:,:,:,:,:),			&
												photoC_inj_loc(:,:,:,:,:,:),			&
												photoC_IB_loc(:,:,:,:,:,:),				&
												keldysh_photoC_loc(:,:,:,:,:,:),		&
												gyro_C_loc(			:,:,:),				&							
												gyro_D_loc(			:,:,:),				&
												gyro_Dw_loc(	  :,:,:,:)																								
																												
												!
		integer								::	kix, kiy, kiz, ki, 						&
												mp_grid(3), n_ki_loc,  n_ki_glob,		&
												eF_idx, wf_idx
		!----------------------------------------------------------------------------------------------------------------------------------
		!	allocate
		!----------------------------------------------------------------------------------------------------------------------------------
		call get_linspace( ef_min, 		ef_max, 		n_eF,				ef_lst	)
		call get_linspace( hw_min, 		hw_max, 		n_hw, 				hw_lst	)	
		call get_linspace( eta_smr_min, eta_smr_max, 	N_smr,		smr_lst	)
		!
		call allo_core_loc_arrays(		Ne_loc_sum,												&
										mep_bands_ic_loc, mep_bands_lc_loc, mep_bands_cs_loc,	&	
										kubo_mep_ic_loc, kubo_mep_lc_loc, kubo_mep_cs_loc,		&									
										kubo_dc_ahc_loc,  kubo_ac_ahc_loc,	kubo_ohc_loc,		&
										photo2_cond_loc, photoC_bcd_loc, photoC_bcd_rect_loc,	&
										photoC_jrk_loc, photoC_inj_loc, photoC_IB_loc,			&	
										keldysh_photoC_loc,										&
										tempS, tempA, kubo_opt_s_loc, kubo_opt_a_loc,			&
										gyro_C_loc, gyro_D_loc, gyro_Dw_loc						&
									)													
		

		!
		!----------------------------------------------------------------------------------------------------------------------------------
		!	get		TB	BASIS	
		!----------------------------------------------------------------------------------------------------------------------------------
		if(use_mpi) call MPI_BARRIER(MPI_COMM_WORLD, ierr)
		
		if(	use_kspace_ham	)	then
			if(mpi_id==mpi_root_id)	then
				write(*,*)	"*"
				write(*,*)	"----------------------USE K-SPACE MODEL HAMS (MHHHHMM HAMS!)---------"
			end if
			!
			call model_ham_allocator( kspace_ham_id, do_calc_velo	,	en_k, V_ka)
			!
		else
			if(mpi_id==mpi_root_id)	then
				write(*,*)	"*"
				write(*,*)	"----------------------GET REAL SPACE BASIS---------------------------"
			end if
			call read_tb_basis(			seed_name, R_vect,		H_tb, r_tb					)
			call kspace_allocator(		H_tb, r_tb, 			en_k, V_ka, A_ka, Om_kab	)
		end if
		!
					allocate(		fd_distrib(		n_eF,	size(en_k) 		))
		if(do_gyro) allocate(		fd_deriv(		n_ef,	size(en_k)		))
		if(do_bcd_photo)&
					allocate(		fd_k_deriv(	3,	n_eF,	size(en_k)		))
		!
		!----------------------------------------------------------------------------------------------------------------------------------
		!	get 	k-space
		!----------------------------------------------------------------------------------------------------------------------------------
		mp_grid				=	get_mp_grid()
		n_ki_loc			= 	0
		num_kpts			= 	mp_grid(1)*mp_grid(2)*mp_grid(3)
		call print_interp_mode()	
		!
		!----------------------------------------------------------------------------------------------------------------------------------
		!	loop	k-space
		!----------------------------------------------------------------------------------------------------------------------------------
		do kiz = 1, mp_grid(3)
			do kiy = 1, mp_grid(2)
				do kix = 1, mp_grid(1)
					ki	=		 kix 	+	mp_grid(1) * ( (kiy-1) + mp_grid(2) * (kiz-1))		
					!
					if( mpi_ki_selector(ki, num_kpts)	) then
						n_ki_loc = n_ki_loc + 1
						!----------------------------------------------------------------------------------------------------------------------------------
						!----------------------------------------------------------------------------------------------------------------------------------
						!----------------------------------------------------------------------------------------------------------------------------------
						!	INTERPOLATE	K-POINT
						!----------------------------------------------------------------------------------------------------------------------------------
						kpt	=	get_rel_kpt(ki,	kix,kiy,kiz)
						call get_wann_interp(		do_gauge_trafo,									& 
													H_tb, r_tb, R_vect, wf_centers,					&
													ki, kpt(:), 	en_k, V_ka, A_ka, Om_kab 		&
											)
						!
						!----------------------------------------------------------------------------------------------------------------------------------
						!	FERMI SETUP
						!----------------------------------------------------------------------------------------------------------------------------------
						Ne_loc_sum(	:	)	=	Ne_loc_sum(	: )	+	fd_get_N_el(	en_k, ef_lst(:),	T_kelvin)
						!
						!$OMP PARALLEL DO DEFAULT(shared) 
						do wf_idx = 1, size(en_k)
							fd_distrib(:,wf_idx)	=	fd_stat(	en_k(wf_idx),	ef_lst(:),	T_kelvin	)
						end do
						!$OMP END PARALLEL DO
						if(	do_gyro	) fd_deriv(:,:)	=	fd_stat_deriv(fd_distrib(:,:), T_kelvin)
						!
						!----------------------------------------------------------------------------------------------------------------------------------
						!	MEP
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_mep )	then	
							mep_bands_ic_loc		=	mep_bands_ic_loc 	+ 	mep_niu_IC(V_ka, en_k)		!	itinerant		(Kubo)
							mep_bands_lc_loc		=	mep_bands_lc_loc 	+ 	mep_niu_LC(V_ka, en_k)		!	local			(Kubo)
							mep_bands_cs_loc 		=	mep_bands_cs_loc 	+ 	mep_niu_CS(A_ka, Om_kab)	!	chern simons	(geometrical)
						end if
						!
						!----------------------------------------------------------------------------------------------------------------------------------
						!	KUBO MEP (MEP with fermi_dirac)
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_kubo	)	then
							kubo_mep_ic_loc			=	kubo_mep_ic_loc 	+	kubo_mep_IC(en_k, V_ka,fd_distrib)
							kubo_mep_lc_loc			=	kubo_mep_lc_loc		+	kubo_mep_LC(en_k, V_ka,fd_distrib)
							kubo_mep_cs_loc			=	kubo_mep_cs_loc		+	kubo_mep_CS(A_ka, Om_kab,fd_distrib)
						end if
						!
						!----------------------------------------------------------------------------------------------------------------------------------
						!	AHC
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_ahc )	then
							kubo_dc_ahc_loc			=	kubo_dc_ahc_loc		+ 	kubo_DC_ahc(en_k,	V_ka,   fd_distrib)
							kubo_ac_ahc_loc			= 	kubo_ac_ahc_loc		+	kubo_AC_ahc(en_k, V_ka, hw_lst, smr_lst, fd_distrib)
							!			---------------------------------
							!kubo_ohc_loc(:,:,:,:)	= 	kubo_ohc_loc(:,:,:,:)	&
							!	 							+	kubo_ohc_tens(en_k, V_ka, hw_lst(:), fd_distrib, i_dp*smr_lst(1))
						end if
						!~
						!----------------------------------------------------------------------------------------------------------------------------------
						!	OPTICAL CONDUCTIVITY (w90 version via Connection)
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_opt )	then
							call kubo_opt_tens(en_k, A_ka, hw_lst, fd_distrib, i_dp*smr_lst(1),  	tempS, tempA)
							!~
							kubo_opt_s_loc			=	kubo_opt_s_loc		+	tempS							
							kubo_opt_a_loc			=	kubo_opt_a_loc		+	tempA
							!			---------------------------------
						end if
						!~
						!----------------------------------------------------------------------------------------------------------------------------------
						!	NAGAOSA PHOTO_C 
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_photoC )	then
							photo2_cond_loc			=	photo2_cond_loc		+	photo_2nd_cond(en_k, V_ka, hw_lst, smr_lst,fd_distrib )
						end if
						!~
						!----------------------------------------------------------------------------------------------------------------------------------
						!	BCD PHOTOCOND 
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_bcd_photo ) then
							fd_k_deriv				=	get_fd_k_deriv(en_k, V_ka, ef_lst)
							!
							photoC_BCD_loc			=	photoC_BCD_loc	+	photoC_bcd_term(	hw_lst, smr_lst, ef_lst, fd_k_deriv,	en_k, V_ka)
							photoC_BCD_rect_loc		=	photoC_BCD_rect_loc+ photoC_bcd_rect_term(hw_lst,smr_lst, ef_lst, fd_k_deriv,	en_k, V_ka)
							!
							photoC_jrk_loc			=	photoC_jrk_loc	+	photoC_jrk_term(	hw_lst, smr_lst, ef_lst, fd_k_deriv, 	en_k, V_ka)	
							photoC_INJ_loc			=	photoC_INJ_loc	+	photoC_INJ_term(	hw_lst, smr_lst, 	fd_distrib, 		en_k, V_ka)
							photoC_IB_loc			=	photoC_IB_loc	+	photoC_IB_term(		hw_lst, smr_lst, ef_lst, fd_k_deriv, 	en_k, V_ka, Om_kab)	
						end if
						!~
						!----------------------------------------------------------------------------------------------------------------------------------
						!	KELDYSH 
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_keldysh ) then
							keldysh_photoC_loc		=	keldysh_photoC_loc	+ keldysh_scnd_photoC(en_k, V_ka, hw_lst, smr_lst, ef_lst)
						end if
						!~
						!----------------------------------------------------------------------------------------------------------------------------------
						!	GYROTROPIC TENSORS (CURRENTS)
						!----------------------------------------------------------------------------------------------------------------------------------
						if( do_gyro	)	then	
							gyro_C_loc(:,:,:)		=	gyro_C_loc(:,:,:)		+	get_gyro_C(			V_ka, 				fd_deriv)
							gyro_D_loc(:,:,:)		=	gyro_D_loc(:,:,:)		+ 	get_gyro_D(	en_k, V_ka, Om_kab, 		fd_deriv)
							gyro_Dw_loc(:,:,:,:)	=	gyro_Dw_loc(:,:,:,:)	+ 	get_gyro_Dw(en_k, V_ka, A_ka, hw_lst, 	fd_deriv)	
						end if
						!
						!----------------------------------------------------------------------------------------------------------------------------------
						!	WRITE VELOCITIES
						!----------------------------------------------------------------------------------------------------------------------------------
						if(	do_write_velo )		call write_velo(ki, V_ka)
						!----------------------------------------------------------------------------------------------------------------------------------
						!----------------------------------------------------------------------------------------------------------------------------------
						!----------------------------------------------------------------------------------------------------------------------------------
						!
						call print_progress(n_ki_loc, mp_grid)
					end if
					!
					!
				end do
			end do
		end do
		!
		!----------------------------------------------------------------------------------------------------------------------------------
		!	GET FERMI ENERGY 
		!----------------------------------------------------------------------------------------------------------------------------------
		call mpi_allreduce_sum(	n_ki_loc,	n_ki_glob	)
		eF_idx	=	fermi_selector(n_ki_glob,	Ne_loc_sum(:), eF_lst,	valence_bands	)
		call print_core_info(n_ki_loc, n_ki_glob, ef_lst, eF_idx	)
		!
		!
		!----------------------------------------------------------------------------------------------------------------------------------
		!	REDUCE MPI & WRITE FILES
		!----------------------------------------------------------------------------------------------------------------------------------
		call integrate_over_k_space(	n_ki_glob, 	eF_idx,												&
										mep_bands_ic_loc, mep_bands_lc_loc, mep_bands_cs_loc,			&	
										!
										kubo_mep_ic_loc, kubo_mep_lc_loc,	kubo_mep_cs_loc,			&									
										kubo_dc_ahc_loc, kubo_ac_ahc_loc,	kubo_ohc_loc,				&
										kubo_opt_s_loc, kubo_opt_a_loc,									&
										gyro_C_loc, gyro_D_loc,	gyro_Dw_loc,							&
										photo2_cond_loc,												&
										photoC_BCD_loc, photoC_BCD_rect_loc, 							&
										photoC_jrk_loc,	photoC_IB_loc, photoC_INJ_loc,					&
										keldysh_photoC_loc												&
									)
		!
		if(mpi_id == mpi_root_id) then 
			call save_npy(	out_dir//'hw_lst.npy',			hw_lst		)
			call save_npy(	out_dir//'smr_lst.npy',		smr_lst		)
			call save_npy(	out_dir//'ef_lst.npy',			eF_lst		)
		end if
		!----------------------------------------------------------------------------------------------------------------------------------
		!----------------------------------------------------------------------------------------------------------------------------------
		!----------------------------------------------------------------------------------------------------------------------------------	
		!
		!	~debug of index flattening
		if(n_ki_glob /= mp_grid(1)*mp_grid(2)*mp_grid(3))	&
			write(*,'(a,i7.7,a,i10,a,i10,a)')	&
			"[#",mpi_id,";core]:	CRITICAL ERROR n_ki_glob=",n_ki_glob,"	(!= expected: ", mp_grid(1)*mp_grid(2)*mp_grid(3),")."
		!
		return
	end subroutine






!private:
!
!
!
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
!	HELPERS
!----------------------------------------------------------------------------------------------------------------------------------	
	integer function fermi_selector(	n_ki_glob,	Ne_loc_sum, eF_lst, Ne_sys	) result(opt_idx)
		integer,							intent(in)			::	n_ki_glob
		real(dp),  							intent(in)			::	Ne_loc_sum(:)
		real(dp),							intent(in)			::	ef_lst(:)
		integer,							intent(in)			::	Ne_sys
		real(dp)												::	opt_error, opt_ef, new_error, ne_sys_re
		real(dp),		allocatable								::	Ne_glob_sum(:)
		real(dp),		allocatable								::	occ_lst(:,:)
		integer													::	eF_idx
		!
		!^^^^^^^^^^^^
		!	get sum over (mpi-parallel) k-pts
		call mpi_reduce_sum(	Ne_loc_sum,	Ne_glob_sum)
		Ne_glob_sum	=	Ne_glob_sum	/	n_ki_glob


		if(.not. allocated(Ne_glob_sum))	stop "fermi_selector Ne_glob_sum was not allocated"
		!
		!
		if(	mpi_id	==	mpi_root_id) 	then
			!
			allocate(	occ_lst(2,	size(ef_lst,1))	)
			!
			write(*,*)		"~"
			write(*,*)		"~"
			write(*,*)		"~"
			write(*,*)		"~"
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]:^^^^^^^	FERMI SELECTOR   ^^^^^^^^^^^^^^^^^^^^^^^"
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]:	select eF s.t. 	N_el(eF)= N_el "
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]:~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			!^^^^^^^^^^^^
			!	get initial minimum
			ne_sys_re	=	real(Ne_sys,dp)
			opt_idx		=	1
			opt_error	=	abs(	Ne_glob_sum(1)	-	ne_sys_re	)
			opt_ef		=	ef_lst(1) 
			!
			!
			!^^^^^^^^^^^^
			!	get optimal Fermi energy
			write(*,'(a,i7.7,a,i5,a)')	"[#",mpi_id,";fermi_selector]: the system is expected to have	N_el,sys :=	",Ne_sys," electron(s)"
			write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";fermi_selector]: now try to find ",&
											"a optimal Fermi energy value s.t. N_el( e_fermi) == N_el,sys .. "
			write(*,*)					"..."
			write(*,*)					"..."
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]:	#eF 	| eF (eV)	 |  N_el(#eF)	|	error abs( N_el(#eF) - N_el )	"
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]: -------------------------------------------------------------------------"
			write(*,'(a,i7.7,a,i5,a,a,a,i5,a,a)')	"[#",mpi_id,";fermi_selector]:	",	&
																	0,"	|	"," -  ","     |", valence_bands ," 		 |		","(electron(s) in system)"
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]:         -------------------------------------------------------------    "
			!
			!
			do eF_idx	=	1, size(	ef_lst,1	)
				!
				!	get new error
				new_error	=	abs(	Ne_glob_sum(eF_idx)	-	ne_sys_re	)
				!
				occ_lst(1,	eF_idx)		=	ef_lst(ef_idx) * aUtoEv
				occ_lst(2,	eF_idx)		=	Ne_glob_sum(eF_idx)
				!	output
				!write(occ_file,'(f16.8,a,f16.8)')	ef_lst(ef_idx) *	 aUtoEv,"	",	Ne_glob_sum(eF_idx)
				
				write(*,'(a,i7.7,a,i5,a,f12.6,a,f12.6,a,e16.8)',advance='no')	"[#",mpi_id,";fermi_selector]:	",	&
										eF_idx," |	   ",  ef_lst(ef_idx)*aUtoEv,"  | ",Ne_glob_sum(eF_idx),"	 |	",new_error
				!
				!	optimal?!
				if(		new_error		<	opt_error	) then
					opt_idx		=	eF_idx
					opt_error	=	new_error
					opt_ef		=	ef_lst(opt_idx)
					write(*,'(a)')	"		(new optimal fermi energy found!)"
				else
					write(*,*)	" "
				end if
				!
				!
			end do
			!
			!	WRITE TO NPY FILE
			call save_npy(	out_dir//'occ_lst.npy',		occ_lst	)
			write(*,'(a,i7.7,a)')	"[#",mpi_id,";write_occ_lst]: 	SUCCESS wrote occ_lst to "//out_dir//'occ_lst.npy'
			!
			!	PRINT FINAL MSG
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]: -----------------------------------------------------------------------"		
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]: -----------------------------------------------------------------------"		
			write(*,*)				"..."
			write(*,'(a,i7.7,a,f12.6,a,e16.8)')	"[#",mpi_id,";fermi_selector]: determined optimal fermi energy eF_optimal=",&
								opt_ef* aUtoEv," eV with abs( N_el(eF_optimal) - N_el )=",opt_error
			write(*,'(a,i7.7,a)')		"[#",mpi_id,";fermi_selector]:~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			write(*,*)	"\n"
		end if
		!
		!
		!^^^^^^^^^^^^
		!	broadcast optimal Fermi energy
		call mpi_bcast_tens(	opt_idx 	)
		!call MPI_BCAST(	opt_idx,	1,		MPI_INTEGER,	mpi_root_id,	MPI_COMM_WORLD,		ierr			)
		!if( ierr	/=	0	) stop "[fermi selector]: mpi bcast failed "
		!
		!
		return
	end function 



	subroutine 	integrate_over_k_space(		n_ki_loc, 	eF_idx,														&
										mep_bands_ic_loc, mep_bands_lc_loc, mep_bands_cs_loc,						&	
										kubo_mep_ic_loc, kubo_mep_lc_loc, kubo_mep_cs_loc,							&									
										kubo_dc_ahc_loc, kubo_ac_ahc_loc,	kubo_ohc_loc,							&
										kubo_opt_s_loc, kubo_opt_a_loc,												&
										gyro_C_loc, gyro_D_loc, gyro_Dw_loc,										&
										photo2_cond_loc,															&
										photoC_bcd_loc,photoC_BCD_rect_loc, 										&	
										photoC_jrk_loc, photoC_IB_loc, photoC_inj_loc,								&
										keldysh_photoC_loc															&													
									)
		!-----------------------------------------------------------------------------------------------------------
		!		K SPACE INTEGRATION 
		!		->sums over mpi_threads and normalizes accordingly
		!
		!
		!		local:		sum of k-points	 over local( within single mpi) thread
		!		global:		sum of k-points over whole mesh (mpi_reduce)
		!
		!			mep_tens_ic_loc, , mep_tens_lc_loc, mep_tens_cs_loc ar given as arrays over valence bands
		!-----------------------------------------------------------------------------------------------------------
		integer,						intent(in)		::	n_ki_loc , eF_idx	
		real(dp),						intent(in)		::	mep_bands_ic_loc(:,:,:), mep_bands_lc_loc(:,:,:), mep_bands_cs_loc(:,:,:),	&
															kubo_mep_ic_loc(:,:,:), kubo_mep_lc_loc(:,:,:), kubo_mep_cs_loc(:,:,:),		&				
															kubo_dc_ahc_loc(:,:,:)								
		complex(dp),					intent(in)		::	kubo_ac_ahc_loc(:,:,:,:,:),	kubo_ohc_loc(:,:,:,:),							&
															kubo_opt_s_loc(:,:,:,:), kubo_opt_a_loc(:,:,:,:),							&
															photo2_cond_loc(:,:,:,:,:,:),												&
															photoC_BCD_loc(:,:,:,:,:,:),photoC_bcd_rect_loc(:,:,:,:,:,:),				& 
															photoC_jrk_loc(:,:,:,:,:,:),												&
															photoC_IB_loc(:,:,:,:,:,:), 												&
															photoC_INJ_loc(:,:,:,:,:,:),												&
															keldysh_photoC_loc(:,:,:,:,:,:),											&
															gyro_C_loc(:,:,:), gyro_D_loc(:,:,:), gyro_Dw_loc(:,:,:,:)		
		!-----------------------------------------------------------------------------------------------------------
		integer											::	n_ki_glob
		real(dp), 				allocatable				::	mep_bands_loc(:,:,:),														&
															mep_bands_glob(:,:,:),														&
															!
															mep_sum_ic_loc(:,:), mep_sum_lc_loc(:,:), mep_sum_cs_loc(:,:),				&
															mep_sum_ic_glob(:,:), mep_sum_lc_glob(:,:), mep_sum_cs_glob(:,:),			&
															kubo_mep_ic_glob(:,:), kubo_mep_lc_glob(:,:), kubo_mep_cs_glob(:,:),		&
															kubo_dc_ahc_glob(:,:,:)												
															!
		complex(dp),			allocatable				::	kubo_ac_ahc_glob(:,:,:,:,:),												&
															kubo_ohc_glob(:,:,:,:),														&
															kubo_opt_s_glob(:,:,:), kubo_opt_a_glob(:,:,:),								&
															photo2_cond_glob(:,:,:,:,:,:),												&
															photoC_BCD_glob(:,:,:,:,:,:),												& 
															photoC_BCD_rect_glob(:,:,:,:,:,:),											& 
															photoC_JRK_glob(:,:,:,:,:,:),												& 
															photoC_IB_glob(:,:,:,:,:,:), 												&
															photoC_INJ_glob(:,:,:,:,:,:),												&
															keldysh_photoC_glob(:,:,:,:,:,:),											&
															gyro_C_glob(:,:,:), gyro_D_glob(:,:,:), gyro_Dw_glob(:,:,:,:)		
		!
		
		!
		!-----------------------------------------------------------------------------------------------------------
		!			COMMUNICATION (k-pts)
		!-----------------------------------------------------------------------------------------------------------
		!	***********				SUM OVER NODES				******************************************************
		call mpi_reduce_sum(	n_ki_loc,				n_ki_glob		)
		!
		!
		if( do_mep ) 											then
			!-----------------------------------------------------------------------------------------------------------
			!			sum over bands before communication	(else: expensive )
			!-----------------------------------------------------------------------------------------------------------		!
			call mep_sum_bands(		mep_bands_ic_loc, 	mep_bands_lc_loc, 	mep_bands_cs_Loc,	&
								mep_sum_ic_loc,		mep_sum_lc_loc,		mep_sum_cs_loc,		&
								mep_bands_loc												&
							)
			call mpi_reduce_sum(	mep_bands_loc	,	mep_bands_glob		)
			call mpi_reduce_sum(	mep_sum_ic_loc	,	mep_sum_ic_glob		)
			call mpi_reduce_sum(	mep_sum_lc_loc	,	mep_sum_lc_glob		)
			call mpi_reduce_sum(	mep_sum_cs_loc	,	mep_sum_cs_glob		)
			!
			call normalize_k_int(mep_sum_ic_glob)
			call normalize_k_int(mep_sum_lc_glob)
			call normalize_k_int(mep_sum_cs_glob)
			call normalize_k_int(mep_bands_glob)
			!
			if(mpi_id == mpi_root_id)	 write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]:  collected MEP tensors"
		end if
		!
		!
		if( do_kubo ) 											then
			call mpi_reduce_sum(	kubo_mep_ic_loc(:,:,eF_idx)	,	kubo_mep_ic_glob	)
			call mpi_reduce_sum(	kubo_mep_lc_loc(:,:,eF_idx)	,	kubo_mep_lc_glob	)
			call mpi_reduce_sum(	kubo_mep_cs_loc(:,:,eF_idx)	,	kubo_mep_cs_glob	)
			!
			call normalize_k_int(	kubo_mep_ic_glob	)
			call normalize_k_int(	kubo_mep_lc_glob	)
			call normalize_k_int(	kubo_mep_cs_glob	)
			!
			if(mpi_id == mpi_root_id) write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]:  collected KUBO MEP tensors"
		end if
		!
		!
		if( do_ahc )											then
			call mpi_reduce_sum(	kubo_dc_ahc_loc(:,:  ,:)	,	kubo_dc_ahc_glob		)
			call mpi_reduce_sum(	kubo_ac_ahc_loc(:,:,:,:,:)	,	kubo_ac_ahc_glob		)
			!call mpi_reduce_sum(	kubo_ohc_loc(:,:,:,:)	,	kubo_ohc_glob		)
			!
			call normalize_k_int(	kubo_dc_ahc_glob	)
			call normalize_k_int(	kubo_ac_ahc_glob	)
			!call normalize_k_int(kubo_ohc_glob)
			!
			if(mpi_id == mpi_root_id) write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]:  collected AHC tensors"
		end if
		!
		!
		if( do_opt )											then
			call mpi_reduce_sum(	kubo_opt_s_loc(:,:,:,eF_idx)	,	kubo_opt_s_glob		)
			call mpi_reduce_sum(	kubo_opt_a_loc(:,:,:,eF_idx)	,	kubo_opt_a_glob		)
			!
			call normalize_k_int(	kubo_opt_s_glob		)
			call normalize_k_int(	kubo_opt_a_glob		)
			!
			if(mpi_id == mpi_root_id) write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]:  collected OPT tensors"
		end if 
		!
		if(	do_photoC)											then
			call mpi_reduce_sum(	photo2_cond_loc(:,:,:,:,:,:) 		,	photo2_cond_glob	)
			call normalize_k_int(photo2_cond_glob)
			if(mpi_id == mpi_root_id) write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]:  collected photoC tensors"
		end if
		!
		if(	do_bcd_photo)										then
			if(mpi_id == mpi_root_id) write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]: WARNING BCD terms not implemented yet"
			!
			call mpi_reduce_sum(	photoC_BCD_loc,			photoC_BCD_glob )		
			call mpi_reduce_sum(	photoC_BCD_rect_loc,	photoC_BCD_rect_glob)
			call mpi_reduce_sum(	photoC_jrk_loc,			photoC_jrk_glob )
			call mpi_reduce_sum(	photoC_INJ_loc,			photoC_INJ_glob )
			call mpi_reduce_sum(	photoC_IB_loc,			photoC_IB_glob 	)
			!
			call normalize_k_int(	photoC_BCD_glob			)
			call normalize_k_int(	photoC_BCD_rect_glob	)
			call normalize_k_int(	photoC_jrk_glob			)
			call normalize_k_int(	photoC_INJ_glob			)
			call normalize_k_int(	photoC_IB_glob			)
		end if
		!
		if(	do_keldysh)											then
			call mpi_reduce_sum(	keldysh_photoC_loc,		keldysh_photoC_glob)
			call normalize_k_int(	keldysh_photoC_glob		)
		end if
		!
		if( do_gyro )											then
			call mpi_reduce_sum(	gyro_C_loc(:,:,:)			,	gyro_C_glob			)
			call mpi_reduce_sum(	gyro_D_loc(:,:,:)			,	gyro_D_glob			)
			call mpi_reduce_sum(	gyro_Dw_loc(:,:,:,:)		,	gyro_Dw_glob		)
			!
			call normalize_k_int(	gyro_C_glob		)
			call normalize_k_int(	gyro_D_glob		)
			call normalize_k_int(	gyro_Dw_glob	)
			if(mpi_id == mpi_root_id) write(*,'(a,i7.7,a)') "[#",mpi_id,"; core_worker]:  collected GYRO tensors"
		end if
		!
		if(mpi_id == mpi_root_id)	then
			write(*,*)				""
			write(*,*)				""
			write(*,*)				"..."					
			write(*,'(a,i7.7,a,a,a,i8,a)') "[#",mpi_id,"; core_worker",cTIME(time()),"]: collected tensors from",mpi_nProcs," mpi-threads"
		end if
	
		!
		!-----------------------------------------------------------------------------------------------------------
		!			OUTPUT
		!-----------------------------------------------------------------------------------------------------------
		if(mpi_id == mpi_root_id) then
			write(*,*)	"*"
			write(*,*)	"------------------TENSOR OUTPUT----------------------------------------------"
			!
			!	MEP TENSORS
			if(allocated(mep_bands_glob))	call save_npy(	out_dir//"mep_bands.npy"	,		mep_bands_glob		)
			if(allocated(mep_sum_ic_glob)) 	call save_npy(	out_dir//'mep_ic.npy'		, 		mep_sum_ic_glob		)
			if(allocated(mep_sum_lc_glob)) 	call save_npy(	out_dir//'mep_lc.npy'		, 		mep_sum_lc_glob		)
			if(allocated(mep_sum_cs_glob)) 	call save_npy(	out_dir//'mep_cs.npy'		, 		mep_sum_cs_glob		)
			if(allocated(kubo_mep_ic_glob)) call save_npy(	out_dir//'kubo_mep_ic.npy'	,		kubo_mep_ic_glob	)
			if(allocated(kubo_mep_lc_glob)) call save_npy(	out_dir//'kubo_mep_lc.npy'	,		kubo_mep_lc_glob	)
			if(allocated(kubo_mep_cs_glob)) call save_npy(	out_dir//'kubo_mep_cs.npy'	,		kubo_mep_cs_glob	)
			!
			!	AHC TENSORS			
			if(allocated(kubo_dc_ahc_glob)) 	call save_npy(	out_dir//'ahc_DC_tens.npy'	,		kubo_dc_ahc_glob		)
			if(allocated(kubo_ac_ahc_glob))	call save_npy(	out_dir//'ahc_AC_tens.npy'	,		kubo_ac_ahc_glob		)
			!if(allocated(kubo_ohc_glob))	call save_npy(	out_dir//'ohcVELO.npy'		,		kubo_ohc_glob		)
			!
			!	OPTICAL TENSORS			
			if(allocated(kubo_opt_s_glob)) 	call save_npy(	out_dir//"opt_Ssymm.npy"	, 		kubo_opt_s_glob		)
			if(allocated(kubo_opt_a_glob))	call save_npy(	out_dir//"opt_Asymm.npy"	, 		kubo_opt_a_glob		)
			if(allocated(photo2_cond_glob))	call save_npy(	out_dir//'photoC_2nd.npy'	, 		photo2_cond_glob	)
			if(allocated(photoC_BCD_glob))	call save_npy(	out_dir//'photoC2_bcd.npy'	,		photoC_BCD_glob		)
			if(allocated(photoC_BCD_rect_glob))&
											call save_npy(	out_dir//'photoC2_bcd_rect.npy',	photoC_BCD_rect_glob)
			if(allocated(photoC_JRK_glob))	call save_npy(	out_dir//'photoC2_jrk.npy'	,		photoC_JRK_glob		)						
			if(allocated(photoC_INJ_glob))	call save_npy(	out_dir//'photoC2_inj.npy'	,		photoC_INJ_glob		)
			if(allocated(photoC_IB_glob))	call save_npy(	out_dir//'photoC2_ib.npy'	,		photoC_IB_glob		)
			if(			allocated(photoC_BCD_glob)	.and.	allocated(photoC_JRK_glob)	&
				.and.	allocated(photoC_IB_glob)	.and.	allocated(photoC_INJ_glob)) &
				call save_npy(	out_dir//'photoC2_sum.npy'	,				photoC_BCD_glob	+ 	photoC_JRK_glob		&
															 			 +	photoC_IB_glob	+	photoC_INJ_glob		)
			!
			!	KELDYSH TENSORS
			if(allocated(keldysh_photoC_glob))	call save_npy(out_dir//'keldysh_photoC2.npy',	keldysh_photoC_glob	)
			!
			!	GYRO TENSORS			
			if(allocated(gyro_C_glob)) 		call save_npy(	out_dir//"gyro_C.npy"		, 		gyro_C_glob			)
			if(allocated(gyro_D_glob)) 		call save_npy(	out_dir//"gyro_D.npy"		, 		gyro_D_glob			)
			if(allocated(gyro_Dw_glob))		call save_npy(	out_dir//"gyro_Dw.npy"		, 		gyro_Dw_glob		)
			!~~
			!~~
			!^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
			!	PRINT MSGs
			!---
			!
			!	MEP
			if(	allocated(mep_bands_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote mep_band to ",			out_dir//"mep_bands.npy"
			if(allocated(mep_sum_ic_glob)) 	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote mep (ic) to ",			out_dir//'mep_ic.npy'
			if(allocated(mep_sum_lc_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote mep (lc) to ",			out_dir//'mep_lc.npy'
			if(allocated(mep_sum_cs_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote mep (cs) to ",			out_dir//'mep_cs.npy'
			if(allocated(kubo_mep_ic_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote kubo_mep to ",			out_dir//'kubo_mep_ic.npy'
			if(allocated(kubo_mep_lc_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote kubo_mep to ",			out_dir//'kubo_mep_lc.npy'
			if(allocated(kubo_mep_cs_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote kubo_mep to ",			out_dir//'kubo_mep_cs.npy'
			!
			!	AHC
			if(allocated(kubo_dc_ahc_glob)) 	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote AHC tensor to ",			out_dir//'ahc_DC_tens.npy'
			if(allocated(kubo_ac_ahc_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote AHC(hw) tensor to ",		out_dir//'ahc_AC_tens.npy'
			!if(allocated(kubo_ohc_glob))	&
			!	write(*,'(a,i7.7,a,a)')		"[#",mpi_id,"; core_worker]: wrote OHC(hw) tensor to ",		out_dir//'ohcVELO.npy'
			!
			!	OPT
			if(allocated(kubo_opt_s_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]:	wrote symm opt tens to ",		out_dir//"opt_Ssymm.npy"
			if(allocated(kubo_opt_a_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]:	wrote symm opt tens to ",		out_dir//"opt_Asymm.npy"
			if(allocated(photo2_cond_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd opt tens to ",		out_dir//'photoC_2nd.npy'
			if(allocated(photoC_BCD_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (met, BCD  term) to ",	&
																										out_dir//"photo_C2_bcd.npy"
			if(allocated(photoC_BCD_rect_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (met, BCD  term rect limit) to ",	&
																										out_dir//"photo_C2_bcd_rect.npy"																							
			if(allocated(photoC_JRK_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (met, jerk term) to ",	&
																										out_dir//"photo_C2_jrk.npy"						
			if(allocated(photoC_INJ_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (ins, INJ  term) to ",	&
																										out_dir//"photo_C2_inj.npy"
			if(allocated(photoC_IB_glob))	&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (ins, IB   term) to ",	&
																										out_dir//"photo_C2_ib.npy"
			if(			allocated(photoC_BCD_glob)	.and.	allocated(photoC_JRK_glob)	&
				.and.	allocated(photoC_IB_glob)	.and.	allocated(photoC_INJ_glob)) &
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (sum=BCD+JRK+INJ+IB   term) to ",	&
																								out_dir//"photo_C2_sum.npy"
			!
			!	KELDYSH
			if(allocated(keldysh_photoC_glob))&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote 2nd photoC tens (KELDYSH) to ",	&
																									out_dir//"keldysh_photoC2.npy"
			!
			!	GYRO
			if(allocated(gyro_C_glob))		&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote GYRO-C tensors to ",		out_dir//"gyro_C.npy"
			if(allocated(gyro_D_glob))		&
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote GYRO-D tensors to ",		out_dir//"gyro_D.npy"
			if(allocated(gyro_Dw_glob))		&	
				write(*,'(a,i7.7,a,a)')		"[#",mpi_id,";core_worker]: wrote GYR-DW tensors to ",		out_dir//"gyro_Dw.npy"
			!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			write(*,*)	"*"
			write(*,*)	"----------------------------------------------------------------"
		end if	
		!
		!
		return
	end subroutine




	subroutine mep_sum_bands(		mep_bands_ic_loc, 	mep_bands_lc_loc, 	mep_bands_cs_Loc,	&
									mep_sum_ic_loc,		mep_sum_lc_loc,		mep_sum_cs_loc,		&
									mep_bands_loc						&
								)
		real(dp),							intent(in)			::	mep_bands_ic_loc(:,:,:), mep_bands_lc_loc(:,:,:), mep_bands_cs_loc(:,:,:)
		real(dp),		allocatable, 		intent(inout)		::	mep_sum_ic_loc(:,:), 	mep_sum_lc_loc(:,:), 	mep_sum_cs_loc(:,:),			& 
																	mep_bands_loc(:,:,:)
		integer													::	n0
		!
		allocate( 	mep_sum_ic_Loc(		3,	3	))		
		allocate(	mep_sum_lc_Loc(		3,	3	))
		allocate(	mep_sum_cs_Loc(		3,	3	))
		mep_sum_ic_loc		=	0.0_dp
		mep_sum_lc_loc		=	0.0_dp
		mep_sum_cs_loc		=	0.0_dp
		!
		if(do_write_mep_bands)		then			
			allocate(	mep_bands_loc(		3,	3,	valence_bands	))
			mep_bands_loc	=	0.0_dp
		end if
		!
		do n0 = 1, valence_bands
			mep_sum_ic_loc(:,:)	=	mep_sum_ic_loc(:,:)	+	mep_bands_ic_loc(:,:,n0)
			mep_sum_lc_loc(:,:)	=	mep_sum_lc_loc(:,:)	+	mep_bands_lc_loc(:,:,n0)
			mep_sum_cs_loc(:,:)	=	mep_sum_cs_loc(:,:)	+	mep_bands_cs_loc(:,:,n0)
			!
			if(do_write_mep_bands) then
				mep_bands_loc(:,:,n0)	=	mep_bands_ic_loc(:,:,n0) + mep_bands_lc_loc(:,:,n0)	+ mep_bands_cs_loc(:,:,n0)
			end if			
		end do
		!
		!
		return 
	end subroutine
!
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
!	ALLOCATORS
	!----------------------------------------------------------------------------------------------------------------------------------
	subroutine allo_core_loc_arrays(	Ne_loc_sum,																		&
										mep_tens_ic_loc, mep_tens_lc_loc, mep_tens_cs_loc,								&	
										kubo_mep_ic_loc, kubo_mep_lc_loc, kubo_mep_cs_loc,								&									
										kubo_dc_ahc_loc, kubo_ac_ahc_loc, kubo_ohc_loc,									&
										photo2_cond_loc, photoC_BCD_loc,	photoC_BCD_rect_loc,						& 
										photoC_jrk_loc, photoC_IB_loc, photoC_INJ_loc,									&
										keldysh_photoC_loc,																&
										tempS, tempA, kubo_opt_s_loc, kubo_opt_a_loc,									&
										gyro_C_loc, gyro_D_loc, gyro_Dw_loc												&
									)
		real(dp),		allocatable,	intent(inout)	::	Ne_loc_sum(:),																&
															mep_tens_ic_loc(:,:,:), mep_tens_lc_loc(:,:,:), mep_tens_cs_loc(:,:,:),		&
															kubo_mep_ic_loc(:,:,:), kubo_mep_lc_loc(:,:,:), kubo_mep_cs_loc(:,:,:),		&				
															kubo_dc_ahc_loc(:,:,:)
		!				
		complex(dp),	allocatable,	intent(inout)	::	kubo_ac_ahc_loc(:,:,:,:,:), kubo_ohc_loc(:,:,:,:),							&
															tempS(:,:,:,:), tempA(:,:,:,:), 											&
															kubo_opt_s_loc(:,:,:,:), kubo_opt_a_loc(:,:,:,:),							&
															photo2_cond_loc(:,:,:,:,:,:),												&
															photoC_BCD_loc(:,:,:,:,:,:),	photoC_BCD_rect_loc(:,:,:,:,:,:),			& 
															photoC_jrk_loc(:,:,:,:,:,:),												& 
															photoC_IB_loc(:,:,:,:,:,:), 												&
															photoC_INJ_loc(:,:,:,:,:,:),												&
															keldysh_photoC_loc(:,:,:,:,:,:),											&
															gyro_C_loc(:,:,:), gyro_D_loc(:,:,:), gyro_Dw_loc(:,:,:,:)		
		!----------------------------------------------------------------------------------------------------------------------------------
		!	ALLOCATE & INIT
		!----------------------------------------------------------------------------------------------------------------------------------	
		!
		allocate(	Ne_loc_sum(	N_eF	)		)
		Ne_loc_sum	=	0.0_dp
		!
		!
		if( do_mep	)	then
			allocate(	mep_tens_ic_loc(			3,3,	valence_bands	)	)
			allocate(	mep_tens_lc_loc(			3,3,	valence_bands	)	)
			allocate(	mep_tens_cs_loc(			3,3,	valence_bands	)	)
			!~
			mep_tens_ic_loc		=	0.0_dp
			mep_tens_lc_loc		=	0.0_dp
			mep_tens_cs_loc		=	0.0_dp
		end if
		!
		!
		if(	do_kubo	)	then	
			allocate(	kubo_mep_ic_loc(			3,3,							n_eF		)	)	
			allocate(	kubo_mep_lc_loc(			3,3,							n_eF		)	)	
			allocate(	kubo_mep_cs_loc(			3,3,							n_eF		)	)
			!~
			kubo_mep_ic_loc		=	0.0_dp
			kubo_mep_lc_loc		=	0.0_dp
			kubo_mep_cs_loc		=	0.0_dp
		end if
		!
		if(	do_ahc	)	then		
			allocate(	kubo_dc_ahc_loc(			3,3,							n_eF		)	)	
			allocate(	kubo_ac_ahc_loc(			3,3,	n_hw	, N_smr,	n_eF		)	)
			!allocate(	kubo_ohc_loc(				3,3,	n_hw	,				n_eF		)	)
			!~
			kubo_dc_ahc_loc		=	0.0_dp
			kubo_ac_ahc_loc		=	0.0_dp	
			!kubo_ohc_loc		=	0.0_dp
		end if
		
		!
		if(	do_opt	)	then
			allocate(	tempS(						3,3,	n_hw	,	n_eF					)	)
			allocate(	tempA(						3,3,	n_hw	,	n_eF					)	)				
			allocate(	kubo_opt_s_loc(				3,3,	n_hw	,	n_eF					)	)
			allocate(	kubo_opt_a_loc(				3,3,	n_hw	,	n_eF					)	)
			!~
			kubo_opt_a_loc		=	0.0_dp
			kubo_opt_s_loc		=	0.0_dp
		end if
		!
		if(	 do_photoC ) then
			allocate(	photo2_cond_loc(			3,3,3,	n_hw	,	N_smr,	n_eF 			)	)
			photo2_cond_loc		=	0.0_dp
		end if
		!
		if( do_bcd_photo ) then
			allocate(	photoC_BCD_loc(				3,3,3,	n_hw,	N_smr,	n_eF 				)	)
			allocate(	photoC_BCD_rect_loc(		3,3,3,	n_hw,	N_smr,	n_eF				)	)
			allocate(	photoC_jrk_loc(				3,3,3,	n_hw, 	N_smr,	n_eF				)	)
			allocate(	photoC_INJ_loc(				3,3,3,	n_hw,	N_smr,	n_eF 				)	)
			allocate(	photoC_IB_loc(				3,3,3,	n_hw,	N_smr,	n_eF 				)	)
			!~
			photoC_BCD_loc		=	cmplx(0.0_dp,0.0_dp,dp)
			photoC_BCD_rect_loc	=	cmplx(0.0_dp,0.0_dp,dp)
			photoC_INJ_loc		=	cmplx(0.0_dp,0.0_dp,dp)
			photoC_IB_loc		=	cmplx(0.0_dp,0.0_dp,dp)			
		end if
		!
		if( do_keldysh ) then
			allocate(	keldysh_photoC_loc(			3,3,3,	n_hw,	n_smr,	n_eF				)	)
			!~
			keldysh_photoC_loc	=	cmplx(0.0_dp,0.0_dp,dp)
		end if
		!
		if(	do_gyro	)	then
			allocate(	gyro_C_loc(					3,3,				n_eF					)	)
			allocate(	gyro_D_loc(					3,3,				n_eF					)	)
			allocate(	gyro_Dw_loc(				3,3,	n_hw	,	n_eF					)	)																								
			!
			gyro_C_loc			=	cmplx(	0.0_dp	,	0.0_dp,		dp	)			
			gyro_D_loc			=	cmplx(	0.0_dp	,	0.0_dp,		dp	)		
			gyro_Dw_loc			=	cmplx(	0.0_dp	,	0.0_dp,		dp	)		
		end if	
		!
		!
		return
	end subroutine



!
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------------------------------------
!	PRINTERS
	!----------------------------------------------------------------------------------------------------------------------------------
	subroutine print_interp_mode()
		integer				::	omp_nThreads, omp_id
		if(use_mpi)	call MPI_BARRIER(MPI_COMM_WORLD, ierr)
		if(mpi_id == mpi_root_id) then
			write(*,*)	"*"
			write(*,*)	"----------------------------------------------------------------"
			write(*,*)	"----------------------------------------------------------------"
			write(*,*)	"----------------------------------------------------------------"
			write(*,*)	"*"
			write(*,*)	"*"
			if(do_gauge_trafo)	then
					write(*,*)	"***^^^^	-	FULL INTERPOLATION MODE (KSPACE MODE)	-	^^^^***"
			else
					write(*,*)	"***^^^^	-	WANNIER GAUGE MODE  (KSPACE MODE) -	^^^^***"
			end if
			write(*,*)	"*"
			write(*,*)	"*"
			write(*,*)	"----------------------------------------------------------------"
			write(*,*)	"----------------------------------------------------------------"
			write(*,*)	"----------------------------------------------------------------"
			write(*,*)	"***^^^^	-	BZ INTEGRATION LOOP	-	^^^^***"
		end if
		if(use_mpi)	call MPI_BARRIER(MPI_COMM_WORLD, ierr)


		!$OMP PARALLEL	
			omp_nThreads	=	omp_get_num_threads()
			omp_id			=	omp_get_thread_num()
			if(omp_id	==	0	) then
				write(*,'(a,i7.7,a,a,a,i3,a)')		"[#",mpi_id,"; core_worker/",cTIME(time()),		&
													"]:  I start interpolating now (#OMP THREADS=",omp_nThreads,")...."
			end if
		!$OMP END PARALLEL

		
		!
		!
		return
	end subroutine
	!
	!
	subroutine print_progress(n_ki_cnt, mp_grid)
		integer,		intent(in)		::	n_ki_cnt, mp_grid(3)
		integer							::	i
		real(dp)						::	n_ki_tot, delta
		character(len=16)				::	final_msg=	'  **finished**'
		!
		n_ki_tot	=	real(mp_grid(1)*mp_grid(2)*mp_grid(3),dp)	/	real(mpi_nProcs,dp)
		!
		!	PRINT AFTER K LOOP
		if(	n_ki_cnt == 500 ) then
			write(*,'(a,i7.7,a,a,a,i8,a,f6.1,a)')		"[#",mpi_id,";core_worker/",&
					cTIME(time()),"]: done with #",n_ki_cnt," kpts (progress:~",100.0_dp*real(n_ki_cnt,dp)/n_ki_tot,"%)."
		else
			do i = 1, 10
				delta		=	(real(n_ki_tot,dp)	*0.1_dp* real(i,dp)	 )	- real(n_ki_cnt,dp)
				!
				if (abs(delta)	< 0.49_dp	)	then
					write(*,'(a,i7.7,a,a,a,i8,a,f6.1,a)',advance="no")		"[#",mpi_id,";core_worker/",&
											cTIME(time()),"]: done with #",n_ki_cnt," kpts (progress:~",10.0_dp*real(i,dp),"%)."
					!
					if( i==10 )		write(*,'(a)',advance="no")	final_msg
					write(*,*)	""
					exit
				end if
			end do
		end if
		!
		!
		return
	end subroutine
	!
	!
	subroutine print_core_info(n_ki_loc, n_ki_glob, eF_lst, eF_final_idx)
		integer,		intent(in)		::	n_ki_loc, n_ki_glob
		real(dp),		intent(in)		::	eF_lst(:)
		integer,		intent(in)		::	eF_final_idx
		character(len=60)				::	gauge_label
		!
		if(do_gauge_trafo)	then
			write(gauge_label,*)		'in the (H) Hamiltonian gauge'
		else
			write(gauge_label,*)		'in the (W) Wannier gauge (no gauge trafo performed!)'
		end if
		write(*,'(a,i7.7,a,a,a,i8,a,i8,a)')					"[#",mpi_id,"; core_worker/",cTIME(time()),		&
													"]: ...finished interpolating (",n_ki_loc,"/",n_ki_glob,") kpts "//gauge_label
		!
		if(use_mpi)		call MPI_BARRIER(MPI_COMM_WORLD, ierr)
		write(*,'(a,i7.7,a,a,a,f8.4,a)')	"[#",mpi_id,";core_worker/",cTIME(time()),"]: choosen fermi energy	", &	
										eF_lst(eF_final_idx) * aUtoEv," eV. Now start reduction of response tensors..." 
		!
		!
		return
	end subroutine




	!
	!
end module core









