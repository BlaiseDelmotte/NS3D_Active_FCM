!!====================================================================
!!
!!
!!====================================================================

Program POS_ONLY_PERCOLATION

!!====================================================================
!!
!!
!!====================================================================

use MPI
use BUCKET_VARIABLE  !- FCM forcing variables

implicit none


!--------------------------------------------------------------------
! ARRAYS STATEMENT
!--------------------------------------------------------------------

!- File name 
character(len=40) :: FILENAME
!- String for time
character(len=10) :: FILE_EXT

! Physical Time
real(kind=8), allocatable, dimension(:) :: TIME_VEC

!!- Vraiables from direct access files
! Read Lagrangian Data
real(kind=8), allocatable, dimension(:,:,:) :: FCM_POS
real(kind=8), allocatable, dimension(:,:,:) :: FCM_RADII

! Lagrangian Data along time
real(kind=8), allocatable, dimension(:,:,:) :: FCM_POS_TIME


integer, allocatable, dimension(:,:) :: CONNECTIVITY
real(kind=8) :: PPI

!!- Dicrestization points in each direction
integer :: NX, NY, NZ
real(kind=8) :: LXMAX, LYMAX, LZMAX

!!- Swilmming velocity (radii/s)
real(kind=8) :: VSW

!!- Minimal/Maximal radius, to compute dimensionless time
real(kind=8) :: RADMIN
real(kind=8) :: RADMAX

real(kind=8) :: BOXSIZE

!!- Volume fraction
real(kind=8) :: VOL_FRAC

!!- Asymptotic Value Mean Orientation vector
real(kind=8), dimension(3) :: PINF

!! Flags for Brownian + Wall
integer :: FLOW_TYPE, BC

!!- Number of boxes in ones direction to compute local statistics
integer :: NBOX_DIR

!!- Particle number temporary
integer :: NPART, NPSTAT, NSPHERE, NELLIPSOID

!!- Temporary dimension integers
integer :: DIM2, DIM3

!!- Number of time iterations
integer :: NCYCLEMAX

!!- Time-step
real(kind=8) :: DTIME

!!- Dump for fluid solution
integer :: FOUT1

!!- Dump for particle solution
integer :: FOUT3

!!- Number of dumps to read
integer :: NB_DUMP_FILES_FLUID
integer :: NSAVES
!! Starting dump to treat correlations
integer :: SAVE_START, SAVE_END, JUMP_SAVE

!!- Flag if quaternions are used or orientation vectors
integer :: USE_QUAT

!- Time 
integer :: TIME

!- Index
integer :: I, J, K, IJK, IND

!- Integers to signalize a non-existing file
integer :: ERR_STAT, &
           ERR_INFO, &
           ERR_FILE_POS, &
           ERR_FILE_POS_NOPER, &
           ERR_FILE_VEL, &
           ERR_FILE_ROT, &
           ERR_FILE_ORIENT, &
           ERR_FILE_SWIM, &
           ERR_FILE_P2, &
           ERR_FILE_P3, &
           ERR_FILE_STRESS, &
           ERR_FILE_RADII
	   
!!- Integers to chose which treatment to perform
integer :: TREAT_VEL
integer :: TREAT_STRESS
integer :: TREAT_CORREL_POS
integer :: TREAT_CORREL_ORIENT
integer :: TREAT_DIFF

!-  MPI Variables
integer :: IERR,NPROC,MYID



!!--------------------------------------------------------------------
!! 0.0 MPI World initiation
!!--------------------------------------------------------------------
call MPI_INIT(IERR)
call MPI_COMM_SIZE(MPI_COMM_WORLD,NPROC,IERR)
call MPI_COMM_RANK(MPI_COMM_WORLD,MYID,IERR)


PPI = 4.0*atan(1.0)

!---------------------------------------------------------------------
!=====================================================================
! 0. READ INPUT, PARAMETERS AND ALLOCATION
!=====================================================================

!- Open file
open(unit=100,file='stat_choice_percolation.in',status='old', iostat=ERR_STAT)

