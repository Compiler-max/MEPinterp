module input_paras
	use m_config
	use mpi
	use matrix_math,				only:		crossP
	use constants,					only:		dp, fp_acc, pi_dp,			&
												mpi_id, mpi_root_id, mpi_nProcs, ierr
	use k_space,					only:		set_recip_latt, set_mp_grid




	implicit none

	private
	public								::		&
												!routines		
												init_parameters, 	my_mkdir,						 		 		&
												!dirs
												w90_dir, out_dir, raw_dir,											&
												!jobs
												plot_bands,															&
												!vars
												seed_name,	valence_bands,											&
												a_latt, kubo_tol



	
	save

	
	integer						::	valence_bands
	character(len=3)			:: 	seed_name
	character(len=4)			::	out_dir ="out/"					
	character(len=9)			::	w90_dir	="w90files/"
	character(len=4)			::	raw_dir ="raw/"
	logical						::	plot_bands
	real(dp)					::	a_latt(3,3), a0
	real(dp),		parameter	::	kubo_tol		= 1e-3_dp




	contains




!public
	logical function init_parameters()
		type(CFG_t) 			:: 	my_cfg
		real(dp)				::	a1(3), a2(3), a3(3)
		integer					::	mp_grid(3)
		logical					::	input_exist
		!
		!ROOT READ
		if(mpi_id == mpi_root_id) then
			inquire(file="./input.txt",exist=input_exist)
			!
			if( input_exist)	then		
				!OPEN FILE
				call CFG_read_file(my_cfg,"./input.txt")
				!
				![methods]
				call CFG_add_get(my_cfg,	"jobs%plot_bands"				,	plot_bands			,	"if true do a bandstructure run"	)
				!READ SCALARS
				![unitCell]
				call CFG_add_get(my_cfg,	"unitCell%a1"      				,	a1(1:3)  	  	,	"a_x lattice vector"				)
				call CFG_add_get(my_cfg,	"unitCell%a2"      				,	a2(1:3)  	  	,	"a_y lattice vector"				)
				call CFG_add_get(my_cfg,	"unitCell%a3"      				,	a3(1:3)  	  	,	"a_z lattice vector"				)
				call CFG_add_get(my_cfg,	"unitCell%a0"					,	a0					,	"lattice scaling factor "			)
				!
				a_latt(1,1:3)	= a1(1:3)
				a_latt(2,1:3)	= a2(1:3)
				a_latt(3,1:3)	= a3(1:3)
				a_latt		=	a0 * a_latt
				![wannInterp]
				call CFG_add_get(my_cfg,	"wannInterp%mp_grid"			,	mp_grid(1:3)		,	"interpolation k-mesh"				)
				call CFG_add_get(my_cfg,	"wannInterp%seed_name"			,	seed_name			,	"seed name of the TB files			")
				![mep]
				call CFG_add_get(my_cfg,	"MEP%valence_bands"				,	valence_bands		,	"number of valence_bands"			)

				write(*,*)					"**********************init_parameters********************************************"
				write(*,*)					"parallelization with ",mpi_nProcs," MPI threads"
				write(*,'(a,i3,a)')			"[#",mpi_id,";init_parameters]: input interpretation:"
				write(*,*)					"[methods]"
				write(*,*)					"	plot_bands=",plot_bands
				write(*,*)					"[unitCell]"
				write(*,*)					"	a1=",a1(1:3)
				write(*,*)					"	a2=",a2(1:3)
				write(*,*)					"	a3=",a3(1:3)
				write(*,*)					"	a0=",a0
				write(*,*)					"[wannInterp]"
				write(*,*)					"	seed_name=",seed_name
				write(*,*)					"[mep]"
				write(*,'(a,i4)')			"	val bands=",valence_bands
			
				!make the output folder
				call my_mkdir(out_dir)
				call my_mkdir(raw_dir)				
				write(*,*)					"---------------------------------------------------------------------------"
			else
				write(*,'(a,i3,a)')			"[#",mpi_id,";init_parameters]: could not find input file"
			end if
		end if
		!
		!
		call MPI_BCAST(			input_exist		,			1			,		MPI_LOGICAL			,		mpi_root_id,	MPI_COMM_WORLD, ierr)
		if( input_exist) then
			!ROOT BCAST
			call MPI_BCAST(		plot_bands		,			1			,		MPI_LOGICAL			,		mpi_root_id,	MPI_COMM_WORLD, ierr)
			call MPI_BCAST(		a_latt			,			9			,	MPI_DOUBLE_PRECISION	,		mpi_root_id,	MPI_COMM_WORLD, ierr)
			call MPI_BCAST(		valence_bands	,			1			,		MPI_INTEGER			,		mpi_root_id,	MPI_COMM_WORLD,	ierr)
			call MPI_BCAST(		seed_name(:)	,	len(seed_name)		,		MPI_CHARACTER		,		mpi_root_id,	MPI_COMM_WORLD,	ierr)
			call MPI_BCAST(		mp_grid			,			3			,		MPI_INTEGER			,		mpi_root_id,	MPI_COMM_WORLD,	ierr)
			!
			!SETUP K-SPACE
			call set_recip_latt(a_latt)
			call set_mp_grid(mp_grid)
		end if
		!
		init_parameters	=	input_exist
		!
		return 
	end function





	subroutine my_mkdir(dir)
		character(len=*)			::	dir
		logical						::	dir_exists
		character(len=8)		::	mkdir="mkdir ./"	!to use with system(mkdir//$dir_path) 	
		!
		inquire(file=dir, exist=dir_exists)
		if( .not. dir_exists )	then
			call system(mkdir//dir)
			write(*,'(a,i3,a,a)')	"[#",mpi_id,"; init_parameters]: created directory ",dir
		end if
		!
		return
	end subroutine




end module input_paras