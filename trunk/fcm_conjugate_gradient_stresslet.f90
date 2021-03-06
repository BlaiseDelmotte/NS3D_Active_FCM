 !!====================================================================
!!
!! 
!!
!! DESCRIPTION: 
!!
!!
!
!!> @brief
!!> Compute the stresslet coefficient using CG from Yeo 2010
!!
!! Date :  17/01/2013
!!
!!
!!> @author 
!!> Blaise Delmotte
!!====================================================================

subroutine FCM_CONJUGATE_GRADIENT_STRESSLET

!!====================================================================
!!
!!====================================================================

use WORK_ARRAYS
use FLUID_VARIABLE
use DNS_DIM
use GEOMETRIC_VARIABLE 
use FCM_PART_VARIABLE
use FCM_FORCING_VARIABLE
use P3DFFT

implicit none

! Norm of the RHS of the CG equation to solve
real(kind=8) :: NORM_EIJ
real(kind=8) :: TOL


! Indices for loops
integer :: K


K = 0


FCM_MAX_ITER = 100

! Initial residual
FCM_RES_ROS = -FCM_EIJ
! Initial direction
FCM_DIR_MIN = -FCM_EIJ

! Compute L2 norm
call FCM_L2NORM(FCM_RES_ROS,FCM_L2RES_ROS)
NORM_EIJ = FCM_L2RES_ROS

TOL = FCM_TOL_L2RES_ROS*NORM_EIJ

! Keep looping as long as relative residual is smaller than TOL
do while ((FCM_L2RES_ROS.gt.TOL).and.(K.lt.FCM_MAX_ITER))

 K = K + 1
 !print*, 'K = ', K

 if (K.ge.(FCM_MAX_ITER-1)) then
  if (MYID==0) then
   print*, K, 'th CG iteration'
   print*,'MAX_L2NORM = ', FCM_L2RES_ROS
   print*,'MAX_SIJ = ', maxval(FCM_SIJ)
   print*,'MAX_FORCE = ', maxval(FCM_FORCE)
  end if
 end if


 call FCM_ZERO_FIELD_VARIABLE
 
 ! Zeros ROS
 FCM_EIJ(:,:) = 0.0

 call FCM_DISTRIB_STRESSLET(FCM_ACTIVATE_STRESSLET,FCM_DIR_MIN)
 
 if (FCM_BC==2) then
  call FCM_MIRROR_FORCES_X
 end if
 
 
 call FCM_FLUID_PREDICTION
 
 call FCM_RATE_OF_STRAIN_FILTER
 
 call FCM_PROD_SCAL(FCM_RES_ROS,FCM_RES_ROS,FCM_INC_DIR_BETA)
 
 call FCM_PROD_SCAL(FCM_EIJ,FCM_DIR_MIN,FCM_INC_DIR_ALPHA)
 
 FCM_INC_DIR_ALPHA = FCM_INC_DIR_BETA/FCM_INC_DIR_ALPHA
 
 FCM_SIJ = FCM_SIJ + FCM_INC_DIR_ALPHA*FCM_DIR_MIN
 
 FCM_RES_ROS = FCM_RES_ROS - FCM_INC_DIR_ALPHA*FCM_EIJ

! Compute max of L2 norm
 call FCM_L2NORM(FCM_RES_ROS,FCM_L2RES_ROS)  
 
 call FCM_PROD_SCAL(FCM_RES_ROS,FCM_RES_ROS,FCM_INC_DIR_ALPHA)
  
 FCM_INC_DIR_BETA = FCM_INC_DIR_ALPHA/FCM_INC_DIR_BETA
 
 FCM_DIR_MIN = FCM_RES_ROS + FCM_INC_DIR_BETA*FCM_DIR_MIN
 
end do

   
end subroutine FCM_CONJUGATE_GRADIENT_STRESSLET