if(ERR_STAT /= 0) then

 print *, "CPU -- ", MYID, ":: ERROR: Input data file stat_choice.in open error!"
 call MPI_FINALIZE(ERR_STAT)
 call abort()
else

 read(100,*), SAVE_START
 read(100,*), SAVE_END
 read(100,*), JUMP_SAVE
 read(100,*), BOXSIZE

end if
close(100)

NSAVES = int(real((SAVE_END-SAVE_START))/real(JUMP_SAVE))+1

!- Open file
open(unit=200,file='fcm_run.info',status='old', iostat=ERR_INFO)

if(ERR_INFO /= 0) then

 print *, "CPU -- ", MYID, ":: ERROR: Input data file fcm_run.info open error!"
 call MPI_FINALIZE(ERR_INFO)
 call abort()
else

 read(200,*), LXMAX
 read(200,*), LYMAX
 read(200,*), LZMAX
 read(200,*), NX
 read(200,*), NY
 read(200,*), NZ
 read(200,*), DTIME
 read(200,*), NCYCLEMAX
 read(200,*), FOUT1
 read(200,*), FOUT3
 read(200,*), NPART
 read(200,*), NSPHERE
 read(200,*), NELLIPSOID
 read(200,*), VSW
 read(200,*), RADMAX
 read(200,*), USE_QUAT
 read(200,*)
 read(200,*), FLOW_TYPE
 read(200,*), BC

end if

close(200)




if (MYID==0) then
 print*,'NSAVES= ' ,  NSAVES
end if

allocate( TIME_VEC(NSAVES) )

allocate( FCM_RADII(NPART,3,1) )

allocate( FCM_POS(NPART,3,1) )
allocate( FCM_POS_TIME(NSAVES,NPART,3) )

allocate( CONNECTIVITY(NPART,NPART) )
 

if (MYID==0) then
	print*,' '
	print*,'-------------------------START READING---------------------- '
	print*,' '
end if
!=====================================================================
! 1. READ LAGRANGIAN DATA AT ENDING TIME
!=====================================================================
if (SAVE_END==NCYCLEMAX) then
	FILENAME='FCM_PART_RADII.end'
	call READ_VAR_MPIIO(NPART,3,1,FCM_RADII,FILENAME,ERR_FILE_RADII)

	if (ERR_FILE_RADII==0) then
		RADMIN = minval(FCM_RADII)
		RADMAX = maxval(FCM_RADII)

		VOL_FRAC = 0.0
		do I = 1, NPART 
			VOL_FRAC = VOL_FRAC &
												+ 4.0/3.0*PPI*FCM_RADII(I,1,1)*FCM_RADII(I,2,1)*FCM_RADII(I,3,1) &
												/ (LXMAX*LYMAX*LZMAX)
		end do
 if (MYID==0) then
		print*,'VOLUME FRACTION = ', VOL_FRAC
	end if
	else
		VOL_FRAC = 0.0
		RADMIN = VSW/2.0
		RADMAX = VSW
	end if

	FILENAME='FCM_PART_POS.end'
	call READ_VAR_MPIIO(NPART,3,1,FCM_POS,FILENAME,ERR_FILE_POS)
	FCM_POS_TIME(NSAVES,:,:) = FCM_POS(:,:,1)


	TIME_VEC(NSAVES) = (real(NCYCLEMAX)-1.0)*DTIME

end if


BOXSIZE = BOXSIZE*RADMAX



!=====================================================================
! 2. READ INTERMEDIATE LAGRANGIAN DATA
!=====================================================================
K=0

do IND= SAVE_START, SAVE_END, JUMP_SAVE
 K = K+1



  if ((mod(K,NSAVES/5)==0).or.(K==NSAVES)) then
   print*, K, '/', SAVE_END, 'FILES READ'
  end if


 

 TIME = (IND-1)*FOUT3 + 1
 TIME_VEC(K) = real(TIME)*DTIME
 
 write(FILE_EXT,10205) TIME
 
 
 write(FILENAME,10101)'FCM_PART_POS_t',trim(FILE_EXT),'.bin'
 call READ_VAR_MPIIO(NPART,3,1,FCM_POS,FILENAME,ERR_FILE_POS) 
 FCM_POS_TIME(K,:,:) = FCM_POS(:,:,1)

