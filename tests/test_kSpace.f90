program test_kSpace

	use		constants,			only:			dp, pi_dp
	use		k_space,	 		only:			set_recip_latt,	get_recip_latt,	& 
												set_mp_grid,					& 
												get_rel_kpts
	use		matrix_math,		only:			is_equal_mat, crossp
	use 	helpers,			only:			my_exit,						&
	    										push_to_outFile, write_test_results


	implicit none  										


	logical,			allocatable		::		passed(:)
	character(len=80), 	allocatable		::		label(:)
	integer								::		nTests, succ_cnt, test
	!
	!
	nTests		=	2
	succ_cnt	=	0
	!
	allocate(	label(nTests)		)	
	allocate(	passed(nTests)		)
	!
	!-----------------------------------------------------------
	!-----------------------------------------------------------
	!-----------------------------------------------------------
	!			perform the tests		
	!-----------------------------------------------------------
	!
	passed		=	.false.
	!-----------------------------------------------------------
	label(	1)	=	'reciprocal lattice generator'
	passed(	1)	=	test_reciprocal()
	!-----------------------------------------------------------
	label(	2)	=	'BZ integration mesh, test'
	passed(	2)	=	test_k_mesh_int()
	!-----------------------------------------------------------
	!
	!
	do test = 1, nTests
		if(	passed(test)	)	succ_cnt= succ_cnt + 1
	end do
	call write_test_results(	'k space tests(creation & mesh)', passed, label, succ_cnt, nTests	)
	!
	call my_exit(	succ_cnt ==	nTests	)




contains

!
!
!
!
!
!			lattice creation test


	logical function test_reciprocal()
		real(dp)					::		recip_latt(3,3), bz_vol, unit_vol
		real(dp),	allocatable		::		a_latt(:,:,:),	recip_sol(:,:,:)
		integer						::		lattice, nLatt, succ_cnt
		character(len=120)			::		msg
		!
		succ_cnt			=	0	
		nLatt				= 	get_test_lattices(a_latt, recip_sol)
		!
		!	perform test for each lattice
		loop_latt:	do lattice	=	1, nLatt
			!
			call set_recip_latt(a_latt(:,:,lattice))
			recip_latt	= get_recip_latt()
			write(*,*)	'[test_reciprocal]:	got recip lattice ',recip_latt
			!
			unit_vol		= dot_product(	crossP(a_latt(1,1:3,lattice),a_latt(2,1:3,lattice)),	a_latt(3,1:3,lattice))
			bz_vol			= dot_product(	crossP(recip_latt(1,1:3),recip_latt(2,1:3)),	recip_latt(3,1:3))
			!
			if( abs(bz_vol-	8.0_dp*pi_dp**3/unit_vol	) 	>  1e-10_dp) then
				write(msg,*) '[test_reciprocal]: got bz_vol',bz_vol,' expected',	8.0_dp*pi_dp**3/unit_vol
				call push_to_outFile(msg)
				exit loop_latt
			else if(	is_equal_mat(1e-8_dp	,recip_latt, 	recip_sol(:,:,lattice))			) then
				succ_cnt	= succ_cnt + 1
			else
				write(msg,*) '[test_reciprocal]: test lattice #',lattice,' failed '
				exit loop_latt
			end if
		end do loop_latt
		!
		write(msg,*) '[test_reciprocal]: passed test on ',succ_cnt,' of ',nLatt,' tested lattices'
		call push_to_outFile(msg) 
		!
		test_reciprocal	= 	(succ_cnt == nLatt)
		!
		return
	end function


	integer function get_test_lattices(a_latt, b_latt)
		real(dp),		allocatable		::	a_latt(:,:,:), b_latt(:,:,:)
		!
		get_test_lattices	=	1
		!	
		allocate(		a_latt(3,3,get_test_lattices)	)
		allocate(		b_latt(3,3,get_test_lattices)	)
		!
		!-------------------------------------------------------
		!		#1			- cubic lattice
		a_latt(:,:,1)	=	0.0_dp
		b_latt(:,:,1)	=	0.0_dp
			!
		a_latt(1,1,1)	=	1.0_dp
		b_latt(1,1,1)	=	2.0_dp * pi_dp
			!
		a_latt(2,2,1)	=	2.0_dp
		b_latt(2,2,1)	=	1.0_dp * pi_dp
			!
		a_latt(3,3,1)	=	- 0.5_dp
		b_latt(3,3,1)	=	-4.0_dp * pi_dp

		!-------------------------------------------------------
		!		#2

		!-------------------------------------------------------
		!-------------------------------------------------------
		!-------------------------------------------------------
		!
		return
	end function

