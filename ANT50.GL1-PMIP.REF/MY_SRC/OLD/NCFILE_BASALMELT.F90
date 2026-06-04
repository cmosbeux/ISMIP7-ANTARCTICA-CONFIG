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
! *  Authors: F. Gillet-Chaulet (IGE-France)
! *  Web:     http://elmerice.elmerfem.org
! *  Original Date: 04/2019
! * 
! *****************************************************************************
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Read a cell variable stored in a netcdf file
!  The netcdf should contains all the cell of the serial mesh
!  IF used in parallel, the parallel mesh should have the same global
!  cell ordering as the serial mesh
!  
!  IF netcdf contains a time dimension, the current simulation time is
!  used as time index : if t = ]0._dp,1._dp] => index=1 etc...
!
!  Required input parameters:
!   File Name = File <netcdf file>
!   VarName = File <name of the netcdf variable>
!   Target Variable Name = String OPTIONAL <name of the Elmer variable>
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!      
      SUBROUTINE NCFILE_BASALMELT( Model,Solver,dt,TransientSimulation )
!------------------------------------------------------------------------------
      USE DefUtils
      USE NETCDF
      IMPLICIT NONE
!------------------------------------------------------------------------------
      TYPE(Solver_t), TARGET :: Solver
      TYPE(Model_t) :: Model
      REAL(KIND=dp) :: dt
      LOGICAL :: TransientSimulation
!------------------------------------------------------------------------------
! Local variables
      TYPE(ValueList_t), POINTER :: SolverParams
      TYPE(Variable_t),POINTER :: Var
      TYPE(Element_t), POINTER :: Element
      INTEGER , POINTER :: NodeIndexes(:)
      INTEGER :: i
      INTEGER :: NElements
      CHARACTER (len=512) :: FName, DName
      CHARACTER (len=512) :: VarName
      CHARACTER (len=512), SAVE :: TVarName
      INTEGER :: varid,ncells,ncid,ndims,ntime,TVarID
      REAL(KIND=dp), SAVE, ALLOCATABLE :: Values(:)
      REAL(KIND=dp) :: zmlt, time
      INTEGER :: TimeIndex
      INTEGER :: EIndex
      CHARACTER(LEN=MAX_NAME_LEN) :: SolverName="NCFILE_BASALMELT"
      LOGICAL :: Parallel,Found,Firsttime=.TRUE.

! masking
      LOGICAL, SAVE :: lmask, llGL
      REAL(KIND=dp), SAVE :: mskcrit
      TYPE(Variable_t),POINTER :: GMVar