end do

call MPI_BCAST(FCM_POS_TIME,NSAVES*NPART*3,MPI_DOUBLE,0,MPI_COMM_WORLD,IERR)

if (MYID==0) then
	print*,' '
	print*,'-------------------------END READING---------------------- '
	print*,' '
	print*,'BOXSIZE = ', BOXSIZE 
	print*,'SAVE_START = ', SAVE_START
	print*,'TIME_START = ', (SAVE_START-1)*FOUT3 + 1
	print*,'SAVE_END = ', SAVE_END
	print*,'TIME_END = ', (SAVE_END-1)*FOUT3 + 1
	print*,'NPART = ', NPART
	print*,'LXMAX = ',LXMAX
end if
!=====================================================================
! 3. TREAT DATA
!=====================================================================

call BUCKET_DISTRIBUTION(	LXMAX, &
																										LYMAX, &
																										LZMAX, &
																										BOXSIZE, &
																										MYID, &
																										NPROC )
																										
call BUCKET_ALLOCATION(NPART)

call BUCKET_BUILD_MAP

K=0

do IND= SAVE_START, SAVE_END, JUMP_SAVE
 print*,MYID,'SAVE # ', IND
 K = K+1
 call COMPUTE_BUCKET_LISTS(NPART, &
                           FCM_POS_TIME(K,:,:)  )
 CONNECTIVITY = 0                           
 call COMPUTE_CONNECTIVITY(NPART, &
                           MYID, &
                           IERR, &
                           BOXSIZE, &
                           LXMAX, &
																												LYMAX, &
																												LZMAX, &
                           FCM_POS_TIME(K,:,:), &
                           CONNECTIVITY )
 if (MYID ==0) then                          
		write(FILE_EXT,10205) (IND-1)*FOUT3 + 1		
		write(FILENAME,10101)'CONNECTIVITY_t',trim(FILE_EXT),'.dat'
		open(unit=100, file=trim(FILENAME), status='replace')
		
		do I = 1, NPART-1
		 do J = I+1, NPART
		  if (CONNECTIVITY(I,J) ==1 ) then
		   write(100,10999) I,achar(9),J
		  end if
		 end do
		end do
		
	end if
	

 
 
end do
 
if (MYID==0) then
	print*,' '
	print*,'PARTICLE POST PROCESSING--->DONE'
	print*,' '
end if
!- Free MPI environement
call MPI_FINALIZE (ierr)

!!====================================================================
1999 format ('VARIABLES = "x", "y", "z", "u", "v", "w"')
2000 format ('VARIABLES = "x", "y", "z", "u", "v", "w", "n", "p"')
2001 format ('ZONE F=POINT I=',i4,' J=',i4,' K=',i4,' SOLUTIONTIME=',e12.5)

1998 format ('VARIABLES = "xp noper", "yp noper", "zp noper"')
2002 format ('VARIABLES = "xp", "yp", "zp"')
2003 format ('VARIABLES = "up", "vp", "wp"')
2004 format ('VARIABLES = "ompx", "ompy", "ompz"')
2005 format ('VARIABLES = "quat1", "quat2", "quat3", "quat4"')
2006 format ('VARIABLES = "pswimx", "pswimy", "pswimz"')
2007 format ('VARIABLES = "Sxx", "Sxy", "Sxz", "Syy", "Syz"')
2008 format ('VARIABLES = "a1", "a2", "a3"')

2010 format ('NPART_FULL = ', i4)
2011 format ('NPART_FULL = ')

10000 format (I5,I5)
10999 format (I5,A,I5)
10200 format (A)
10201 format (A,I1)
10202 format (A,I2)
10203 format (A,I3)
10204 format (A,I4)
10205 format (I8.8)
10101 format (A,A,A)

end program POS_ONLY_PERCOLATION
