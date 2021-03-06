!***** JADIM_TOOLS/traj2vtu
! NAME
!   write_vtu
! SYNOPSIS
! subroutine write_vtu
! AUTHOR
!   A. Chouippe 
! CREATION DATE
!  13/04/2010
! DESCRIPTION
! Cree des fichiers au format vtu pour la visualisation des particules
! Subroutine d'écriture 
!!! MODIFICATION HISTORY
! PARENTS
! CHILDREN
!!! ARGUMENTS
! SOURCE
subroutine PRINT_PARAVIEW_PART_ELL(TIME,&
                               NP, &
                               POSI, &
                               VEL, &
                               ROT, &
                               PSWIM, &
                               P_SCAL_PMEAN, &
                               ELL_MAT, &
                               RAD, &
                               FCM_VSW )


implicit none


integer,                     intent(in) :: TIME
integer,                     intent(in) :: NP
real(kind=8), dimension(NP,3), intent(in) :: POSI
real(kind=8), dimension(NP,3), intent(in) :: VEL
real(kind=8), dimension(NP,3), intent(in) :: ROT
real(kind=8), dimension(NP,3), intent(in) :: PSWIM
real(kind=8), dimension(NP), intent(in) :: P_SCAL_PMEAN
real(kind=8), dimension(NP,9), intent(in) :: ELL_MAT
real(kind=8), dimension(NP,3), intent(in) :: RAD
real(kind=8), intent(in) :: FCM_VSW
!---------------------------------------------------------------------
character(len=40) :: FILENAME


integer :: IP
!
!.. Executable Statements ..

write(FILENAME,10100)'PART_KINEMATICS_t_',TIME,'.vtu'
!
open(1984,file=trim(FILENAME))
write(1984,'(A)') '<VTKFile type="UnstructuredGrid" version="0.1" byte_order="LittleEndian">'
write(1984,'(A)') '<UnstructuredGrid>' 
write(1984,23) NP
! Sortie des positions des particules -----------------------
write(1984,'(A)') '   <Points>'
write(1984,'(A)') '        <DataArray type="Float32" NumberOfComponents="3" format="ascii">'
write(1984,*)     (POSI(IP,1)/maxval(RAD), POSI(IP,2)/maxval(RAD), POSI(IP,3)/maxval(RAD), IP=1,NP)
write(1984,'(A)') '        </DataArray>'
write(1984,'(A)') '   </Points>'
! Sortie des donnees associees aux particules
!-----------------------------------------------
write(1984,'(A)') '   <PointData>'
!1. vitesses des particules
write(1984,'(A)') '        <DataArray type="Float32" Name="Vitesse" NumberOfComponents="3" format="ascii">'
write(1984,*)     (VEL(IP,1)/FCM_VSW, VEL(IP,2)/FCM_VSW, VEL(IP,3)/FCM_VSW, IP=1,NP)
write(1984,'(A)') '        </DataArray>'
!2. rotation des particules
write(1984,'(A)') '        <DataArray type="Float32" Name="Rotation" NumberOfComponents="3" format="ascii">'
write(1984,*)     (ROT(IP,1), ROT(IP,2), ROT(IP,3), IP=1,NP)
write(1984,'(A)') '        </DataArray>'
!3. orientatiion des particules
write(1984,'(A)') '        <DataArray type="Float32" Name="Orientation" NumberOfComponents="3" format="ascii">'
write(1984,*)     (PSWIM(IP,1), PSWIM(IP,2), PSWIM(IP,3), IP=1,NP)
write(1984,'(A)') '        </DataArray>'
!3b. produit scalaire avec vecteur orientation moyen
write(1984,'(A)') '        <DataArray type="Float32" Name="Scal_Pmean"  format="ascii">'
write(1984,*)     (P_SCAL_PMEAN(IP), IP=1,NP)
write(1984,'(A)') '        </DataArray>'
!4. Tenseur ellipsoides (rayons + orientation)
write(1984,'(A)') '        <DataArray type="Float32" Name="Tensor" NumberOfComponents="9" format="ascii">'
write(1984,*)     (ELL_MAT(IP,1), ELL_MAT(IP,2), ELL_MAT(IP,3), &
                   ELL_MAT(IP,4), ELL_MAT(IP,5), ELL_MAT(IP,6), &
                   ELL_MAT(IP,7), ELL_MAT(IP,8), ELL_MAT(IP,9), IP=1,NP)
write(1984,'(A)') '        </DataArray>'
!5. rayons max adim des particules 
write(1984,'(A)') '        <DataArray type="Float32" Name="Rayon"  format="ascii">'
write(1984,*)     (maxval(RAD(IP,:))/maxval(RAD), IP=1,NP)
write(1984,'(A)') '        </DataArray>'
!6. Numeros identifiants des particules
write(1984,'(A)') '        <DataArray type="Float32" Name="NumId"  format="ascii">'
write(1984,*)     (IP, IP=1,NP)
write(1984,'(A)') '        </DataArray>'
write(1984,'(A)') '   </PointData>'
write(1984,'(A)') '   <Cells>'
write(1984,'(A)') '      <DataArray type="Int32" Name="connectivity" format="ascii">'
write(1984,'(A)') '      </DataArray>'
write(1984,'(A)') '       <DataArray type="Int32" Name="offsets" format="ascii">'
write(1984,'(A)') '       </DataArray>'
write(1984,'(A)') '       <DataArray type="UInt8" Name="types" format="ascii">'
write(1984,'(A)') '       </DataArray>'
write(1984,'(A)') '   </Cells>'
write(1984,'(A)') ' </Piece>'  
write(1984,'(A)') '</UnstructuredGrid>'   
write(1984,'(A)') '</VTKFile>'
close(1984)

write(*,*) 'Creation du Fichier ', FILENAME

! ... Format Declarations ...
23 format (1x,'<Piece NumberOfPoints=" ',i12,' " NumberOfCells="0">')
10100 format (A,I8.8,A)
end subroutine PRINT_PARAVIEW_PART_ELL
!***