! sanity check declaration
      TYPE(GaussIntegrationPoints_t) :: IntegStuff
      REAL(KIND=dp) :: U,V,W,S,SqrtElementMetric
      REAL(KIND=dp)       :: rmlt_msh
      REAL(KIND=dp), SAVE :: rarea_msh
      REAL(KIND=dp) :: rtmp
      INTEGER :: inode
      INTEGER :: ierr
      LOGICAL :: zstat
      TYPE(Nodes_t),SAVE :: ElementNodes
      REAL(KIND=dp),ALLOCATABLE,SAVE :: Basis(:), dBasisdx(:,:)
      REAL(KIND=dp),ALLOCATABLE,SAVE :: rarea_elm(:)
      INTEGER:: M

      ! get parameters
      SolverParams => GetSolverParams()

      ! check if this is a paralell run
      Parallel=(ParEnv % PEs > 1)

      ! First call
      IF (Firsttime) THEN
         Firsttime=.False.

         ! should we mask melt by grounded mask ?
         lmask=ListGetLogical( SolverParams, 'Mask Melt', UnFoundFatal=.TRUE. )
         
         CALL INFO(SolverName,'',Level=1)
         CALL INFO(SolverName,'BASAL MELT rate definition',Level=1)
         CALL INFO(SolverName,'--------------------------',Level=1)
         WRITE(Message,'(a,L)') &
               'mask grounded cell melt at every step: ',lmask
         CALL INFO(SolverName,Message,Level=1)

         ! define GL treatment
         IF ( lmask ) THEN
            llGL=ListGetLogical( Model%Simulation, 'Grounding Line Melt', UnFoundFatal=.TRUE. )
            IF ( llGL ) THEN
               mskcrit =  0.5_dp ! Melt is at the Grounding Line and floating points
               WRITE(Message,'(a)') &
                     '   - Melt at the grounding line'
            ELSE
               mskcrit = -0.5_dp ! No melt at the Grounding Line, only floating points
               WRITE(Message,'(a)') &
                     '   - NO melt at the grounding line'
            ENDIF
            CALL INFO(SolverName,Message,Level=1)
         END IF

         ! READ NETCDF DATA
         ! ================

         ! read netcdf
         DName = ListGetString(SolverParams,'Dir Name',UnFoundFatal=.TRUE.)
         FName = ListGetString(SolverParams,'File Name',UnFoundFatal=.TRUE.)
         VarName = ListGetString(SolverParams,'Variable Name',UnFoundFatal=.TRUE.)
         TVarName = ListGetString(SolverParams,'Target Variable Name',Found)
         IF (.NOT.Found) TVarName=VarName

         WRITE(Message,'(a,a)') 'Dir name: ',TRIM(DName)
         CALL INFO(SolverName,Message,Level=1)
         WRITE(Message,'(a,a)') 'File name: ',TRIM(FName)
         CALL INFO(SolverName,Message,Level=1)
         WRITE(Message,'(a,a)') 'Variable name: ',TRIM(VarName)
         CALL INFO(SolverName,Message,Level=1)
         CALL INFO(SolverName,'--------------------------',Level=1)
         CALL INFO(SolverName,'',Level=1)

         ! get variable
         Var => VariableGet( Model % Mesh % Variables,TRIM(TVarName),UnFoundFatal=.TRUE.)
         IF(Var % TYPE /= Variable_on_elements) &
         CALL FATAL(SolverName,'Wrong variable type; use -elem ')

         CALL NCERR( NF90_OPEN(TRIM(DName)//TRIM(FName),NF90_NOWRITE,ncid), &
                     "file open failed", SolverName)

         CALL NCERR( NF90_inq_dimid(ncid, 'ncells' , varid), &
                     "unable to get ncells dim", SolverName)

         CALL NCERR( NF90_inquire_dimension(ncid,varid,len=ncells), &
                     "unable to get ncells", SolverName)

         ! get variable ID
         CALL NCERR( NF90_inq_varid(ncid,trim(VarName),TVarId), &
                     "unable to get varid", SolverName)

         ! variable dimensions
         CALL NCERR( NF90_inquire_variable(ncid, TVarId, ndims=ndims), &
                     "unable to get variable dimensions", SolverName)
      
         ALLOCATE(Values(ncells))
         Values(:)=0.0_dp

         ! if ndim > 1 we should have a time dimension
         IF (ndims.GT.1) THEN
            CALL NCERR( NF90_inq_dimid(ncid, 'time' , varid), &
                        "unable to get time dimension", SolverName)

            CALL NCERR( NF90_inquire_dimension(ncid,varid,len=ntime), &
                        "unable to get ntime", SolverName)
        
            ! check ntime lenght
            IF (ntime > 1) &
               CALL FATAL(SolverName, &
                    "E R R O R: more than one time frame in input file")

            ! get time index
            TimeIndex = 1  ! ntime > 1 not yet managed

            CALL NCERR( NF90_get_var(ncid,TVarId,Values,start=(/1,TimeIndex/),count=(/ncells,1/)), &
                        "unable to get variable", SolverName)

            WRITE(Message,'(a,i0)') 'reading time step: ',TimeIndex
            CALL INFO(SolverName,Message,level=4)

         ELSE

            CALL NCERR(nf90_get_var(ncid,TVarId,Values,start=(/1/),count=(/ncells/)) , &
                       "unable to get variable", SolverName)

         END IF

         ! close file
         CALL NCERR(NF90_close(ncid), "unable to close file", SolverName)

         ! set missing values to 0 (no melt)
         WHERE (Values == -9999._dp)
            Values = 0.0_dp
         END WHERE

         ! Compute element area for sanity check
         ! =====================================
         
         ! init
         rarea_msh = 0.0_dp

         ! allocate Basis (what is Basis ????)
         M=Model % MaxElementNodes
         ALLOCATE(Basis(M))

         ! get the number of active element (ie with ice on it ????)
         NElements = GetNOFActive()
        
         ! allocate
         ALLOCATE(rarea_elm(NElements))

         DO i=1,NElements

            ! retrive the ith element
            Element => GetActiveElement(i)

            ! get the local index
            IF (Parallel) THEN 
               EIndex=Element % GElementIndex
            ELSE
               EIndex=Element % ElementIndex
            ENDIF

            ! ????
            IntegStuff = GaussPoints( Element )

            ! get nodes for a specific element
            CALL GetElementNodes( ElementNodes,Element)
    
            ! loop over each GaussPoints (nodes ????) in the Elements
            DO inode = 1,IntegStuff % n
    
               ! ???? what is U,V,W,S
               U = IntegStuff % u(inode)
               V = IntegStuff % v(inode)
               W = IntegStuff % w(inode)
               S = IntegStuff % s(inode)
    
               ! get Element info
               zstat = ElementInfo(Element,ElementNodes,U,V,W,SqrtElementMetric, Basis)

               ! retreive Sqrt (???) Element metrics 
               rarea_elm(i)=rarea_elm(i)+SqrtElementMetric*S
            END DO

          END DO
 
          ! compute total area
          rarea_msh = SUM(rarea_elm)
    
          ! global area mean
          IF (Parallel) THEN
             CALL MPI_ALLREDUCE(rarea_msh,rtmp,1,MPI_DOUBLE_PRECISION,MPI_SUM,ELMER_COMM_WORLD,ierr)
             rarea_msh = rtmp
          ENDIF
    
          DEALLOCATE(Basis)

      END IF

      ! FILL ELMER VARIABLE
      ! ===================

      ! init     
      rmlt_msh = 0.0_dp
 
      ! get melt variable      
      Var => VariableGet( Model % Mesh % Variables,TRIM(TVarName),UnFoundFatal=.TRUE.)
      Var % Values(:) = 0.0_dp

      ! get grounded mask in case needed
      GMVar => VariableGet(Solver%Mesh%Variables,'GroundedMask',UnfoundFatal=.TRUE.)

      ! get the number of active element (ie with ice on it ????)
      NElements = GetNOFActive()
      DO i=1,NElements

         ! retrive the ith element
         Element => GetActiveElement(i)

         ! get the local index
         IF (Parallel) THEN 
           EIndex=Element % GElementIndex
         ELSE
           EIndex=Element % ElementIndex
         ENDIF

         ! fill the output variable
         zmlt = Values(EIndex)

         ! mask data if asked in sif
         IF ( lmask ) THEN
            ! get element node index
            NodeIndexes => Element % NodeIndexes

            ! mask data if any of the nodes > mskcrit
            IF ( MAXVAL( GMVar % Values(GMVar % Perm(NodeIndexes(:)) ) ) .GE. mskcrit ) &
               zmlt = 0.0
         END IF

         ! sanity check
         rmlt_msh = rmlt_msh + zmlt * rarea_elm(i)

         ! Fill Var values ready for Elmer
         Var % Values(Var % Perm(Element % ElementIndex)) = zmlt

      END DO

      ! sanity check
      IF (Parallel) THEN
         CALL MPI_ALLREDUCE(rmlt_msh,rtmp,1,MPI_DOUBLE_PRECISION,MPI_SUM,ELMER_COMM_WORLD,ierr)
         rmlt_msh = rtmp
      END IF

      CALL INFO(SolverName,'',Level=1)
      CALL INFO(SolverName,'--------------------------',Level=1)
      WRITE(Message,'(a,f12.4,f12.4)') 'BMELT [Gt/y], AREA [1e6 km2] = ', rmlt_msh*0.917_dp/1.0e9, rarea_msh/1e6/1e6
      CALL INFO(SolverName,Message,Level=1)
      CALL INFO(SolverName,'--------------------------',Level=1)
      CALL INFO(SolverName,'',Level=1)

      CONTAINS

      SUBROUTINE NCERR(istatus,cmessage, csolvername)

         USE DefUtils
         USE NETCDF

         IMPLICIT NONE

         CHARACTER(LEN=*), INTENT(in) :: cmessage, csolvername
         INTEGER         , INTENT(in) :: istatus
         IF ( istatus /= NF90_NOERR ) &
            CALL FATAL(csolvername,TRIM(cmessage))

      END SUBROUTINE NCERR

      END SUBROUTINE NCFILE_BASALMELT

