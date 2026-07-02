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
! *  Author: F. Gillet-Chaulet (IGE)
! *  Email:  fabien.gillet-chaulet@univ-grenoble-alpes.fr
! *  Web:    http://elmerice.elmerfem.org
! *
! *  Original Date: 07/09/2022
! *  
! *  reset thickness to critical thickness; when number of elements is
! below a given threshold
! *****************************************************************************
!!!  
      SUBROUTINE ExcludeAreas( Model,Solver,dt,TransientSimulation)
      USE DefUtils
      IMPLICIT NONE

      TYPE(Model_t) :: Model
      TYPE(Solver_t), TARGET :: Solver
      REAL(KIND=dp) :: dt
      LOGICAL :: TransientSimulation

      CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='ExcludeAreas'

      TYPE(Mesh_t),POINTER :: Mesh
      TYPE(Variable_t), POINTER :: HVar,NoE
      TYPE(Element_t),POINTER :: Element
      TYPE(GaussIntegrationPoints_t) :: IP
      TYPE(Nodes_t),SAVE :: Nodes
      TYPE(ValueList_t), POINTER :: SolverParams
      TYPE(ValueList_t),POINTER :: BodyForce,Material
      REAL(KIND=dp), ALLOCATABLE,SAVE :: Basis(:),NodalH(:),MinH(:)
      REAL(KIND=dp) :: totarea,totvolume
      REAL(KIND=dp) :: detJ,s,HAtIP
 
      INTEGER :: EThreshold

      INTEGER :: t,p,i,j
      INTEGER :: n
      INTEGER :: EIndex

      LOGICAL :: stat,GotIt
      LOGICAL,SAVE :: FirstTime=.True.


      Mesh => Solver % Mesh

      SolverParams => GetSolverParams()
      EThreshold = ListGetInteger(SolverParams,"Critical Number of elements",UnFoundFatal=.TRUE.)

      IF (FirstTime) THEN
         n = MAX(Mesh % MaxElementNodes,Mesh % MaxElementDOFs)
         ALLOCATE(Basis(n),NodalH(n),MinH(n))
         FirstTime=.False.
      END IF
      
      ! Get Ice thickness
      HVar => VariableGet( Mesh % Variables,'H',UnfoundFatal=.True.)

      ! Get NumberofEleemnts inside connected regions
      NoE => VariableGet( Mesh % Variables,'RegionNoE',UnfoundFatal=.True.)
      IF (.NOT.ASSOCIATED(NoE%Perm)) &
         CALL FATAL(SolverName,"RegionNoE has no valid permutation")
      IF (NoE%TYPE.NE.Variable_on_elements) &
         CALL FATAL(SolverName,"RegionNoE should be on_elements")
      
      totarea=0._dp
      totvolume=0._dp
      DO t=1,GetNOFActive()
         Element => GetActiveElement(t)
         EIndex = Element % ElementIndex 
         n  = GetElementNOFNodes(Element)
         
         ! Element is passive
         IF (NoE % Values(NoE%Perm(EIndex)).LT.0) CYCLE

         ! Element belongs to a region with more elements than threshold
         IF (NINT(NoE % Values(NoE%Perm(EIndex))).GT.EThreshold) CYCLE

         CALL GetLocalSolution(NodalH,UElement=Element,UVariable=HVar)

         BodyForce => GetBodyForce(Element)
         Material => GetMaterial(Element)
         MinH = ListGetConstReal(BodyForce,'H Lower Limit', Gotit)
         IF (.NOT.Gotit) &
            MinH = ListGetConstReal(Material,'Min H', Gotit)
         IF (.NOT.GotIt) &
            CALL FATAL("ExcludeAreas","Limit for H not found...")

         CALL GetElementNodes(Nodes,Element)
         IP = GaussPoints( Element )

         DO p = 1, IP % n
            stat = ElementInfo( Element, Nodes, IP % U(p), IP % V(p), &
              IP % W(p), detJ, Basis) 
            s = detJ * IP % S(p)    

            HAtIP=SUM(NodalH(1:n)*Basis(1:n))

            totarea=totarea+s
            totvolume=totvolume+HAtIP*s
         END DO

         DO i=1,n
            j = HVar % Perm(Element % NodeIndexes(i))
            IF(j>0) HVar%Values(j) = MinH(i)
         END DO

      END DO

      PRINT *,"excluded area : ",totarea
      PRINT *,"excluded volume :",totvolume


      END



