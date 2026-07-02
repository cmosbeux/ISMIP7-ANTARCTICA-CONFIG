!/*****************************************************************************/
! *
! *  Elmer/Ice, a glaciological add-on to Elmer
! *  http://elmerice.elmerfem.org
! *
! * 
! *  This program is free software; you can redistribute it and/or
! *  modify it under the terms of the GNU General Public License
! *  as published by the Free Software Foundation; either version 2
! *  of the License, or (at your option) any later version.
! * 
! *  This program is distributed in the hope that it will be useful,
! *  but WITHOUT ANY WARRANTY; without even the implied warranty of
! *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! *  GNU General Public License for more details.
! *
! *  You should have received a copy of the GNU General Public License
! *  along with this program (in file fem/GPL-2); if not, write to the 
! *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, 
! *  Boston, MA 02110-1301, USA.
! *
! *****************************************************************************/
! ******************************************************************************
! *
! *  Authors: 
! *  Email:   
! *  Web:     http://elmerice.elmerfem.org
! *
! *  Original Date: 
! * 
! *****************************************************************************
SUBROUTINE ToLonLat( Model,Solver,dt,TransientSimulation )
!------------------------------------------------------------------------------
!******************************************************************************
  USE DefUtils
  USE fortranc
  USE proj
  IMPLICIT NONE
!------------------------------------------------------------------------------
  TYPE(Solver_t),TARGET :: Solver
  TYPE(Model_t) :: Model
  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation
!------------------------------------------------------------------------------
! Local variables
!------------------------------------------------------------------------------
  TYPE(ValueList_t), POINTER :: Params
  TYPE(Mesh_t), POINTER :: Mesh
  TYPE(Variable_t), POINTER :: Sol
  TYPE(pj_object) :: pj
  TYPE(pjuv_object) :: coordp,coordg
  REAL(KIND=dp), POINTER :: Values(:)
  REAL(KIND=dp) :: x,y
  INTEGER, POINTER :: Perm(:)
  INTEGER :: i
  CHARACTER(LEN=MAX_NAME_LEN) :: proj_string
  CHARACTER(LEN=MAX_NAME_LEN),parameter :: SolverName='ToLonLat'

  Mesh => GetMesh()
  Params => GetSolverParams()

! Get LonLat
  Sol => VariableGet( Mesh % Variables, 'LonLat', UnFoundFatal=.true. )
  Values => Sol % Values
  Perm => Sol % Perm
  IF (Sol % DOFs.NE.2) CALL FATAL(SolverName,'LonLat shoudl have DOFs=2')

! initialise projection
  proj_string=ListGetString(Params,'projection',UnFoundFatal=.True.)
  PRINT*,TRIM(proj_string)
  pj = pj_init_plus(TRIM(proj_string)//CHAR(0))
  !pj = pj_init_plus(TRIM(proj_string))
  IF (.NOT.pj_associated(pj)) CALL FATAL(SolverName,'proj not associated')
!Done

  Do i=1,Mesh%NumberOfNodes
     x=Mesh%Nodes%x(i)
     y=Mesh%Nodes%y(i)
     coordp = pjuv_object(x,y)
     coordg = pj_inv(coordp, pj)
     Values(2*(Perm(i)-1)+1) = coordg % u * pj_rad_to_deg
     Values(2*(Perm(i)-1)+2) = coordg % v * pj_rad_to_deg
  End do
    
  CALL pj_free(pj)
!------------------------------------------------------------------------------
END SUBROUTINE ToLonLat
!------------------------------------------------------------------------------

