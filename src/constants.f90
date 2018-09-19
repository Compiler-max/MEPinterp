module constants
	implicit none

	save
	
	!FLOATING POINT
	integer, 		parameter 	:: 	dp 				= kind(0.d0)
	real(dp),		parameter	:: 	fp_acc			= 1e-14_dp

	!MPI
	integer						::	mpi_id, mpi_root_id, mpi_nProcs, ierr

	!MATHEMATICAL
	real(dp), 		parameter 	::	PI_dp 			= 4 * atan (1.0_dp)
	complex(dp),	parameter 	::	i_dp 			= cmplx(0.0_dp, 1.0_dp, dp)


	!PHYSICAL
	real(dp),		parameter 	::	aUtoAngstrm 	= 0.52917721092_dp, &
									aUtoEv	 		= 27.211385_dp							!Hartree to eV
	real(dp),		parameter	::	aUtoTesla		= 235051.76_dp							!magn. field
	real(dp),		parameter	::	speedOfLight	= 137.035999_dp !in atomic units
	real(dp),		parameter	::	kBoltz_Eh_K		= 8.6173303_dp * 1e-5_dp / aUtoEv 		!kBoltz from wiki: kB	=	8.6173303(50)×10−5	eV⋅K−1
	real(dp),		parameter	::	T_room			= 300.0_dp


end module constants