!
!
!
!
!
!
!----------------- k-integration tests	--------------------------------------------------------------------------------------

	logical function test_k_mesh_int()
		!
		!	test function:	
		!	
		integer					::	mp_grid(3),  mesh, n_meshes
		integer, allocatable	::	nk_dim_lst(:)
		real(dp)				::	int_ana, int_num,	&
									precision,			&
									a, b, c, d, e, f
		real(dp), allocatable	::	rel_kpts(:,:)
		character(len=120)		::	msg
		!
		test_k_mesh_int	=	.false.
		precision		=	1e-8_dp
		n_meshes		=	10
		!
		!
		allocate(	nk_dim_lst(n_meshes)		)
		!
		nk_dim_lst(1)	=	1
		nk_dim_lst(2)	=	2
		nk_dim_lst(3)	=	4
		nk_dim_lst(4)	=	8
		nk_dim_lst(5)	=	16
		nk_dim_lst(6)	=	32
		nk_dim_lst(7)	=	64
		nk_dim_lst(8)	=	128
		nk_dim_lst(9)	=	256
		nk_dim_lst(10)	=	512
		!
		!	get analytic integral
		a 	= 	1.0_dp
		b 	=	1.0_dp
		c 	= 	1.0_dp
		!	
		d	=  	2.0_dp		
		e	=  	2.0_dp 		
		f	= 	2.0_dp		
		int_ana			=	ana_integral(a,b,c,d,e,f)	
		!
		!	refine mesh
		loop_mesh:	do mesh = 1, n_meshes
			!
			!	setup new mesh
			mp_grid(1:3)	=	nk_dim_lst(mesh)
			call set_mp_grid(mp_grid)
			call get_rel_kpts(rel_kpts)
			!
			!	do numerical integration
			int_num	=	num_integral(a,b,c, d, e, f, rel_kpts)
			!
			!	compare to analytic solution
			if( abs(int_ana-int_num)	< precision	)	then 
				test_k_mesh_int	=	.true.
				exit loop_mesh
			end if

			write(msg,*)	"[test_k_mesh_int]: for #nK_per_dim",nk_dim_lst(mesh),' the delta was ',int_ana-int_num
			call push_to_outFile(msg)

			deallocate(rel_kpts)
		end do loop_mesh
		!
		!
		if(.not. test_k_mesh_int	) then
			write(msg,*) "[test_k_mesh]: the numerical integration did not converge for precision=",precision
			call push_to_outFile(msg)
			write(msg,'(a,f16.8,a,f16.8,a)') '[test_k_mesh]: ana_int=',int_ana,' /= ', int_num,'= num_int'
			call push_to_outFile(msg)
		else
			write(msg,*)	'[test_k_mesh]: the k_integration converged for precision=',precision,' on mp_grid: ',mp_grid(1)
			call push_to_outFile(msg)
		end if
		!
		return
	end function

	
	real(dp) function f_test(a,b,c,x)
		!	f_test	=	a x^2    b y^4     c z^2 
		real(dp),	intent(in)		::	a, b, c, x(3)
		!
		f_test	=	(a *b*c) *  x(1)**2	*  x(2)**2 	*  x(3)**2
		!
		return
	end function 



	real(dp) function ana_integral(a,b,c,d,e,f)
		!	a x^2    b y^4     c z**2    {  {x,-d,d},{y,-e,e},{z,-f,f}	}  
		!	WOLFRRAM ALPHA:
		!	'integrate[(a*x**2) * (b*y**4) * (c*z**4),{x,-d,+d},{y,-e,e},{z,-f,+f}]'		
		real(dp),	intent(in)				::	a, b, c, d, e, f
		!
		ana_integral	= 	(8.0_dp/27.0_dp) * a * b * c * d**3 * e**3 * f**3
		!
		return
	end function



	real(dp) function num_integral(a,b,c, d, e, f, rel_kpts)
		real(dp),	intent(in)		::	a, b, c, d, e, f, &
										rel_kpts(:,:)
		integer						::	kpt
		real(dp)					::	abs_kpt(3)
		!
		num_integral	=	0.0_dp
		!
		do kpt = 1, size(rel_kpts,2)
			abs_kpt(1)	= rel_kpts(1,kpt) * d * 2.0_dp 
			abs_kpt(2)	= rel_kpts(2,kpt) * e * 2.0_dp
			abs_kpt(3)	= rel_kpts(3,kpt) * f * 2.0_dp
			!
			!
			num_integral	= num_integral + f_test(a,b,c, abs_kpt)
		end do
		!	normalize
		num_integral	=	num_integral /	real(size(rel_kpts,2),dp)
		!
		return
	end function




end program