module statistics
	use constants, 		only:			dp, aUtoEv, kBoltz_Eh_K
	!
	implicit none

	public					::			fd_stat,		fd_stat_deriv, 			&
										fd_get_N_el
	private


	save


	real(dp),	parameter	::			min_temp	= 1e-2_dp

contains





	real(dp) pure function fd_stat(e_band, e_fermi,	T_kelvin) 
		real(dp), 		intent(in)			::	e_band, e_fermi, T_kelvin
		real(dp)							::	T_smear
		!
		fd_stat		=	0.0_dp
		!
		if(	 T_kelvin > min_temp ) 				then
			!
			!	FINITE TEMPERATURE
			T_smear			=	kBoltz_Eh_K		*	T_kelvin
			fd_stat		 	= 	1.0_dp	/	(	1.0_dp	+	exp(	(e_band	- e_fermi)	/	(T_smear)))
			!
			!
		else if(	e_band < e_fermi	)  		then
			!	
			!	ZERO TEMPERATURE
			fd_stat	=	1.0_dp
		end if
		!
		!
		return
	end function




	


	real(dp) pure function fd_get_N_el(en_k, e_fermi, T_kelvin)
		real(dp),		intent(in)			::	en_k(:), e_fermi, T_kelvin
		integer								::	n
		!
		fd_get_N_el	=	0.0_dp
		!
		do n = 1, size(en_k)
			fd_get_N_el	=	fd_get_N_el	+	fd_stat(en_k(n),	e_fermi, T_kelvin)
		end do
		!
		return
	end function



	real(dp) pure function fd_stat_deriv(e_band, e_fermi, T_kelvin)
		real(dp), 		intent(in)			::	e_band, e_fermi, T_kelvin
		real(dp)							::	T_smear, x
		!
		!	w90git:
		!if (abs (x) .le.36.0) then
        ! 	utility_w0gauss = 1.00_dp / (2.00_dp + exp ( - x) + exp ( + x) )
        !  	! in order to avoid problems for large values of x in the e
       	!else
        !	utility_w0gauss = 0.0_dp
       	!endif
       	!
       	fd_stat_deriv		=	0.0_dp	
       	!
       	if(	T_kelvin > min_temp	)								then
       		T_smear			=	kBoltz_Eh_K		*	T_kelvin
       		x				=	(e_band	- e_fermi) / T_smear
       		!
       		!
       		fd_stat_deriv	=	1.00_dp 	/ 	(	2.00_dp + exp( x ) + exp( -x ) 	)
       	end if

		return
	end function	

end module statistics